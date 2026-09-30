import QtQuick
import "."

/** Steps of a process: done (green bar, tick), now (yellow bar), later (grey). `model` is a list of labels; `current` the active index. */
Row {
    id: steps

    property var model: []
    property int current: 0

    spacing: 2

    Repeater {
        model: steps.model
        delegate: Item {
            id: step
            required property int index
            required property var modelData
            readonly property bool done: index < steps.current
            readonly property bool now: index === steps.current
            width: Math.max(KanteStyle.unit(110), label.implicitWidth + KanteStyle.unit(24))
            height: KanteStyle.unit(60)

            Rectangle { anchors.fill: parent; color: KanteStyle.cardColor }
            Rectangle {
                width: parent.width
                height: KanteStyle.unit(4)
                color: step.done ? KanteStyle.positiveTextColor : (step.now ? KanteStyle.accentColor : KanteStyle.frameColor)
            }
            Column {
                x: KanteStyle.unit(10)
                y: KanteStyle.unit(12)
                spacing: 2
                Text {
                    text: (step.done ? "✓ 0" : "0") + (step.index + 1)
                    color: step.done ? KanteStyle.positiveTextColor : (step.now ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor)
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
                }
                Text {
                    id: label
                    text: step.modelData
                    color: step.now ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
                    font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize)
                }
            }
        }
    }
}
