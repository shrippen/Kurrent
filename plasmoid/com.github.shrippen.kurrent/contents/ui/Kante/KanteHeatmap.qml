import QtQuick
import "."

/**
 * Heat scale: a grid of squares, `levels` a list of 0 to 4 (0 = empty, 4 = full cyan).
 * Steps 22 / 44 / 66 / 100 % of the focus colour over the sunken ground.
 */
Grid {
    id: heat

    property var levels: []
    property int cellSize: KanteStyle.unit(16)
    /** Colour of a level; apps read it for their legend. */
    function levelColor(l) {
        return KanteStyle.tint(KanteStyle.focusColor, l >= 4 ? 1 : l * 0.22)
    }

    spacing: 3
    columns: 14

    Repeater {
        model: heat.levels.length
        delegate: Item {
            required property int index
            readonly property int level: Math.max(0, Math.min(4, heat.levels[index]))
            width: heat.cellSize
            height: heat.cellSize
            Rectangle { anchors.fill: parent; color: KanteStyle.sunkenColor }
            Rectangle { anchors.fill: parent; color: level > 0 ? heat.levelColor(level) : "transparent" }
        }
    }
}
