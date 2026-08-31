import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "colors.js" as Colors
import "."
import "components"

ConfigPageBase {
    id: root
    ConfigControllerLoader {
        id: configControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var configController: configControllerLoader.controller

    function hiddenSet() {
        var raw = cfg_hiddenLabels || ""
        if (!raw.trim()) return {}
        var parts = raw.split("||")
        var s = {}
        for (var i = 0; i < parts.length; ++i) {
            var v = parts[i].trim()
            if (v !== "") s[v] = true
        }
        return s
    }

    function toggleHidden(label) {
        var current = hiddenSet()
        if (current[label]) {
            delete current[label]
        } else {
            current[label] = true
        }
        cfg_hiddenLabels = Object.keys(current).join("||")
    }

    function isHidden(label) {
        return !!hiddenSet()[label]
    }

    function labelCount(name) {
        if (!configController) {
            return 0
        }
        var n = configController.labelTaskCounts[name]
        return n === undefined || n === null ? 0 : Number(n)
    }

    function addCurrentLabel() {
        var name = newLabelField.text.trim()
        if (!name || !configController) {
            return
        }
        configController.createLabel(name)
        newLabelField.text = ""
    }

    function renameCurrent(from) {
        var dest = renameField.text.trim()
        if (!dest || dest === from || !configController) {
            return
        }
        configController.renameLabel(from, dest)
        cfg_hiddenLabels = configController.renameSeparatedList(cfg_hiddenLabels || "", from, dest, "||")
        cfg_labelColors = configController.moveColorKey(cfg_labelColors || "", from, dest)
        renameField.text = ""
        renameFromCombo.currentIndex = -1
    }

    function applyColor(name, hex) {
        if (!configController) {
            return
        }
        cfg_labelColors = configController.setColorOverride(cfg_labelColors || "", name, hex)
    }

    ConfigFormShell {
        id: shell

        PluginMissingView {
            visible: configControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        Kirigami.Heading {
            text: i18n("Labels (Categories)")
            level: 3
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("Labels are extracted from Akonadi task categories. Hidden labels will not appear in the sidebar filter list but remain on tasks.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            QQC2.Label {
                visible: labelRepeater.count === 0
                text: i18n("No labels found. Labels are automatically discovered from task categories in Akonadi.")
                opacity: 0.6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                id: labelRepeater
                model: configController ? configController.availableLabels : []

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true

                    contentItem: GridLayout {
                        columns: shell.wideLayout ? 2 : 1
                        columnSpacing: Design.spaceSmall
                        rowSpacing: Design.spaceSmall

                        RowLayout {
                            Layout.columnSpan: shell.wideLayout ? 2 : 1
                            Layout.fillWidth: true
                            spacing: Design.spaceSmall

                            Kirigami.Icon {
                                source: "tag"
                                color: Design.colorForKey(modelData, "label")
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: i18np("%1 task", "%1 tasks", root.labelCount(modelData))
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    opacity: 0.6
                                }
                            }
                        }

                        QQC2.TextField {
                            Layout.fillWidth: true
                            placeholderText: "#rrggbb"
                            text: {
                                try {
                                    var map = JSON.parse(root.cfg_labelColors || "{}")
                                    return map[modelData] || ""
                                } catch (e) {
                                    return ""
                                }
                            }
                            onEditingFinished: root.applyColor(modelData, text.trim())
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Design.spaceSmall

                            QQC2.Switch {
                                text: i18n("Visible")
                                checked: !root.isHidden(modelData)
                                onToggled: root.toggleHidden(modelData)
                                QQC2.ToolTip.text: i18n("Show this label in the sidebar filter")
                                QQC2.ToolTip.visible: hovered
                            }

                            Item { Layout.fillWidth: true }

                            QQC2.ToolButton {
                                icon.name: "edit-delete"
                                display: QQC2.AbstractButton.IconOnly
                                onClicked: if (configController) configController.deleteLabel(modelData)
                                QQC2.ToolTip.text: i18n("Delete label")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            QQC2.TextField {
                id: newLabelField
                Layout.fillWidth: true
                placeholderText: i18n("New label")
                Keys.onReturnPressed: root.addCurrentLabel()
                Keys.onEnterPressed: root.addCurrentLabel()
            }

            QQC2.Button {
                text: i18n("Add label")
                icon.name: "list-add"
                enabled: newLabelField.text.trim().length > 0
                onClicked: root.addCurrentLabel()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: shell.wideLayout ? 3 : 1
            columnSpacing: Design.spaceSmall
            rowSpacing: Design.spaceSmall

            QQC2.ComboBox {
                id: renameFromCombo
                Layout.fillWidth: true
                displayText: currentIndex >= 0 ? currentText : i18n("Rename from")
                model: configController ? configController.availableLabels : []
                enabled: configController && configController.availableLabels.length > 0
            }

            QQC2.TextField {
                id: renameField
                Layout.fillWidth: true
                placeholderText: i18n("Rename to")
                enabled: renameFromCombo.currentIndex >= 0
                Keys.onReturnPressed: {
                    if (renameFromCombo.currentIndex >= 0) {
                        root.renameCurrent(renameFromCombo.currentText)
                    }
                }
            }

            QQC2.Button {
                Layout.fillWidth: !shell.wideLayout
                text: i18n("Rename")
                icon.name: "edit-rename"
                enabled: renameFromCombo.currentIndex >= 0 && renameField.text.trim().length > 0
                onClicked: root.renameCurrent(renameFromCombo.currentText)
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("Show All")
                icon.name: "view-visible"
                onClicked: cfg_hiddenLabels = ""
            }

            Item { Layout.fillWidth: true }

            QQC2.Button {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: if (configController) configController.refresh()
            }
        }
    }
}
