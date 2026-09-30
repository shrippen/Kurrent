import QtQuick
import QtQuick.Layouts
import "."

/**
 * A setting: title, hint and the control (`control`). While `modified` a cyan
 * square marks the title and the reset button shows; `resetRequested` fires when
 * it is pressed.
 */
Item {
    id: row

    property string title: ""
    property string hint: ""
    property bool modified: false
    property string resetText: "Zurücksetzen"
    default property alias control: controlSlot.data
    signal resetRequested()

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: Math.max(texts.implicitHeight, controlRow.implicitHeight) + KanteStyle.unit(20)

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: KanteStyle.ruleColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: KanteStyle.unit(10)
        anchors.bottomMargin: KanteStyle.unit(10)
        spacing: KanteStyle.unit(16)

        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            spacing: 2
            Row {
                spacing: KanteStyle.unit(8)
                Text {
                    text: row.title
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.defaultFont
                }
                Rectangle {
                    visible: row.modified
                    width: KanteStyle.unit(6)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: KanteStyle.focusColor
                }
            }
            Text {
                visible: row.hint.length > 0
                Layout.fillWidth: true
                text: row.hint
                color: KanteStyle.mutedTextColor
                font: KanteStyle.smallFont
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            id: controlRow
            spacing: KanteStyle.unit(8)
            Item {
                id: controlSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
            KanteButton {
                visible: row.modified
                text: row.resetText
                emphasis: KanteButton.Emphasis.Quiet
                size: KanteButton.Size.Small
                onClicked: row.resetRequested()
            }
        }
    }
}
