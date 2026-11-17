import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components"

// A failed write shows a message in every view: the toast listens to the controller's
// `error` signal, whatever the view behind it.
Item {
    id: scene
    width: 400; height: 200

    QtObject {
        id: fakeController
        signal error(string message)
    }

    Component {
        id: toastScene
        ErrorToast {
            width: 320
            controller: fakeController
        }
    }

    TestCase {
        name: "ErrorToast"
        when: windowShown

        function test_errorSignalShowsMessage() {
            const toast = createTemporaryObject(toastScene, scene)
            verify(toast, "the toast")
            verify(!toast.shown, "hidden at first")

            fakeController.error("Could not save the task.")
            verify(toast.shown, "shown after the signal")
            compare(toast.text, "Could not save the task.")
        }

        function test_nextErrorReplacesMessage() {
            const toast = createTemporaryObject(toastScene, scene)
            fakeController.error("first")
            fakeController.error("second")
            compare(toast.text, "second")
        }
    }
}
