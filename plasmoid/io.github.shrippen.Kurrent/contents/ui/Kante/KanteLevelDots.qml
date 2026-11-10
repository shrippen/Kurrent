import QtQuick
import "."

/**
 * A level as a row of dots (Kante 1.60, for Mitori): `value` of `count` filled, the rest
 * sunken, such as how well a technique sits (1 seen … 4 ready for the exam). Small enough
 * for a list row; the number of filled dots says it, not the colour alone.
 *
 *   value   0..count (0: nothing yet)
 *   count   4 by default
 *   names   optional words per level, names[0] for none: what screen readers hear
 *           (else "value / count")
 *   color   the filled dots, the accent by default
 */
Row {
    id: dots

    property int value: 0
    property int count: 4
    property var names: []
    property color color: KanteStyle.accentColor
    /** Diameter of one dot. */
    property real dotSize: KanteStyle.unit(8)

    spacing: KanteStyle.unit(3)

    Accessible.role: Accessible.StaticText
    Accessible.name: names && names.length > value ? String(names[value]) : value + " / " + count

    Repeater {
        model: dots.count
        delegate: Rectangle {
            required property int index
            readonly property bool filled: index < dots.value
            width: dots.dotSize
            height: dots.dotSize
            radius: KanteStyle.active ? 0 : width / 2
            color: filled ? dots.color : KanteStyle.sunkenColor
            border.width: filled ? 0 : KanteStyle.borderWidth
            border.color: KanteStyle.frameColor
        }
    }
}
