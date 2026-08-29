import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".." as KurrentUi

ColumnLayout {
    id: root

    required property string widgetVersion
    required property string backendVersion
    property string installCommand: "curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | sudo bash"

    readonly property string displayBackendVersion: backendVersion !== "" ? backendVersion : i18n("unknown")

    spacing: KurrentUi.Design.spaceSmall

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        text: i18n("Backend version mismatch") + "\n"
              + i18n("This widget is version %1 but the installed backend is %2. Reinstall the backend to match.",
                     widgetVersion, displayBackendVersion)
        actions: [
            Kirigami.Action {
                text: i18n("Copy command")
                icon.name: "edit-copy"
                onTriggered: {
                    commandEdit.selectAll()
                    commandEdit.copy()
                    commandEdit.deselect()
                }
            },
            Kirigami.Action {
                text: i18n("Open GitHub")
                icon.name: "internet-services"
                onTriggered: Qt.openUrlExternally("https://github.com/shrippen/Kurrent")
            }
        ]
    }

    TextEdit {
        id: commandEdit
        visible: false
        readOnly: true
        text: root.installCommand
    }
}
