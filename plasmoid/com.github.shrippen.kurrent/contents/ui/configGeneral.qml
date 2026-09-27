import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"
import org.kde.plasma.plasmoid

ConfigPageBase {
    id: root


    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(defaultViewCombo, cfg_defaultView || "inbox")
        selectCombo(defaultDueCombo, cfg_defaultDueMode || "none")
        selectCombo(reminderCombo, String(cfg_defaultReminderMinutes))
    }

    readonly property bool akonadiOnline: !!settingsController && settingsController.akonadiAvailable
    readonly property string taskAppName: settingsController ? settingsController.taskAppName() : ""
    readonly property int calendarCount: {
        var m = settingsController ? settingsController.collectionModel : null
        if (!m) return 0
        var n = 0
        for (var i = 0; i < m.count; ++i) if (m.enabledAt(i)) ++n
        return n
    }
    readonly property int taskTotal: {
        // Re-count when tasks arrive (the model's counts change without a count change).
        var dep = settingsController ? settingsController.viewTaskCounts : null
        var m = settingsController ? settingsController.collectionModel : null
        if (!m) return 0
        var n = 0
        for (var i = 0; i < m.count; ++i) if (m.enabledAt(i)) n += m.taskCountAt(i)
        return n
    }

    function normalizeReleaseVersion(v) {
        if (!v) {
            return ""
        }
        var trimmed = String(v).trim()
        if (trimmed === "") {
            return ""
        }
        var parts = trimmed.split(".")
        if (parts.length >= 2) {
            return parts[0] + "." + parts[1]
        }
        return parts[0]
    }

    readonly property string configWidgetVersion: normalizeReleaseVersion(
        (typeof Plasmoid !== "undefined" && Plasmoid.metaData) ? Plasmoid.metaData.version : "")
    readonly property string configBackendVersion: settingsControllerLoader.status === Loader.Ready && settingsController
        ? normalizeReleaseVersion(settingsController.pluginVersion) : ""
    readonly property bool configBackendVersionMismatch: settingsControllerLoader.status === Loader.Ready
        && configWidgetVersion !== ""
        && (configBackendVersion === "" || configBackendVersion !== configWidgetVersion)

    ConfigFormShell {
        Kirigami.FormLayout {
            Layout.fillWidth: true

            PluginMissingView {
                visible: settingsControllerLoader.status === Loader.Error
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
            }

            VersionMismatchBanner {
                visible: root.configBackendVersionMismatch
                Layout.fillWidth: true
                widgetVersion: root.configWidgetVersion
                backendVersion: root.configBackendVersion
            }

            // Akonadi at a glance: connection, calendars, tasks, and the app to set up more (a1).
            RowLayout {
                Kirigami.FormData.label: i18n("Akonadi")
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: root.akonadiOnline ? "checkmark" : "network-disconnect"
                    color: root.akonadiOnline ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: !settingsController ? i18n("Connecting…")
                        : !root.akonadiOnline ? i18n("Akonadi is not running")
                        : i18n("Connected") + " · " + i18np("%1 calendar", "%1 calendars", root.calendarCount)
                          + " · " + i18np("%1 task", "%1 tasks", root.taskTotal)
                }
            }

            QQC2.Button {
                visible: root.taskAppName.length > 0
                icon.name: "view-calendar-tasks"
                text: i18n("Open %1", root.taskAppName)
                onClicked: settingsController.launchTaskApp()
            }

            ConfigHint {
                text: root.taskAppName.length > 0
                      ? i18n("Add CalDAV or Nextcloud calendars in %1 (DAV groupware resource).", root.taskAppName)
                      : i18n("Add CalDAV or Nextcloud calendars in KOrganizer or Merkuro (DAV groupware resource).")
            }

            QQC2.ComboBox {
                id: defaultViewCombo
                Kirigami.FormData.label: i18n("Default view")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Inbox"), value: "inbox" },
                    { text: i18n("Today"), value: "today" },
                    { text: i18n("Overdue"), value: "overdue" },
                    { text: i18n("Tomorrow"), value: "tomorrow" },
                    { text: i18n("Scheduled"), value: "scheduled" },
                    { text: i18n("Anytime"), value: "anytime" },
                    { text: i18n("Recurring"), value: "recurring" },
                    { text: i18n("Unlabeled"), value: "unlabeled" },
                    { text: i18n("Completed"), value: "completed" }
                ]
                onActivated: cfg_defaultView = model[currentIndex].value
                Component.onCompleted: selectCombo(defaultViewCombo, plasmoid.configuration.defaultView || "inbox")
            }

            QQC2.CheckBox {
                id: rememberLastCheck
                text: i18n("Remember the last view instead")
                checked: root.cfg_rememberLastView
                onCheckedChanged: root.cfg_rememberLastView = checked
            }

            // Defaults for new tasks in one place (a3).
            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("New tasks")
            }

            QQC2.RadioButton {
                id: newTaskAskRadio
                Kirigami.FormData.label: i18n("Project")
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

            ProjectPicker {
                id: defaultProjectPicker
                visible: root.cfg_newTaskProjectMode === "fixed"
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                collectionModel: settingsController ? settingsController.collectionModel : null
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

            QQC2.ComboBox {
                id: defaultDueCombo
                Kirigami.FormData.label: i18n("Due date")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                textRole: "text"
                model: [
                    { text: i18n("None"), value: "none" },
                    { text: i18n("Today"), value: "today" },
                    { text: i18n("Tomorrow"), value: "tomorrow" }
                ]
                onActivated: cfg_defaultDueMode = model[currentIndex].value
                Component.onCompleted: selectCombo(defaultDueCombo, plasmoid.configuration.defaultDueMode || "none")
            }

            QQC2.ComboBox {
                id: reminderCombo
                Kirigami.FormData.label: i18n("Reminder")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                textRole: "text"
                model: [
                    { text: i18n("Off"), value: "-1" },
                    { text: i18n("At due time"), value: "0" },
                    { text: i18n("15 minutes before"), value: "15" },
                    { text: i18n("1 hour before"), value: "60" },
                    { text: i18n("1 day before"), value: "1440" }
                ]
                onActivated: cfg_defaultReminderMinutes = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(reminderCombo, String(plasmoid.configuration.defaultReminderMinutes !== undefined ? plasmoid.configuration.defaultReminderMinutes : -1))
            }

            // One section instead of one heading per check box (a2).
            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Behaviour")
            }

            QQC2.CheckBox {
                id: showCompletedCheck
                Kirigami.FormData.label: i18n("Completed tasks")
                text: i18n("Show completed tasks")
                checked: root.cfg_showCompleted
                onCheckedChanged: root.cfg_showCompleted = checked
            }

            QQC2.CheckBox {
                id: confirmDeleteCheck
                Kirigami.FormData.label: i18n("Delete")
                text: i18n("Ask before deleting a task")
                checked: root.cfg_confirmDelete
                onCheckedChanged: root.cfg_confirmDelete = checked
            }

            QQC2.CheckBox {
                id: modifierCheck
                Kirigami.FormData.label: i18n("Tick off")
                text: i18n("Only with Shift or Ctrl held")
                checked: root.cfg_completeNeedsModifier
                onCheckedChanged: root.cfg_completeNeedsModifier = checked
            }

        }

        ConfigResetButton {
            page: root
            defaults: ({
                defaultView: "inbox",
                rememberLastView: false,
                showCompleted: false,
                newTaskProjectMode: "ask",
                newTaskDefaultCollectionId: "",
                defaultDueMode: "none",
                defaultReminderMinutes: -1,
                confirmDelete: false,
                completeNeedsModifier: false
            })
        }
    }

    QQC2.ButtonGroup {
        id: newTaskModeGroup
    }

    ConfigControllerLoader {
        id: settingsControllerLoader
        onLoaded: {
            refresh()
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
            if (controller && ids.length > 0) {
                controller.setEnabledCollectionIds(ids)
            }
            defaultProjectPicker.rebuild()
        }
    }
    readonly property var settingsController: settingsControllerLoader.controller
}
