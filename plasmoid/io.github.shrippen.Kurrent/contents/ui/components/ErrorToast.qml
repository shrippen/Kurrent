import QtQuick
import "../Kante"

// The message of a failed write (save, delete, move), in every view. The controller's
// `error` signal carries it; `errorMessage` is only for "loading failed".
KanteToast {
    id: toast

    required property var controller

    kind: KanteToast.Kind.Danger
    life: 6000

    Connections {
        target: toast.controller

        function onError(message) {
            toast.text = message
            toast.show()
        }
    }
}
