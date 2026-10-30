import QtQuick
import QtQuick.Shapes
import "."

/**
 * Note highway (Kante 1.23, for Kontra): one lane per string, the notes run from the
 * right onto the play line. Purely presentational: the app moves `position` (seconds)
 * and sets the note states; nothing here animates on its own.
 *
 *   strings, stringNames      lanes; string 0 is the lowest. `lowStringOnTop` false
 *                             (default) puts the highest string on top, as in a tab
 *   stringColors              optional colour per string (0 = lowest); where missing
 *                             KanteStyle.stringColor (the app's `stringPalette`, 1.28)
 *   notes                     [{time, duration, string, fret, state, label, cents}],
 *                             sorted by time; seconds. state: "pending", "hit", "wrong",
 *                             "missed", "early", "late", "offpitch" (1.27). cents: how
 *                             far an offpitch note was off ("+32 ct" beside its sign).
 *                             setNoteState(index, state[, cents]) changes one note
 *                             without reassigning the list; resetStates() undoes it
 *                             technique (1.31): "slide", "hammer", "pull", "slap", "pop" or
 *                             "ghost" or "dead" (1.32), its tab sign above the head
 *                             (KanteTechniqueMark); a ghost note shows its fret in
 *                             parentheses and no other sign (1.37), a dead note x. techniqueResult
 *                             (1.31): "", "played", "other", "unheard";
 *                             setTechniqueResult(index, result) changes one, resetStates()
 *                             undoes them too
 *   showCents                 the cents beside offpitch signs (Full marks only; default true)
 *   bars                      bar start times in seconds (numbers or {time, number}); number
 *                             (1.28): the bar's label, e.g. the written bar number, so
 *                             unrolled repeats read "5, 6, 5, 6"; left out: index + 1;
 *                             section (1.50): the part that starts with the bar ("Refrain",
 *                             "B", or a list ["Refrain", "B"] → "Refrain · B"), a rehearsal
 *                             mark (KanteRehearsalMark) above the bar number. With sections
 *                             the lanes move down by its row, without them the layout is the
 *                             old one
 *   position                  the current time in seconds (sits on the play line)
 *   pixelsPerSecond           speed of the highway
 *   playLine                  where the play line is, 0..1 of the width from the left
 *   loopStart, loopEnd        loop range in seconds, -1 for none
 *   marks                     Full, Quiet (play mode: string colours, small muted signs)
 *                             or Off (no states)
 *
 * A note is a square head with the fret number at its onset and a tail as long as it
 * lasts. The state shows by shape and colour: pending filled in the string colour,
 * hit filled + check, wrong filled + cross, missed hollow and dashed, early / late
 * filled + arrow (left: before the beat, right: after it), offpitch filled + wave and
 * its cents. KanteNoteMark draws the signs.
 *
 * Speed (chosen over a Canvas, which would repaint every note on every frame): the
 * notes are items on one strip at x = time × pixelsPerSecond, and only the strip moves
 * with `position` (one binding per frame, no per-note work). Each note has a light
 * placeholder (about 0.05 ms per note at load); its visuals are created asynchronously
 * when it comes within a view and a half of the play line and dropped behind it. The
 * window moves in steps of half a view, so the per-note bindings run about twice per
 * view width, not per frame. Measured with 3000 notes, about 300 in view: under 2 ms of
 * binding work per frame; 65-70 fps on llvmpipe (CPU rendering), a GPU is not the limit.
 */
