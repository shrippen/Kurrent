import QtQuick
import QtQuick.Shapes
import "."

/**
 * Card surface: filled polygon with the top-right corner cut off and an
 * optional 4 px accent bar along the top edge. With chamfer 0 it is a plain
 * rectangle. `chamferBottom` adds the second cut bottom-left (dialogs, install
 * box). `interactive` makes it a link card: under the pointer the cut opens
 * and the card lifts 3 px (Kante only). Used for Kante surfaces only; System
 * views keep their own Rectangles.
 */
Item {
    id: card

    property color color: KanteStyle.cardColor
    /** Accent bar on top; "transparent" for none. */
    property color barColor: "transparent"
    property int barHeight: KanteStyle.unit(4)
    property int chamfer: KanteStyle.chamfer
    /** Second cut at the bottom-left corner (0: none). */
    property int chamferBottom: 0
    property color borderColor: "transparent"
    /** A link card: the cut opens and the card lifts under the pointer. */
    property bool interactive: false
    readonly property bool hovered: hover.hovered
    /** Square: styles that read background.radius (Material menus, dialogs) get 0. */
    readonly property int radius: 0

    property real grow: interactive && hovered && KanteStyle.themed ? KanteStyle.unit(12) : 0
    Behavior on grow { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutCubic } }

    transform: Translate {
        y: card.grow > 0 ? -KanteStyle.unit(3) : 0
        Behavior on y { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
        id: hover
        enabled: card.interactive
    }

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            fillColor: card.color
            strokeColor: card.borderColor
            strokeWidth: card.borderColor.a > 0 ? 1 : -1
            startX: 0; startY: 0
            PathLine { x: card.width - card.chamfer - card.grow; y: 0 }
            PathLine { x: card.width; y: card.chamfer + card.grow }
            PathLine { x: card.width; y: card.height }
            PathLine { x: card.chamferBottom; y: card.height }
            PathLine { x: 0; y: card.height - card.chamferBottom }
            PathLine { x: 0; y: 0 }
        }

        // Accent bar, cut with the same corner.
        ShapePath {
            fillColor: card.barColor
            strokeWidth: -1
            startX: 0; startY: 0
            PathLine { x: card.width - card.chamfer - card.grow; y: 0 }
            PathLine { x: card.width - card.chamfer - card.grow + card.barHeight; y: card.barHeight }
            PathLine { x: 0; y: card.barHeight }
            PathLine { x: 0; y: 0 }
        }
    }
}
