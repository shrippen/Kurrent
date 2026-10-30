import QtQuick
import "."

/**
 * A daily goal as a vertical segment display (Kante 1.25, for Kaiwa's panel widget; web:
 * `.goalbar`; decision D-7). `segments` lamps stacked bottom to top, as many lit as `value`
 * reaches, with an optional label beside them (a streak, "12 T"). Square like every Kante
 * marker, readable at 22 px in a panel. Lit segments take the accent colour, which follows
 * the Plasma highlight in System.
 *
 *   KanteGoalMeter { value: minutes / goal; label: streak + " T" }
 */
Row {
    id: goal

    property real value: 0
    property int segments: 5
    property string label: ""
    property string accessibleName: "Tagesziel"
    /** Height of the stack; the panel's thickness minus its margins. */
    property real stackHeight: KanteStyle.unit(22)

    readonly property int lit: Math.max(0, Math.min(segments, Math.floor(value * segments + 1e-6)))

    spacing: KanteStyle.unit(6)

    Accessible.role: Accessible.ProgressBar
    Accessible.name: accessibleName
    Accessible.description: Math.round(Math.min(1, Math.max(0, value)) * 100) + " %" + (label ? ", " + label : "")

    Column {
        id: stack
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.max(1, Math.round(goal.stackHeight / goal.segments * 0.25))
        Repeater {
            model: goal.segments
            delegate: Rectangle {
                required property int index
                // Top to bottom in the Column; segment 0 is at the bottom.
                readonly property int fromBottom: goal.segments - 1 - index
                width: Math.round(goal.stackHeight * 0.9)
                height: Math.max(2, (goal.stackHeight - (goal.segments - 1) * stack.spacing) / goal.segments)
                color: fromBottom < goal.lit ? KanteStyle.accentColor : KanteStyle.frameColor
            }
        }
    }
    Text {
        visible: goal.label.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: goal.label
        color: KanteStyle.textColor
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
    }
}
