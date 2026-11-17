import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/recurrence.js" as Recurrence

TestCase {
    name: "RecurrenceJs"

    function test_indexFor() {
        compare(Recurrence.indexFor("none"), 0)
        compare(Recurrence.indexFor("daily"), 1)
        compare(Recurrence.indexFor("weekly"), 2)
        compare(Recurrence.indexFor("monthly"), 3)
        compare(Recurrence.indexFor("yearly"), 4)
        // Anything else, such as a custom rule, shows as "none".
        compare(Recurrence.indexFor("custom"), 0)
        compare(Recurrence.indexFor(undefined), 0)
    }

    function test_valueFor() {
        compare(Recurrence.valueFor(0), "none")
        compare(Recurrence.valueFor(1), "daily")
        compare(Recurrence.valueFor(2), "weekly")
        compare(Recurrence.valueFor(3), "monthly")
        compare(Recurrence.valueFor(4), "yearly")
        compare(Recurrence.valueFor(-1), "none")
        compare(Recurrence.valueFor(9), "none")
    }

    function test_roundTrip() {
        for (var i = 0; i <= 4; ++i) {
            compare(Recurrence.indexFor(Recurrence.valueFor(i)), i)
        }
    }
}
