import QtQuick
import QtQuick.Controls
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/components"

// The Agenda takes the focus on a press, so its keys work on the desktop; the press must still
// reach the buttons in it (the week's "Overdue" tray and the folds of done and overdue tasks).
Item {
    id: scene
    width: 400; height: 300
    property int clicks: 0

    Item {
        id: host
        anchors.fill: parent
        // The Agenda's views scroll; a Flickable takes every press it gets.
        Flickable {
            anchors.fill: parent
            contentHeight: 600
            Button { id: button; x: 10; y: 10; width: 100; height: 40; text: "fold"; focusPolicy: Qt.NoFocus; onClicked: scene.clicks++ }
            Rectangle { id: empty; x: 10; y: 100; width: 100; height: 40 }
        }
        FocusTaker { target: host }
    }

    TestCase {
        name: "FocusTaker"
        when: windowShown

        function test_buttonsStillTakeTheClick() {
            mouseClick(button)
            compare(scene.clicks, 1)
        }

        function test_aPressInAScrollingViewTakesTheFocus() {
            verify(!host.activeFocus)
            mouseClick(empty)
            verify(host.activeFocus)
        }
    }
}
