import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/focus.js" as Focus

TestCase {
    name: "FocusJs"
    when: windowShown

    Item {
        id: kurrent
        Item {
            id: inner
            Item { id: field; focus: true }
        }
    }
    // Another widget or the folder view on the same desktop window.
    Item {
        id: neighbour
        Item { id: icons }
    }

    function test_insideOnlyWithFocusInTheScope() {
        verify(Focus.inside(field, kurrent))
        verify(Focus.inside(kurrent, kurrent))
        verify(!Focus.inside(icons, kurrent))
        verify(!Focus.inside(null, kurrent))
        verify(!Focus.inside(field, null))
    }
}
