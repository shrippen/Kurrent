import QtQuick
import "."

/**
 * Four corner brackets that lock onto a target (focus of a tile or card).
 * Place it over the item with anchors.fill; `active` fades them in while they
 * travel from outside to `restInset`. Without motion they simply appear.
 */
Item {
    id: brk

    property bool active: false
    property color color: KanteStyle.focusColor
    property int arm: KanteStyle.unit(12)
    property int thickness: 2
    /** Distance from the edge when locked on (negative: outside). */
    property real restInset: KanteStyle.unit(5)
    /** Where they start before locking on. */
    property real startInset: -KanteStyle.unit(14)

    visible: KanteStyle.active
    opacity: active ? 1 : 0
    property real inset: active ? restInset : startInset

    Behavior on opacity { NumberAnimation { duration: KanteStyle.durationFast } }
    Behavior on inset { NumberAnimation { duration: KanteStyle.animate ? 220 : 0; easing.type: Easing.OutCubic } }

    Repeater {
        model: 4
        delegate: Item {
            required property int index
            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index >= 2
            width: brk.arm
            height: brk.arm
            x: atRight ? brk.width - width - brk.inset : brk.inset
            y: atBottom ? brk.height - height - brk.inset : brk.inset
            Rectangle {
                width: parent.width
                height: brk.thickness
                y: atBottom ? parent.height - height : 0
                color: brk.color
            }
            Rectangle {
                width: brk.thickness
                height: parent.height
                x: atRight ? parent.width - width : 0
                color: brk.color
            }
        }
    }
}
