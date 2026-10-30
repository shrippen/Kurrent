import QtQuick
import QtQuick.Shapes
import "."

/**
 * Notation in the bass clef, one voice (Kante 1.23, for Kontra). Glyphs from Bravura
 * (SMuFL, SIL OFL, fonts/OFL-Bravura.txt): clef, key and time signatures, noteheads,
 * flags, rests, accidentals, dots. Drawn here: staff and ledger lines, stems (up below
 * the middle line, down from it), beams within a beat (eighths and shorter; a dotted
 * quarter in 6/8, 9/8, 12/8), ties and the triplet 3 over a beamed group.
 *
 *   notes      [{time, beats, midi, state, tied, cents}], sorted by time; time in seconds,
 *              beats = duration in quarters (1.5 dotted quarter, 1/3 eighth triplet),
 *              tied: tied to the next note (same pitch), state as KanteTabLane
 *              ("offpitch" with its `cents` beside the sign, 1.27)
 *              technique, techniqueResult (1.31) as KanteTabLane: the tab sign above the
 *              staff, under the state sign (KanteTechniqueMark); setTechniqueResult(index,
 *              result) changes a result without a new layout
 *   rests      [{time, beats}]
 *   bars       [{time, number, numerator, denominator, keyFifths, chord}] (numbers or a missing
 *              signature keep the previous one; 4/4 at first); the time signature shows
 *              on the first bar of the page and where it changes.
 *              keyFifths (1.27, also read as key_fifths): the key from this bar on; a
 *              new key signature shows where it changes (after a thin double bar line).
 *              Naturals stand only alone: a change to C shows naturals for the old key;
 *              any other change shows just the new key, read as a new section without
 *              cancelling the old one. A change at the start of a line shows at the
 *              start of that line.
 *              chord (1.27): a chord symbol at the start of the bar
 *              number (1.28): the bar's label, e.g. the written bar number (unrolled
 *              repeats read "5, 6, 5, 6"); a number or a string, left out: index + 1
 *              section (1.50): the part that starts with the bar ("Refrain", "B", or a
 *              list ["Refrain", "B"] → "Refrain · B"), a rehearsal mark
 *              (KanteRehearsalMark) on top of the line, cut short before the next mark;
 *              with sections the staff moves down by their row. Screen readers hear the
 *              part of the current bar ("Teil Refrain · B", KanteStyle.partText)
 *   chords     (1.27) [{time, text}]: chord symbols at a time in seconds, above the staff
 *              over the note at that time; with the chords of `bars`, sorted by time.
 *              "#" shows as ♯, a "b" after a note letter or before a digit as ♭
 *              ("Bb7" B♭7, "C7b9" C7♭9); the rest is shown as given
 *   keyFifths  key signature: 1..7 sharps, -1..-7 flats; notes are spelled in the key
 *              (else sharps in sharp keys, flats in flat keys), an accidental holds to
 *              the end of the bar. The key of the first bar unless it sets its own
 *   position   the current time in seconds
 *   marks      Full, Quiet (notes in the text colour, small muted signs) or Off;
 *              setNoteState(index, state[, cents]) / resetStates() change states
 *              without a new layout
 *   showCents  the cents beside offpitch signs (Full marks only; default true)
 *   loopStart, loopEnd  loop range in seconds, -1 for none (1.35): a tint with bracket
 *              edges as on KanteTabLane, one part per line; a loop that runs on to the
 *              next line is open at the line end and goes on there without bracket. An
 *              edge on a bar start or end sits on the bar line
 *
 * Pages line by line as KanteTabStaff: the top line holds the current bar, `systems - 1`
 * lines preview. The current note sits on a selection band, states show above the staff
 * (KanteNoteMark) and in the note's colour; chord symbols sit between them and the staff
 * (the staff moves down by their row only when there are chord symbols). Spacing within a bar follows time. Sizes
 * come from `staffSpace` (KanteStyle.unit, so it scales with the platform), readable
 * at 200 %. The layout is computed once per page, not per frame.
 */
