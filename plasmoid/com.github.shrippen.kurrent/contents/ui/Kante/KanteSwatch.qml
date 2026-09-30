import QtQuick
import QtQuick.Shapes
import "."

/**
 * Colour swatch of an entity: always a square. The ring shows where the colour
 * comes from: solid = set here, dashed = inherited, dotted = generated; a
 * selected swatch gets a light ring.
 */
Item {
    id: swatch

    enum Source {
        None,
        Own,
        Inherited,
        Generated
    }

    property color swatchColor: KanteStyle.focusColor
    property int source: KanteSwatch.Source.None
    property bool selected: false
    signal clicked()

    implicitWidth: KanteStyle.unit(18)
    implicitHeight: implicitWidth

    Rectangle { anchors.fill: parent; color: swatch.swatchColor }

    Shape {
        anchors.fill: parent
        anchors.margins: -4
        visible: swatch.selected || swatch.source !== KanteSwatch.Source.None
        antialiasing: true
        ShapePath {
            fillColor: "transparent"
            strokeColor: swatch.selected ? KanteStyle.strongTextColor : swatch.swatchColor
            strokeWidth: 2
            strokeStyle: (swatch.selected || swatch.source === KanteSwatch.Source.Own) ? ShapePath.SolidLine : ShapePath.DashLine
            dashPattern: swatch.source === KanteSwatch.Source.Generated ? [1, 1.5] : [3, 2]
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: 1
            PathLine { x: swatch.width + 8 - 1; y: 1 }
            PathLine { x: swatch.width + 8 - 1; y: swatch.height + 8 - 1 }
            PathLine { x: 1; y: swatch.height + 8 - 1 }
            PathLine { x: 1; y: 1 }
        }
    }

    TapHandler { onTapped: swatch.clicked() }
}
