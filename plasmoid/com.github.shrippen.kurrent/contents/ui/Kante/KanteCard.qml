import QtQuick
import QtQuick.Shapes
import "."

/**
 * Card surface: filled polygon with the top-right corner cut off and an
 * optional accent bar along the top edge (shrippen Design Default).
 * With chamfer 0 it is a plain rectangle. Used for Kante surfaces only;
 * System views keep their own Rectangles.
 */
Item {
    id: card

    property color color: KanteStyle.cardColor
    /** Accent bar on top; "transparent" for none. */
    property color barColor: "transparent"
    property int barHeight: 3
    property int chamfer: KanteStyle.chamfer
    property color borderColor: "transparent"
    /** Square: styles that read background.radius (Material menus, dialogs) get 0. */
    readonly property int radius: 0

    Shape {
        anchors.fill: parent

        ShapePath {
            fillColor: card.color
            strokeColor: card.borderColor
            strokeWidth: card.borderColor.a > 0 ? 1 : -1
            startX: 0; startY: 0
            PathLine { x: card.width - card.chamfer; y: 0 }
            PathLine { x: card.width; y: card.chamfer }
            PathLine { x: card.width; y: card.height }
            PathLine { x: 0; y: card.height }
            PathLine { x: 0; y: 0 }
        }

        // Accent bar, cut with the same corner.
        ShapePath {
            fillColor: card.barColor
            strokeWidth: -1
            startX: 0; startY: 0
            PathLine { x: card.width - card.chamfer; y: 0 }
            PathLine { x: card.width - card.chamfer + card.barHeight; y: card.barHeight }
            PathLine { x: 0; y: card.barHeight }
            PathLine { x: 0; y: 0 }
        }
    }
}
