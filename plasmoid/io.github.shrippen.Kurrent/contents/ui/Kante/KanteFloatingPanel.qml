import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import "."

/**
 * Floating panel (Kante 1.81, for Klappe): a palette that floats over content, such as the
 * tools over a borderless floor plan. A Kante card with a hard shadow, a head line with the
 * title in `KanteSectionLabel` style and a sign to fold it; folded, only the head shows.
 * The caller places it (`x`, `y`, or anchors) and puts the content inside as children, which
 * it sizes itself (a Column of buttons, say); the panel is as wide and high as they and the head.
 *
 *   title       the heading
 *   collapsed   folded to its head (default false); the app may keep it
 *   toggle()    folds or unfolds
 *   headerHeight   height of the head, the panel's height while folded
 *   collapseText, expandText   the app's words for the sign (tooltip, screen readers)
 *
 * Keyboard: the head takes Tab (and shows a frame); Enter, Return and Space fold or unfold.
 * A click on the head does the same. The sign points down while open and right while folded.
 */
Item {
    id: panel

    property string title: ""
    property bool collapsed: false
    property string collapseText: "Einklappen"
    property string expandText: "Ausklappen"
    default property alias content: body.data

    readonly property real headerHeight: KanteStyle.heightMedium
    readonly property real pad: KanteStyle.unit(10)

    function toggle() {
        collapsed = !collapsed
    }

    implicitWidth: Math.max(KanteStyle.unit(160), head.implicitWidth, body.implicitWidth + 2 * pad)
    implicitHeight: headerHeight + (collapsed ? 0 : body.implicitHeight + 2 * pad)

    // The hard shadow: the card's shape again, 3 px down and right (Kante only).
    KantePolygon {
        visible: KanteStyle.themed
        x: KanteStyle.unit(3)
        y: KanteStyle.unit(3)
        z: -1
        width: panel.width
        height: panel.height
        fillColor: KanteStyle.tint(KanteStyle.strongTextColor, 0.2)
        cutTopRight: KanteStyle.chamferSmall
    }

    KanteCard {
        anchors.fill: parent
        color: KanteStyle.dialogColor
        borderColor: KanteStyle.frameColor
        chamfer: KanteStyle.chamferSmall
    }

    Item {
        id: head
        width: parent.width
        height: panel.headerHeight
        implicitWidth: label.implicitWidth + sign.width + 3 * panel.pad
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: panel.title
        Accessible.description: panel.collapsed ? panel.expandText : panel.collapseText
        Accessible.focusable: true
        QQC2.ToolTip.text: panel.collapsed ? panel.expandText : panel.collapseText
        QQC2.ToolTip.visible: hover.hovered
        QQC2.ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
        Accessible.onPressAction: panel.toggle()

        Keys.onPressed: function (event) {
            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) {
                return
            }
            panel.toggle()
            event.accepted = true
        }

        KanteSectionLabel {
            id: label
            anchors.left: parent.left
            anchors.leftMargin: panel.pad
            anchors.right: sign.left
            anchors.rightMargin: panel.pad
            anchors.verticalCenter: parent.verticalCenter
            text: panel.title
        }

        // A solid triangle: down while open, right while folded.
        Shape {
            id: sign
            anchors.right: parent.right
            anchors.rightMargin: panel.pad
            anchors.verticalCenter: parent.verticalCenter
            width: KanteStyle.unit(10)
            height: width
            antialiasing: true
            ShapePath {
                strokeWidth: -1
                fillColor: head.activeFocus || hover.hovered ? KanteStyle.focusColor : KanteStyle.mutedTextColor
                PathSvg {
                    readonly property real s: sign.width
                    path: panel.collapsed ? "M " + s * 0.2 + " 0 L " + s * 0.9 + " " + s / 2 + " L " + s * 0.2 + " " + s + " Z"
                                          : "M 0 " + s * 0.2 + " L " + s + " " + s * 0.2 + " L " + s / 2 + " " + s * 0.9 + " Z"
                }
            }
        }

        HoverHandler { id: hover }
        TapHandler {
            onTapped: {
                head.forceActiveFocus()
                panel.toggle()
            }
        }

        // The rule under the head, while open.
        Rectangle {
            visible: !panel.collapsed
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: KanteStyle.ruleColor
        }

        // Keyboard focus: a frame inside the head.
        Rectangle {
            visible: head.activeFocus
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.width: 2
            border.color: KanteStyle.focusColor
        }
    }

    Column {
        id: body
        visible: !panel.collapsed
        x: panel.pad
        y: panel.headerHeight + panel.pad
        width: panel.width - 2 * panel.pad
        spacing: KanteStyle.unit(8)
    }
}
