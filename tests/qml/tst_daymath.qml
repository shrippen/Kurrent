import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/daymath.js" as DayMath

TestCase {
    name: "DayMathJs"

    function test_clockOfMinute() {
        compare(DayMath.clockOfMinute(0), "00:00")
        compare(DayMath.clockOfMinute(545), "09:05")
        compare(DayMath.clockOfMinute(1439), "23:59")
    }

    function test_today() {
        var t = DayMath.today()
        var now = new Date()
        compare(t.getFullYear(), now.getFullYear())
        compare(t.getMonth(), now.getMonth())
        compare(t.getDate(), now.getDate())
        compare(t.getHours() + t.getMinutes() + t.getSeconds() + t.getMilliseconds(), 0)
    }

    function test_addDays() {
        var d = new Date(2026, 0, 31, 15, 30)
        var next = DayMath.addDays(d, 1)
        compare(next.getMonth(), 1)
        compare(next.getDate(), 1)
        compare(next.getHours(), 0)
        compare(DayMath.addDays(d, -31).getFullYear(), 2025)
        compare(d.getDate(), 31)
        compare(d.getHours(), 15)
    }

    // Across the DST change in Europe (29.3.2026) the result stays at midnight.
    function test_addDaysKeepsMidnight() {
        var r = DayMath.addDays(new Date(2026, 2, 28), 2)
        compare(r.getDate(), 30)
        compare(r.getHours(), 0)
    }
}
