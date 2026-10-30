import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/taps.js" as Taps

TestCase {
    name: "TapsJs"

    function test_doubleClickOpensTheEditorOnce() {
        // Without the inspector the first tap opens the editor; the second one adds nothing.
        compare(Taps.tapAction(1, false), "edit")
        compare(Taps.tapAction(2, false), "")
        // With it the first tap inspects and the double click opens the editor.
        compare(Taps.tapAction(1, true), "inspect")
        compare(Taps.tapAction(2, true), "edit")
        compare(Taps.tapAction(3, true), "")
    }
}
