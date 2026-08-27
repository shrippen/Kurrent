import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property alias cfg_catchUpEnabled: catchUpCheck.checked
    property alias cfg_showJoinButton: showJoinCheck.checked
    property alias cfg_searchTitleOnly: searchTitleCheck.checked
    property alias cfg_searchCaseSensitive: searchCaseCheck.checked
    property alias cfg_completeChildren: completeChildrenCheck.checked
    property alias cfg_relativeDates: relativeDatesCheck.checked
    property alias cfg_showTimeOnRow: showTimeCheck.checked
    property alias cfg_showDateChip: dateChipCheck.checked
    property alias cfg_showLabelChips: labelChipCheck.checked
    property alias cfg_showPriorityChip: priorityChipCheck.checked
    property alias cfg_showRecurringIcon: recurringIconCheck.checked
    property int cfg_morningHour
    property int cfg_afternoonHour
    property int cfg_eveningHour

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
    }

    ConfigFormShell {

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                id: catchUpCheck
                Kirigami.FormData.label: i18n("Catch-up")
                text: i18n("Show overdue tasks at the top of Today")
                Component.onCompleted: checked = plasmoid.configuration.catchUpEnabled !== false
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
                Component.onCompleted: checked = plasmoid.configuration.showDateChip !== false
            }

            QQC2.CheckBox {
                id: labelChipCheck
                text: i18n("Labels")
                Component.onCompleted: checked = plasmoid.configuration.showLabelChips !== false
            }

            QQC2.CheckBox {
                id: priorityChipCheck
                text: i18n("Priority")
                Component.onCompleted: checked = plasmoid.configuration.showPriorityChip !== false
            }

            QQC2.CheckBox {
                id: recurringIconCheck
                text: i18n("Recurring icon")
                Component.onCompleted: checked = plasmoid.configuration.showRecurringIcon !== false
            }

            QQC2.CheckBox {
                id: showJoinCheck
                Kirigami.FormData.label: i18n("Meetings")
                text: i18n("Show a Join button for http(s) links")
                Component.onCompleted: checked = plasmoid.configuration.showJoinButton !== false
            }

            QQC2.CheckBox {
                id: searchTitleCheck
                Kirigami.FormData.label: i18n("Search")
                text: i18n("Search titles only")
                Component.onCompleted: checked = plasmoid.configuration.searchTitleOnly === true
            }

            QQC2.CheckBox {
                id: searchCaseCheck
                text: i18n("Case sensitive")
                Component.onCompleted: checked = plasmoid.configuration.searchCaseSensitive === true
            }

            QQC2.CheckBox {
                id: relativeDatesCheck
                Kirigami.FormData.label: i18n("Dates")
                text: i18n("Relative dates (Today, Tomorrow)")
                Component.onCompleted: checked = plasmoid.configuration.relativeDates === true
            }

            QQC2.CheckBox {
                id: showTimeCheck
                text: i18n("Show time on the due chip")
                Component.onCompleted: checked = plasmoid.configuration.showTimeOnRow !== false
            }

            QQC2.CheckBox {
                id: completeChildrenCheck
                Kirigami.FormData.label: i18n("Subtasks")
                text: i18n("Completing a parent also completes its children")
                Component.onCompleted: checked = plasmoid.configuration.completeChildren === true
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    catchUpEnabled: true,
                    morningHour: 6,
                    afternoonHour: 12,
                    eveningHour: 18,
                    showDateChip: true,
                    showLabelChips: true,
                    showPriorityChip: true,
                    showRecurringIcon: true,
                    showJoinButton: true,
                    searchTitleOnly: false,
                    searchCaseSensitive: false,
                    relativeDates: false,
                    showTimeOnRow: true,
                    completeChildren: false
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
