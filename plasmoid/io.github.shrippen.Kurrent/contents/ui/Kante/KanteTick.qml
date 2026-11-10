import QtQuick
import QtQuick.Shapes
import "."

/** A check mark that is drawn as a stroke when `checked` turns on (the box and toast tick). */
Shape {
    id: tick

    property bool checked: false
    property color color: KanteStyle.accentForegroundColor
    property real lineWidth: Math.max(2, Math.round(width / 5))
    property real progress: checked ? 1 : 0
    // Path length in stroke widths, for the dash trick.
    readonly property real span: (width * 1.25) / lineWidth

    antialiasing: true

    Behavior on progress { NumberAnimation { duration: KanteStyle.animate ? 220 : 0; easing.type: Easing.OutCubic } }

    ShapePath {
        strokeColor: tick.progress > 0 ? tick.color : "transparent"
        strokeWidth: tick.lineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        strokeStyle: ShapePath.DashLine
        dashPattern: [tick.span, tick.span + 1]
        dashOffset: tick.span * (1 - tick.progress)
        startX: tick.width * 0.18
        startY: tick.height * 0.54
        PathLine { x: tick.width * 0.42; y: tick.height * 0.76 }
        PathLine { x: tick.width * 0.82; y: tick.height * 0.26 }
    }
}
