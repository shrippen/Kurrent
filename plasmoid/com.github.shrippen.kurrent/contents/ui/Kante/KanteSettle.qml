import QtQuick
import "."

/**
 * Drop settle: after a tile is dropped it glides from where it was released into
 * its cell with a small overshoot. Set `target`, then call `settle(fromX, fromY)`
 * with the release position (in the target's parent); the target is already at its
 * final x and y. Without motion it just sits there.
 */
Item {
    id: settle

    property Item target: null
    visible: false

    function settle(fromX, fromY) {
        if (!KanteStyle.animate || !target) {
            return
        }
        ax.from = fromX
        ax.to = target.x
        ay.from = fromY
        ay.to = target.y
        ax.restart()
        ay.restart()
    }

    NumberAnimation { id: ax; target: settle.target; property: "x"; duration: 380; easing.type: Easing.OutBack; easing.overshoot: KanteStyle.snapOvershoot }
    NumberAnimation { id: ay; target: settle.target; property: "y"; duration: 380; easing.type: Easing.OutBack; easing.overshoot: KanteStyle.snapOvershoot }
}
