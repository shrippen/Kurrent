import QtQuick
import QtQuick.Shapes
import "."

/**
 * Filled and/or stroked polygon with the top-right corner cut off and, for
 * primary buttons, dialogs and the install box, a second cut at the bottom-left.
 * The base of every cut Kante shape. A stroke is drawn inside the item.
 */
Shape {
    id: poly

    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real cutTopRight: KanteStyle.chamfer
    property real cutBottomLeft: 0
    /** Distance of the outline from the item edge (a stroke is centred on it). */
    property real inset: strokeWidth > 0 ? strokeWidth / 2 : 0

    antialiasing: true

    ShapePath {
        fillColor: poly.fillColor
        strokeColor: poly.strokeColor
        strokeWidth: poly.strokeWidth > 0 ? poly.strokeWidth : -1
        joinStyle: ShapePath.MiterJoin
        startX: poly.inset
        startY: poly.inset
        PathLine { x: poly.width - poly.inset - poly.cutTopRight; y: poly.inset }
        PathLine { x: poly.width - poly.inset; y: poly.inset + poly.cutTopRight }
        PathLine { x: poly.width - poly.inset; y: poly.height - poly.inset }
        PathLine { x: poly.inset + poly.cutBottomLeft; y: poly.height - poly.inset }
        PathLine { x: poly.inset; y: poly.height - poly.inset - poly.cutBottomLeft }
        PathLine { x: poly.inset; y: poly.inset }
    }
}
