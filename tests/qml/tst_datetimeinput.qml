import QtQuick
import QtQuick.Controls
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components"

// A date field builds its date popup (a month grid of day delegates) when the picker opens,
// not with the field: the editor and the inline editor hold six of them, all built at start.
Item {
    id: scene
    width: 400; height: 400

    DateTimeInput { id: input; mode: "date"; popupParent: scene }

    TestCase {
        name: "DateTimeInput"
        when: windowShown

        // Date popups among `item`'s data (a popup is data, not a child).
        function popups(item) {
            let n = 0
            for (let i = 0; i < item.data.length; i++) {
                if (String(item.data[i]).indexOf("DatePopup") >= 0) {
                    n++
                }
            }
            return n
        }
        function pickerButton() {
            for (let i = 0; i < input.children.length; i++) {
                const c = input.children[i]
                if (c.icon && c.icon.name === "view-calendar") {
                    return c
                }
            }
            return null
        }

        function test_popupBuiltOnOpen() {
            compare(popups(input) + popups(scene), 0, "no popup before the picker opens")
            const overlay = input.Overlay.overlay
            const before = overlay.children.length
            const button = pickerButton()
            verify(button, "the picker button")
            button.clicked()
            tryVerify(() => overlay.children.length > before, 2000, "the popup opens")
        }
    }
}
