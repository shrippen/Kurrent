import QtQuick
import "."

/**
 * Progress: a flat bar (`value` 0..1), a segment display (`segments` > 0: a row
 * of lamps, each one switches on in three hard steps when the value reaches it)
 * or indeterminate warning stripes. 8 px high.
 * `parts` stacks shares in one bar (web: several `.progress-bar > i`): a list of
 * {value, color}, values 0..1 of the whole, drawn left to right; the rest stays sunken.
 * Review progress: accepted, rejected, open.
 */
Item {
    id: bar

    property real value: 0
    property bool indeterminate: false
    /** 0: continuous bar; n: n segments. */
    property int segments: 0
    property color color: KanteStyle.accentColor
    /** Shares of one bar: [{value: 0.3, color: …}, …]; replaces `value` when set. */
    property var parts: []

    implicitWidth: KanteStyle.unit(200)
    implicitHeight: KanteStyle.unit(8)

    Rectangle {
        anchors.fill: parent
        visible: bar.segments === 0
        color: KanteStyle.sunkenColor

        Row {
            visible: !bar.indeterminate && bar.parts.length > 0
            height: parent.height
            Repeater {
                model: bar.parts
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(0, Math.min(1, modelData.value || 0)) * bar.width
                    height: bar.height
                    color: modelData.color || bar.color
                    Behavior on width { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutCubic } }
                }
            }
        }

        Rectangle {
            visible: !bar.indeterminate && bar.parts.length === 0
            width: Math.max(0, Math.min(1, bar.value)) * parent.width
            height: parent.height
            color: bar.color
            Behavior on width { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutCubic } }
        }

        KanteHazard {
            anchors.fill: parent
            visible: bar.indeterminate
            color: bar.color
            gapColor: KanteStyle.sunkenColor
            stripe: KanteStyle.unit(8)
        }
    }

    Row {
        anchors.fill: parent
        visible: bar.segments > 0
        spacing: 3
        Repeater {
            model: bar.segments
            delegate: Rectangle {
                required property int index
                width: (bar.width - (bar.segments - 1) * 3) / bar.segments
                height: bar.height
                readonly property bool lit: !bar.indeterminate && (index + 1) <= Math.round(bar.value * bar.segments)
                color: lit ? bar.color : KanteStyle.sunkenColor
                // A segment switches on like a lamp: dim, dimmer, full, in three hard steps.
                onLitChanged: if (lit && KanteStyle.animate) lamp.restart()
                SequentialAnimation {
                    id: lamp
                    PropertyAction { property: "opacity"; value: 0.5 }
                    PauseAnimation { duration: 87 }
                    PropertyAction { property: "opacity"; value: 0.2 }
                    PauseAnimation { duration: 87 }
                    PropertyAction { property: "opacity"; value: 1 }
                }
            }
        }
    }
}
