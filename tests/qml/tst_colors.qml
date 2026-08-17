import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/colors.js" as Colors

TestCase {
    name: "ColorsJs"

    function test_normalizePriority() {
        compare(Colors.normalizePriority(0), 0)
        compare(Colors.normalizePriority(2), 1)
        compare(Colors.normalizePriority(5), 5)
        compare(Colors.normalizePriority(8), 9)
        compare(Colors.normalizePriority(12), 0)
    }

    function test_priorityLabelAndIndex() {
        compare(Colors.priorityLabel(1), "high")
        compare(Colors.priorityLabel(6), "medium")
        compare(Colors.priorityLabel(9), "low")
        compare(Colors.priorityLabel(0), "")
        compare(Colors.priorityToIndex(2), 1)
        compare(Colors.priorityToIndex(5), 2)
        compare(Colors.priorityToIndex(9), 3)
        compare(Colors.indexToPriority(0), 0)
        compare(Colors.indexToPriority(2), 5)
    }

    function test_colorsAreStable() {
        compare(String(Colors.colorForKey("inbox")), String(Colors.colorForKey("inbox")))
        verify(String(Colors.colorForKey("")).length > 0)
        verify(String(Colors.colorForPriority(1)).length > 0)
        verify(String(Colors.colorForPriority(0)).length > 0)
    }
}
