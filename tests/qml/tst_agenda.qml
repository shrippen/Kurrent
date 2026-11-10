import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/agenda.js" as Agenda

TestCase {
    name: "AgendaJs"

    function test_drawnStart() {
        // A block from its start, also while its top handle is dragged down (10:00 → 11:00).
        compare(Agenda.drawnStart(600, 420, 1320, 30), 600)
        compare(Agenda.drawnStart(660, 420, 1320, 30), 660)
        // Short entries at the grid's end move up: 23:45 and 23:50 on a grid to 24:00 → 23:30.
        compare(Agenda.drawnStart(1425, 420, 1440, 30), 1410)
        compare(Agenda.drawnStart(1430, 0, 1440, 30), 1410)
        // Never above the grid.
        compare(Agenda.drawnStart(300, 360, 1440, 30), 360)
    }

    function test_dragPayload() {
        var p = Agenda.dragPayload({"itemId": 7, "uid": "u", "summary": "Weekly", "recurring": true, "priority": 1})
        compare(p.itemId, 7)
        compare(p.summary, "Weekly")
        // The payload keeps the flag (a recurring task moves only its occurrence).
        compare(p.recurring, true)
        compare(Agenda.dragPayload({"itemId": 8}).recurring, false)
    }

    FontMetrics {
        id: fm
    }

    // Titles wrap at word boundaries; a word wider than the column ends in "…" instead of
    // breaking mid-word ("Wochenplanun/g" in the week view).
    function test_fitWords() {
        var width = fm.advanceWidth("Wochenplan")
        var fitted = Agenda.fitWords("09:00 Wochenplanung", width, fm)
        var words = fitted.split(" ")
        compare(words[0], "09:00")
        verify(words[1].endsWith("…"), words[1])
        verify(fm.advanceWidth(words[1]) <= width, words[1])
        // Words that fit and the spacing between them stay as they are.
        compare(Agenda.fitWords("Call  mit Speiche", width, fm), "Call  mit Speiche")
        // A line may break after a hyphen: only a part too wide is cut.
        compare(Agenda.fitWords("Anwohner-Dankeschön", width, fm), "Anwohner-Dankeschön")
        var cut = Agenda.fitWords("Wochenplanung-Dankeschön", width, fm)
        verify(cut.startsWith("Wochen") && cut.endsWith("…-Dankeschön"), cut)
        verify(fm.advanceWidth(cut.split("-")[0] + "-") <= width, cut)
        // Qt breaks after "/" but not between "-" or "/" and a digit (UAX #14 LB25): a date is
        // one piece, "Kunde/Lieferant" two.
        compare(Agenda.fitWords("Kunde/Lieferant", fm.advanceWidth("Lieferant"), fm), "Kunde/Lieferant")
        var narrow = fm.advanceWidth("2026-1")
        var date = Agenda.fitWords("2026-11-10", narrow, fm)
        verify(date.endsWith("…") && fm.advanceWidth(date) <= narrow, date)
        // Before layout (no width yet) the text passes through.
        compare(Agenda.fitWords("Wochenplanung", 0, fm), "Wochenplanung")
        compare(Agenda.fitWords(undefined, width, fm), "")
    }
}
