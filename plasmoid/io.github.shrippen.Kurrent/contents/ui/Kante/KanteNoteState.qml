import QtQuick

/**
 * The state of the notes of a notation view (Kante 1.24, 1.27, 1.31), kept apart from the
 * `notes` list: how each note was played (state, cents) and how its technique was played.
 * KanteBassStaff, KanteTabStaff, KanteTabLane and KanteKeyLane each hold one and hand
 * `setNoteState`, `setTechniqueResult` and `resetStates` on, so a change reaches only that
 * note and no new layout. Has no look of its own.
 *
 *   notes      the view's note list [{state, cents, techniqueResult, ...}]; set by the view in its
 *              `onNotesChanged`, not bound: a binding resets while the view's own bindings
 *              read it, which is a binding loop. A new list resets the states.
 *   revision   counts every change; bind to it to follow them
 *   stateCounts, techniqueCounts   notes per state / technique result, kept up to date
 *   hidden     the view shows no states (Marks Off): the shown* functions then give "pending" / ""
 *
 * Signals tell the view which items to touch: `stateSet`, `techniqueSet`, `reset`.
 */
QtObject {
    id: root

    property var notes: []
    property int revision: 0
    property bool hidden: false
    // By note index (plain objects: no bindings depend on them, read through `revision`).
    property var changedStates: ({})
    property var changedCents: ({})
    property var changedTechniques: ({})
    property var stateCounts: ({})
    property var techniqueCounts: ({})

    /** `cents` is NaN when the call gave none. */
    signal stateSet(int index, string state, real cents)
    signal techniqueSet(int index, string result)
    signal reset()

    function inRange(index) {
        return !!notes && index >= 0 && index < notes.length
    }
    function setNoteState(index, state, cents) {
        if (!inRange(index)) {
            return
        }

        const old = stateOf(index)
        stateCounts[old] = (stateCounts[old] || 1) - 1
        stateCounts[String(state)] = (stateCounts[String(state)] || 0) + 1
        changedStates[index] = String(state)
        if (cents !== undefined) {
            changedCents[index] = Number(cents)
        }
        stateSet(index, String(state), cents !== undefined ? Number(cents) : NaN)
        revision++
    }
    function setTechniqueResult(index, result) {
        if (!inRange(index)) {
            return
        }

        const old = techniqueResultOf(index)
        if (old !== "") {
            techniqueCounts[old] = (techniqueCounts[old] || 1) - 1
        }
        const r = String(result || "")
        if (r !== "") {
            techniqueCounts[r] = (techniqueCounts[r] || 0) + 1
        }
        changedTechniques[index] = r
        techniqueSet(index, r)
        revision++
    }
    /** Back to the states in `notes`. */
    function resetStates() {
        changedStates = {}
        changedCents = {}
        changedTechniques = {}

        // Count what the list itself says, so the summaries need no pass over the notes.
        const states = {}
        const techniques = {}
        for (let k = 0; notes && k < notes.length; k++) {
            const st = notes[k].state ? String(notes[k].state) : "pending"
            states[st] = (states[st] || 0) + 1
            const tr = notes[k].techniqueResult ? String(notes[k].techniqueResult) : ""
            if (tr !== "") {
                techniques[tr] = (techniques[tr] || 0) + 1
            }
        }
        stateCounts = states
        techniqueCounts = techniques
        reset()
        revision++
    }
    /** The state of note i: as set with setNoteState, else from `notes`. */
    function stateOf(i) {
        const s = changedStates[i]
        return s !== undefined ? s : (notes && notes[i] && notes[i].state ? String(notes[i].state) : "pending")
    }
    /** The cents of note i (offpitch): as set with setNoteState, else from `notes`; NaN for none. */
    function centsOf(i) {
        const c = changedCents[i]
        if (c !== undefined) {
            return c
        }
        const n = notes && notes[i]
        return n && n.cents !== undefined && n.cents !== null ? Number(n.cents) : NaN
    }
    /** The technique result of note i: as set with setTechniqueResult, else from `notes`. */
    function techniqueResultOf(i) {
        const r = changedTechniques[i]
        return r !== undefined ? r : (notes && notes[i] && notes[i].techniqueResult ? String(notes[i].techniqueResult) : "")
    }
    /** The state as shown: "pending" when hidden. Pass `revision` so a binding follows changes. */
    function shownState(i, revision) {
        return hidden || i === undefined ? "pending" : stateOf(i)
    }
    /** The technique result as shown: "" when hidden. Depends on `revision` as shownState. */
    function shownTechniqueResult(i, revision) {
        return hidden ? "" : techniqueResultOf(i)
    }
    /** "Technik gespielt 3, Andere Technik 1" over all notes (screen readers); "" when hidden. */
    function techniqueSummary(revision) {
        return hidden ? "" : KanteStyle.techniqueCountsText(techniqueCounts)
    }
    /** ", +32 ct" for an offpitch note with cents (screen readers), else "". Depends on `revision`. */
    function centsSuffix(i, revision) {
        const t = shownState(i, revision) === "offpitch" ? KanteStyle.centsText(centsOf(i)) : ""
        return t !== "" ? ", " + t : ""
    }

    onNotesChanged: resetStates()
}
