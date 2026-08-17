import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import com.github.shrippen.kurrent 1.0
import "colors.js" as Colors

KCM.SimpleKCM {
    id: root

    property string cfg_enabledCollections
    property string cfg_hiddenProjects

    TaskController {
        id: configController
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

    function toggleEnabled(collectionId) {
        var current = enabledSet()
        var key = String(collectionId)
        var allIds = []
        for (var i = 0; i < configController.collectionModel.count; ++i) {
            allIds.push(String(configController.collectionModel.collectionIdAt(i)))
        }

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

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(Math.max(parent.width - Kirigami.Units.largeSpacing * 2,
                                 Kirigami.Units.gridUnit * 12),
                        Kirigami.Units.gridUnit * 28)
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            text: i18n("Projects (Akonadi Calendars)")
            level: 3
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("Manage which Akonadi calendars are used as projects. Disabled calendars are excluded from task fetching entirely. Hidden calendars are still fetched but not shown in the sidebar.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            QQC2.Label {
                visible: projectRepeater.count === 0
                text: i18n("No Akonadi calendars found. Make sure Akonadi is running.")
                opacity: 0.6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                id: projectRepeater
                model: configController.collectionModel

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "folder"
                            color: Colors.colorForKey(String(model.collectionId))
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: Kirigami.Units.iconSizes.smallMedium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: model.name
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: i18np("%1 task", "%1 tasks", model.taskCount)
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                opacity: 0.6
                            }
                        }

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
                onClicked: configController.refresh()
            }
        }
    }
}
