import QtQuick
import QtQuick.Shapes
import "."

/**
 * Falling notes for a keyboard (Kante 1.30, for Kontra's bass over MIDI): one column per
 * key, the notes fall from the top onto the play line. Placed above a KanteKeyboard of the
 * same width, `low` and `high`, its columns stand over the keys (both use KanteKeyLayout).
 * The KanteTabLane of keys: same notes (with `midi` instead of string and fret), same
 * timing and the same calls, so an app feeds it the notes it gives the tab lane.
 * Purely presentational: the app moves `position` (seconds); nothing animates on its own.
 *
 *   low, high, noteNames, middleCOctave   the key range and names, as KanteKeyboard
 *   notes            [{time, duration, midi, state, label, cents}], sorted by time;
 *                    seconds. state as KanteTabLane: "pending", "hit", "wrong", "missed",
 *                    "early", "late", "offpitch" (with its cents)
 *                    setNoteState(index, state[, cents]), resetStates(), stateOf(i),
 *                    centsOf(i), stateRevision: one note at a time, as the tab lane
 *   bars             bar start times in seconds (numbers or {time, number}), a line across
 *                    with the bar number (`number` or index + 1) at the left; `section`
 *                    (1.50) as KanteTabLane: a rehearsal mark right of the bar number
 *   position         the current time in seconds (sits on the play line)
 *   pixelsPerSecond  speed of the fall
 *   playLine         where the play line is, 0..1 of the height from the bottom (default
 *                    0.2 as the tab lane, so played notes stay in view with their signs a
 *                    moment; 0: on the keys below); notes come from the top
 *   loopStart, loopEnd  loop range in seconds, -1 for none (tint with bracket edges)
 *   marks            Full, Quiet (notes in `noteColor`, small muted signs) or Off
 *   names            the key name (or the note's `label`) on each head, where it fits ("E1")
 *   noteColor        fill of pending notes (default KanteStyle.infoColor)
 *
 * A note is a block in its key's column, as long as it lasts, with a square head at its
 * onset (the bottom end, where it meets the play line). State by shape and colour as on
 * the tab lane: pending in `noteColor`, hit + check, wrong + cross, missed hollow and
 * dashed, early / late + arrow, offpitch + wave and its cents (KanteNoteMark).
 *
 * Speed: as KanteTabLane, the notes sit on one strip that moves with `position` (one
 * binding per frame); their visuals are made asynchronously near the view.
 */