Item {
    id: lane

    enum Marks {
        Full,
        Quiet,
        Off
    }

    property int strings: 4
    property var stringNames: ["E", "A", "D", "G"]
    property bool lowStringOnTop: false
    property var stringColors: []
    property var notes: []
    property var bars: []
    property real position: 0
    property real pixelsPerSecond: KanteStyle.unit(160)
    property real playLine: 0.2
    property real loopStart: -1
    property real loopEnd: -1
    /** Bar numbers above the lanes. */
    property bool barNumbers: true
    /** Name for screen readers. */
    property string accessibleName: "Tab-Lane"
    /**
     * How note states show (Kante 1.24): Full (fill and badge), Quiet (the note keeps its
     * string colour, a small muted sign beside it tells the state by shape: Kontra's play
     * mode), Off (no states, every note as pending).
     */
    property int marks: KanteTabLane.Marks.Full
    /** Cents beside the sign of an offpitch note (Kante 1.27), in Full marks. */
    property bool showCents: true
    /** Counts state changes made with setNoteState / resetStates (and new note lists). */
    readonly property int stateRevision: revision
    property int revision: 0
    // States set with setNoteState, by note index (plain object: no bindings depend on it).
    property var changedStates: ({})
    // Cents given to setNoteState, by note index.
    property var changedCents: ({})
    // Notes per state, kept up to date by setNoteState (the summary stays O(1)).
    property var stateCounts: ({})
    // Technique results set with setTechniqueResult, by note index (1.31).
    property var changedTechniques: ({})
    // Notes per technique result, kept up to date by setTechniqueResult.
    property var techniqueCounts: ({})

    /**
     * Sets how the technique of one note was played (Kante 1.31): "", "played", "other" or
     * "unheard". Like setNoteState, only that note's sign changes.
     */
    function setTechniqueResult(index, result) {
        if (!notes || index < 0 || index >= notes.length) {
            return
        }
        var old = techniqueResultOf(index)
        if (old !== "") {
            techniqueCounts[old] = (techniqueCounts[old] || 1) - 1
        }
        var r = String(result || "")
        if (r !== "") {
            techniqueCounts[r] = (techniqueCounts[r] || 0) + 1
        }
        changedTechniques[index] = r
        var it = noteRepeater.itemAt(index)
        if (it) {
            it.techniqueOverride = r
        }
        revision++
    }
    /** The technique result of note i: as set with setTechniqueResult, else from `notes`. */
    function techniqueResultOf(i) {
        var r = changedTechniques[i]
        return r !== undefined ? r : (notes && notes[i] && notes[i].techniqueResult ? String(notes[i].techniqueResult) : "")
    }

    /**
     * Sets the state of one note without reassigning `notes`: only that note's visuals
     * change (and the screen-reader summary). Cost: well under 1 ms per call with 3000 notes.
     * `cents` (optional, 1.27): how far an offpitch note was off; left out, the note's
     * `cents` in `notes` holds.
     */
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
    /** Back to the states in `notes` (e.g. a new run of the same song). */
    function resetStates() {
        changedStates = {}
        changedCents = {}
        changedTechniques = {}
        var c = {}, tc = {}
        for (var k = 0; notes && k < notes.length; k++) {
            var st = notes[k].state ? String(notes[k].state) : "pending"
            c[st] = (c[st] || 0) + 1
            var tr = notes[k].techniqueResult ? String(notes[k].techniqueResult) : ""
            if (tr !== "") {
                tc[tr] = (tc[tr] || 0) + 1
            }
        }
        stateCounts = c
        techniqueCounts = tc
        for (var i = 0; i < noteRepeater.count; i++) {
            var it = noteRepeater.itemAt(i)
            if (it) {
                it.override = ""
                it.overrideCents = NaN
                it.techniqueOverride = "-"
            }
        }
        revision++
    }
    /** The state of note i: as set with setNoteState, else from `notes`. */
    function stateOf(i) {
        var s = changedStates[i]
        return s !== undefined ? s : (notes[i] && notes[i].state ? String(notes[i].state) : "pending")
    }
    /** The cents of note i (offpitch): as set with setNoteState, else from `notes`; NaN for none. */
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

    /** Per bar: {text, next} of its rehearsal mark (1.50); next = start of the next mark. */
    readonly property var sectionList: sectionsOf(bars)
    readonly property bool hasSections: sectionList.some(function (o) { return o.text !== "" })
    /** The part being played (1.50): changes only when the bar does, not every frame. */
    readonly property int currentBarIndex: hasSections ? barIndexAt(position) : -1
    readonly property string currentPart: currentBarIndex >= 0 && sectionList[currentBarIndex] ? sectionList[currentBarIndex].part : ""

    // ── Geometry ─────────────────────────────────────────────────────
    /** Row of the rehearsal marks above the bar numbers (1.50); 0 without sections. */
    readonly property real sectionRow: hasSections ? markProbe.implicitHeight + KanteStyle.unit(4) : 0
    readonly property real topPad: sectionRow + (barNumbers ? Math.round(labelMetrics.height + KanteStyle.unit(4)) : KanteStyle.unit(2))
    readonly property real gutter: Math.round(nameMetrics.width + KanteStyle.unit(24))
    readonly property real plotWidth: Math.max(1, width - gutter)
    readonly property real laneHeight: (height - topPad) / Math.max(1, strings)
    readonly property real head: Math.max(KanteStyle.unit(12), Math.round(laneHeight * 0.72))
    readonly property real playX: Math.round(plotWidth * Math.max(0, Math.min(1, playLine)))
    readonly property real pps: Math.max(1, pixelsPerSecond)
    // Seconds before and after the play line that are in view (plus a head).
    readonly property real viewBefore: (playX + head) / pps
    readonly property real viewAfter: (plotWidth - playX + head) / pps
    readonly property real chunk: Math.max(0.25, plotWidth / pps / 2)
    readonly property real chunkStart: Math.floor(position / chunk) * chunk
    readonly property real windowFrom: chunkStart - viewBefore
    readonly property real windowTo: chunkStart + chunk + viewAfter

    implicitWidth: KanteStyle.unit(640)
    implicitHeight: topPad + Math.max(1, strings) * KanteStyle.unit(38)

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
    function nameOf(s) {
        return stringNames && s < stringNames.length ? String(stringNames[s]) : String(s + 1)
    }
    /** Next note and the count per state, for screen readers. */
    function summary(next, list, revision) {
        var counts = stateCounts
        var parts = []
        if (next >= 0) {
            var n = list[next]
            parts.push(KanteStyle.noteStateName("pending") + ": " + nameOf(n.string) + " " + n.fret)
        }
        ["hit", "offpitch", "wrong", "missed", "early", "late"].forEach(function (st) {
            if (counts[st]) {
                parts.push(KanteStyle.noteStateName(st) + " " + counts[st])
            }
        })
        var t = KanteStyle.techniqueCountsText(techniqueCounts)
        if (t !== "") {
            parts.push(t)
        }
        // The part being played comes first (1.50).
        if (currentPart !== "") {
            parts.unshift(KanteStyle.partText.arg(currentPart))
        }
        return parts.join(", ")
    }
    /**
     * Rehearsal marks by bar (1.50): [{text, next, part}]; next the time of the next bar with
     * a mark, part the mark in effect (this bar's or the last one before it).
     */
    function sectionsOf(list) {
        const out = []
        let next = Infinity
        for (let i = (list ? list.length : 0) - 1; i >= 0; i--) {
            const o = list[i]
            const text = typeof o === "object" && o !== null ? KanteStyle.rehearsalText(o.section) : ""
            out[i] = { text: text, next: next, part: text }
            if (text !== "") {
                next = barTime(o)
            }
        }
        for (let k = 1; k < out.length; k++) {
            if (out[k].part === "") {
                out[k].part = out[k - 1].part
            }
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
    /** The string palette: kept apart from the state colours (hit, wrong, early/late). */
    function stringColor(s) {
        if (stringColors && s < stringColors.length && stringColors[s] !== undefined) {
            return stringColors[s]
        }
        return KanteStyle.stringColor(s)
    }
    function rowOf(s) {
        return lowStringOnTop ? s : strings - 1 - s
    }
    function rowCenter(s) {
        return topPad + (rowOf(s) + 0.5) * laneHeight
    }
    /** Label of a bar (1.28): its `number` as sent (written bar number), else index + 1. */
    function barLabel(o, i) {
        var n = typeof o === "object" && o !== null ? o.number : undefined
        return n === undefined || n === null || String(n) === "" ? String(i + 1) : String(n)
    }
    function barTime(b) {
        return typeof b === "object" && b !== null ? Number(b.time) : Number(b)
    }

    TextMetrics {
        id: nameMetrics
        font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        text: {
            var w = "M"
            for (var s = 0; s < lane.strings; s++) {
                if (lane.nameOf(s).length > w.length) {
                    w = lane.nameOf(s)
                }
            }
            return w
        }
    }
    // Measures a mark's height for the section row.
    KanteRehearsalMark { id: markProbe; visible: false; text: "A"; Accessible.ignored: true }
    TextMetrics {
        id: labelMetrics
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
        text: "128"
    }

    // Lanes: name, colour key and the string line.
    Repeater {
        model: lane.strings
        delegate: Item {
            required property int index
            readonly property color tone: lane.stringColor(index)
            y: lane.rowCenter(index) - lane.laneHeight / 2
            width: lane.width
            height: lane.laneHeight
            Rectangle {
                visible: lane.rowOf(index) % 2 === 1
                x: lane.gutter
                width: lane.plotWidth
                height: parent.height
                color: KanteStyle.tint1Color
                opacity: 0.5
            }
            Rectangle {
                x: KanteStyle.unit(4)
                anchors.verticalCenter: parent.verticalCenter
                width: KanteStyle.unit(4)
                height: Math.min(parent.height * 0.6, KanteStyle.unit(16))
                color: parent.tone
            }
            Text {
                x: KanteStyle.unit(12)
                anchors.verticalCenter: parent.verticalCenter
                text: lane.nameOf(parent.index)
                color: KanteStyle.strongTextColor
                font: nameMetrics.font
            }
            Rectangle {
                x: lane.gutter
                width: lane.plotWidth
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(1, Math.round(KanteStyle.unit(1) + (lane.strings - 1 - parent.index) * KanteStyle.unit(1) / 2))
                color: KanteStyle.tint(parent.tone, 0.45)
            }
        }
    }

    // The highway: one strip that moves with `position`.
    Item {
        id: plot
        x: lane.gutter
        width: lane.plotWidth
        height: lane.height
        clip: true

        Item {
            id: strip
            x: lane.playX - lane.position * lane.pps
            height: plot.height

            // Loop range: a tint with bracket edges ([ and ]), not colour alone.
            Item {
                visible: lane.loopStart >= 0 && lane.loopEnd > lane.loopStart
                x: lane.loopStart * lane.pps
                width: (lane.loopEnd - lane.loopStart) * lane.pps
                y: lane.topPad
                height: plot.height - lane.topPad
                Rectangle { anchors.fill: parent; color: KanteStyle.tintHighlightColor }
                Repeater {
                    model: 2
                    delegate: Item {
                        required property int index
                        x: index === 0 ? 0 : parent.width - width
                        width: KanteStyle.unit(8)
                        height: parent.height
                        Rectangle { x: parent.index === 0 ? 0 : parent.width - width; width: 2; height: parent.height; color: KanteStyle.focusColor }
                        Rectangle { width: parent.width; height: 2; color: KanteStyle.focusColor }
                        Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: KanteStyle.focusColor }
                    }
                }
            }

            Repeater {
                model: lane.bars ? lane.bars.length : 0
                delegate: Item {
                    required property int index
                    readonly property real t: lane.barTime(lane.bars[index])
                    visible: t >= lane.windowFrom && t <= lane.windowTo
                    x: Math.round(t * lane.pps)
                    height: plot.height
                    Rectangle { y: lane.topPad; width: 1; height: plot.height - lane.topPad; color: KanteStyle.frameColor }
                    Text {
                        visible: lane.barNumbers
                        x: KanteStyle.unit(3)
                        y: lane.sectionRow
                        text: lane.barLabel(lane.bars[parent.index], parent.index)
                        color: KanteStyle.mutedTextColor
                        font: labelMetrics.font
                    }
                    // Rehearsal mark (1.50): shown only while whole in the plot (the
                    // software renderer does not clip a Shape); cut short before the next.
                    KanteRehearsalMark {
                        readonly property var sec: lane.sectionList[parent.index]
                        // Read only for a bar with a mark: the others cost nothing per frame.
                        readonly property real plotX: text !== "" ? parent.x + x + strip.x : 0
                        visible: text !== "" && plotX >= 0 && plotX + width <= plot.width
                        x: KanteStyle.unit(3)
                        y: Math.round((lane.sectionRow - height) / 2)
                        text: sec ? sec.text : ""
                        maximumWidth: sec ? Math.min(plot.width, (sec.next - parent.t) * lane.pps) - KanteStyle.unit(10) : 0
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
                    readonly property int str: Math.max(0, Math.min(lane.strings - 1, Number(n.string) || 0))
                    /** Set by setNoteState; "" = the state in `notes`. */
                    property string override: ""
                    /** Set by setNoteState with cents; NaN = the cents in `notes`. */
                    property real overrideCents: NaN
                    /** Set by setTechniqueResult; "-" = the result in `notes` (1.31). */
                    property string techniqueOverride: "-"
                    readonly property string technique: n.technique ? String(n.technique) : ""
                    readonly property string techniqueResult: lane.marks === KanteTabLane.Marks.Off ? ""
                        : (techniqueOverride !== "-" ? techniqueOverride : (n.techniqueResult ? String(n.techniqueResult) : ""))
                    readonly property real cents: !isNaN(overrideCents) ? overrideCents
                        : (n.cents !== undefined && n.cents !== null ? Number(n.cents) : NaN)
                    readonly property string st: lane.marks === KanteTabLane.Marks.Off ? "pending"
                        : (override !== "" ? override : (n.state ? String(n.state) : "pending"))
                    readonly property bool full: lane.marks === KanteTabLane.Marks.Full
                    readonly property bool hollow: st === "missed" && full
                    readonly property color fill: st === "pending" || !full ? lane.stringColor(str) : KanteStyle.noteStateColor(st)
                    readonly property bool near: t + d >= lane.windowFrom - lane.chunk && t <= lane.windowTo + lane.chunk
                    visible: t + d >= lane.windowFrom && t <= lane.windowTo
                    // A note with a cents label lies over its neighbours, so the label reads.
                    z: st === "offpitch" && full && lane.showCents && !isNaN(cents) ? 1 : 0
                    x: t * lane.pps
                    y: lane.rowCenter(str)

                    Accessible.ignored: true

                    // The note itself is made only near the window, a few frames ahead
                    // (asynchronous), so a long song costs little at load and nothing per frame.
                    Loader {
                        active: note.near
                        asynchronous: true
                        sourceComponent: Component {
                            Item {
                                // Tail: as long as the note lasts.
                                Rectangle {
                                    visible: note.d * lane.pps > lane.head / 2
                                    y: -height / 2
                                    width: note.d * lane.pps
                                    height: Math.round(lane.head * 0.3)
                                    color: KanteStyle.tint(note.fill, note.hollow ? 0.2 : 0.5)
                                }
                                Rectangle {
                                    id: headBox
                                    x: -lane.head / 2
                                    y: -lane.head / 2
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
                                    active: note.hollow
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
                                    anchors.centerIn: headBox
                                    readonly property string fretText: note.n.fret !== undefined ? String(note.n.fret) : ""
                                    // A ghost note's fret in parentheses, as written in tab (1.31); a
                                    // dead note's as x (1.32).
                                    text: note.technique === "dead" ? "x"
                                        : note.technique === "ghost" && fretText !== "" ? "(" + fretText + ")" : fretText
                                    color: note.hollow ? KanteStyle.textColor : KanteStyle.inkOn(note.fill)
                                    font.family: nameMetrics.font.family
                                    font.weight: Font.Medium
                                    font.pixelSize: Math.max(8, Math.round(lane.head * 0.56))
                                }
                                Loader {
                                    active: note.st !== "pending" && !note.hollow
                                    // Quiet: small and muted, above the head's corner.
                                    x: note.full ? headBox.x + headBox.width - width * 0.6 : headBox.x + headBox.width
                                    y: note.full ? headBox.y - height * 0.4 : headBox.y - height * 0.7
                                    width: Math.round(lane.head * (note.full ? 0.55 : 0.4))
                                    height: width
                                    sourceComponent: KanteNoteMark {
                                        noteState: note.st
                                        cents: note.cents
                                        showCents: lane.showCents && note.full
                                        badge: note.full
                                        color: note.full ? KanteStyle.noteStateColor(note.st) : KanteStyle.mutedTextColor
                                    }
                                }
                                // Technique sign above the head, left of the state badge (1.31).
                                // A ghost note's parentheses are its sign: its result frames the
                                // head (1.37).
                                KanteTechniqueMark {
                                    id: techniqueMark
                                    readonly property bool ghost: note.technique === "ghost"
                                    visible: sign !== ""
                                    signVisible: !ghost
                                    technique: note.technique
                                    result: note.techniqueResult
                                    // Quiet: muted, the result still told by the frame.
                                    color: note.full ? resultColor : KanteStyle.mutedTextColor
                                    height: ghost ? headBox.height : Math.round(lane.head * 0.5)
                                    width: ghost ? headBox.width : implicitWidth
                                    // Its right edge stops short of the badge (which starts at 0.67 head).
                                    x: ghost ? headBox.x : headBox.x + lane.head * 0.62 - width
                                    y: ghost ? headBox.y : headBox.y - height - KanteStyle.unit(1)
                                }
                                Text {
                                    visible: !!note.n.label
                                    x: headBox.x
                                    y: (techniqueMark.drawn ? techniqueMark.y : headBox.y) - height
                                    text: note.n.label || ""
                                    color: KanteStyle.mutedTextColor
                                    font: labelMetrics.font
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Play line with a diamond on top.
    Rectangle {
        x: lane.gutter + lane.playX - width / 2
        y: lane.topPad
        width: Math.max(2, KanteStyle.unit(3))
        height: lane.height - lane.topPad
        color: KanteStyle.accentColor
    }
    Rectangle {
        x: lane.gutter + lane.playX - width / 2
        y: lane.topPad - height / 2
        width: KanteStyle.unit(9)
        height: width
        rotation: 45
        color: KanteStyle.accentColor
    }
}
