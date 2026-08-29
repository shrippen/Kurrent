import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property alias cfg_showCompleted: showCompletedCheck.checked
    property alias cfg_rememberLastView: rememberLastCheck.checked
    property alias cfg_confirmDelete: confirmDeleteCheck.checked
    property alias cfg_completeNeedsModifier: modifierCheck.checked
    property string cfg_defaultView
    property string cfg_newTaskProjectMode
    property string cfg_newTaskDefaultCollectionId
    property string cfg_defaultDueMode

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

            Kirigami.Heading {
                Kirigami.FormData.label: i18n("Akonadi")
                text: i18n("Tasks are loaded from your existing Akonadi setup.")
                level: 3
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Setup")
                text: i18n("Configure CalDAV/Nextcloud in KOrganizer or Merkuro (DAV groupware resource).")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
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
                Component.onCompleted: checked = plasmoid.configuration.rememberLastView === true
            }

            QQC2.CheckBox {
                id: showCompletedCheck
                Kirigami.FormData.label: i18n("Completed tasks")
                text: i18n("Show completed tasks")
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

            ProjectPicker {
                id: defaultProjectPicker
                visible: root.cfg_newTaskProjectMode === "fixed"
                Kirigami.FormData.label: visible ? i18n("Default project") : ""
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
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
                Kirigami.FormData.label: i18n("Default due date")
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

            QQC2.CheckBox {
                id: confirmDeleteCheck
                Kirigami.FormData.label: i18n("Delete")
                text: i18n("Ask before deleting a task")
                Component.onCompleted: checked = plasmoid.configuration.confirmDelete === true
            }

            QQC2.CheckBox {
                id: modifierCheck
                Kirigami.FormData.label: i18n("Checkbox")
                text: i18n("Complete only with Shift or Ctrl held")
                Component.onCompleted: checked = plasmoid.configuration.completeNeedsModifier === true
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    defaultView: "inbox",
                    rememberLastView: false,
                    showCompleted: false,
                    newTaskProjectMode: "ask",
                    newTaskDefaultCollectionId: "",
                    defaultDueMode: "none",
                    confirmDelete: false,
                    completeNeedsModifier: false
                })
            }
        }
    }

    QQC2.ButtonGroup {
        id: newTaskModeGroup
    }

    Loader {
        id: settingsControllerLoader
        source: Qt.resolvedUrl("PluginController.qml")
        onLoaded: {
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
                item.setEnabledCollectionIds(ids)
            }
            defaultProjectPicker.rebuild()
        }
    }
    readonly property var settingsController: settingsControllerLoader.item
}
