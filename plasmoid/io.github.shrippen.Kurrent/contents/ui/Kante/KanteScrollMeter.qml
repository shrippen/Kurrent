import QtQuick
import "."

/** A thin cyan line with a 000 % readout that shows how far a Flickable is scrolled. Put it under a header. */
Item {
    id: meter

    property Flickable flickable: null
    readonly property real ratio: {
        if (!flickable) {
            return 0
        }
        var max = flickable.contentHeight - flickable.height
        return max > 0 ? Math.max(0, Math.min(1, (flickable.contentY - flickable.originY) / max)) : 0
    }

    implicitHeight: KanteStyle.unit(18)
    implicitWidth: KanteStyle.unit(200)
    visible: KanteStyle.active

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: KanteStyle.ruleColor
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width * meter.ratio
        height: 2
        color: KanteStyle.focusColor
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        text: String(Math.round(meter.ratio * 100)).padStart(3, "0") + " %"
        color: KanteStyle.focusColor
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
    }
}
