import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components"

// New counts update the view tiles in place. The tiles were a Repeater over a fresh array, so
// every count change (each search, each sync) tore down and rebuilt all five tiles.
Item {
    id: scene
    width: 800; height: 120

    QtObject {
        id: fakeController
        property var viewTaskCounts: ({ overdue: 1, today: 2, tomorrow: 0, scheduled: 5, completed: 9 })
        property string currentView: "today"
    }

    ViewTiles { id: tiles; width: 800; controller: fakeController }

    TestCase {
        name: "ViewTiles"
        when: windowShown

        function tileItems() {
            return tiles.children.filter(c => c.modelData !== undefined)
        }

        function test_countsUpdateInPlace() {
            const before = tileItems()
            compare(before.length, 5)
            fakeController.viewTaskCounts = { overdue: 3, today: 2, tomorrow: 0, scheduled: 5, completed: 9 }
            const after = tileItems()
            compare(after.length, 5)
            verify(after[0] === before[0], "the overdue tile stays the same item")
            compare(after[0].modelData.value, "3")
        }
    }
}
