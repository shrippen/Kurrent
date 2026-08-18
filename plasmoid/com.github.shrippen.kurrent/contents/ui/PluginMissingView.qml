import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "." as KurrentUi

Item {
    id: root

    readonly property string installCommand: "curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | sudo bash"

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: column.implicitHeight + KurrentUi.Design.spaceLarge * 2

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - KurrentUi.Design.spaceLarge * 2, Kirigami.Units.gridUnit * 28))
        spacing: KurrentUi.Design.spaceSmall

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            icon.name: "dialog-information"
            text: i18n("Backend not installed")
            explanation: i18n("The KDE Store package is only the widget. Run this in a terminal to install the plugin:")
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: commandEdit.implicitHeight + KurrentUi.Design.padInner * 2
            radius: KurrentUi.Design.inputRadius
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: KurrentUi.Design.windowBorderColor()

            TextEdit {
                id: commandEdit
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: KurrentUi.Design.padInner
                readOnly: true
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                text: root.installCommand
                color: Kirigami.Theme.textColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                selectionColor: Kirigami.Theme.highlightColor
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: KurrentUi.Design.spaceSmall

            QQC2.Button {
                icon.name: "edit-copy"
                text: i18n("Copy command")
                onClicked: {
                    commandEdit.selectAll()
                    commandEdit.copy()
                    commandEdit.deselect()
                }
            }
            QQC2.Button {
                icon.name: "internet-services"
                text: i18n("Open GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/shrippen/Kurrent")
            }
            Item {
                Layout.fillWidth: true
            }
        }
    }
}
