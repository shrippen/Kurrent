import QtQuick 2.15

// Takes the focus for `target` on a press anywhere in its parent, so keys of its own work on
// the desktop. A PointHandler on top only watches: the press still reaches the buttons and
// scrolling views below it (a TapHandler there took the click from the buttons; one in the
// parent never saw presses a Flickable took).
Item {
    id: taker
    property Item target: null
    anchors.fill: parent
    z: 1000
    PointHandler {
        enabled: taker.enabled
        onActiveChanged: {
            if (active && taker.target && !taker.target.activeFocus) {
                taker.target.forceActiveFocus()
            }
        }
    }
}
