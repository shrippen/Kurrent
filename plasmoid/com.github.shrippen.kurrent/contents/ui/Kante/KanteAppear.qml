import QtQuick
import "."

/**
 * Lamp-style entrance: the content switches on in three hard steps (off, dim,
 * flicker-free full), one item after the other via `index` (55 ms apart) for a
 * grid of tiles. Runs once when created, or on `replay()`.
 */
Item {
    id: appear

    default property alias content: box.data
    property int index: 0
    property bool autoPlay: true

    implicitWidth: box.childrenRect.width
    implicitHeight: box.childrenRect.height

    function replay() {
        if (!KanteStyle.animate) {
            box.opacity = 1
            return
        }
        seq.stop()
        box.opacity = 0
        seq.start()
    }

    Component.onCompleted: {
        if (autoPlay) {
            replay()
        }
    }

    SequentialAnimation {
        id: seq
        PauseAnimation { duration: appear.index * 55 }
        PropertyAction { target: box; property: "opacity"; value: 0.5 }
        PauseAnimation { duration: 87 }
        PropertyAction { target: box; property: "opacity"; value: 0.2 }
        PauseAnimation { duration: 87 }
        PropertyAction { target: box; property: "opacity"; value: 1 }
    }

    Item {
        id: box
        width: appear.width
        height: appear.height
    }
}
