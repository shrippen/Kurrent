import QtQuick
import "."

/**
 * Mechanical counter: every digit is a reel that rolls to its value, one after
 * the other. Leading zeros stay (`digits`). Set `value`; without motion the
 * reels just show it.
 */
Item {
    id: odo

    property int value: 0
    property int digits: 3
    property font font: KanteStyle.headingFont(KanteStyle.unit(30) * 0.75)
    property color color: KanteStyle.strongTextColor
    readonly property string padded: String(Math.max(0, value)).padStart(digits, "0")

    implicitWidth: row.implicitWidth
    implicitHeight: metric.height

    TextMetrics { id: metric; font: odo.font; text: "0" }

    Row {
        id: row
        Repeater {
            model: odo.digits
            delegate: Item {
                id: reel
                required property int index
                readonly property int digit: parseInt(odo.padded.charAt(index)) || 0
                width: metric.advanceWidth
                height: metric.height
                clip: true

                Column {
                    y: -reel.digit * metric.height
                    Behavior on y {
                        SequentialAnimation {
                            PauseAnimation { duration: KanteStyle.animate ? reel.index * 120 : 0 }
                            NumberAnimation { duration: KanteStyle.animate ? 900 : 0; easing.type: Easing.OutCubic }
                        }
                    }
                    Repeater {
                        model: 10
                        delegate: Text {
                            required property int index
                            width: reel.width
                            height: metric.height
                            horizontalAlignment: Text.AlignHCenter
                            text: index
                            font: odo.font
                            color: odo.color
                        }
                    }
                }
            }
        }
    }
}
