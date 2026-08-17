import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import com.github.shrippen.kurrent 1.0
import "components"

KCM.SimpleKCM {
    id: root

    property alias cfg_showCompleted: showCompletedCheck.checked
    property alias cfg_blurBackground: blurBackgroundCheck.checked
    property string cfg_defaultView
    property string cfg_sidebarRowSize
    property string cfg_newTaskProjectMode
    property string cfg_newTaskDefaultCollectionId

    Kirigami.FormLayout {
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Akonadi")
            text: i18n("Tasks are loaded from your existing Akonadi setup.")
            level: 3
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Setup")
            text: i18n("Configure CalDAV/Nextcloud in KOrganizer or Kalendar (DAV groupware resource).")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.ComboBox {
            id: defaultViewCombo
            Kirigami.FormData.label: i18n("Default view")
            textRole: "text"
            model: [
                { text: i18n("Inbox"), value: "inbox" },
                { text: i18n("Today"), value: "today" },
                { text: i18n("Tomorrow"), value: "tomorrow" },
                { text: i18n("Scheduled"), value: "scheduled" },
                { text: i18n("Anytime"), value: "anytime" },
                { text: i18n("Recurring"), value: "recurring" },
                { text: i18n("Unlabeled"), value: "unlabeled" },
                { text: i18n("Completed"), value: "completed" }
            ]
            onActivated: cfg_defaultView = model[currentIndex].value
            Component.onCompleted: {
                var selected = plasmoid.configuration.defaultView || "inbox"
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === selected) {
                        currentIndex = i
                        break
                    }
                }
                cfg_defaultView = selected
            }
        }

        QQC2.CheckBox {
            id: showCompletedCheck
            Kirigami.FormData.label: i18n("Completed tasks")
            text: i18n("Show completed tasks")
        }

        QQC2.CheckBox {
            id: blurBackgroundCheck
            Kirigami.FormData.label: i18n("Appearance")
            text: i18n("Blurred background")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Use Plasma’s translucent background so KWin blurs the wallpaper. Also applies to the panel flyout.")
        }

        QQC2.ComboBox {
            id: sidebarRowSizeCombo
            Kirigami.FormData.label: i18n("Sidebar row size")
            textRole: "text"
            model: [
                { text: i18n("Auto (compact, larger with touch)"), value: "auto" },
                { text: i18n("Compact"), value: "compact" },
                { text: i18n("Comfortable (touch-friendly)"), value: "comfortable" }
            ]
            onActivated: cfg_sidebarRowSize = model[currentIndex].value
            Component.onCompleted: {
                var selected = plasmoid.configuration.sidebarRowSize || "auto"
                for (var i = 0; i < model.length; ++i) {
                    if (model[i].value === selected) {
                        currentIndex = i
                        break
                    }
                }
                cfg_sidebarRowSize = selected
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Auto uses compact rows on mouse/desktop and comfortable rows when Plasma detects tablet or touch input.")
        }

        QQC2.RadioButton {
            id: newTaskAskRadio
            Kirigami.FormData.label: i18n("New tasks")
            text: i18n("Ask which project to use")
            checked: (root.cfg_newTaskProjectMode || "ask") === "ask"
            QQC2.ButtonGroup.group: newTaskModeGroup
            onClicked: root.cfg_newTaskProjectMode = "ask"
        }

        QQC2.RadioButton {
            text: i18n("Use the top project in the sidebar")
            checked: root.cfg_newTaskProjectMode === "first"
            QQC2.ButtonGroup.group: newTaskModeGroup
            onClicked: root.cfg_newTaskProjectMode = "first"
        }

        QQC2.RadioButton {
            text: i18n("Use a specific project")
            checked: root.cfg_newTaskProjectMode === "fixed"
            QQC2.ButtonGroup.group: newTaskModeGroup
            onClicked: root.cfg_newTaskProjectMode = "fixed"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("When no project is selected in the sidebar, new tasks follow this setting.")
        }

        ProjectPicker {
            id: defaultProjectPicker
            visible: root.cfg_newTaskProjectMode === "fixed"
            Kirigami.FormData.label: visible ? i18n("Default project") : ""
            Layout.fillWidth: true
            collectionModel: settingsController.collectionModel
            hiddenProjects: plasmoid.configuration.hiddenProjects || ""
            includeEmptyProjects: true
            includeHiddenProjects: true
            collectionId: {
                var n = Number(root.cfg_newTaskDefaultCollectionId)
                return n > 0 ? n : -1
            }
            onCollectionIdChanged: {
                if (root.cfg_newTaskProjectMode === "fixed" && collectionId > 0) {
                    root.cfg_newTaskDefaultCollectionId = String(collectionId)
                }
            }
        }
    }

    QQC2.ButtonGroup {
        id: newTaskModeGroup
    }

    TaskController {
        id: settingsController
        Component.onCompleted: {
            var raw = plasmoid.configuration.enabledCollections || ""
            if (!raw.trim()) {
                defaultProjectPicker.rebuild()
                return
            }
            var parts = raw.split(",")
            var ids = []
            for (var i = 0; i < parts.length; ++i) {
                var value = parseInt(parts[i].trim(), 10)
                if (!isNaN(value)) {
                    ids.push(value)
                }
            }
            if (ids.length > 0) {
                settingsController.setEnabledCollectionIds(ids)
            }
            defaultProjectPicker.rebuild()
        }
    }
}
