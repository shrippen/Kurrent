import QtQuick
import QtQuick.Shapes
import "."

/**
 * Drag and drop placeholders drawn with a dashed 2 px outline: the Gap that the
 * picked tile leaves behind (cyan) and the Cell it may land in (grey).
 */
Shape {
    id: zone

    enum Kind {
        Gap,
        Cell
    }

    property int kind: KanteDropZone.Kind.Gap
    readonly property color tone: kind === KanteDropZone.Kind.Gap ? KanteStyle.focusColor : KanteStyle.frameColor

    antialiasing: true

    ShapePath {
        fillColor: "transparent"
        strokeColor: zone.tone
        strokeWidth: 2
        strokeStyle: ShapePath.DashLine
        dashPattern: [3, 2]
        joinStyle: ShapePath.MiterJoin
        startX: 1
        startY: 1
        PathLine { x: zone.width - 1; y: 1 }
        PathLine { x: zone.width - 1; y: zone.height - 1 }
        PathLine { x: 1; y: zone.height - 1 }
        PathLine { x: 1; y: 1 }
    }
}
