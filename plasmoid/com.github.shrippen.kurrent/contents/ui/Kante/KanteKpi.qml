import QtQuick
import "."

/**
 * A figure with its label and, if wanted, its change: `delta` is the text ("+12 %"),
 * `trend` 1 up, -1 down, 0 flat. The arrow is a shape, so the change never
 * depends on colour alone. `good` says which way is good: 1 up (default,
 * e.g. revenue), -1 down (costs, errors: rising turns red), 0 none (arrow only).
 */
Column {
    id: kpi

    property string value: ""
    property string label: ""
    property string delta: ""
    property int trend: 0
    property int good: 1
    // trend × good: > 0 good news, < 0 bad news; with good 0 the arrow only names the direction
    readonly property int sense: trend * good
    readonly property color deltaColor: sense > 0 ? KanteStyle.positiveTextColor
        : (sense < 0 ? KanteStyle.negativeTextColor
                     : (trend !== 0 ? KanteStyle.textColor : KanteStyle.mutedTextColor))

    spacing: 2

    Text {
        text: kpi.value
        color: KanteStyle.strongTextColor
        font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 2.6)
    }
    Text {
        text: kpi.label
        color: KanteStyle.mutedTextColor
        font: KanteStyle.labelFont()
    }
    Row {
        visible: kpi.delta.length > 0
        spacing: KanteStyle.unit(6)
        readonly property color tone: kpi.deltaColor
        onToneChanged: arrow.requestPaint()

        Canvas {
            id: arrow
            width: KanteStyle.unit(10)
            height: KanteStyle.unit(9)
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = parent.tone
                ctx.beginPath()
                if (kpi.trend > 0) {
                    ctx.moveTo(width / 2, 0); ctx.lineTo(width, height); ctx.lineTo(0, height)
                } else if (kpi.trend < 0) {
                    ctx.moveTo(0, 0); ctx.lineTo(width, 0); ctx.lineTo(width / 2, height)
                } else {
                    ctx.rect(0, height / 2 - 1, width, 2)
                }
                ctx.closePath()
                ctx.fill()
            }
            Component.onCompleted: requestPaint()
        }
        Text {
            text: kpi.delta
            color: parent.tone
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }
}
