import QtQuick
import "."

/**
 * Classic tablature (Kante 1.23, for Kontra): one line per string, fret numbers on the
 * lines, bar lines, repeat signs and simple rhythm below the staff (stems, flags, beams
 * within a beat, dots). It pages line by line: the top line holds the current bar, the
 * `systems - 1` lines below show what comes next, and the lines jump (no scrolling)
 * when the current bar leaves the top line. The current note sits on a selection band;
 * `cursor` adds a thin line at `position`.
 *
 *   strings, stringNames, lowStringOnTop   as KanteTabLane (string 0 = lowest; the
 *                                          highest string on top by default)
 *   stringColors as KanteTabLane (1.28): colours the string lines and the fret numbers of
 *                pending notes (and of all notes in Quiet marks; in Full the state colour
 *                wins); where missing KanteStyle.stringColor (the app's `stringPalette`)
 *   notes        [{time, duration, beats, string, fret, state, label, cents}], sorted by time;
 *                time and duration in seconds, beats = duration in quarter notes (1 a
 *                quarter, 0.5 an eighth, 1.5 a dotted quarter). Notes with the same time
 *                form a chord (one stem). state as KanteTabLane, "offpitch" (1.27) with
 *                its `cents` beside the sign (`showCents`, Full marks)
 *                technique, techniqueResult (1.31) as KanteTabLane: the tab sign beside the
 *                fret number (KanteTechniqueMark), a ghost note's fret in parentheses (its
 *                only sign, 1.37),
 *                a dead note's (1.32, "dead") as x;
 *                setTechniqueResult(index, result) changes a result without a new layout
 *   bars         bar start times in seconds, numbers or {time, number, repeatStart, repeatEnd,
 *                endings}; number (Kante 1.28): the bar's label, e.g. the written bar number,
 *                so unrolled repeats read "5, 6, 5, 6" (a number or a string; left out:
 *                index + 1);
 *                endings (Kante 1.28): the alternate endings (volta) the bar belongs to, as
 *                written, e.g. [1] or [1, 2] (a single number n reads as [n]); left out or
 *                [] for none. Bars in a row with the same endings share one bracket, numbered
 *                "1." or "1., 2." at its start; it is closed on the right when its last bar
 *                ends with a repeat sign (repeatEnd), else open (the last ending). A bracket
 *                that runs on to the next line goes on there without number and hook. With
 *                endings the staff moves down by the bracket row, without them the layout is
 *                the old one;
 *                section (Kante 1.50): the part that starts with the bar ("Refrain", "B", or
 *                a list ["Refrain", "B"] → "Refrain · B"), a rehearsal mark
 *                (KanteRehearsalMark) above the bar, cut short before the next mark on the
 *                line. With sections the staff moves down by their row; screen readers hear
 *                the part of the current bar ("Teil Refrain · B", KanteStyle.partText)
 *   position     the current time in seconds
 *   barsPerSystem  bars per line, 0 = as many as fit (`minBarWidth` each)
 *   systems      lines shown
 *   marks        Full, Quiet (fret numbers in the text colour, small muted signs) or Off;
 *                setNoteState(index, state[, cents]) / resetStates() change states without a new
 *                layout (the layout is computed once per page, the states are read live)
 *   loopStart, loopEnd  loop range in seconds, -1 for none (1.35): a tint with bracket edges
 *                as on KanteTabLane, one part per line; a loop that runs on to the next
 *                line is open at the line end and goes on there without bracket. An edge
 *                on a bar start or end sits on the bar line
 *
 * The state of a note shows above the staff as a KanteNoteMark and in the colour of
 * its fret number. The layout is computed once per page (not per frame): only the
 * band and the cursor follow `position`. Rhythm glyphs (flags) come from Bravura
 * (SMuFL, SIL OFL, fonts/OFL-Bravura.txt).
 */
