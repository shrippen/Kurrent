import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"

ConfigPageBase {
    id: root


    readonly property string sectionDefaults: "views,projects,labels,priorities,progress,status,secrecy,location"
    readonly property string primaryViewDefaults: "inbox,today,overdue,tomorrow,scheduled,anytime,completed"
    readonly property string maintenanceViewDefaults: "recurring,unlabeled,reminder,nolocation,nopriority,nostatus"
    readonly property string viewDefaults: primaryViewDefaults + "," + maintenanceViewDefaults
    ConfigControllerLoader {
        id: orderControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var orderController: orderControllerLoader.controller

    // Saved view order, limited to one group (primary views or Maintenance).
    function viewKeysIn(groupDefaults) {
        if (!orderController) {
            return []
        }
        var group = groupDefaults.split(",")
        return orderController.mergeOrderedKeys(root.cfg_sidebarViewOrder || "", root.viewDefaults, ",")
                .filter(function(k) { return group.indexOf(k) >= 0 })
    }

    function toggleView(key) {
        if (orderController) {
            root.cfg_hiddenViews = orderController.toggleToken(root.cfg_hiddenViews || "", key, "||")
        }
    }

    readonly property var smartViewNames: {
        try {
            return JSON.parse(root.cfg_smartViews || "[]").map(function(v) { return v.name || v.id })
        } catch (e) {
            return []
        }
    }

    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(sidebarRowSizeCombo, cfg_sidebarRowSize || "auto")
        widthBox.value = cfg_sidebarWidthUnits
    }

    function sectionLabel(id) {
        switch (id) {
        case "views": return i18n("Views")
        case "projects": return i18n("Projects")
        case "labels": return i18n("Labels")
        case "priorities": return i18n("Priorities")
        case "progress": return i18n("Progress")
        case "status": return i18n("Status")
        case "secrecy": return i18n("Secrecy")
        case "location": return i18n("Location")
        default: return id
        }
    }

    function viewLabel(id) {
        switch (id) {
        case "inbox": return i18n("Inbox")
        case "today": return i18n("Today")
        case "overdue": return i18n("Overdue")
        case "tomorrow": return i18n("Tomorrow")
        case "scheduled": return i18n("Scheduled")
        case "anytime": return i18n("Anytime")
        case "recurring": return i18n("Recurring")
        case "unlabeled": return i18n("Unlabeled")
        case "completed": return i18n("Completed")
        case "reminder": return i18n("Has reminder")
        case "nolocation": return i18n("Has no location")
        case "nopriority": return i18n("No priority")
        case "nostatus": return i18n("No status")
        default: return id
        }
    }

    ConfigFormShell {

        PluginMissingView {
            visible: orderControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            // Width as a slider with the pixel value; the sidebar edge can also be dragged (c4).
            RowLayout {
                Kirigami.FormData.label: i18n("Width")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                spacing: Kirigami.Units.smallSpacing

                QQC2.Slider {
                    id: widthBox
                    Layout.fillWidth: true
                    from: 6
                    to: 20
                    stepSize: 1
                    snapMode: QQC2.Slider.SnapAlways
                    value: plasmoid.configuration.sidebarWidthUnits || 10
                    onMoved: root.cfg_sidebarWidthUnits = value
                    Component.onCompleted: root.cfg_sidebarWidthUnits = value
                }
                QQC2.Label {
                    text: i18n("%1 px", Math.round(widthBox.value * Kirigami.Units.gridUnit))
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                }
            }

            ConfigHint {
                text: i18n("You can also drag the edge of the sidebar.")
            }

            QQC2.ComboBox {
                id: sidebarRowSizeCombo
                Kirigami.FormData.label: i18n("Row size")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                textRole: "text"
                model: [
                    { text: i18n("Auto (compact, larger with touch)"), value: "auto" },
                    { text: i18n("Compact"), value: "compact" },
                    { text: i18n("Dense (more rows)"), value: "dense" },
                    { text: i18n("Comfortable (touch-friendly)"), value: "comfortable" }
                ]
                onActivated: cfg_sidebarRowSize = model[currentIndex].value
                Component.onCompleted: selectCombo(sidebarRowSizeCombo, plasmoid.configuration.sidebarRowSize || "auto")
            }

            QQC2.CheckBox {
                id: emptyProjectsCheck
                Kirigami.FormData.label: i18n("Projects")
                text: i18n("Show empty projects")
                checked: root.cfg_showEmptyProjects
                onCheckedChanged: root.cfg_showEmptyProjects = checked
            }

            QQC2.CheckBox {
                id: countsCheck
                Kirigami.FormData.label: i18n("Counts")
                text: i18n("Show task counts")
                checked: root.cfg_showSidebarCounts
                onCheckedChanged: root.cfg_showSidebarCounts = checked
            }

            QQC2.CheckBox {
                id: countsCollapsedCheck
                text: i18n("Exclude collapsed subtasks from counts")
                enabled: countsCheck.checked
                checked: root.cfg_countsExcludeCollapsed
                onCheckedChanged: root.cfg_countsExcludeCollapsed = checked
            }

        }

        // Lists span the full width, with the hint under the heading (c1, c2).
        ConfigSection {
            text: i18n("Sections")
        }
        ConfigHint {
            text: i18n("Drag to reorder, switch to show or hide.")
        }
        ConfigOrderList {
            Layout.fillWidth: true
            keys: orderController
                  ? orderController.mergeOrderedKeys(root.cfg_sidebarSectionOrder || "", root.sectionDefaults, ",")
                  : []
            hiddenRaw: root.cfg_hiddenSidebarSections || ""
            hiddenSeparator: "||"
            titleForKey: function(key) { return root.sectionLabel(key) }
            onOrderChanged: function(joined) { root.cfg_sidebarSectionOrder = joined }
            onVisibilityToggled: function(key) {
                if (!orderController) {
                    return
                }
                root.cfg_hiddenSidebarSections = orderController.toggleToken(
                    root.cfg_hiddenSidebarSections || "", key, "||")
            }
        }

        // Views grouped as the sidebar shows them: views, the Maintenance folder, Smart Views (c3).
        ConfigSection {
            text: i18n("Views")
        }
        ConfigOrderList {
            Layout.fillWidth: true
            keys: root.viewKeysIn(root.primaryViewDefaults)
            hiddenRaw: root.cfg_hiddenViews || ""
            hiddenSeparator: "||"
            titleForKey: function(key) { return root.viewLabel(key) }
            onOrderChanged: function(joined) {
                root.cfg_sidebarViewOrder = joined + "," + root.viewKeysIn(root.maintenanceViewDefaults).join(",")
            }
            onVisibilityToggled: function(key) { root.toggleView(key) }
        }

        QQC2.Label {
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: i18n("Maintenance")
            font.bold: true
        }
        ConfigOrderList {
            Layout.fillWidth: true
            keys: root.viewKeysIn(root.maintenanceViewDefaults)
            hiddenRaw: root.cfg_hiddenViews || ""
            hiddenSeparator: "||"
            titleForKey: function(key) { return root.viewLabel(key) }
            onOrderChanged: function(joined) {
                root.cfg_sidebarViewOrder = root.viewKeysIn(root.primaryViewDefaults).join(",") + "," + joined
            }
            onVisibilityToggled: function(key) { root.toggleView(key) }
        }

        QQC2.Label {
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: i18n("Smart Views")
            font.bold: true
        }
        ConfigHint {
            text: root.smartViewNames.length > 0
                  ? root.smartViewNames.join(" · ") + "\n" + i18n("Managed under Views › Smart Views.")
                  : i18n("None yet. Create them under Views › Smart Views.")
        }

        ConfigResetButton {
                page: root
                defaults: ({
                    sidebarWidthUnits: 10,
                    sidebarRowSize: "auto",
                    showEmptyProjects: false,
                    showSidebarCounts: true,
                    countsExcludeCollapsed: false,
                    sidebarSectionOrder: "views,projects,labels,priorities,progress,status,secrecy,location",
                    hiddenSidebarSections: "progress||status||secrecy||location",
                    sidebarViewOrder: "",
                    hiddenViews: ""
                })
        }
    }
}
