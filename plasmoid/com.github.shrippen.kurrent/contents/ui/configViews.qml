import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"
import ".."

ConfigPageBase {
    id: root


    property int editingIndex: -1

    function smartViewsArray() {
        try {
            return JSON.parse(cfg_smartViews || "[]")
        } catch (e) {
            return []
        }
    }

    function writeSmartViews(arr) {
        cfg_smartViews = JSON.stringify(arr)
    }

    function duplicateBuiltinView(viewId) {
        var names = {
            inbox: i18n("Inbox"),
            today: i18n("Today"),
            overdue: i18n("Overdue"),
            tomorrow: i18n("Tomorrow"),
            scheduled: i18n("Scheduled"),
            anytime: i18n("Anytime"),
            recurring: i18n("Recurring"),
            unlabeled: i18n("Unlabeled"),
            completed: i18n("Completed")
        }
        var rules = { status: "open" }
        if (viewId === "completed") {
            rules = { status: "completed" }
        } else if (viewId === "recurring") {
            rules = { recurring: true, status: "open" }
        } else if (viewId === "overdue") {
            rules = { dueWindow: "overdue", status: "open" }
        } else if (viewId === "today") {
            rules = { dueWindow: "today", status: "open" }
        } else if (viewId === "tomorrow") {
            rules = { dueWindow: "tomorrow", status: "open" }
        }
        var arr = root.smartViewsArray()
        var id = "view" + String(Date.now())
        arr.push({
            id: id,
            name: names[viewId] || viewId,
            icon: "view-filter",
            mode: "list",
            sort: "",
            rules: rules
        })
        root.writeSmartViews(arr)
        root.editingIndex = arr.length - 1
        editorDialog.open()
    }

    ConfigFormShell {
        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                Kirigami.FormData.label: i18n("Smart Views")
                text: i18n("Saved filters appear in the sidebar. Each can set filter rules and a default main-pane mode.")
                level: 4
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                model: root.smartViewsArray()
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        source: modelData.icon || "view-filter"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: modelData.name || modelData.id
                        elide: Text.ElideRight
                    }

                    QQC2.ToolButton {
                        icon.name: "document-edit"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: {
                            root.editingIndex = index
                            editorDialog.open()
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: {
                            var arr = root.smartViewsArray()
                            arr.splice(index, 1)
                            root.writeSmartViews(arr)
                        }
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Add")
                spacing: Design.spaceSmall

                QQC2.Button {
                    text: i18n("New Smart View")
                    onClicked: {
                        var arr = root.smartViewsArray()
                        var id = "view" + String(Date.now())
                        arr.push({
                            id: id,
                            name: i18n("New Smart View"),
                            icon: "view-filter",
                            mode: "list",
                            sort: "",
                            rules: { status: "open" }
                        })
                        root.writeSmartViews(arr)
                        root.editingIndex = arr.length - 1
                        editorDialog.open()
                    }
                }

                QQC2.ComboBox {
                    id: duplicateCombo
                    Layout.fillWidth: true
                    textRole: "text"
                    model: [
                        { text: i18n("Duplicate built-in view…"), value: "" },
                        { text: i18n("Today"), value: "today" },
                        { text: i18n("Overdue"), value: "overdue" },
                        { text: i18n("Tomorrow"), value: "tomorrow" },
                        { text: i18n("Inbox"), value: "inbox" },
                        { text: i18n("Scheduled"), value: "scheduled" },
                        { text: i18n("Recurring"), value: "recurring" },
                        { text: i18n("Completed"), value: "completed" }
                    ]
                    onActivated: {
                        if (model[currentIndex].value) {
                            root.duplicateBuiltinView(model[currentIndex].value)
                            currentIndex = 0
                        }
                    }
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Kanban")
            }

            QQC2.ComboBox {
                id: kanbanSourceCombo
                Kirigami.FormData.label: i18n("Default column source")
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Status"), value: "status" },
                    { text: i18n("Completion"), value: "completion" },
                    { text: i18n("Project"), value: "project" },
                    { text: i18n("Due date buckets"), value: "due" },
                    { text: i18n("Priority"), value: "priority" },
                    { text: i18n("Label"), value: "label" },
                    { text: i18n("Day section"), value: "daysection" },
                    { text: i18n("Secrecy"), value: "secrecy" },
                    { text: i18n("Custom column (KURRENT/COLUMN)"), value: "column" }
                ]
                Component.onCompleted: {
                    currentIndex = Math.max(0, indexOfValue(cfg_kanbanColumnSource || "status"))
                }
                onActivated: cfg_kanbanColumnSource = model[currentIndex].value
            }

            QQC2.ComboBox {
                id: kanbanWriteCombo
                Kirigami.FormData.label: i18n("Kanban writes")
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Standard VTODO fields"), value: "fields" },
                    { text: i18n("KURRENT/COLUMN only"), value: "custom" },
                    { text: i18n("Both"), value: "both" }
                ]
                Component.onCompleted: {
                    currentIndex = Math.max(0, indexOfValue(cfg_kanbanWriteMode || "fields"))
                }
                onActivated: cfg_kanbanWriteMode = model[currentIndex].value
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Swimlanes")
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Lane axis (rows)")
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Project"), value: "project" },
                    { text: i18n("Label"), value: "label" },
                    { text: i18n("Priority"), value: "priority" },
                    { text: i18n("Parent task"), value: "parent" }
                ]
                Component.onCompleted: {
                    currentIndex = Math.max(0, indexOfValue(cfg_swimlaneLaneAxis || "project"))
                }
                onActivated: cfg_swimlaneLaneAxis = model[currentIndex].value
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Time axis (columns)")
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Day"), value: "day" },
                    { text: i18n("Week"), value: "week" },
                    { text: i18n("Month"), value: "month" }
                ]
                Component.onCompleted: {
                    currentIndex = Math.max(0, indexOfValue(cfg_swimlaneTimeBucket || "day"))
                }
                onActivated: cfg_swimlaneTimeBucket = model[currentIndex].value
            }
        }
    }

    QQC2.Dialog {
        id: editorDialog
        parent: root
        modal: true
        width: Math.min(parent.width * 0.9, Kirigami.Units.gridUnit * 36)
        title: i18n("Edit Smart View")

        property var draft: ({ rules: {} })

        onAboutToShow: {
            var arr = root.smartViewsArray()
            if (root.editingIndex >= 0 && root.editingIndex < arr.length) {
                draft = JSON.parse(JSON.stringify(arr[root.editingIndex]))
            }
            if (!draft.rules) {
                draft.rules = {}
            }
            nameField.text = draft.name || ""
            iconField.text = draft.icon || "view-filter"
            textRuleField.text = draft.rules.text || ""
            labelRuleField.text = draft.rules.label || ""
            listRuleField.text = draft.rules.list || ""
            columnRuleField.text = draft.rules.column || ""
            recurringCheck.checked = draft.rules.recurring === true
            sortField.text = draft.sort || ""
            modeCombo.currentIndex = Math.max(0, modeCombo.indexOfValue(draft.mode || "list"))
            statusCombo.currentIndex = Math.max(0, statusCombo.indexOfValue(draft.rules.status || "open"))
            dueCombo.currentIndex = Math.max(0, dueCombo.indexOfValue(draft.rules.dueWindow || ""))
            priorityCombo.currentIndex = Math.max(0, priorityCombo.indexOfValue(String(draft.rules.priority !== undefined ? draft.rules.priority : -1)))
        }

        contentItem: ColumnLayout {
            spacing: Design.spaceSmall

            QQC2.TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: i18n("Name")
            }

            QQC2.TextField {
                id: iconField
                Layout.fillWidth: true
                placeholderText: i18n("Icon name (Plasma icon)")
            }

            QQC2.ComboBox {
                id: modeCombo
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("List"), value: "list" },
                    { text: i18n("Kanban"), value: "kanban" },
                    { text: i18n("Swimlanes"), value: "swimlane" },
                    { text: i18n("Project plan"), value: "plan" },
                    { text: i18n("Heatmap"), value: "heatmap" },
                    { text: i18n("Calendar + tasks"), value: "calendar" }
                ]
            }

            QQC2.TextField {
                id: sortField
                Layout.fillWidth: true
                placeholderText: i18n("Sort override (e.g. priority,due,title)")
            }

            QQC2.TextField {
                id: textRuleField
                Layout.fillWidth: true
                placeholderText: i18n("Text contains")
            }

            QQC2.TextField {
                id: labelRuleField
                Layout.fillWidth: true
                placeholderText: i18n("Label")
            }

            QQC2.ComboBox {
                id: statusCombo
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Any status"), value: "" },
                    { text: i18n("Open"), value: "open" },
                    { text: i18n("In process"), value: "in-process" },
                    { text: i18n("Completed"), value: "completed" },
                    { text: i18n("Cancelled"), value: "cancelled" }
                ]
            }

            QQC2.ComboBox {
                id: dueCombo
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Any due date"), value: "" },
                    { text: i18n("Overdue"), value: "overdue" },
                    { text: i18n("Today"), value: "today" },
                    { text: i18n("Tomorrow"), value: "tomorrow" },
                    { text: i18n("This week"), value: "week" },
                    { text: i18n("No date"), value: "none" }
                ]
            }

            QQC2.ComboBox {
                id: priorityCombo
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Any priority"), value: "-1" },
                    { text: i18n("High"), value: "1" },
                    { text: i18n("Medium"), value: "5" },
                    { text: i18n("Low"), value: "9" },
                    { text: i18n("None"), value: "0" }
                ]
            }

            QQC2.CheckBox {
                id: recurringCheck
                text: i18n("Recurring only")
            }

            QQC2.TextField {
                id: listRuleField
                Layout.fillWidth: true
                placeholderText: i18n("KURRENT/LIST (day section)")
            }

            QQC2.TextField {
                id: columnRuleField
                Layout.fillWidth: true
                placeholderText: i18n("KURRENT/COLUMN")
            }
        }

        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

        onAccepted: {
            var arr = root.smartViewsArray()
            if (root.editingIndex < 0 || root.editingIndex >= arr.length) {
                return
            }
            var entry = arr[root.editingIndex]
            entry.name = nameField.text.trim() || entry.name
            entry.icon = iconField.text.trim() || "view-filter"
            entry.mode = modeCombo.currentValue
            entry.sort = sortField.text.trim()
            entry.rules = {
                text: textRuleField.text.trim(),
                label: labelRuleField.text.trim(),
                status: statusCombo.currentValue,
                dueWindow: dueCombo.currentValue,
                priority: parseInt(priorityCombo.currentValue, 10),
                recurring: recurringCheck.checked,
                list: listRuleField.text.trim(),
                column: columnRuleField.text.trim()
            }
            arr[root.editingIndex] = entry
            root.writeSmartViews(arr)
        }
    }
}