Item {
    id: staff

    enum Marks {
        Full,
        Quiet,
        Off
    }

    property int strings: 4
    property var stringNames: ["E", "A", "D", "G"]
    property bool lowStringOnTop: false
    /** Colour per string, 0 = lowest (1.28); where missing KanteStyle.stringColor. */
    property var stringColors: []
    property var notes: []
    property var bars: []
    property real position: 0
    /** Loop range in seconds, -1 for none (1.35). */
    property real loopStart: -1
    property real loopEnd: -1
    property int barsPerSystem: 0
    property int systems: 1
    property bool rhythm: true
    property bool cursor: true
    property real lineSpacing: KanteStyle.unit(14)
    property real minBarWidth: KanteStyle.unit(200)
    /** Ground behind the fret numbers (they interrupt the string line). */
    property color groundColor: KanteStyle.backgroundColor
    property string accessibleName: "Tabulatur"
    /** Text of the bar in the screen-reader description; %1 bar, %2 of. */
    property string barText: "Takt %1 von %2"
    /** Text of a bar's endings in the screen-reader description (1.28); %1 e.g. "1, 2". */
    property string endingText: "Volta %1"
    /**
     * How note states show (Kante 1.24): Full (state colour and sign), Quiet (notes in the
     * text colour, small muted signs that tell the state by shape: Kontra's play mode),
     * Off (no states).
     */
    property int marks: KanteTabStaff.Marks.Full
    /** Counts state changes made with setNoteState / resetStates (and new note lists). */
    readonly property int stateRevision: revision
    property int revision: 0
    // States set with setNoteState, by note index (plain object, read through stateRevision).
    property var changedStates: ({})
    // Cents given to setNoteState, by note index.
    property var changedCents: ({})
    /** Cents beside the sign of an offpitch note (Kante 1.27), in Full marks. */
    property bool showCents: true
    // Technique results set with setTechniqueResult, by note index (1.31).
    property var changedTechniques: ({})

    /** Sets how the technique of one note was played (Kante 1.31): "", "played", "other", "unheard". */
    function setTechniqueResult(index, result) {
        if (!notes || index < 0 || index >= notes.length) {
            return
        }
        changedTechniques[index] = String(result || "")
        revision++
    }
    /** The technique result of note i: as set with setTechniqueResult, else from `notes`. */
    function techniqueResultOf(i) {
        var r = changedTechniques[i]
        return r !== undefined ? r : (notes && notes[i] && notes[i].techniqueResult ? String(notes[i].techniqueResult) : "")
    }
    /** The result as shown: "" when marks are Off. Depends on stateRevision. */
    function shownTechniqueResult(i, revision) {
        return marks === KanteTabStaff.Marks.Off ? "" : techniqueResultOf(i)
    }
    /** "Technik gespielt 3, Andere Technik 1" over all notes (screen readers). Depends on stateRevision. */
    function techniqueSummary(revision) {
        var counts = {}
        for (var i = 0; notes && i < notes.length; i++) {
            var r = shownTechniqueResult(i, revision)
            if (r !== "") {
                counts[r] = (counts[r] || 0) + 1
            }
        }
        return KanteStyle.techniqueCountsText(counts)
    }

    /**
     * Sets the state of one note without reassigning `notes` (no new layout, only colours and
     * signs). `cents` (optional, 1.27): how far an offpitch note was off; left out, the
     * note's `cents` in `notes` holds.
     */
    function setNoteState(index, state, cents) {
        if (!notes || index < 0 || index >= notes.length) {
            return
        }
        changedStates[index] = String(state)
        if (cents !== undefined) {
            changedCents[index] = Number(cents)
        }
        revision++
    }
    /** Back to the states in `notes`. */
    function resetStates() {
        changedStates = {}
        changedCents = {}
        changedTechniques = {}
        revision++
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
    /** ", +32 ct" for an offpitch note with cents (screen readers), else "". Depends on stateRevision. */
    function centsSuffix(i, revision) {
        var t = shownState(i, revision) === "offpitch" ? KanteStyle.centsText(centsOf(i)) : ""
        return t !== "" ? ", " + t : ""
    }
    /** The state of note i: as set with setNoteState, else from `notes`. */
    function stateOf(i) {
        var s = changedStates[i]
        return s !== undefined ? s : (notes && notes[i] && notes[i].state ? String(notes[i].state) : "pending")
    }
    /** The state as shown: "pending" when marks are Off. Depends on stateRevision. */
    function shownState(i, revision) {
        return marks === KanteTabStaff.Marks.Off || i === undefined ? "pending" : stateOf(i)
    }
    onNotesChanged: resetStates()

    /** Last note with time ≤ position, -1 before the first. */
    readonly property int currentIndex: lastAtOrBefore(position)
    readonly property var barList: normalizeBars(bars, notes)
    readonly property int currentBar: barAt(position)
    readonly property real ls: Math.max(6, lineSpacing)
    readonly property int perSystem: barsPerSystem > 0 ? barsPerSystem
        : Math.max(1, Math.floor((width - headerWidth) / Math.max(1, minBarWidth)))
    readonly property int firstBar: Math.max(0, Math.floor(currentBar / perSystem) * perSystem)

    readonly property real markRow: ls * 1.3
    /** Any bar with endings: then a row for the volta brackets above the bar numbers. */
    readonly property bool hasEndings: barList.some(function (b) { return b.endings.length > 0 })
    readonly property real endingRow: hasEndings ? ls * 1.6 : 0
    /** Any bar with a section: then a row for the rehearsal marks on top (1.50). */
    readonly property bool hasSections: barList.some(function (b) { return b.section !== "" })
    readonly property real sectionRow: hasSections ? markProbe.implicitHeight + ls * 0.4 : 0
    readonly property real staffTop: sectionRow + endingRow + markRow + ls * 0.5
    readonly property real staffHeight: (Math.max(1, strings) - 1) * ls
    readonly property real systemHeight: staffTop + staffHeight + (rhythm ? ls * 3.2 : ls * 0.8) + ls * 0.4
    readonly property real headerWidth: Math.round(nameMetrics.width + ls * 2.6)
    readonly property real barWidth: (width - headerWidth) / perSystem

    readonly property var layout: computeLayout(firstBar, perSystem, Math.max(1, systems), width, ls, notes, barList,
                                                strings, lowStringOnTop, rhythm)
    /** Loop parts of the page, one per line: [{x, w, sys, left, right}] (1.35). */
    readonly property var loopParts: loopLayout(firstBar, perSystem, Math.max(1, systems), width, barList,
                                                loopStart, loopEnd)

    implicitWidth: KanteStyle.unit(720)
    implicitHeight: Math.ceil(systemHeight * Math.max(1, systems))

    Accessible.role: Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: {
        let d = barText.arg(barList.length ? barList[currentBar].number : 1).arg(barList.length)
        const cb = barList[currentBar]
        if (cb && cb.part !== "") {
            d += ", " + KanteStyle.partText.arg(cb.part)
        }
        if (cb && cb.endings.length > 0) {
            d += ", " + endingText.arg(cb.endings.join(", "))
        }
        // notes can change before currentIndex follows (e.g. emptied while playing)
        const n = currentIndex >= 0 ? notes[currentIndex] : undefined
        if (n) {
            d += ", " + nameOf(Number(n.string) || 0) + " " + n.fret + " (" + KanteStyle.noteStateName(shownState(currentIndex, stateRevision)) + centsSuffix(currentIndex, stateRevision) + ")"
        }
        const t = techniqueSummary(stateRevision)
        if (t !== "") {
            d += ", " + t
        }
        return d
    }

    FontLoader { id: music; source: Qt.resolvedUrl("fonts/Bravura.otf") }
    TextMetrics {
        id: nameMetrics
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
        text: {
            var w = "M"
            for (var s = 0; s < staff.strings; s++) {
                if (staff.nameOf(s).length > w.length) {
                    w = staff.nameOf(s)
                }
            }
            return w
        }
    }

    function stringColor(s) {
        if (stringColors && s < stringColors.length && stringColors[s] !== undefined) {
            return stringColors[s]
        }
        return KanteStyle.stringColor(s)
    }
    function nameOf(s) {
        return stringNames && s < stringNames.length ? String(stringNames[s]) : String(s + 1)
    }
    function lastAtOrBefore(t) {
        var a = 0, b = notes ? notes.length : 0
        while (a < b) {
            var m = (a + b) >> 1
            if (Number(notes[m].time) <= t + 1e-6) {
                a = m + 1
            } else {
                b = m
            }
        }
        return a - 1
    }
    /** Bars as [{time, end, repeatStart, repeatEnd, endings}]; one bar over all notes when none are given. */
    function normalizeBars(list, ns) {
        var out = []
        for (var i = 0; list && i < list.length; i++) {
            var b = list[i]
            var o = typeof b === "object" && b !== null ? b : { time: b }
            out.push({ time: Number(o.time) || 0, repeatStart: !!o.repeatStart, repeatEnd: !!o.repeatEnd,
                       endings: endingsOf(o.endings), number: barLabel(o, i),
                       section: KanteStyle.rehearsalText(o.section), part: "" })
        }
        var lastEnd = 0
        for (var k = 0; ns && k < ns.length; k++) {
            lastEnd = Math.max(lastEnd, Number(ns[k].time) + Math.max(0, Number(ns[k].duration) || 0))
        }
        if (out.length === 0) {
            out.push({ time: ns && ns.length ? Math.min(0, Number(ns[0].time)) : 0, repeatStart: false, repeatEnd: false,
                       endings: [], number: "1", section: "", part: "" })
        }
        // The part in effect: this bar's section or the last one before it (1.50).
        for (let p = 0; p < out.length; p++) {
            out[p].part = out[p].section !== "" ? out[p].section : (p > 0 ? out[p - 1].part : "")
        }
        for (var j = 0; j < out.length; j++) {
            if (j + 1 < out.length) {
                out[j].end = out[j + 1].time
            } else {
                var len = j > 0 ? out[j].time - out[j - 1].time : lastEnd - out[j].time
                out[j].end = out[j].time + Math.max(len > 0 ? len : 2, lastEnd - out[j].time)
            }
        }
        return out
    }
    /** Label of a bar (1.28): its `number` as sent (written bar number), else index + 1. */
    function barLabel(o, i) {
        var n = typeof o === "object" && o !== null ? o.number : undefined
        return n === undefined || n === null || String(n) === "" ? String(i + 1) : String(n)
    }
    /** Endings of a bar as a sorted list of numbers ≥ 1: [1, 2] stays, 2 becomes [2], none []. */
    function endingsOf(e) {
        // A list from QML or C++ is not always a JS Array: test for a length.
        var list = e === undefined || e === null ? [] : (typeof e === "object" && e.length !== undefined ? e : [e])
        var out = []
        for (var i = 0; i < list.length; i++) {
            var n = Math.round(Number(list[i]))
            if (n >= 1 && out.indexOf(n) < 0) {
                out.push(n)
            }
        }
        return out.sort(function (a, b) { return a - b })
    }
    function barAt(t) {
        var a = 0, b = barList.length
        while (a < b) {
            var m = (a + b) >> 1
            if (barList[m].time <= t + 1e-6) {
                a = m + 1
            } else {
                b = m
            }
        }
        return Math.max(0, a - 1)
    }
    function rowOf(s) {
        return lowStringOnTop ? s : strings - 1 - s
    }
    /** x of time t in bar b on its line (padding left and right of the bar). */
    function xOf(t, b) {
        var bar = barList[b]
        var col = (b - firstBar) % perSystem
        var padL = ls * 1.2, padR = ls * 0.8
        var f = (t - bar.time) / Math.max(1e-6, bar.end - bar.time)
        return headerWidth + col * barWidth + padL + Math.max(0, Math.min(1, f)) * (barWidth - padL - padR)
    }
    function sysOf(b) {
        return Math.floor((b - firstBar) / perSystem)
    }
    /** True when time t lies in the loop range (1.35). */
    function inLoop(t) {
        return loopStart >= 0 && loopEnd > loopStart && t >= loopStart - 1e-6 && t < loopEnd - 1e-6
    }
    /** x of a loop edge at time t in bar b: on the bar line at a bar start or end, else xOf. */
    function loopX(t, b) {
        var bar = barList[b]
        var left = headerWidth + ((b - firstBar) % perSystem) * barWidth
        if (Math.abs(t - bar.time) < 1e-3) {
            return left
        }
        if (Math.abs(t - bar.end) < 1e-3) {
            return left + barWidth
        }
        return xOf(t, b)
    }
    /**
     * The loop cut into lines: per line the part of [from, to] it shows. left / right: the
     * loop starts / ends on this line (bracket edge), else it runs on (open edge).
     */
    function loopLayout(first, per, nsys, w, bl, from, to) {
        var out = []
        if (w <= 0 || bl.length === 0 || from < 0 || to <= from) {
            return out
        }
        var last = Math.min(bl.length - 1, first + per * nsys - 1)
        for (var s = 0; s < nsys; s++) {
            let b0 = first + s * per
            let b1 = Math.min(last, b0 + per - 1)
            if (b1 < b0) {
                break
            }
            let t0 = Math.max(from, bl[b0].time)
            let t1 = Math.min(to, bl[b1].end)
            if (t1 <= t0 + 1e-6) {
                continue
            }
            // The bar of each edge, kept on this line; the end belongs to the bar before it.
            let x0 = loopX(t0, Math.max(b0, Math.min(b1, barAt(t0))))
            let x1 = loopX(t1, Math.max(b0, Math.min(b1, barAt(t1 - 1e-3))))
            out.push({ x: x0, w: Math.max(1, x1 - x0), sys: s, left: from >= bl[b0].time - 1e-6,
                       right: to <= bl[b1].end + 1e-6 })
        }
        return out
    }
    /** Rhythm of a duration in quarters: {level: beams/flags (0 none), stem: 0 none / 1 short / 2 full, dot}. */
    function rhythmOf(beats) {
        var b = Number(beats) || 0
        var bases = [[4, 0, 0], [2, 0, 1], [1, 0, 2], [0.5, 1, 2], [0.25, 2, 2], [0.125, 3, 2]]
        for (var i = 0; i < bases.length; i++) {
            var base = bases[i][0]
            if (Math.abs(b - base * 1.5) < 1e-3) {
                return { level: bases[i][1], stem: bases[i][2], dot: true }
            }
            if (b >= base - 1e-3) {
                return { level: bases[i][1], stem: bases[i][2], dot: false }
            }
        }
        return { level: 3, stem: 2, dot: false }
    }

    function computeLayout(first, per, nsys, w, ls, ns, bl, nstr, lowTop, withRhythm) {
        var L = { lines: [], frets: [], marks: [], rects: [], flags: [], heads: [], endings: [], sections: [], boxes: {} }
        if (w <= 0 || bl.length === 0) {
            return L
        }
        var last = Math.min(bl.length - 1, first + per * nsys - 1)
        for (var s = 0; s < nsys; s++) {
            var sy = s * systemHeight
            var top = sy + staffTop
            var used = Math.min(per, Math.max(0, last - (first + s * per) + 1))
            var right = headerWidth + used * barWidth
            if (used <= 0) {
                continue
            }
            for (var l = 0; l < nstr; l++) {
                L.lines.push({ x: headerWidth - ls * 0.4, y: top + l * ls, w: right - headerWidth + ls * 0.4, h: 1, kind: "line",
                               str: lowTop ? l : nstr - 1 - l })
            }
            L.heads.push({ y: top, sys: s })
            L.lines.push({ x: headerWidth - ls * 0.4, y: top, w: 1, h: staffHeight + 1, kind: "bar" })
            for (var c = 0; c < used; c++) {
                var bi = first + s * per + c
                var bx = headerWidth + c * barWidth
                var bar = bl[bi]
                L.lines.push({ x: bx + barWidth - 1, y: top, w: 1, h: staffHeight + 1, kind: "bar" })
                L.heads.push({ y: sy + sectionRow + endingRow, x: bx, number: bar.number })
                if (bar.repeatStart) {
                    L.lines.push({ x: bx, y: top, w: Math.max(2, ls * 0.25), h: staffHeight + 1, kind: "bar" })
                    L.rects.push({ x: bx + ls * 0.5, y: 0, sys: s, kind: "dots" })
                }
                if (bar.repeatEnd) {
                    L.lines.push({ x: bx + barWidth - Math.max(2, ls * 0.25), y: top, w: Math.max(2, ls * 0.25), h: staffHeight + 1, kind: "bar" })
                    L.rects.push({ x: bx + barWidth - ls * 0.75, y: 0, sys: s, kind: "dots" })
                }
            }
        }
        // Rehearsal marks (1.50): over the first bar of a part, as wide as the room up to the
        // next mark on the line (or the line's end).
        for (let ms = 0; ms < nsys; ms++) {
            let mFirst = first + ms * per
            let mLast = Math.min(last, mFirst + per - 1)
            for (let mb = mLast, mRight = headerWidth + (mLast - mFirst + 1) * barWidth; mb >= mFirst; mb--) {
                if (bl[mb].section === "") {
                    continue
                }
                let mx = headerWidth + (mb - mFirst) * barWidth + ls * 0.2
                L.sections.push({ x: mx, y: ms * systemHeight, sys: ms, text: bl[mb].section, maxW: mRight - mx - ls * 0.5 })
                mRight = mx
            }
        }
        L.sections.reverse()
        // Volta brackets: one per run of bars with the same endings, cut at the end of a line.
        for (var es = 0; es < nsys; es++) {
            var eFirst = first + es * per
            var eLast = Math.min(last, eFirst + per - 1)
            for (var eb = eFirst; eb <= eLast; eb++) {
                var key = bl[eb].endings.join(",")
                if (key === "") {
                    continue
                }
                var runEnd = eb
                while (runEnd + 1 <= eLast && bl[runEnd + 1].endings.join(",") === key) {
                    runEnd++
                }
                var starts = eb === 0 || bl[eb - 1].endings.join(",") !== key
                var ends = runEnd + 1 >= bl.length || bl[runEnd + 1].endings.join(",") !== key
                var ex0 = headerWidth + (eb - eFirst) * barWidth
                var ex1 = headerWidth + (runEnd - eFirst + 1) * barWidth
                L.endings.push({
                    x: ex0 + (starts ? ls * 0.25 : 0), w: ex1 - ex0 - (starts ? ls * 0.25 : 0) - (ends ? ls * 0.5 : 0),
                    y: es * systemHeight + sectionRow + ls * 0.3, sys: es,
                    text: starts ? bl[eb].endings.map(function (n) { return n + "." }).join(", ") : "",
                    left: starts, right: ends && bl[runEnd].repeatEnd
                })
                eb = runEnd
            }
        }
        // Notes of the page.
        var from = bl[first].time, to = bl[last].end
        var onsets = []
        for (var i = 0; ns && i < ns.length; i++) {
            var n = ns[i]
            var t = Number(n.time)
            if (t < from - 1e-6 || t >= to - 1e-6) {
                continue
            }
            var b = barAt(t)
            var x = xOf(t, b)
            var sys = sysOf(b)
            var str = Math.max(0, Math.min(nstr - 1, Number(n.string) || 0))
            var y = sys * systemHeight + staffTop + rowOf(str) * ls
            var fretText = n.fret !== undefined ? String(n.fret) : ""
            var technique = n.technique ? String(n.technique) : ""
            // A ghost note's fret in parentheses, as written in tab (1.31).
            if (technique === "ghost" && fretText !== "") {
                fretText = "(" + fretText + ")"
            }
            // A dead note reads x instead of its fret (1.32).
            if (technique === "dead") {
                fretText = "x"
            }
            L.frets.push({ x: x, y: y, text: fretText, index: i, label: n.label || "", str: str, technique: technique, time: t })
            L.boxes[i] = { x: x, sys: sys }
            var prev = onsets.length ? onsets[onsets.length - 1] : null
            if (prev && Math.abs(prev.t - t) < 1e-3) {
                prev.indices.push(i)
                continue
            }
            var dur = Math.max(0, Number(n.duration) || 0)
            var beats = Number(n.beats) || 0
            var spq = dur > 0 && beats > 0 ? dur / beats : (bl[b].end - bl[b].time) / 4
            onsets.push({ t: t, x: x, sys: sys, bar: b, beat: Math.floor((t - bl[b].time) / spq + 1e-3),
                          r: rhythmOf(beats > 0 ? beats : dur / spq), indices: [i] })
        }
        for (var o = 0; o < onsets.length; o++) {
            var on = onsets[o]
            // One sign per onset (a chord shows its first non-pending state); hidden while pending.
            L.marks.push({ x: on.x, y: on.sys * systemHeight + sectionRow + endingRow + markRow / 2, indices: on.indices })
        }
        if (!withRhythm) {
            return L
        }
        // Stems, dots, beams within a beat, flags for single short notes.
        var stemW = Math.max(1, Math.round(ls * 0.1))
        var beamH = Math.max(2, Math.round(ls * 0.28))
        for (var k = 0; k < onsets.length; k++) {
            var e = onsets[k]
            var y0 = e.sys * systemHeight + staffTop + staffHeight + ls * 0.6
            var y1 = y0 + ls * 2.1
            e.y1 = y1
            if (e.r.stem > 0) {
                L.lines.push({ x: e.x - stemW / 2, y: e.r.stem === 1 ? y1 - ls * 1.0 : y0, w: stemW, h: e.r.stem === 1 ? ls * 1.0 : y1 - y0, kind: "stem" })
            }
            if (e.r.dot) {
                L.lines.push({ x: e.x + ls * 0.35, y: y1 - ls * 0.45, w: Math.max(2, ls * 0.24), h: Math.max(2, ls * 0.24), kind: "stem" })
            }
        }
        var g = 0
        while (g < onsets.length) {
            var h = g
            if (onsets[g].r.level > 0) {
                while (h + 1 < onsets.length && onsets[h + 1].r.level > 0 && onsets[h + 1].bar === onsets[g].bar
                       && onsets[h + 1].beat === onsets[g].beat && onsets[h + 1].sys === onsets[g].sys) {
                    h++
                }
            }
            if (h > g) {
                var gx0 = onsets[g].x - stemW / 2, gx1 = onsets[h].x + stemW / 2
                L.lines.push({ x: gx0, y: onsets[g].y1 - beamH, w: gx1 - gx0, h: beamH, kind: "beam" })
                for (var lv = 2; lv <= 3; lv++) {
                    var off = (lv - 1) * (beamH + Math.max(2, ls * 0.18))
                    for (var q = g; q <= h; q++) {
                        if (onsets[q].r.level < lv) {
                            continue
                        }
                        var r = q
                        while (r + 1 <= h && onsets[r + 1].r.level >= lv) {
                            r++
                        }
                        if (r > q) {
                            L.lines.push({ x: onsets[q].x - stemW / 2, y: onsets[q].y1 - beamH - off, w: onsets[r].x - onsets[q].x + stemW, h: beamH, kind: "beam" })
                        } else {
                            var stub = ls * 0.8
                            var left = q === h
                            L.lines.push({ x: left ? onsets[q].x - stub : onsets[q].x - stemW / 2, y: onsets[q].y1 - beamH - off, w: stub + stemW / 2, h: beamH, kind: "beam" })
                        }
                        q = r
                    }
                }
            } else if (onsets[g].r.level > 0) {
                L.flags.push({ x: onsets[g].x - stemW / 2, y: onsets[g].y1, glyph: ["", "", "", ""][onsets[g].r.level] })
            }
            g = h + 1
        }
        return L
    }

    // Loop range (1.35): a tint with bracket edges ([ and ]) as on KanteTabLane, not colour
    // alone; as high as the cursor, behind the staff so frets stay readable.
    Repeater {
        model: staff.loopParts
        delegate: Item {
            id: loopPart
            required property var modelData
            x: modelData.x
            y: modelData.sys * staff.systemHeight + staff.staffTop - staff.ls * 0.8
            width: modelData.w
            height: staff.staffHeight + staff.ls * 1.6
            Rectangle { anchors.fill: parent; color: KanteStyle.tintHighlightColor }
            Repeater {
                model: [loopPart.modelData.left, loopPart.modelData.right]
                delegate: Item {
                    required property int index
                    required property var modelData
                    visible: modelData === true
                    x: index === 0 ? 0 : loopPart.width - width
                    width: KanteStyle.unit(8)
                    height: loopPart.height
                    Rectangle { x: parent.index === 0 ? 0 : parent.width - width; width: 2; height: parent.height; color: KanteStyle.focusColor }
                    Rectangle { width: parent.width; height: 2; color: KanteStyle.focusColor }
                    Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: KanteStyle.focusColor }
                }
            }
        }
    }

    // Selection band behind the current note.
    Rectangle {
        readonly property var box: staff.currentIndex >= 0 ? staff.layout.boxes[staff.currentIndex] : undefined
        visible: box !== undefined
        x: visible ? box.x - staff.ls * 0.8 : 0
        y: visible ? box.sys * staff.systemHeight + staff.staffTop - staff.ls * 0.6 : 0
        width: staff.ls * 1.6
        height: staff.staffHeight + staff.ls * 1.2
        color: KanteStyle.selectionColor
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: KanteStyle.focusColor }
    }

    Repeater {
        model: staff.layout.lines
        delegate: Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: modelData.kind === "line" ? staff.stringColor(modelData.str)
                 : modelData.kind === "bar" ? KanteStyle.textColor : KanteStyle.textColor
            // On a light ground the string lines take their full colour: at 0.7 they missed 3:1
            // (1.51, a beamer in Kante Light).
            opacity: modelData.kind === "line" && !(KanteStyle.active && KanteStyle.light) ? 0.7 : 1
        }
    }

    // Repeat dots: in the spaces next to the middle of the staff.
    Repeater {
        model: staff.layout.rects
        delegate: Item {
            required property var modelData
            readonly property int spaces: Math.max(1, staff.strings - 1)
            readonly property real mid: staff.staffHeight / 2
            readonly property real d: spaces % 2 === 1 ? staff.ls : staff.ls / 2
            x: modelData.x
            y: modelData.sys * staff.systemHeight + staff.staffTop
            Repeater {
                model: 2
                delegate: Rectangle {
                    required property int index
                    width: Math.max(3, staff.ls * 0.32)
                    height: width
                    x: -width / 2
                    y: (index === 0 ? parent.mid - parent.d : parent.mid + parent.d) - height / 2
                    color: KanteStyle.textColor
                }
            }
        }
    }

    // Volta brackets: a line over the bars of an ending, a hook down at its start (with the
    // number) and, when the ending closes with a repeat sign, at its end.
    Repeater {
        model: staff.layout.endings
        delegate: Item {
            id: volta
            required property var modelData
            readonly property real stroke: Math.max(1, Math.round(staff.ls * 0.1))
            readonly property real hook: staff.endingRow - staff.ls * 0.5
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: hook
            Rectangle { width: parent.width; height: volta.stroke; color: KanteStyle.textColor }
            Rectangle { visible: volta.modelData.left; width: volta.stroke; height: volta.hook; color: KanteStyle.textColor }
            Rectangle { visible: volta.modelData.right; x: parent.width - width; width: volta.stroke; height: volta.hook; color: KanteStyle.textColor }
            Text {
                visible: text !== ""
                x: staff.ls * 0.35
                y: volta.stroke + staff.ls * 0.05
                text: volta.modelData.text
                color: KanteStyle.strongTextColor
                font.family: nameMetrics.font.family
                font.weight: Font.Bold
                font.pixelSize: Math.round(staff.ls * 0.8)
            }
        }
    }

    // Rehearsal marks (1.50); the probe measures the row.
    KanteRehearsalMark { id: markProbe; visible: false; text: "A"; pixelSize: staff.ls; Accessible.ignored: true }
    Repeater {
        model: staff.layout.sections
        delegate: KanteRehearsalMark {
            required property var modelData
            x: modelData.x
            y: modelData.y + Math.round((staff.sectionRow - height) / 2)
            text: modelData.text
            pixelSize: staff.ls
            maximumWidth: modelData.maxW
            groundColor: staff.groundColor
            Accessible.ignored: true
        }
    }

    // Line heads: string names and TAB; bar numbers.
    Repeater {
        model: staff.layout.heads
        delegate: Item {
            id: hd
            required property var modelData
            readonly property bool line: modelData.sys !== undefined
            Repeater {
                model: hd.line ? staff.strings : 0
                delegate: Text {
                    required property int index
                    x: KanteStyle.unit(2)
                    y: hd.modelData.y + staff.rowOf(index) * staff.ls - height / 2
                    text: staff.nameOf(index)
                    color: KanteStyle.mutedTextColor
                    font: nameMetrics.font
                }
            }
            Column {
                visible: hd.line
                x: nameMetrics.width + staff.ls * 0.8
                y: hd.line ? hd.modelData.y + (staff.staffHeight - height) / 2 : 0
                spacing: -staff.ls * 0.25
                Repeater {
                    model: ["T", "A", "B"]
                    delegate: Text {
                        required property string modelData
                        text: modelData
                        color: KanteStyle.strongTextColor
                        font.family: KanteStyle.headingFont(10).family
                        font.weight: Font.Bold
                        font.pixelSize: Math.round(Math.min(staff.ls * 1.0, (staff.staffHeight + staff.ls) / 3))
                    }
                }
            }
            Text {
                visible: !hd.line
                x: hd.line ? 0 : hd.modelData.x + KanteStyle.unit(2)
                y: hd.line ? 0 : hd.modelData.y
                text: hd.line ? "" : hd.modelData.number
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
            }
        }
    }

    Repeater {
        model: staff.layout.frets
        delegate: Rectangle {
            required property var modelData
            readonly property bool current: modelData.index === staff.currentIndex
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            width: fret.implicitWidth + staff.ls * 0.3
            height: Math.round(staff.ls * 0.95)
            // In the loop the ground carries the loop tint (1.35).
            color: current ? "transparent"
                 : staff.inLoop(modelData.time) ? Qt.tint(staff.groundColor, KanteStyle.tintHighlightColor) : staff.groundColor
            Text {
                id: fret
                anchors.centerIn: parent
                text: parent.modelData.text
                readonly property string st: staff.shownState(parent.modelData.index, staff.stateRevision)
                color: st === "pending" || staff.marks !== KanteTabStaff.Marks.Full
                     ? (parent.current ? KanteStyle.strongTextColor : staff.stringColor(parent.modelData.str))
                     : KanteStyle.noteStateColor(st)
                font.family: nameMetrics.font.family
                font.weight: parent.current ? Font.Bold : Font.Medium
                font.pixelSize: Math.round(staff.ls * 0.9)
            }
            // Technique sign above right of the fret number (1.31); a ghost note's parentheses
            // are its sign, its result frames them (1.37).
            KanteTechniqueMark {
                readonly property bool ghost: technique === "ghost"
                technique: parent.modelData.technique || ""
                signVisible: !ghost
                result: staff.shownTechniqueResult(parent.modelData.index, staff.stateRevision)
                color: staff.marks === KanteTabStaff.Marks.Quiet ? KanteStyle.mutedTextColor : resultColor
                height: ghost ? parent.height : Math.round(staff.ls * 0.7)
                width: ghost ? parent.width : implicitWidth
                x: ghost ? 0 : parent.width
                y: ghost ? 0 : parent.height / 2 - height
            }
            Text {
                visible: parent.modelData.label !== ""
                anchors.bottom: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.modelData.label
                color: KanteStyle.mutedTextColor
                font.family: nameMetrics.font.family
                font.pixelSize: Math.round(staff.ls * 0.6)
            }
        }
    }

    Repeater {
        model: staff.layout.marks
        delegate: KanteNoteMark {
            required property var modelData
            readonly property bool full: staff.marks === KanteTabStaff.Marks.Full
            visible: drawn
            width: Math.round(staff.ls * (full ? 0.95 : 0.7))
            height: width
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            // The first note of the onset that is not pending speaks for the chord.
            readonly property int shownIndex: {
                for (var k = 0; k < modelData.indices.length; k++) {
                    if (staff.shownState(modelData.indices[k], staff.stateRevision) !== "pending") return modelData.indices[k]
                }
                return -1
            }
            noteState: shownIndex >= 0 ? staff.shownState(shownIndex, staff.stateRevision) : "pending"
            cents: shownIndex >= 0 && staff.stateRevision >= 0 ? staff.centsOf(shownIndex) : NaN
            showCents: staff.showCents && full
            color: full ? KanteStyle.noteStateColor(noteState) : KanteStyle.mutedTextColor
        }
    }

    Repeater {
        model: staff.layout.flags
        delegate: Text {
            required property var modelData
            x: modelData.x
            y: modelData.y - baselineOffset
            text: modelData.glyph
            color: KanteStyle.textColor
            font.family: music.font.family
            font.pixelSize: Math.round(staff.ls * 2.0)
        }
    }

    // Cursor at `position`.
    Rectangle {
        readonly property int bar: staff.currentBar
        readonly property int sys: staff.sysOf(bar)
        visible: staff.cursor && sys >= 0 && sys < staff.systems && staff.barList.length > 0
        x: visible ? Math.round(staff.xOf(staff.position, bar)) : 0
        y: sys * staff.systemHeight + staff.staffTop - staff.ls * 0.8
        width: Math.max(2, KanteStyle.unit(2))
        height: staff.staffHeight + staff.ls * 1.6
        color: KanteStyle.accentColor
    }
}
