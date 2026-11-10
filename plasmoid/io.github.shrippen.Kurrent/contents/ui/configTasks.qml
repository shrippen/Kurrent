import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"

// Task rows and how they behave: click, row content with a live preview, search, sorting.
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
        selectCombo(clickCombo, cfg_clickAction || "inline")
        selectCombo(previewLinesCombo, String(cfg_descriptionPreviewLines))
        selectCombo(sortScopeCombo, cfg_sortScope || "global")
    }

    // Row chips as data: one check box each, laid out in two columns (e1).
    readonly property var chipOptions: [
        { key: "showDateChip", text: i18n("Due date") },
        { key: "showLabelChips", text: i18n("Labels") },
        { key: "showPriorityChip", text: i18n("Priority") },
        { key: "showRecurringIcon", text: i18n("Recurring icon") },
        { key: "showProgressChip", text: i18n("Progress") },
        { key: "showStatusChip", text: i18n("Status") },
        { key: "showSecrecyChip", text: i18n("Secrecy") },
        { key: "showLocationChip", text: i18n("Location") }
    ]

    ConfigFormShell {

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                id: clickCombo
                Kirigami.FormData.label: i18n("Click a task")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Open the inline editor"), value: "inline" },
                    { text: i18n("Open the full editor"), value: "full" },
                    { text: i18n("Select only"), value: "select" }
                ]
                onActivated: cfg_clickAction = model[currentIndex].value
                Component.onCompleted: selectCombo(clickCombo, plasmoid.configuration.clickAction || "inline")
            }

            // The inspector takes the click in the wide layout (f2); double click is fixed (f3).
            ConfigHint {
                text: i18n("In the wide layout with the inspector on, a click shows the task in the inspector. Double-click always opens the full editor.")
            }

            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Rows")
            }

            TaskRowPreview {
                Kirigami.FormData.label: i18n("Preview")
                showDate: root.cfg_showDateChip
                showLabels: root.cfg_showLabelChips
                showPriority: root.cfg_showPriorityChip
                showRecurring: root.cfg_showRecurringIcon
                showProgress: root.cfg_showProgressChip
                showStatus: root.cfg_showStatusChip
                showSecrecy: root.cfg_showSecrecyChip
                showLocation: root.cfg_showLocationChip
                relativeDates: root.cfg_relativeDates
                showTime: root.cfg_showTimeOnRow
                descriptionLines: root.cfg_descriptionPreviewLines
                comfortable: root.cfg_density === "comfortable"
            }

            GridLayout {
                Kirigami.FormData.label: i18n("Row chips")
                Kirigami.FormData.labelAlignment: Qt.AlignTop
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: 0

                Repeater {
                    model: root.chipOptions
                    QQC2.CheckBox {
                        required property var modelData
                        text: modelData.text
                        checked: root["cfg_" + modelData.key]
                        onToggled: root["cfg_" + modelData.key] = checked
                    }
                }
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Dates")
                text: i18n("Relative dates (Today, Tomorrow)")
                checked: root.cfg_relativeDates
                onToggled: root.cfg_relativeDates = checked
            }

            QQC2.CheckBox {
                text: i18n("Show time on the due chip")
                checked: root.cfg_showTimeOnRow
                onToggled: root.cfg_showTimeOnRow = checked
            }

            QQC2.ComboBox {
                id: previewLinesCombo
                Kirigami.FormData.label: i18n("Description preview")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                textRole: "text"
                model: [
                    { text: i18n("Hidden"), value: "0" },
                    { text: i18n("1 line"), value: "1" },
                    { text: i18n("2 lines"), value: "2" }
                ]
                onActivated: root.cfg_descriptionPreviewLines = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(previewLinesCombo, String(plasmoid.configuration.descriptionPreviewLines || 0))
            }

            // Behaviour and search: one section each instead of one heading per check box (e3).
            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Behaviour")
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Meetings")
                text: i18n("Show a Join button for http(s) links")
                checked: root.cfg_showJoinButton
                onToggled: root.cfg_showJoinButton = checked
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Selection")
                text: i18n("Multi-select with Ctrl+click")
                checked: root.cfg_multiSelectEnabled
                onToggled: root.cfg_multiSelectEnabled = checked
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Subtasks")
                text: i18n("Also complete subtasks")
                checked: root.cfg_completeChildren
                onToggled: root.cfg_completeChildren = checked
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Search")
                text: i18n("Search titles only")
                checked: root.cfg_searchTitleOnly
                onToggled: root.cfg_searchTitleOnly = checked
            }

            QQC2.CheckBox {
                text: i18n("Case sensitive")
                checked: root.cfg_searchCaseSensitive
                onToggled: root.cfg_searchCaseSensitive = checked
            }

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

            ConfigHint {
                text: sortScopeCombo.currentIndex >= 0
                        && sortScopeCombo.model[sortScopeCombo.currentIndex].value === "perView"
                        ? i18n("Each sidebar view keeps its own sort. Views you have not changed start with Priority › Due › Title A–Z.")
                        : i18n("One sort order for every view. The default is Priority › Due › Title A–Z until you change it in the task list.")
            }

        }

        ConfigResetButton {
            page: root
            defaults: ({
                clickAction: "inline",
                showDateChip: true,
                showLabelChips: true,
                showPriorityChip: true,
                showRecurringIcon: true,
                showProgressChip: true,
                showStatusChip: true,
                showSecrecyChip: true,
                showLocationChip: true,
                relativeDates: true,
                showTimeOnRow: true,
                descriptionPreviewLines: 0,
                showJoinButton: true,
                multiSelectEnabled: false,
                completeChildren: false,
                searchTitleOnly: false,
                searchCaseSensitive: false,
                sortScope: "global",
                sortMode: "",
                sortModeByView: "{}"
            })
        }
    }
}
