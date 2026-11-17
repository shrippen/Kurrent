import QtQuick
import QtQuick.Controls
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components"

// A task row builds its reschedule menu when it is asked for, not with the row: about 30 rows
// are on screen, each carried a menu of five items it rarely opens.
Item {
    id: scene
    width: 500; height: 200

    QtObject { id: fakeController }

    Component {
        id: rowScene
        TaskDelegate {
            width: 500
            controller: fakeController
            model: ({ itemId: 7, uid: "t7", summary: "Call the bank", dueDate: new Date(), completed: false })
            index: 0
        }
    }

    TestCase {
        name: "TaskDelegate"
        when: windowShown

        function menus(item) {
            let n = 0
            for (let i = 0; i < item.data.length; i++) {
                if (item.data[i] instanceof Menu) {
                    n++
                }
            }
            return n
        }

        function test_rescheduleMenuBuiltOnDemand() {
            const row = createTemporaryObject(rowScene, scene)
            verify(row, "the row")
            compare(menus(row), 0, "no menu with the row")
            const before = row.Overlay.overlay.children.length
            row.openRescheduleMenu()
            tryVerify(() => row.Overlay.overlay.children.length > before, 2000, "the menu opens")
        }
    }
}
