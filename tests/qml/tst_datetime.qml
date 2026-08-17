import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/datetime.js" as DateTime

TestCase {
    name: "DateTimeJs"

    function test_pad2() {
        compare(DateTime.pad2(3), "03")
        compare(DateTime.pad2(12), "12")
    }

    function test_digitsOnly() {
        compare(DateTime.digitsOnly("13.08.2026"), "13082026")
        compare(DateTime.digitsOnly(""), "")
    }

    function test_formatDigitsWithDateTokens() {
        var tokens = DateTime._parseFormatTokens("dd.MM.yyyy")
        compare(DateTime.maxDigitsFor(tokens), 8)
        compare(DateTime.formatDigitsWithTokens("13082026", tokens), "13.08.2026")
        compare(DateTime.formatDigitsWithTokens("13", tokens), "13")
    }

    function test_formatDigitsWithTimeTokens() {
        var tokens = DateTime._parseFormatTokens("HH:mm")
        compare(DateTime.formatDigitsWithTokens("0930", tokens), "09:30")
    }

    function test_parseIsoDateAndTime() {
        var d = DateTime.parseDate("2026-08-13")
        verify(d !== null)
        var t = DateTime.parseTime("9:05")
        compare(t.hours, 9)
        compare(t.minutes, 5)
        verify(DateTime.parseTime("25:00") === null)
        var combined = DateTime.combineDateTime("2026-08-13", "09:30", false)
        verify(combined !== null)
        var allDay = DateTime.combineDateTime("2026-08-13", "", true)
        verify(allDay !== null)
        verify(DateTime.combineDateTime("", "09:30", false) === null)
    }

    function test_segments() {
        var tokens = DateTime._parseFormatTokens("dd.MM.yyyy")
        var segs = DateTime.computeSegments("13.08.2026", tokens)
        compare(segs.length, 3)
        compare(DateTime.segmentAtPosition("13.08.2026", tokens, 4).kind, "month")
    }
}
