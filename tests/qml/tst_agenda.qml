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
        // Only before a letter: "-" before a quote is no break for Qt, so the word stays one
        // piece and is cut as a whole; after "–" Qt does break.
        var quoted = Agenda.fitWords('Mail-"Newsletter"', fm.advanceWidth('"Newsletter"'), fm)
        verify(quoted.endsWith("…") && fm.advanceWidth(quoted) <= fm.advanceWidth('"Newsletter"'), quoted)
        var dashWidth = Math.max(fm.advanceWidth("Frankfurt–"), fm.advanceWidth("Mannheim"))
        compare(Agenda.fitWords("Frankfurt–Mannheim", dashWidth, fm), "Frankfurt–Mannheim")
        // A no-break space joins words: "10 km" is one piece.
        var nbsp = Agenda.fitWords("10\u00a0km", fm.advanceWidth("10"), fm)
        verify(nbsp.endsWith("…"), nbsp)
        // Chinese, Japanese and Thai have no spaces; Qt breaks between their characters, so
        // such a title must not be cut to one line.
        var narrowCjk = fm.advanceWidth("每周计划")
        compare(Agenda.fitWords("每周计划会议与团队讨论", narrowCjk, fm), "每周计划会议与团队讨论")
        compare(Agenda.fitWords("ประชุมวางแผนประจำสัปดาห์", fm.advanceWidth("ประชุม"), fm), "ประชุมวางแผนประจำสัปดาห์")
        // Hangul (and Khmer, Lao) Qt does not break between characters: a word too wide is cut.
        var korean = Agenda.fitWords("주간계획회의준비사항점검 내일", fm.advanceWidth("주간계획"), fm)
        verify(korean.split(" ")[0].endsWith("…"), korean)
        // Only the part outside a break-anywhere script is cut: "会议" stays, the Latin word is cut.
        var mixed = Agenda.fitWords("会议Wochenplanungsbesprechung", fm.advanceWidth("Wochenplan"), fm)
        verify(mixed.startsWith("会议Wochen") && mixed.endsWith("…"), mixed)
        // Before layout (no width yet) the text passes through.
        compare(Agenda.fitWords("Wochenplanung", 0, fm), "Wochenplanung")
        compare(Agenda.fitWords(undefined, width, fm), "")
    }
}