Item {
    id: lane

    enum Marks {
        Full,
        Quiet,
        Off
    }

    property int low: 28
    property int high: 67
    property alias noteNames: layout.noteNames
    property alias middleCOctave: layout.middleCOctave
    property var notes: []
    property var bars: []
    property real position: 0
    property real pixelsPerSecond: KanteStyle.unit(120)
    property real playLine: 0.2
    property real loopStart: -1
    property real loopEnd: -1
    /** Bar numbers at the bar lines. */
    property bool barNumbers: true
    /** Key names on the notes' heads, where they fit. */
    property bool names: true
    /** Fill of a pending note (and of every note in Quiet marks). */
    property color noteColor: KanteStyle.infoColor
    property string accessibleName: "Notenspur"
    property int marks: KanteKeyLane.Marks.Full
    property bool showCents: true
    readonly property int stateRevision: revision
    property int revision: 0
    property var changedStates: ({})
    property var changedCents: ({})
    property var stateCounts: ({})

    /** The key geometry (KanteKeyLayout), e.g. to align own items with the keys. */
    readonly property KanteKeyLayout keyLayout: KanteKeyLayout {
        id: layout
        low: lane.low
        high: lane.high
        width: lane.width
    }

    /** Sets the state of one note without reassigning `notes` (as KanteTabLane). */
    function setNoteState(index, state, cents) {
        if (!notes || index < 0 || index >= notes.length) {
            return
        }
        var old = stateOf(index)
        stateCounts[old] = (stateCounts[old] || 1) - 1
        stateCounts[String(state)] = (stateCounts[String(state)] || 0) + 1
        changedStates[index] = String(state)
        if (cents !== undefined) {
            changedCents[index] = Number(cents)
        }
        var it = noteRepeater.itemAt(index)
        if (it) {
            it.override = String(state)
            if (cents !== undefined) {
                it.overrideCents = Number(cents)
            }
        }
        revision++
    }
    /** Back to the states in `notes`. */
    function resetStates() {
        changedStates = {}
        changedCents = {}
        var c = {}
        for (var k = 0; notes && k < notes.length; k++) {
            var st = notes[k].state ? String(notes[k].state) : "pending"
            c[st] = (c[st] || 0) + 1
        }
        stateCounts = c
        for (var i = 0; i < noteRepeater.count; i++) {
            var it = noteRepeater.itemAt(i)
            if (it) {
                it.override = ""
                it.overrideCents = NaN
            }
        }
        revision++
    }
    function stateOf(i) {
        var s = changedStates[i]
        return s !== undefined ? s : (notes[i] && notes[i].state ? String(notes[i].state) : "pending")
    }
    function centsOf(i) {
        var c = changedCents[i]
        if (c !== undefined) {
            return c
        }
        var n = notes && notes[i]
        return n && n.cents !== undefined && n.cents !== null ? Number(n.cents) : NaN
    }
    onNotesChanged: resetStates()

    /** Index of the next note to play (first with time ≥ position), -1 after the last. */
    readonly property int nextIndex: firstAtOrAfter(position)
    /** Per bar: {text, part} of its rehearsal mark (1.50). */
    readonly property var sectionList: sectionsOf(bars)
    readonly property bool hasSections: sectionList.some(function (o) { return o.text !== "" })
    /** The part being played (1.50): changes only when the bar does, not every frame. */
    readonly property int currentBarIndex: hasSections ? barIndexAt(position) : -1
    readonly property string currentPart: currentBarIndex >= 0 && sectionList[currentBarIndex] ? sectionList[currentBarIndex].part : ""

    // ── Geometry: time runs upwards from the play line ───────────────
    readonly property real playY: Math.round(height * (1 - Math.max(0, Math.min(1, playLine))))
    readonly property real pps: Math.max(1, pixelsPerSecond)
    readonly property real head: Math.max(KanteStyle.unit(8), Math.min(layout.whiteWidth * layout.blackWidth, KanteStyle.unit(28)))
    // Seconds below and above the play line in which a head is (partly) inside the lane.
    readonly property real pastSpan: (height - playY + head) / pps
    readonly property real futureSpan: (playY + head) / pps
    readonly property real viewBefore: (height - playY + head) / pps
    readonly property real viewAfter: (playY + head) / pps
    readonly property real chunk: Math.max(0.25, height / pps / 2)
    readonly property real chunkStart: Math.floor(position / chunk) * chunk
    readonly property real windowFrom: chunkStart - viewBefore
    readonly property real windowTo: chunkStart + chunk + viewAfter

    implicitWidth: KanteStyle.unit(680)
    implicitHeight: KanteStyle.unit(300)

    Accessible.role: Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: summary(nextIndex, notes, stateRevision)

    function firstAtOrAfter(t) {
        var a = 0, b = notes ? notes.length : 0
        while (a < b) {
            var m = (a + b) >> 1
            if (Number(notes[m].time) < t) {
                a = m + 1
            } else {
                b = m
            }
        }
        return notes && a < notes.length ? a : -1
    }
    /** Key name with octave, e.g. "E1"; as KanteKeyLayout.nameOf. */
    function nameOf(m) {
        return layout.nameOf(m)
    }
    /** Next note and the count per state, for screen readers. */
    function summary(next, list, revision) {
        var counts = stateCounts
        var parts = []
        if (next >= 0) {
            parts.push(KanteStyle.noteStateName("pending") + ": " + nameOf(Number(list[next].midi)))
        }
        ["hit", "offpitch", "wrong", "missed", "early", "late"].forEach(function (st) {
            if (counts[st]) {
                parts.push(KanteStyle.noteStateName(st) + " " + counts[st])
            }
        })
        // The part being played comes first (1.50).
        if (currentPart !== "") {
            parts.unshift(KanteStyle.partText.arg(currentPart))
        }
        return parts.join(", ")
    }
    /**
     * Rehearsal marks by bar (1.50), as KanteTabLane: [{text, part}], part the mark in
     * effect (this bar's or the last one before it).
     */
    function sectionsOf(list) {
        const out = []
        for (let i = 0; list && i < list.length; i++) {
            const o = list[i]
            const text = typeof o === "object" && o !== null ? KanteStyle.rehearsalText(o.section) : ""
            out.push({ text: text, part: text !== "" ? text : (i > 0 ? out[i - 1].part : "") })
        }
        return out
    }
    /** Index of the last bar that starts at or before t, -1 before the first. */
    function barIndexAt(t) {
        let a = 0, b = bars ? bars.length : 0
        while (a < b) {
            const m = (a + b) >> 1
            if (barTime(bars[m]) <= t + 1e-6) {
                a = m + 1
            } else {
                b = m
            }
        }
        return a - 1
    }
    function barLabel(o, i) {
        var n = typeof o === "object" && o !== null ? o.number : undefined
        return n === undefined || n === null || String(n) === "" ? String(i + 1) : String(n)
    }
    function barTime(b) {
        return typeof b === "object" && b !== null ? Number(b.time) : Number(b)
    }

    TextMetrics {
        id: labelMetrics
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
        text: "128"
    }

    // Columns: the black keys' columns tinted, a line at every C (octave).
    Repeater {
        model: layout.count
        delegate: Item {
            required property int index
            readonly property int midi: layout.first + index
            x: layout.x(midi)
            width: layout.keyWidth(midi)
            height: lane.height
            Rectangle {
                visible: layout.isBlack(parent.midi)
                anchors.fill: parent
                color: KanteStyle.tint1Color
            }
            Rectangle {
                visible: layout.pc(parent.midi) === 0
                width: 1
                height: parent.height
                color: KanteStyle.frameColor
            }
        }
    }

    Item {
        id: plot
        anchors.fill: parent
        clip: true

        // The strip: time 0 at y = 0, later times upwards (negative y); moves with `position`.
        Item {
            id: strip
            y: lane.playY + lane.position * lane.pps
            width: plot.width

            Item {
                visible: lane.loopStart >= 0 && lane.loopEnd > lane.loopStart
                y: -lane.loopEnd * lane.pps
                height: (lane.loopEnd - lane.loopStart) * lane.pps
                width: plot.width
                Rectangle { anchors.fill: parent; color: KanteStyle.tintHighlightColor }
                Repeater {
                    model: 2
                    delegate: Item {
                        required property int index
                        y: index === 0 ? parent.height - height : 0
                        height: KanteStyle.unit(8)
                        width: parent.width
                        Rectangle { y: parent.index === 0 ? parent.height - height : 0; height: 2; width: parent.width; color: KanteStyle.focusColor }
                        Rectangle { width: 2; height: parent.height; color: KanteStyle.focusColor }
                        Rectangle { x: parent.width - 2; width: 2; height: parent.height; color: KanteStyle.focusColor }
                    }
                }
            }

            Repeater {
                model: lane.bars ? lane.bars.length : 0
                delegate: Item {
                    required property int index
                    readonly property real t: lane.barTime(lane.bars[index])
                    visible: t >= lane.windowFrom && t <= lane.windowTo
                    y: -Math.round(t * lane.pps)
                    width: plot.width
                    Rectangle { width: parent.width; height: 1; color: KanteStyle.frameColor }
                    Text {
                        visible: lane.barNumbers
                        x: KanteStyle.unit(3)
                        y: -height
                        text: lane.barLabel(lane.bars[parent.index], parent.index)
                        color: KanteStyle.mutedTextColor
                        font: labelMetrics.font
                    }
                    // Rehearsal mark (1.50) above the bar line, right of the number: shown only
                    // while whole in the plot (the software renderer does not clip a Shape).
                    KanteRehearsalMark {
                        readonly property var sec: lane.sectionList[parent.index]
                        // Read only for a bar with a mark: the others cost nothing per frame.
                        readonly property real plotY: text !== "" ? parent.y + y + strip.y : 0
                        visible: text !== "" && plotY >= 0 && plotY + height <= plot.height
                        x: KanteStyle.unit(3) + (lane.barNumbers ? labelMetrics.width + KanteStyle.unit(8) : 0)
                        y: -height - KanteStyle.unit(2)
                        text: sec ? sec.text : ""
                        maximumWidth: plot.width - x - KanteStyle.unit(4)
                        Accessible.ignored: true
                    }
                }
            }

            Repeater {
                id: noteRepeater
                model: lane.notes ? lane.notes.length : 0
                delegate: Item {
                    id: note
                    required property int index
                    readonly property var n: lane.notes[index] || ({})
                    readonly property real t: Number(n.time) || 0
                    readonly property real d: Math.max(0, Number(n.duration) || 0)
                    readonly property int midi: Math.max(layout.first, Math.min(layout.last, Math.round(Number(n.midi) || 0)))
                    readonly property bool outside: Number(n.midi) < layout.first || Number(n.midi) > layout.last
                    property string override: ""
                    property real overrideCents: NaN
                    readonly property real cents: !isNaN(overrideCents) ? overrideCents
                        : (n.cents !== undefined && n.cents !== null ? Number(n.cents) : NaN)
                    readonly property string st: lane.marks === KanteKeyLane.Marks.Off ? "pending"
                        : (override !== "" ? override : (n.state ? String(n.state) : "pending"))
                    readonly property bool full: lane.marks === KanteKeyLane.Marks.Full
                    readonly property bool hollow: st === "missed" && full
                    readonly property color fill: st === "pending" || !full ? lane.noteColor : KanteStyle.noteStateColor(st)
                    readonly property bool near: t + d >= lane.windowFrom - lane.chunk && t <= lane.windowTo + lane.chunk
                    readonly property real colX: layout.x(midi)
                    readonly property real colW: layout.keyWidth(midi)
                    // The head is inside the lane. Signs (Shapes) are only made then: the
                    // software renderer does not clip a Shape, so a sign below the play line
                    // showed over the keyboard.
                    readonly property bool headIn: near && t >= lane.position - lane.pastSpan && t <= lane.position + lane.futureSpan
                    visible: !outside && t + d >= lane.windowFrom && t <= lane.windowTo
                    z: st === "offpitch" && full && lane.showCents && !isNaN(cents) ? 1 : 0
                    x: colX + colW / 2
                    y: -t * lane.pps

                    Accessible.ignored: true

                    Loader {
                        active: note.near && !note.outside
                        asynchronous: true
                        sourceComponent: Component {
                            Item {
                                // Body: as long as the note lasts, upwards from the head.
                                Rectangle {
                                    x: -width / 2
                                    y: -height
                                    width: Math.max(2, Math.round(note.colW * 0.7))
                                    height: Math.max(lane.head, note.d * lane.pps)
                                    color: KanteStyle.tint(note.fill, note.hollow ? 0.2 : 0.5)
                                }
                                Rectangle {
                                    id: headBox
                                    x: -lane.head / 2
                                    y: -lane.head
                                    width: lane.head
                                    height: lane.head
                                    color: note.hollow ? KanteStyle.backgroundColor : note.fill
                                }
                                // A wrong note's head is framed in the strong text colour (1.49): with deuteranopia its
                                // red read like a string's ochre, and the cross badge alone was too small.
                                Rectangle {
                                    objectName: "kanteWrongFrame"
                                    readonly property real w: Math.max(2, Math.round(lane.head * 0.12))
                                    visible: note.full && note.st === "wrong"
                                    anchors.fill: headBox
                                    anchors.margins: -w
                                    color: "transparent"
                                    border.width: w
                                    border.color: KanteStyle.strongTextColor
                                }
                                Loader {
                                    active: note.hollow && note.headIn
                                    anchors.fill: headBox
                                    sourceComponent: Shape {
                                        antialiasing: true
                                        ShapePath {
                                            id: dash
                                            readonly property real w: Math.max(2, Math.round(lane.head * 0.08))
                                            readonly property real a: w / 2
                                            readonly property real b: lane.head - w / 2
                                            strokeColor: note.fill
                                            strokeWidth: w
                                            fillColor: "transparent"
                                            strokeStyle: ShapePath.DashLine
                                            dashPattern: [2, 1.5]
                                            joinStyle: ShapePath.MiterJoin
                                            PathSvg { path: "M " + dash.a + " " + dash.a + " H " + dash.b + " V " + dash.b + " H " + dash.a + " Z" }
                                        }
                                    }
                                }
                                Text {
                                    id: nameText
                                    visible: lane.names && implicitWidth <= lane.head
                                    anchors.centerIn: headBox
                                    text: note.n.label ? String(note.n.label) : lane.nameOf(note.midi)
                                    color: note.hollow ? KanteStyle.textColor : KanteStyle.inkOn(note.fill)
                                    font.family: labelMetrics.font.family
                                    font.weight: Font.Medium
                                    font.pixelSize: Math.max(7, Math.round(lane.head * 0.42))
                                }
                                Loader {
                                    active: note.st !== "pending" && !note.hollow && note.headIn
                                    x: note.full ? headBox.x + headBox.width - width * 0.6 : headBox.x + headBox.width
                                    y: note.full ? headBox.y - height * 0.4 : headBox.y - height * 0.7
                                    width: Math.round(lane.head * (note.full ? 0.6 : 0.45))
                                    height: width
                                    sourceComponent: KanteNoteMark {
                                        noteState: note.st
                                        cents: note.cents
                                        showCents: lane.showCents && note.full
                                        badge: note.full
                                        color: note.full ? KanteStyle.noteStateColor(note.st) : KanteStyle.mutedTextColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Play line with a diamond at its left end.
    Rectangle {
        y: lane.playY - height / 2
        width: lane.width
        height: Math.max(2, KanteStyle.unit(3))
        color: KanteStyle.accentColor
    }
    Rectangle {
        x: -width / 2 + KanteStyle.unit(4)
        y: lane.playY - height / 2
        width: KanteStyle.unit(9)
        height: width
        rotation: 45
        color: KanteStyle.accentColor
    }
}
