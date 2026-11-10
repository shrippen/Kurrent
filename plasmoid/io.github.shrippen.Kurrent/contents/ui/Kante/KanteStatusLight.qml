import QtQuick
import "."

/** One tile per service: a bar and a square in the state colour, the name and a detail ("OK · 42 ms"). Uptime tiers: from 99.9 % ok, below warn, below 99 % bad. */
Item {
    id: light

    enum State {
        Ok,
        Warn,
        Bad,
        Off
    }

    property int status: KanteStatusLight.State.Ok
    property string name: ""
    property string detail: ""

    readonly property color tone: {
        switch (status) {
        case KanteStatusLight.State.Warn: return KanteStyle.warningColor
        case KanteStatusLight.State.Bad: return KanteStyle.negativeTextColor
        case KanteStatusLight.State.Off: return KanteStyle.frameColor
        default: return KanteStyle.positiveTextColor
        }
    }
    /** The state for an uptime in percent. */
    function stateForUptime(percent) {
        return percent >= 99.9 ? KanteStatusLight.State.Ok : (percent >= 99 ? KanteStatusLight.State.Warn : KanteStatusLight.State.Bad)
    }

    implicitWidth: KanteStyle.unit(150)
    implicitHeight: KanteStyle.unit(64)

    KanteCard {
        anchors.fill: parent
        barColor: light.tone
        chamfer: KanteStyle.chamferSmall
    }
    Column {
        x: KanteStyle.unit(14)
        y: KanteStyle.unit(14)
        spacing: KanteStyle.unit(4)
        Text {
            text: light.name
            color: KanteStyle.strongTextColor
            font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.05)
        }
        Row {
            spacing: KanteStyle.unit(6)
            Rectangle { width: KanteStyle.unit(9); height: width; color: light.tone; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: light.detail
                color: KanteStyle.textColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
            }
        }
    }
}
