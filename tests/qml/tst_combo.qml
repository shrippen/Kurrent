import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/combo.js" as Combo

TestCase {
    name: "ComboJs"

    function box() {
        return { currentIndex: 0, model: [{ text: "A", value: "a" }, { text: "B", value: "b" }, { text: "C", value: "c" }] }
    }

    function test_selectsMatchingValue() {
        var c = box()
        Combo.selectByValue(c, "c")
        compare(c.currentIndex, 2)
    }

    function test_unknownValueKeepsIndex() {
        var c = box()
        c.currentIndex = 1
        Combo.selectByValue(c, "zzz")
        compare(c.currentIndex, 1)
    }
}
