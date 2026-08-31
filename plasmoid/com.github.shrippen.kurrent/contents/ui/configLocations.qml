import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "colors.js" as Colors
import "."
import "components"

KCM.SimpleKCM {
    id: root

    property string cfg_hiddenLocations
    property string cfg_locationColors

    Loader {
        id: configControllerLoader
        source: Qt.resolvedUrl("PluginController.qml")
        onLoaded: item.showCompleted = true
    }
    readonly property var configController: configControllerLoader.item

    function hiddenSet() {
        var raw = cfg_hiddenLocations || ""
        if (!raw.trim()) return {}
        var parts = raw.split("||")
        var s = {}
        for (var i = 0; i < parts.length; ++i) {
            var v = parts[i].trim()
            if (v !== "") s[v] = true
        }
        return s
    }

    function toggleHidden(location) {
        var current = hiddenSet()
        if (current[location]) {
            delete current[location]
        } else {
            current[location] = true
        }
        cfg_hiddenLocations = Object.keys(current).join("||")
    }

    function isHidden(location) {
        return !!hiddenSet()[location]
    }

    function locationCount(name) {
        if (!configController) {
            return 0
        }
        var n = configController.sidebarLocationCounts[name]
        return n === undefined || n === null ? 0 : Number(n)
    }

    function addCurrentLocation() {
        var name = newLocationField.text.trim()
        if (!name || !configController) {
            return
        }
        configController.createLocation(name)
        newLocationField.text = ""
    }

    function renameCurrent(from) {
        var dest = renameField.text.trim()
        if (!dest || dest === from || !configController) {
            return
        }
        configController.renameLocation(from, dest)
        cfg_hiddenLocations = configController.renameSeparatedList(cfg_hiddenLocations || "", from, dest, "||")
        cfg_locationColors = configController.moveColorKey(cfg_locationColors || "", from, dest)
        renameField.text = ""
        renameFromCombo.currentIndex = -1
    }

    function applyColor(name, hex) {
        if (!configController) {
            return
        }
        cfg_locationColors = configController.setColorOverride(cfg_locationColors || "", name, hex)
    }

    ConfigFormShell {
        id: shell

        PluginMissingView {
            visible: configControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        Kirigami.Heading {
            text: i18n("Locations")
            level: 3
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("Locations come from the VTODO LOCATION field. Hidden locations will not appear in the sidebar filter list but remain on tasks.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            QQC2.Label {
                visible: locationRepeater.count === 0
                text: i18n("No locations found. Locations are discovered from task LOCATION values in Akonadi, or add one below.")
                opacity: 0.6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                id: locationRepeater
                model: configController ? configController.availableLocations : []

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
                                source: "mark-location"
                                color: Design.colorForKey(modelData, "location")
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
                                    text: i18np("%1 task", "%1 tasks", root.locationCount(modelData))
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
                                    var map = JSON.parse(root.cfg_locationColors || "{}")
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
                                QQC2.ToolTip.text: i18n("Show this location in the sidebar filter")
                                QQC2.ToolTip.visible: hovered
                            }

                            Item { Layout.fillWidth: true }

                            QQC2.ToolButton {
                                icon.name: "edit-delete"
                                display: QQC2.AbstractButton.IconOnly
                                onClicked: if (configController) configController.deleteLocation(modelData)
                                QQC2.ToolTip.text: i18n("Delete location")
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
                id: newLocationField
                Layout.fillWidth: true
                placeholderText: i18n("New location")
                Keys.onReturnPressed: root.addCurrentLocation()
                Keys.onEnterPressed: root.addCurrentLocation()
            }

            QQC2.Button {
                text: i18n("Add location")
                icon.name: "list-add"
                enabled: newLocationField.text.trim().length > 0
                onClicked: root.addCurrentLocation()
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
                model: configController ? configController.availableLocations : []
                enabled: configController && configController.availableLocations.length > 0
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
                onClicked: cfg_hiddenLocations = ""
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
