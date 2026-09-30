import QtQuick
import QtQuick.Layouts
import "."

/**
 * Bar that appears when something is selected: the count, your actions
 * (`actions`, e.g. KanteButtons) and a way to clear the selection. Cyan bar on
 * top, because selection is cyan. Set `visible` from the selection.
 */
Item {
    id: bar

    property int count: 0
    property string countLabel: "ausgewählt"
    property string clearText: "Aufheben"
    default property alias actions: actionRow.data
    signal clearRequested()

    implicitWidth: KanteStyle.unit(480)
    implicitHeight: KanteStyle.heightLarge + KanteStyle.unit(3)

    KanteCard {
        anchors.fill: parent
        color: KanteStyle.dialogColor
        barColor: KanteStyle.focusColor
        barHeight: KanteStyle.unit(3)
        chamfer: KanteStyle.chamferSmall
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: KanteStyle.unit(10)
        anchors.topMargin: KanteStyle.unit(12)
        spacing: KanteStyle.unit(12)

        Text {
            text: String(bar.count).padStart(2, "0")
            color: KanteStyle.strongTextColor
            font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.4)
        }
        Text {
            text: bar.countLabel
            color: KanteStyle.mutedTextColor
            font: KanteStyle.labelFont()
        }
        RowLayout { id: actionRow; spacing: KanteStyle.unit(8) }
        Item { Layout.fillWidth: true }
        KanteButton {
            text: bar.clearText
            emphasis: KanteButton.Emphasis.Quiet
            size: KanteButton.Size.Small
            onClicked: bar.clearRequested()
        }
    }
}
