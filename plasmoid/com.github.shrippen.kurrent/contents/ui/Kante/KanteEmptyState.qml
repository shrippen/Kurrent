import QtQuick
import QtQuick.Layouts
import "."

/** "Nothing here yet" / "service offline" / "plugin missing": a title, a line and room for one action. */
Item {
    id: empty

    property string title: ""
    property string text: ""
    /** An action (a KanteButton) placed under the text. */
    default property alias action: actionSlot.data

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: column.implicitHeight + KanteStyle.unit(48)

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: KanteStyle.frameColor
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: parent.width - KanteStyle.unit(32)
        spacing: KanteStyle.unit(8)
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: empty.title
            color: KanteStyle.strongTextColor
            font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.3)
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: empty.text
            color: KanteStyle.mutedTextColor
            font: KanteStyle.defaultFont
            wrapMode: Text.WordWrap
        }
        Item {
            id: actionSlot
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
