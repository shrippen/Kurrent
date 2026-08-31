import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "colors.js" as Colors
import "."
import "components"

ConfigPageBase {
    id: root


    readonly property int writableProjectCount: {
        var model = configController ? configController.collectionModel : null
        if (!model) {
            return 0
        }
        var count = 0
        for (var i = 0; i < model.count; ++i) {
            if (model.writableAt(i)) {
                ++count
            }
        }
        return count
    }
    ConfigControllerLoader {
        id: configControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var configController: configControllerLoader.controller

    function hiddenSet() {
        var raw = cfg_hiddenProjects || ""
        if (!raw.trim()) return {}
        var parts = raw.split(",")
        var s = {}
        for (var i = 0; i < parts.length; ++i) {
            var v = parts[i].trim()
            if (v !== "") s[v] = true
        }
        return s
    }

    function enabledSet() {
        var raw = cfg_enabledCollections || ""
        if (!raw.trim()) return {}
        var parts = raw.split(",")
        var s = {}
        for (var i = 0; i < parts.length; ++i) {
            var v = parts[i].trim()
            if (v !== "") s[v] = true
        }
        return s
    }

    function writableCollectionIds() {
        var model = configController ? configController.collectionModel : null
        var ids = []
        if (!model) {
            return ids
        }
        for (var i = 0; i < model.count; ++i) {
            if (model.writableAt(i)) {
                ids.push(String(model.collectionIdAt(i)))
            }
        }
        return ids
    }

    function toggleEnabled(collectionId) {
        var current = enabledSet()
        var key = String(collectionId)
        var allIds = writableCollectionIds()

        var isEmpty = Object.keys(current).length === 0
        if (isEmpty) {
            var result = []
            for (var j = 0; j < allIds.length; ++j) {
                if (allIds[j] !== key) result.push(allIds[j])
            }
            cfg_enabledCollections = result.join(",")
        } else if (current[key]) {
            delete current[key]
            var arr = Object.keys(current)
            cfg_enabledCollections = arr.length > 0 ? arr.join(",") : ""
        } else {
            current[key] = true
            var arr2 = Object.keys(current)
            if (arr2.length >= allIds.length) {
                cfg_enabledCollections = ""
            } else {
                cfg_enabledCollections = arr2.join(",")
            }
        }
    }

    function toggleHidden(collectionId) {
        var current = hiddenSet()
        var key = String(collectionId)
        if (current[key]) {
            delete current[key]
        } else {
            current[key] = true
        }
        cfg_hiddenProjects = Object.keys(current).join(",")
    }

    function isEnabled(collectionId) {
        var s = enabledSet()
        if (Object.keys(s).length === 0) return true
        return !!s[String(collectionId)]
    }

    function isHidden(collectionId) {
        return !!hiddenSet()[String(collectionId)]
    }

    function applyColor(collectionId, hex) {
        if (!configController) {
            return
        }
        cfg_projectColors = configController.setColorOverride(cfg_projectColors || "", String(collectionId), hex)
    }

    ConfigFormShell {
        id: shell

        PluginMissingView {
            visible: configControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        Kirigami.Heading {
            text: i18n("Projects (Akonadi Calendars)")
            level: 3
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("Manage which writable Akonadi calendars are used as projects. Disabled calendars are excluded from task fetching entirely. Hidden calendars are still fetched but not shown in the sidebar.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            QQC2.Label {
                visible: root.writableProjectCount === 0
                text: i18n("No writable Akonadi calendars found. Make sure Akonadi is running and your CalDAV resource allows task edits.")
                opacity: 0.6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                id: projectRepeater
                model: configController ? configController.collectionModel : 0

                delegate: Kirigami.AbstractCard {
                    visible: model.writable
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
                                source: "folder"
                                color: Design.colorForKey(String(model.collectionId))
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: i18np("%1 task", "%1 tasks", model.taskCount)
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
                                    var map = JSON.parse(root.cfg_projectColors || "{}")
                                    return map[String(model.collectionId)] || ""
                                } catch (e) {
                                    return ""
                                }
                            }
                            onEditingFinished: root.applyColor(model.collectionId, text.trim())
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Design.spaceSmall

                            QQC2.Switch {
                                text: i18n("Enabled")
                                checked: root.isEnabled(model.collectionId)
                                onToggled: root.toggleEnabled(model.collectionId)
                                QQC2.ToolTip.text: i18n("Include this calendar when fetching tasks")
                                QQC2.ToolTip.visible: hovered
                            }

                            QQC2.Switch {
                                text: i18n("Visible")
                                checked: !root.isHidden(model.collectionId)
                                onToggled: root.toggleHidden(model.collectionId)
                                QQC2.ToolTip.text: i18n("Show this project in the sidebar")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("Enable All")
                icon.name: "checkbox"
                onClicked: cfg_enabledCollections = ""
            }

            QQC2.Button {
                text: i18n("Show All")
                icon.name: "view-visible"
                onClicked: cfg_hiddenProjects = ""
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
