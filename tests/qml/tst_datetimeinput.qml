import QtQuick
import QtQuick.Controls
import QtTest

// A date field builds its date popup (a month grid of day delegates) when the picker opens,
// not with the field: the editor and the inline editor hold six of them, all built at start.
// Created at run time: without kirigami-addons the test skips instead of failing to compile,
// unless KURRENT_REQUIRE_KIRIGAMI_ADDONS=1 (CI) makes it fail.
Item {
    id: scene
    width: 400; height: 400

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
        function pickerButton(input) {
            for (let i = 0; i < input.children.length; i++) {
                const c = input.children[i]
                if (c.icon && c.icon.name === "view-calendar") {
                    return c
                }
            }
            return null
        }

        function test_popupBuiltOnOpen() {
            const component = Qt.createComponent(
                "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components/DateTimeInput.qml")
            if (!kurrentRequireAddons && component.status === Component.Error
                    && component.errorString().indexOf("kirigamiaddons") >= 0) {
                skip("org.kde.kirigamiaddons.dateandtime is not installed")
            }
            compare(component.status, Component.Ready, component.errorString())
            const input = createTemporaryObject(component, scene, { mode: "date", popupParent: scene })
            compare(popups(input) + popups(scene), 0, "no popup before the picker opens")
            const overlay = input.Overlay.overlay
            const before = overlay.children.length
            const button = pickerButton(input)
            verify(button, "the picker button")
            button.clicked()
            tryVerify(() => overlay.children.length > before, 2000, "the popup opens")
        }
    }
}
