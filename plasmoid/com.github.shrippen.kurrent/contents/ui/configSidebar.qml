import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property alias cfg_showEmptyProjects: emptyProjectsCheck.checked
    property alias cfg_showSidebarCounts: countsCheck.checked
    property alias cfg_countsExcludeCollapsed: countsCollapsedCheck.checked
    property string cfg_sidebarRowSize
    property int cfg_sidebarWidthUnits
    property string cfg_sidebarSectionOrder
    property string cfg_hiddenSidebarSections
    property string cfg_sidebarViewOrder
    property string cfg_hiddenViews

    readonly property string sectionDefaults: "views,projects,labels,priorities"
    readonly property string viewDefaults: "inbox,today,overdue,tomorrow,scheduled,anytime,recurring,unlabeled,completed"

    Loader {
        id: orderControllerLoader
        source: Qt.resolvedUrl("PluginController.qml")
    }
    readonly property var orderController: orderControllerLoader.item

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

            QQC2.SpinBox {
                id: widthBox
                Kirigami.FormData.label: i18n("Width")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                from: 6
                to: 20
                value: plasmoid.configuration.sidebarWidthUnits || 10
                textFromValue: function(value) { return i18n("%1 grid units", value) }
                valueFromText: function(text) { return widthBox.value }
                onValueChanged: root.cfg_sidebarWidthUnits = value
                Component.onCompleted: root.cfg_sidebarWidthUnits = value
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
                    { text: i18n("Comfortable (touch-friendly)"), value: "comfortable" }
                ]
                onActivated: cfg_sidebarRowSize = model[currentIndex].value
                Component.onCompleted: selectCombo(sidebarRowSizeCombo, plasmoid.configuration.sidebarRowSize || "auto")
            }

            QQC2.CheckBox {
                id: emptyProjectsCheck
                Kirigami.FormData.label: i18n("Projects")
                text: i18n("Show empty projects")
                Component.onCompleted: checked = plasmoid.configuration.showEmptyProjects === true
            }

            QQC2.CheckBox {
                id: countsCheck
                Kirigami.FormData.label: i18n("Counts")
                text: i18n("Show task counts")
                Component.onCompleted: checked = plasmoid.configuration.showSidebarCounts !== false
            }

            QQC2.CheckBox {
                id: countsCollapsedCheck
                text: i18n("Exclude collapsed subtasks from counts")
                enabled: countsCheck.checked
                Component.onCompleted: checked = plasmoid.configuration.countsExcludeCollapsed === true
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Sections")
            }

            ConfigOrderList {
                Kirigami.FormData.label: i18n("Order and visibility")
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

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Views")
            }

            ConfigOrderList {
                Kirigami.FormData.label: i18n("Order and visibility")
                Layout.fillWidth: true
                keys: orderController
                      ? orderController.mergeOrderedKeys(root.cfg_sidebarViewOrder || "", root.viewDefaults, ",")
                      : []
                hiddenRaw: root.cfg_hiddenViews || ""
                hiddenSeparator: "||"
                titleForKey: function(key) { return root.viewLabel(key) }
                onOrderChanged: function(joined) { root.cfg_sidebarViewOrder = joined }
                onVisibilityToggled: function(key) {
                    if (!orderController) {
                        return
                    }
                    root.cfg_hiddenViews = orderController.toggleToken(
                        root.cfg_hiddenViews || "", key, "||")
                }
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    sidebarWidthUnits: 10,
                    sidebarRowSize: "auto",
                    showEmptyProjects: false,
                    showSidebarCounts: true,
                    countsExcludeCollapsed: false,
                    sidebarSectionOrder: "views,projects,labels,priorities",
                    hiddenSidebarSections: "",
                    sidebarViewOrder: "",
                    hiddenViews: ""
                })
            }
        }
    }
}
