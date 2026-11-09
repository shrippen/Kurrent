import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/matrixlabels.js" as Labels

// matrixlabels.js loads datetime.js via .import, so neither script sees the QML
// context (no Locale enum there). These calls threw "Locale is not defined" before.
TestCase {
    name: "MatrixLabelsJs"

    readonly property var t: ({
        overdue: "Overdue", later: "Later", unscheduled: "Unscheduled",
        today: "Today", tomorrow: "Tomorrow",
        week: function (n) { return "Week " + n }
    })

    readonly property var matrix: ({
        today: "2026-11-01",
        timeStart: { "2026-11": "2026-11-01", "2026-11-10": "2026-11-10" },
        timeEnd: { "2026-11": "2026-11-30", "2026-11-10": "2026-11-10" }
    })

    function test_monthTitle() {
        compare(Labels.title(matrix, "2026-11", "month", t),
                Qt.locale().monthName(10, Locale.LongFormat))
        compare(Labels.fullLabel(matrix, "2026-11", "month", t),
                Qt.locale().monthName(10, Locale.LongFormat) + " 2026")
    }

    function test_dayTitle() {
        var day = new Date(2026, 10, 10)
        var expected = Qt.locale().dayName(day.getDay(), Locale.ShortFormat) + " 10"
        compare(Labels.title(matrix, "2026-11-10", "day", t), expected)
        verify(Labels.fullLabel(matrix, "2026-11-10", "day", t).indexOf(expected + " · ") === 0)
    }

    function test_relativeAndSpecialTitles() {
        compare(Labels.title(matrix, "2026-11-01", "day", t), "2026-11-01") // no timeStart entry: the key
        var m = { today: "2026-11-10", timeStart: { "2026-11-10": "2026-11-10" } }
        compare(Labels.title(m, "2026-11-10", "day", t), "Today")
        compare(Labels.title(m, "overdue", "day", t), "Overdue")
    }
}
