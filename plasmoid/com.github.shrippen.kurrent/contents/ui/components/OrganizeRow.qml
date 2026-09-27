import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// One compact row on the Organize page (projects, labels, locations): colour swatch, name,
// task count, the caller's switches, and a menu with rename and delete (i3, k1-k3).
// Rename also by double-clicking the name.
QQC2.ItemDelegate {
    id: row

    property string name: ""
    property int count: 0
    property string iconName: "tag"
    property string colorValue: ""
    property color autoColor: Kirigami.Theme.textColor
    property bool renamable: true
    property bool deletable: true
    default property alias extra: extraRow.data

    signal colorPicked(string hex)
    signal renameRequested(string newName)
    signal deleteRequested()

    property bool editing: false

    function startRename() {
        if (!renamable) {
            return
        }
        nameField.text = name
        editing = true
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    function finishRename() {
        var t = nameField.text.trim()
        editing = false
        if (t.length > 0 && t !== name) {
            renameRequested(t)
        }
    }

    Layout.fillWidth: true
    hoverEnabled: true
    down: false
    padding: Kirigami.Units.smallSpacing

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: row.iconName
            color: row.colorValue.length > 0 ? row.colorValue : row.autoColor
        }

        ColorSwatchButton {
            value: row.colorValue
            autoColor: row.autoColor
            onPicked: function(hex) { row.colorPicked(hex) }
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: !row.editing
            text: row.name
            elide: Text.ElideRight
            TapHandler {
                enabled: row.renamable
                onDoubleTapped: row.startRename()
            }
        }
        QQC2.TextField {
            id: nameField
            Layout.fillWidth: true
            visible: row.editing
            onAccepted: row.finishRename()
            onActiveFocusChanged: if (!activeFocus && row.editing) row.finishRename()
            Keys.onEscapePressed: row.editing = false
        }

        QQC2.Label {
            text: i18np("%1 task", "%1 tasks", row.count)
            font: Kirigami.Theme.smallFont
            opacity: 0.6
        }

        RowLayout {
            id: extraRow
            spacing: Kirigami.Units.smallSpacing
        }

        QQC2.ToolButton {
            visible: row.renamable || row.deletable
            icon.name: "overflow-menu"
            display: QQC2.AbstractButton.IconOnly
            text: i18n("More")
            onClicked: menu.popup(this, 0, height)

            QQC2.Menu {
                id: menu
                QQC2.MenuItem {
                    visible: row.renamable
                    text: i18n("Rename")
                    icon.name: "edit-rename"
                    onTriggered: row.startRename()
                }
                QQC2.MenuItem {
                    visible: row.deletable
                    text: i18n("Delete…")
                    icon.name: "edit-delete"
                    onTriggered: confirm.open()
                }
            }
        }
    }

    // Delete says how many tasks lose the entry (k3).
    Kirigami.PromptDialog {
        id: confirm
        parent: QQC2.Overlay.overlay
        title: i18n("Delete “%1”?", row.name)
        subtitle: i18np("It is removed from %1 task.", "It is removed from %1 tasks.", row.count)
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: row.deleteRequested()
    }
}
