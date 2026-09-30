import QtQuick
import QtQuick.Shapes
import "."

/**
 * Running light: a short bright segment travelling around the cut outline of a
 * surface that is working (a tile being analysed, an upload area). Place it over
 * the surface with anchors.fill.
 */
Shape {
    id: runner

    property bool running: true
    property color color: KanteStyle.accentColor
    property real cut: KanteStyle.chamfer
    property real lineWidth: 2
    property real dashOffset: 0
    // Perimeter and dash lengths in stroke widths (Qt scales dash patterns by the width).
    readonly property real perimeter: (2 * (width + height) - 2 * cut + Math.SQRT2 * cut) / lineWidth

    visible: KanteStyle.active
    antialiasing: true

    NumberAnimation on dashOffset {
        running: runner.running && KanteStyle.animate && runner.visible
        loops: Animation.Infinite
        from: 0
        to: -runner.perimeter
        duration: 1800
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: runner.color
        strokeWidth: runner.lineWidth
        strokeStyle: ShapePath.DashLine
        dashPattern: [Math.max(1, 40 / runner.lineWidth), Math.max(1, runner.perimeter - 40 / runner.lineWidth)]
        dashOffset: runner.dashOffset
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        startX: runner.lineWidth / 2
        startY: runner.lineWidth / 2
        PathLine { x: runner.width - runner.lineWidth / 2 - runner.cut; y: runner.lineWidth / 2 }
        PathLine { x: runner.width - runner.lineWidth / 2; y: runner.lineWidth / 2 + runner.cut }
        PathLine { x: runner.width - runner.lineWidth / 2; y: runner.height - runner.lineWidth / 2 }
        PathLine { x: runner.lineWidth / 2; y: runner.height - runner.lineWidth / 2 }
        PathLine { x: runner.lineWidth / 2; y: runner.lineWidth / 2 }
    }
}
