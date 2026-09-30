import QtQuick
import "."

/**
 * Diagonal warning stripes, marching to the right while `running` (banner
 * edges, indeterminate progress). Rectangular: it clips its stripes.
 */
Item {
    id: hazard

    property color color: KanteStyle.accentColor
    property color gapColor: "transparent"
    /** Horizontal width of one stripe and of one period (stripe + gap). */
    property real stripe: KanteStyle.unit(8)
    property bool running: true
    readonly property real period: stripe * 2
    property real offset: 0

    clip: true

    Rectangle { anchors.fill: parent; color: hazard.gapColor }

    Repeater {
        model: Math.ceil(hazard.width / hazard.period) + 3
        delegate: Rectangle {
            required property int index
            width: hazard.stripe * 0.7071
            height: hazard.height * 3
            rotation: 45
            antialiasing: true
            color: hazard.color
            x: (index - 1) * hazard.period + hazard.offset - width / 2 + hazard.stripe / 2
            y: -hazard.height
        }
    }

    NumberAnimation on offset {
        running: hazard.running && KanteStyle.animate && hazard.visible
        loops: Animation.Infinite
        from: 0
        to: hazard.period
        duration: 1400
    }
}
