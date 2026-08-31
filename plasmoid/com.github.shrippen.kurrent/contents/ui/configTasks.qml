import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"

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
        selectCombo(morningHourCombo, String(cfg_morningHour))
        selectCombo(afternoonHourCombo, String(cfg_afternoonHour))
        selectCombo(eveningHourCombo, String(cfg_eveningHour))
        selectCombo(sortScopeCombo, cfg_sortScope || "global")
    }

    ConfigFormShell {

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                id: sortScopeCombo
                Kirigami.FormData.label: i18n("Sort order")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Remember globally (all views)"), value: "global" },
                    { text: i18n("Remember per view"), value: "perView" }
                ]
                onActivated: cfg_sortScope = model[currentIndex].value
                Component.onCompleted: selectCombo(sortScopeCombo, plasmoid.configuration.sortScope || "global")
            }

            QQC2.Label {
                Kirigami.FormData.label: ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: sortScopeCombo.currentIndex >= 0
                        && sortScopeCombo.model[sortScopeCombo.currentIndex].value === "perView"
                        ? i18n("Each sidebar view keeps its own sort. Views you have not changed start with Priority › Due › Title A–Z.")
                        : i18n("One sort order for every view. The default is Priority › Due › Title A–Z until you change it in the task list.")
            }

            QQC2.ComboBox {
                id: morningHourCombo
                Kirigami.FormData.label: i18n("Morning starts")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                textRole: "text"
                model: root.hourModel
                onActivated: root.cfg_morningHour = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(morningHourCombo, String(plasmoid.configuration.morningHour !== undefined ? plasmoid.configuration.morningHour : 6))
            }

            QQC2.ComboBox {
                id: afternoonHourCombo
                Kirigami.FormData.label: i18n("Afternoon starts")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                textRole: "text"
                model: root.hourModel
                onActivated: root.cfg_afternoonHour = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(afternoonHourCombo, String(plasmoid.configuration.afternoonHour !== undefined ? plasmoid.configuration.afternoonHour : 12))
            }

            QQC2.ComboBox {
                id: eveningHourCombo
                Kirigami.FormData.label: i18n("Evening starts")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                textRole: "text"
                model: root.hourModel
                onActivated: root.cfg_eveningHour = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(eveningHourCombo, String(plasmoid.configuration.eveningHour !== undefined ? plasmoid.configuration.eveningHour : 18))
            }

            QQC2.CheckBox {
                id: dateChipCheck
                Kirigami.FormData.label: i18n("Row chips")
                text: i18n("Due date")
                checked: root.cfg_showDateChip
                onCheckedChanged: root.cfg_showDateChip = checked
            }

            QQC2.CheckBox {
                id: labelChipCheck
                text: i18n("Labels")
                checked: root.cfg_showLabelChips
                onCheckedChanged: root.cfg_showLabelChips = checked
            }

            QQC2.CheckBox {
                id: priorityChipCheck
                text: i18n("Priority")
                checked: root.cfg_showPriorityChip
                onCheckedChanged: root.cfg_showPriorityChip = checked
            }

            QQC2.CheckBox {
                id: recurringIconCheck
                text: i18n("Recurring icon")
                checked: root.cfg_showRecurringIcon
                onCheckedChanged: root.cfg_showRecurringIcon = checked
            }

            QQC2.CheckBox {
                id: progressChipCheck
                text: i18n("Progress")
                checked: root.cfg_showProgressChip
                onCheckedChanged: root.cfg_showProgressChip = checked
            }

            QQC2.CheckBox {
                id: statusChipCheck
                text: i18n("Status")
                checked: root.cfg_showStatusChip
                onCheckedChanged: root.cfg_showStatusChip = checked
            }

            QQC2.CheckBox {
                id: secrecyChipCheck
                text: i18n("Secrecy")
                checked: root.cfg_showSecrecyChip
                onCheckedChanged: root.cfg_showSecrecyChip = checked
            }

            QQC2.CheckBox {
                id: locationChipCheck
                text: i18n("Location")
                checked: root.cfg_showLocationChip
                onCheckedChanged: root.cfg_showLocationChip = checked
            }

            QQC2.CheckBox {
                id: showJoinCheck
                Kirigami.FormData.label: i18n("Meetings")
                text: i18n("Show a Join button for http(s) links")
                checked: root.cfg_showJoinButton
                onCheckedChanged: root.cfg_showJoinButton = checked
            }

            QQC2.CheckBox {
                id: multiSelectCheck
                Kirigami.FormData.label: i18n("Selection")
                text: i18n("Enable multi-select (Ctrl+click) and bulk actions")
                checked: root.cfg_multiSelectEnabled
                onCheckedChanged: root.cfg_multiSelectEnabled = checked
            }

            QQC2.CheckBox {
                id: searchTitleCheck
                Kirigami.FormData.label: i18n("Search")
                text: i18n("Search titles only")
                checked: root.cfg_searchTitleOnly
                onCheckedChanged: root.cfg_searchTitleOnly = checked
            }

            QQC2.CheckBox {
                id: searchCaseCheck
                text: i18n("Case sensitive")
                checked: root.cfg_searchCaseSensitive
                onCheckedChanged: root.cfg_searchCaseSensitive = checked
            }

            QQC2.CheckBox {
                id: relativeDatesCheck
                Kirigami.FormData.label: i18n("Dates")
                text: i18n("Relative dates (Today, Tomorrow)")
                checked: root.cfg_relativeDates
                onCheckedChanged: root.cfg_relativeDates = checked
            }

            QQC2.CheckBox {
                id: showTimeCheck
                text: i18n("Show time on the due chip")
                checked: root.cfg_showTimeOnRow
                onCheckedChanged: root.cfg_showTimeOnRow = checked
            }

            QQC2.CheckBox {
                id: completeChildrenCheck
                Kirigami.FormData.label: i18n("Subtasks")
                text: i18n("Completing a parent also completes its children")
                checked: root.cfg_completeChildren
                onCheckedChanged: root.cfg_completeChildren = checked
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    morningHour: 6,
                    afternoonHour: 12,
                    eveningHour: 18,
                    showDateChip: true,
                    showLabelChips: true,
                    showPriorityChip: true,
                    showRecurringIcon: true,
                    showProgressChip: true,
                    showStatusChip: true,
                    showSecrecyChip: true,
                    showLocationChip: true,
                    showJoinButton: true,
                    searchTitleOnly: false,
                    searchCaseSensitive: false,
                    relativeDates: false,
                    showTimeOnRow: true,
                    completeChildren: false,
                    sortScope: "global",
                    sortMode: "",
                    sortModeByView: "{}"
                })
            }
        }
    }

    readonly property var hourModel: (function() {
        var rows = []
        for (var h = 0; h < 24; ++h) {
            rows.push({ text: i18n("%1:00", h), value: String(h) })
        }
        return rows
    })()
}