Item {
    id: staff

    enum Marks {
        Full,
        Quiet,
        Off
    }

    property var notes: []
    property var rests: []
    property var bars: []
    property int keyFifths: 0
    /** Chord symbols [{time, text}] (Kante 1.27); bars can carry one each as `chord`. */
    property var chords: []
    property real position: 0
    /** Loop range in seconds, -1 for none (1.35). */
    property real loopStart: -1
    property real loopEnd: -1
    property int barsPerSystem: 0
    property int systems: 1
    property bool cursor: true
    /** Distance of two staff lines. */
    property real staffSpace: KanteStyle.unit(10)
    property real minBarWidth: staffSpace * 18
    property string accessibleName: "Noten, Bassschlüssel"
    property string barText: "Takt %1 von %2"
    /** The chord at the position in the screen-reader description; %1 the symbol. */
    property string chordText: "Akkord %1"
    /** Note names for screen readers (C D E F G A B; German: H for B), and the accidental words. */
    property var letterNames: ["C", "D", "E", "F", "G", "A", "H"]
    property string sharpText: "is"
    property string flatText: "es"
    /**
     * How note states show (Kante 1.24): Full (state colour and sign), Quiet (notes in the
     * text colour, small muted signs that tell the state by shape: Kontra's play mode),
     * Off (no states).
     */
    property int marks: KanteBassStaff.Marks.Full
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
        return marks === KanteBassStaff.Marks.Off ? "" : techniqueResultOf(i)
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
        return marks === KanteBassStaff.Marks.Off || i === undefined ? "pending" : stateOf(i)
    }
    onNotesChanged: resetStates()

    readonly property real sp: Math.max(4, staffSpace)
    readonly property int currentIndex: lastAtOrBefore(position)
    readonly property var barList: normalizeBars(bars, notes, rests, keyFifths)
    /** Every chord symbol, from `chords` and the bars: [{time, text}] sorted by time. */
    readonly property var chordList: collectChords(chords, barList)
    readonly property bool hasChords: chordList.length > 0
    readonly property int currentBar: barAt(position)
    // Wide enough for the widest key a line can start with (with the naturals of a change).
    readonly property real headerWidth: sp * (4.2 + maxHeaderKey(barList) * 1.1 + 3.0)
    readonly property int perSystem: barsPerSystem > 0 ? barsPerSystem
        : Math.max(1, Math.floor((width - headerWidth) / Math.max(1, minBarWidth)))
    readonly property int firstBar: Math.max(0, Math.floor(currentBar / perSystem) * perSystem)
    readonly property real barWidth: (width - headerWidth) / perSystem
    /** Any bar with a section: then a row for the rehearsal marks on top (1.50). */
    readonly property bool hasSections: barList.some(function (b) { return b.section !== "" })
    readonly property real sectionRow: hasSections ? markProbe.implicitHeight + sp * 0.5 : 0
    readonly property real staffTop: sectionRow + sp * (hasChords ? 7.5 : 5.5)
    readonly property real systemHeight: staffTop + sp * 4 + sp * 5
    readonly property var layout: computeLayout(firstBar, perSystem, Math.max(1, systems), width, sp, notes, rests, barList, chordList)
    /** Loop parts of the page, one per line: [{x, w, sys, left, right}] (1.35). */
    readonly property var loopParts: loopLayout(firstBar, perSystem, Math.max(1, systems), width, barList,
                                                loopStart, loopEnd)

    implicitWidth: KanteStyle.unit(720)
    implicitHeight: Math.ceil(systemHeight * Math.max(1, systems))

    Accessible.role: Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: {
        let d = barText.arg(barList.length ? barList[currentBar].number : 1).arg(barList.length)
        const part = barList.length ? barList[currentBar].part : ""
        if (part !== "") {
            d += ", " + KanteStyle.partText.arg(part)
        }
        const ch = chordAt(position)
        if (ch !== "") {
            d += ", " + chordText.arg(ch)
        }
        // notes can change before currentIndex follows (e.g. emptied while playing)
        const n = currentIndex >= 0 ? notes[currentIndex] : undefined
        if (n) {
            d += ", " + pitchName(Number(n.midi), barList.length ? barList[currentBar].key : keyFifths)
                + " (" + KanteStyle.noteStateName(shownState(currentIndex, stateRevision)) + centsSuffix(currentIndex, stateRevision) + ")"
        }
        const t = techniqueSummary(stateRevision)
        if (t !== "") {
            d += ", " + t
        }
        return d
    }

    FontLoader { id: music; source: Qt.resolvedUrl("fonts/Bravura.otf") }

    // ── Pitch ────────────────────────────────────────────────────────
    readonly property var letterPc: [0, 2, 4, 5, 7, 9, 11]
    function keyAlter(letter, fifths) {
        var sharps = [3, 0, 4, 1, 5, 2, 6], flats = [6, 2, 5, 1, 4, 0, 3]
        var f = Math.max(-7, Math.min(7, fifths))
        for (var i = 0; i < Math.abs(f); i++) {
            if ((f > 0 ? sharps : flats)[i] === letter) {
                return f > 0 ? 1 : -1
            }
        }
        return 0
    }
    /** {letter 0..6 (C..B), alter -1/0/1, octave, pos} of a MIDI pitch in the key; pos 0 = bottom line (G2). */
    function spell(midi, fifths) {
        var pc = ((midi % 12) + 12) % 12
        var best = null
        for (var pass = 0; pass < 3 && !best; pass++) {
            for (var l = 0; l < 7 && !best; l++) {
                var a = pc - letterPc[l]
                if (a > 6) a -= 12
                if (a < -6) a += 12
                if (Math.abs(a) > 1) continue
                if ((pass === 0 && a === keyAlter(l, fifths) )
                        || (pass === 1 && a === 0)
                        || (pass === 2 && a === (fifths < 0 ? -1 : 1))) {
                    best = { letter: l, alter: a }
                }
            }
        }
        if (!best) {
            best = { letter: 0, alter: 0 }
        }
        best.octave = Math.floor((midi - best.alter) / 12) - 1
        best.pos = best.octave * 7 + best.letter - 18
        return best
    }
    function pitchName(midi, fifths) {
        if (isNaN(midi)) {
            return ""
        }
        var s = spell(midi, fifths === undefined ? keyFifths : fifths)
        var name = String(letterNames[s.letter])
        return name + (s.alter > 0 ? sharpText : s.alter < 0 ? flatText : "") + s.octave
    }
    /** Note value of a duration in quarters: {type 0 whole .. 5 32nd, dots, triplet}. */
    function valueOf(beats) {
        var b = Number(beats) || 0
        var bases = [4, 2, 1, 0.5, 0.25, 0.125]
        for (var i = 0; i < bases.length; i++) {
            if (Math.abs(b - bases[i]) < 1e-3) return { type: i, dots: 0, triplet: false }
            if (Math.abs(b - bases[i] * 1.5) < 1e-3) return { type: i, dots: 1, triplet: false }
            if (Math.abs(b - bases[i] * 1.75) < 1e-3) return { type: i, dots: 2, triplet: false }
            if (Math.abs(b - bases[i] * 2 / 3) < 1e-3) return { type: i, dots: 0, triplet: true }
        }
        for (var k = 0; k < bases.length; k++) {
            if (b >= bases[k]) return { type: k, dots: 0, triplet: false }
        }
        return { type: 5, dots: 0, triplet: false }
    }

    // ── Time ─────────────────────────────────────────────────────────
    function lastAtOrBefore(t) {
        var a = 0, b = notes ? notes.length : 0
        while (a < b) {
            var m = (a + b) >> 1
            if (Number(notes[m].time) <= t + 1e-6) a = m + 1
            else b = m
        }
        return a - 1
    }
    /** Label of a bar (1.28): its `number` as sent (written bar number), else index + 1. */
    function barLabel(o, i) {
        var n = typeof o === "object" && o !== null ? o.number : undefined
        return n === undefined || n === null || String(n) === "" ? String(i + 1) : String(n)
    }
    function normalizeBars(list, ns, rs, fifths) {
        var out = [], num = 4, den = 4
        var key = clampKey(fifths)
        for (var i = 0; list && i < list.length; i++) {
            var o = typeof list[i] === "object" && list[i] !== null ? list[i] : { time: list[i] }
            var changed = i === 0
            if (o.numerator && o.denominator && (o.numerator !== num || o.denominator !== den)) {
                num = Number(o.numerator)
                den = Number(o.denominator)
                changed = true
            }
            // Key from this bar on (keyFifths, or key_fifths as a Rust or Python app names it).
            var fromKey = key
            var k = o.keyFifths !== undefined ? o.keyFifths : o.key_fifths
            if (k !== undefined && k !== null && k !== "" && !isNaN(Number(k))) {
                key = clampKey(k)
            }
            out.push({ time: Number(o.time) || 0, num: num, den: den, changed: changed,
                       key: key, fromKey: fromKey, keyChanged: i > 0 && key !== fromKey,
                       chord: o.chord !== undefined && o.chord !== null ? String(o.chord) : "",
                       number: barLabel(o, i), section: KanteStyle.rehearsalText(o.section), part: "" })
        }
        // Seconds per quarter, from the notes (median of time step / beats): sizes a bar
        // when none or only the start of the last one is given.
        var lastEnd = 0, steps = []
        for (var k = 0; ns && k < ns.length; k++) {
            var b = Number(ns[k].beats) || 0
            if (k + 1 < ns.length && b > 0 && Number(ns[k + 1].time) > Number(ns[k].time)) {
                steps.push((Number(ns[k + 1].time) - Number(ns[k].time)) / b)
            }
        }
        steps.sort(function (a, b) { return a - b })
        var spq = steps.length ? steps[Math.floor(steps.length / 2)] : 0.5
        for (var k2 = 0; ns && k2 < ns.length; k2++) lastEnd = Math.max(lastEnd, Number(ns[k2].time) + (Number(ns[k2].beats) || 0) * spq)
        for (var r = 0; rs && r < rs.length; r++) lastEnd = Math.max(lastEnd, Number(rs[r].time) + (Number(rs[r].beats) || 0) * spq)
        if (out.length === 0) {
            out.push({ time: 0, num: 4, den: 4, changed: true, key: key, fromKey: key, keyChanged: false, chord: "", number: "1",
                       section: "", part: "" })
        }
        for (var j = 0; j < out.length; j++) {
            if (j + 1 < out.length) {
                out[j].end = out[j + 1].time
            } else {
                var len = j > 0 ? out[j].time - out[j - 1].time : out[j].num * 4 / out[j].den * spq
                out[j].end = out[j].time + len
                // More notes after the last given bar: add bars of the same length.
                while (out[out.length - 1].end < lastEnd - 1e-3 && len > 0) {
                    var prev = out[out.length - 1]
                    out.push({ time: prev.end, end: prev.end + len, num: prev.num, den: prev.den, changed: false,
                               key: prev.key, fromKey: prev.key, keyChanged: false, chord: "",
                               number: isNaN(Number(prev.number)) ? String(out.length + 1) : String(Number(prev.number) + 1),
                               section: "", part: "" })
                }
                break
            }
        }
        // The part in effect: this bar's section or the last one before it (1.50).
        for (let p = 0; p < out.length; p++) {
            out[p].part = out[p].section !== "" ? out[p].section : (p > 0 ? out[p - 1].part : "")
        }
        return out
    }
    function barAt(t) {
        var a = 0, b = barList.length
        while (a < b) {
            var m = (a + b) >> 1
            if (barList[m].time <= t + 1e-6) a = m + 1
            else b = m
        }
        return Math.max(0, a - 1)
    }
    function clampKey(k) {
        return Math.max(-7, Math.min(7, Math.round(Number(k) || 0)))
    }
    /**
     * The signs of a key signature going from key `from` to `to`, left to right.
     * [{pos, sign: 1 sharp, -1 flat, 0 natural}], pos as in spell() (0 = bottom line).
     * Naturals never mix with new signs (owner's rule, 1.27): only a change to C shows
     * naturals, for all of the old key; every other change shows just the new key.
     */
    function keySigns(from, to) {
        var sharpPos = [6, 3, 7, 4, 1, 5, 2], flatPos = [2, 5, 1, 4, 0, 3, -1]
        var out = []
        if (from !== to && from !== 0 && to === 0) {
            for (var c = 0; c < Math.abs(from); c++) {
                out.push({ pos: (from > 0 ? sharpPos : flatPos)[c], sign: 0 })
            }
        }
        for (var k = 0; k < Math.abs(to); k++) {
            out.push({ pos: (to > 0 ? sharpPos : flatPos)[k], sign: to > 0 ? 1 : -1 })
        }
        return out
    }
    /** The most key signs a line can start with (the header is that wide on every line). */
    function maxHeaderKey(bl) {
        var m = 0
        for (var i = 0; bl && i < bl.length; i++) {
            m = Math.max(m, bl[i].keyChanged ? keySigns(bl[i].fromKey, bl[i].key).length : Math.abs(bl[i].key))
        }
        return m
    }
    /** "Bb7" -> "B♭7", "F#m" -> "F♯m", "C7b9" -> "C7♭9". */
    function chordLabel(t) {
        return String(t).replace(/#/g, "\u266F").replace(/([A-G])b/g, "$1\u266D").replace(/b(?=\d)/g, "\u266D")
    }
    function collectChords(list, bl) {
        var out = []
        for (var b = 0; bl && b < bl.length; b++) {
            if (bl[b].chord !== "") {
                out.push({ time: bl[b].time, text: bl[b].chord })
            }
        }
        for (var i = 0; list && i < list.length; i++) {
            var c = list[i]
            if (c && c.text !== undefined && String(c.text) !== "") {
                out.push({ time: Number(c.time) || 0, text: String(c.text) })
            }
        }
        out.sort(function (a, b) { return a.time - b.time })
        return out
    }
    /** The chord symbol in force at time t ("" before the first). */
    function chordAt(t) {
        var c = ""
        for (var i = 0; i < chordList.length && chordList[i].time <= t + 1e-6; i++) {
            c = chordList[i].text
        }
        return c
    }
    function sysOf(b) {
        return Math.floor((b - firstBar) / perSystem)
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
     * The loop cut into lines (1.35): per line the part of [from, to] it shows. left / right:
     * the loop starts / ends on this line (bracket edge), else it runs on (open edge).
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
    function padLeft(b) {
        var bar = barList[b]
        var midLine = (b - firstBar) % perSystem !== 0 && b !== firstBar
        var showTime = bar.changed && midLine
        var keyCount = bar.keyChanged && midLine ? keySigns(bar.fromKey, bar.key).length : 0
        return sp * (2.0 + (keyCount > 0 ? keyCount * 1.1 + 1.6 : 0) + (showTime ? 2.4 : 0))
    }
    function xOf(t, b) {
        var bar = barList[b]
        var col = (b - firstBar) % perSystem
        var pl = padLeft(b), pr = sp * 1.4
        var f = (t - bar.time) / Math.max(1e-6, bar.end - bar.time)
        return headerWidth + col * barWidth + pl + Math.max(0, Math.min(1, f)) * (barWidth - pl - pr)
    }
    function yOf(pos, sys) {
        return sys * systemHeight + staffTop + sp * 4 - pos * sp / 2
    }

    // ── Layout ───────────────────────────────────────────────────────
    function computeLayout(first, per, nsys, w, sp, ns, rs, bl, cl) {
        var L = { glyphs: [], rects: [], polys: [], ties: [], marks: [], techniques: [], sections: [], boxes: {} }
        if (w <= 0 || bl.length === 0) {
            return L
        }
        var G = { clef: "", sharp: "", flat: "", natural: "", dot: "",
                  heads: ["", "", "", "", "", ""],
                  rests: ["", "", "", "", "", ""],
                  flagsUp: ["", "", "", "", "", ""], flagsDown: ["", "", "", "", "", ""] }
        function signGlyph(sign) { return sign > 0 ? G.sharp : sign < 0 ? G.flat : G.natural }
        var lineT = Math.max(1, Math.round(sp * 0.13)), stemW = Math.max(1, Math.round(sp * 0.12))
        var ledgerT = Math.max(1, Math.round(sp * 0.16))
        var last = Math.min(bl.length - 1, first + per * nsys - 1)
        function digits(n, x, y) {
            var s = String(n)
            for (var i = 0; i < s.length; i++) {
                L.glyphs.push({ x: x + (i - s.length / 2) * sp * 1.8 , y: y, g: String.fromCharCode(0xE080 + Number(s[i])), ink: "" })
            }
        }
        function timeSig(bar, x, sys) {
            digits(bar.num, x, yOf(6, sys))
            digits(bar.den, x, yOf(2, sys))
        }
        // Staff, clef, key, bars.
        for (var s = 0; s < nsys; s++) {
            var used = Math.min(per, Math.max(0, last - (first + s * per) + 1))
            if (used <= 0) continue
            var right = headerWidth + used * barWidth
            for (var l = 0; l < 5; l++) {
                L.rects.push({ x: sp * 0.4, y: yOf(l * 2, s) - lineT / 2, w: right - sp * 0.4, h: lineT, ink: "line" })
            }
            L.rects.push({ x: sp * 0.4, y: yOf(8, s), w: Math.max(1, Math.round(sp * 0.16)), h: sp * 4, ink: "" })
            L.glyphs.push({ x: sp * 0.9, y: yOf(6, s), g: G.clef, ink: "" })
            var firstOfLine = first + s * per
            // The line's key; a change right here also shows its naturals.
            var lineBar = bl[firstOfLine]
            var ks = keySigns(lineBar.keyChanged ? lineBar.fromKey : lineBar.key, lineBar.key)
            for (var k = 0; k < ks.length; k++) {
                L.glyphs.push({ x: sp * (4.2 + k * 1.1), y: yOf(ks[k].pos, s), g: signGlyph(ks[k].sign), ink: "" })
            }
            if (s === 0 || bl[firstOfLine].changed) {
                timeSig(bl[firstOfLine], sp * (4.2 + ks.length * 1.1 + 1.3), s)
            }
            for (var c = 0; c < used; c++) {
                var bi = firstOfLine + c
                var bx = headerWidth + c * barWidth
                var endX = bx + barWidth
                var finalBar = bi === bl.length - 1
                L.rects.push({ x: endX - (finalBar ? sp * 0.9 : Math.max(1, Math.round(sp * 0.16))), y: yOf(8, s),
                               w: Math.max(1, Math.round(sp * 0.16)), h: sp * 4, ink: "" })
                if (finalBar) {
                    L.rects.push({ x: endX - sp * 0.5, y: yOf(8, s), w: sp * 0.5, h: sp * 4, ink: "" })
                } else if (bl[bi + 1].keyChanged) {
                    // A thin double bar line before a new key.
                    L.rects.push({ x: endX - Math.max(1, Math.round(sp * 0.16)) - sp * 0.45, y: yOf(8, s),
                                   w: Math.max(1, Math.round(sp * 0.16)), h: sp * 4, ink: "" })
                }
                L.glyphs.push({ x: bx + sp * 0.2, y: yOf(8, s) - sp * 1.0, g: "", text: bl[bi].number, ink: "muted" })
                var midKey = c > 0 && bl[bi].keyChanged ? keySigns(bl[bi].fromKey, bl[bi].key) : []
                for (var mk = 0; mk < midKey.length; mk++) {
                    L.glyphs.push({ x: bx + sp * (1.2 + mk * 1.1), y: yOf(midKey[mk].pos, s), g: signGlyph(midKey[mk].sign), ink: "" })
                }
                if (c > 0 && bl[bi].changed) {
                    timeSig(bl[bi], bx + sp * (midKey.length > 0 ? 1.2 + midKey.length * 1.1 + 1.2 : 1.6), s)
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
                let mx = headerWidth + (mb - mFirst) * barWidth + sp * 0.2
                L.sections.push({ x: mx, y: ms * systemHeight, text: bl[mb].section, maxW: mRight - mx - sp * 0.6 })
                mRight = mx
            }
        }
        L.sections.reverse()
        var from = bl[first].time, to = bl[last].end
        // Chord symbols: above the staff, left-aligned over the note at their time; one
        // that would run into the previous one on its line moves right.
        var chordRight = {}
        for (var ci = 0; cl && ci < cl.length; ci++) {
            var ct = cl[ci].time
            if (ct < from - 1e-6 || ct >= to - 1e-6) continue
            var cb = barAt(ct), csys = sysOf(cb)
            var label = chordLabel(cl[ci].text)
            var cx = Math.max(xOf(ct, cb) - sp * 0.6, (chordRight[csys] || 0) + sp * 0.8)
            L.glyphs.push({ x: cx, y: csys * systemHeight + sectionRow + sp * 3.2, g: "", text: label, ink: "chord", chord: true })
            chordRight[csys] = cx + label.length * sp * 0.95
        }
        // Rests.
        for (var r = 0; rs && r < rs.length; r++) {
            var rt = Number(rs[r].time)
            if (rt < from - 1e-6 || rt >= to - 1e-6) continue
            var rb = barAt(rt), rsys = sysOf(rb)
            var rv = valueOf(rs[r].beats)
            var fullBar = Math.abs(Number(rs[r].beats) - bl[rb].num * 4 / bl[rb].den) < 1e-3
            var rx = fullBar ? headerWidth + ((rb - first) % per + 0.5) * barWidth - sp * 0.6 : xOf(rt, rb) - sp * 0.5
            var rtype = fullBar ? 0 : rv.type
            L.glyphs.push({ x: rx, y: yOf(rtype === 0 ? 6 : 4, rsys), g: G.rests[rtype], ink: "" })
            for (var rd = 0; rd < rv.dots && !fullBar; rd++) {
                L.glyphs.push({ x: rx + sp * (1.5 + rd * 0.5), y: yOf(5, rsys), g: G.dot, ink: "" })
            }
        }
        // Notes: heads, accidentals, dots, ledger lines; stems and beams after grouping.
        var items = []
        var acc = {}, accBar = -1
        for (var i = 0; ns && i < ns.length; i++) {
            var n = ns[i]
            var t = Number(n.time)
            if (t < from - 1e-6 || t >= to - 1e-6) continue
            var b = barAt(t), sys = sysOf(b)
            if (b !== accBar) {
                acc = {}
                accBar = b
            }
            var midi = Number(n.midi)
            var f = bl[b].key
            var sp_ = spell(midi, f)
            var v = valueOf(n.beats)
            var headW = sp * (v.type === 0 ? 1.69 : 1.18)
            var x = xOf(t, b) - headW / 2
            var y = yOf(sp_.pos, sys)
            var st = n.state || "pending"
            var prevTied = i > 0 && ns[i - 1].tied && Number(ns[i - 1].midi) === midi
            var key = sp_.pos
            var current = acc[key] !== undefined ? acc[key] : keyAlter(sp_.letter, f)
            if (sp_.alter !== current && !(prevTied && barAt(Number(ns[i - 1].time)) !== b)) {
                var ag = sp_.alter > 0 ? G.sharp : sp_.alter < 0 ? G.flat : G.natural
                var aw = sp_.alter > 0 ? 1.0 : sp_.alter < 0 ? 0.9 : 0.7
                L.glyphs.push({ x: x - sp * (aw + 0.25), y: y, g: ag, ink: "note", index: i })
            }
            acc[key] = sp_.alter
            L.glyphs.push({ x: x, y: y, g: G.heads[v.type], ink: "note", index: i })
            for (var d = 0; d < v.dots; d++) {
                L.glyphs.push({ x: x + headW + sp * (0.35 + d * 0.5), y: yOf(sp_.pos % 2 === 0 ? sp_.pos + 1 : sp_.pos, sys), g: G.dot, ink: "note", index: i })
            }
            for (var p = -2; p >= sp_.pos; p -= 2) {
                L.rects.push({ x: x - sp * 0.4, y: yOf(p, sys) - ledgerT / 2, w: headW + sp * 0.8, h: ledgerT, ink: "" })
            }
            for (var q = 10; q <= sp_.pos; q += 2) {
                L.rects.push({ x: x - sp * 0.4, y: yOf(q, sys) - ledgerT / 2, w: headW + sp * 0.8, h: ledgerT, ink: "" })
            }
            L.marks.push({ x: x + headW / 2, y: sys * systemHeight + sectionRow + sp * 1.0, index: i })
            // The technique sign under the state sign, above the chord symbols (1.31).
            if (n.technique) {
                L.techniques.push({ x: x + headW / 2, y: sys * systemHeight + sectionRow + sp * 2.4, index: i, technique: String(n.technique) })
            }
            L.boxes[i] = { x: x, w: headW, sys: sys }
            var unit = bl[b].den === 8 && bl[b].num % 3 === 0 ? 1.5 : 1
            var spq = (bl[b].end - bl[b].time) / (bl[b].num * 4 / bl[b].den)
            items.push({ i: i, x: x, y: y, pos: sp_.pos, w: headW, v: v, sys: sys, bar: b, st: st, tied: !!n.tied,
                         group: Math.floor((t - bl[b].time) / spq / unit + 1e-3), t: t })
        }
        // A rest between two notes ends a beam.
        function restBetween(t0, t1) {
            for (var k = 0; rs && k < rs.length; k++) {
                var x = Number(rs[k].time)
                if (x > t0 + 1e-6 && x < t1 - 1e-6) return true
            }
            return false
        }
        var g = 0
        while (g < items.length) {
            var h = g
            if (items[g].v.type >= 3) {
                while (h + 1 < items.length && items[h + 1].v.type >= 3 && items[h + 1].bar === items[g].bar
                       && items[h + 1].group === items[g].group && items[h + 1].sys === items[g].sys
                       && !restBetween(items[h].t, items[h + 1].t)) {
                    h++
                }
            }
            var grp = items.slice(g, h + 1)
            var avg = 0
            for (var a = 0; a < grp.length; a++) avg += grp[a].pos
            avg /= grp.length
            var up = avg < 4
            var sx = function (it) { return up ? it.x + it.w - stemW : it.x }
            var natural = function (it) {
                // 3.5 spaces, and at least to the middle line for notes on ledger lines.
                var mid = yOf(4, it.sys)
                return up ? Math.min(it.y - sp * 3.5, mid) : Math.max(it.y + sp * 3.5, mid)
            }
            var beamAt = null
            if (grp.length > 1) {
                var x0 = sx(grp[0]), x1 = sx(grp[grp.length - 1])
                var b0 = natural(grp[0]), b1 = natural(grp[grp.length - 1])
                var dy = Math.max(-sp, Math.min(sp, b1 - b0))
                var slope = x1 > x0 ? dy / (x1 - x0) : 0
                var shift = 0
                for (var m = 0; m < grp.length; m++) {
                    var by = b0 + slope * (sx(grp[m]) - x0)
                    var need = up ? by - (grp[m].y - sp * 2.5) : (grp[m].y + sp * 2.5) - by
                    shift = Math.max(shift, need)
                }
                b0 += up ? -shift : shift
                beamAt = function (x) { return b0 + slope * (x - x0) }
                var thick = sp * 0.5, gap = sp * 0.25
                for (var lv = 1; lv <= 3; lv++) {
                    var off = (lv - 1) * (thick + gap) * (up ? 1 : -1)
                    for (var u = 0; u < grp.length; u++) {
                        if (grp[u].v.type < 2 + lv) continue
                        var e = u
                        while (e + 1 < grp.length && grp[e + 1].v.type >= 2 + lv) e++
                        var xa = sx(grp[u]), xb = sx(grp[e]) + stemW
                        if (e === u) {
                            var stub = sp * 1.1
                            if (u === grp.length - 1) { xa = sx(grp[u]) - stub; xb = sx(grp[u]) + stemW }
                            else { xa = sx(grp[u]); xb = xa + stub }
                        }
                        var ya = beamAt(xa) + off, yb = beamAt(xb) + off
                        var t2 = up ? thick : -thick
                        L.polys.push({ pts: [xa, ya, xb, yb, xb, yb + t2, xa, ya + t2], ink: "" })
                        u = e
                    }
                }
                var allTriplets = grp.every(function (it) { return it.v.triplet })
                if (allTriplets) {
                    var cx = (x0 + x1) / 2
                    var cy = beamAt(cx) + (up ? -sp * 1.2 : sp * 2.0)
                    L.glyphs.push({ x: cx - sp * 0.5, y: cy, g: "", ink: "" })
                }
            }
            for (var z = 0; z < grp.length; z++) {
                var it = grp[z]
                if (it.v.type === 0) continue
                var end = beamAt ? beamAt(sx(it)) : natural(it)
                var attach = up ? it.y - sp * 0.168 : it.y + sp * 0.168
                L.rects.push({ x: sx(it), y: Math.min(end, attach), w: stemW, h: Math.abs(attach - end), ink: "" })
                if (!beamAt && it.v.type >= 3) {
                    L.glyphs.push({ x: sx(it), y: end, g: (up ? G.flagsUp : G.flagsDown)[it.v.type], ink: "" })
                }
                if (!beamAt && it.v.triplet) {
                    L.glyphs.push({ x: it.x, y: up ? end - sp * 0.8 : end + sp * 1.8, g: "", ink: "" })
                }
                it.up = up
            }
            g = h + 1
        }
        // Ties: to the next note, on the side away from the stem; to the line end across lines.
        for (var y2 = 0; y2 < items.length; y2++) {
            var a1 = items[y2]
            if (!a1.tied) continue
            var nxt = y2 + 1 < items.length && items[y2 + 1].i === a1.i + 1 ? items[y2 + 1] : null
            var tx0 = a1.x + a1.w + sp * 0.1
            var tx1 = nxt && nxt.sys === a1.sys ? nxt.x - sp * 0.1 : headerWidth + Math.min(per, bl.length - first - a1.sys * per) * barWidth - sp * 0.3
            var below = a1.up !== false
            var ty = a1.y + (below ? sp * 0.45 : -sp * 0.45)
            var hgt = Math.min(sp * 1.2, Math.max(sp * 0.5, (tx1 - tx0) * 0.12)) * (below ? 1 : -1)
            var th = sp * 0.36 * (below ? 1 : -1)
            var dx = (tx1 - tx0) / 3
            L.ties.push({ ink: "note", index: a1.i, path: "M " + tx0 + " " + ty
                + " C " + (tx0 + dx) + " " + (ty + hgt) + " " + (tx1 - dx) + " " + (ty + hgt) + " " + tx1 + " " + ty
                + " C " + (tx1 - dx) + " " + (ty + hgt - th) + " " + (tx0 + dx) + " " + (ty + hgt - th) + " " + tx0 + " " + ty + " Z" })
        }
        return L
    }

    /** Colour of a layout part; "note" parts follow the live state of note `index`. */
    function inkColor(ink, index, revision) {
        if (ink === "note") {
            var st = shownState(index, revision)
            return st === "pending" || marks !== KanteBassStaff.Marks.Full ? KanteStyle.textColor : KanteStyle.noteStateColor(st)
        }
        if (ink === "line") return KanteStyle.mutedTextColor
        if (ink === "chord") return KanteStyle.strongTextColor
        if (ink === "muted") return KanteStyle.mutedTextColor
        if (ink === "" || ink === "pending" || ink === undefined) return KanteStyle.textColor
        return KanteStyle.noteStateColor(ink)
    }

    // Rehearsal marks (1.50); the probe measures the row.
    KanteRehearsalMark { id: markProbe; visible: false; text: "A"; pixelSize: staff.sp * 1.4; Accessible.ignored: true }
    Repeater {
        model: staff.layout.sections
        delegate: KanteRehearsalMark {
            required property var modelData
            x: modelData.x
            y: modelData.y + Math.round((staff.sectionRow - height) / 2)
            text: modelData.text
            pixelSize: staff.sp * 1.4
            maximumWidth: modelData.maxW
            Accessible.ignored: true
        }
    }

    // Loop range (1.35): a tint with bracket edges ([ and ]) as on KanteTabLane, not colour
    // alone; as high as the cursor, behind the staff.
    Repeater {
        model: staff.loopParts
        delegate: Item {
            id: loopPart
            required property var modelData
            x: modelData.x
            y: modelData.sys * staff.systemHeight + staff.staffTop - staff.sp * 1.5
            width: modelData.w
            height: staff.sp * 7
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
        x: visible ? box.x - staff.sp * 0.6 : 0
        y: visible ? box.sys * staff.systemHeight + staff.staffTop - staff.sp * 1.5 : 0
        width: visible ? box.w + staff.sp * 1.2 : 0
        height: staff.sp * 7
        color: KanteStyle.selectionColor
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: KanteStyle.focusColor }
    }

    Repeater {
        model: staff.layout.rects
        delegate: Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: staff.inkColor(modelData.ink)
            opacity: modelData.ink === "line" ? 0.8 : 1
        }
    }
    Repeater {
        model: staff.layout.polys
        delegate: Shape {
            required property var modelData
            antialiasing: true
            ShapePath {
                strokeColor: "transparent"
                fillColor: staff.inkColor(modelData.ink)
                PathPolyline {
                    path: {
                        var p = modelData.pts
                        return [Qt.point(p[0], p[1]), Qt.point(p[2], p[3]), Qt.point(p[4], p[5]), Qt.point(p[6], p[7]), Qt.point(p[0], p[1])]
                    }
                }
            }
        }
    }
    Repeater {
        model: staff.layout.ties
        delegate: Shape {
            required property var modelData
            antialiasing: true
            ShapePath {
                strokeColor: "transparent"
                fillColor: staff.inkColor(modelData.ink, modelData.index, staff.stateRevision)
                PathSvg { path: modelData.path }
            }
        }
    }
    Repeater {
        model: staff.layout.glyphs
        delegate: Text {
            required property var modelData
            readonly property bool glyph: modelData.g !== ""
            readonly property bool current: modelData.index !== undefined && modelData.index === staff.currentIndex
            x: modelData.x
            y: modelData.y - (glyph ? baselineOffset : 0)
            text: glyph ? modelData.g : modelData.text
            color: {
                var c = staff.inkColor(modelData.ink, modelData.index, staff.stateRevision)
                return current && modelData.ink === "note" && staff.shownState(modelData.index, staff.stateRevision) === "pending" ? KanteStyle.strongTextColor : c
            }
            readonly property bool chord: modelData.chord === true
            font.family: glyph ? music.font.family : chord ? KanteStyle.defaultFont.family : KanteStyle.monoFont(10, false).family
            font.pixelSize: glyph ? Math.round(staff.sp * 4) : chord ? Math.max(10, Math.round(staff.sp * 1.6)) : Math.max(8, Math.round(staff.sp * 0.95))
            font.weight: chord ? Font.DemiBold : Font.Normal
            Accessible.ignored: true
        }
    }
    Repeater {
        model: staff.layout.marks
        delegate: KanteNoteMark {
            required property var modelData
            readonly property bool full: staff.marks === KanteBassStaff.Marks.Full
            visible: drawn
            width: Math.round(staff.sp * (full ? 1.3 : 0.95))
            height: width
            x: modelData.x - width / 2
            y: modelData.y - height / 2
            noteState: staff.shownState(modelData.index, staff.stateRevision)
            cents: staff.stateRevision >= 0 ? staff.centsOf(modelData.index) : NaN
            showCents: staff.showCents && full
            color: full ? KanteStyle.noteStateColor(noteState) : KanteStyle.mutedTextColor
        }
    }

    Repeater {
        model: staff.layout.techniques
        delegate: KanteTechniqueMark {
            required property var modelData
            technique: modelData.technique
            result: staff.shownTechniqueResult(modelData.index, staff.stateRevision)
            color: staff.marks === KanteBassStaff.Marks.Quiet ? KanteStyle.mutedTextColor : resultColor
            height: Math.round(staff.sp * 1.2)
            width: implicitWidth
            x: modelData.x - width / 2
            y: modelData.y - height / 2
        }
    }

    Rectangle {
        readonly property int bar: staff.currentBar
        readonly property int sys: staff.sysOf(bar)
        visible: staff.cursor && sys >= 0 && sys < staff.systems && staff.barList.length > 0
        x: visible ? Math.round(staff.xOf(staff.position, bar)) : 0
        y: sys * staff.systemHeight + staff.staffTop - staff.sp * 1.5
        width: Math.max(2, KanteStyle.unit(2))
        height: staff.sp * 7
        color: KanteStyle.accentColor
        opacity: 0.8
    }
}
