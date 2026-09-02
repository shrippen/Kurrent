import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"
import ".."

ConfigPageBase {
    id: root

    ConfigControllerLoader {
        id: configControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var configController: configControllerLoader.controller

    property int editingIndex: -1

    readonly property var smartViewsListModel: {
        // Re-evaluate whenever cfg_smartViews changes.
        var _unused = cfg_smartViews
        return root.smartViewsArray()
    }

    // ── Available data from live controller ──
    readonly property var availableProjectItems: {
        var items = [{ text: i18n("Any project"), value: -1 }]
        if (!configController || !configController.collectionModel) {
            return items
        }
        var model = configController.collectionModel
        for (var i = 0; i < model.count; ++i) {
            if (model.enabledAt(i)) {
                items.push({
                    text: model.nameAt(i),
                    value: model.collectionIdAt(i)
                })
            }
        }
        return items
    }

    readonly property var availableLabelItems: {
        var items = [i18n("Any label")]
        if (!configController) {
            return items
        }
        var labels = configController.availableLabels || []
        for (var i = 0; i < labels.length; ++i) {
            items.push(labels[i])
        }
        return items
    }

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

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Smart Views")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18n("Saved filters appear in the sidebar. Each can set filter rules and a default main-pane mode.")
                    opacity: 0.65
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.spaceSmall

                    QQC2.Button {
                        text: i18n("New Smart View")
                        icon.name: "list-add"
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

                Repeater {
                    model: root.smartViewsListModel
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
                                if (index >= 0 && index < arr.length) {
                                    arr.splice(index, 1)
                                    root.writeSmartViews(arr)
                                }
                            }
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
                    { text: i18n("Custom column (KCURRENT/COLUMN)"), value: "column" }
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
                    { text: i18n("KCURRENT/COLUMN only"), value: "custom" },
                    { text: i18n("Both"), value: "both" }
                ]
                Component.onCompleted: {
                    currentIndex = Math.max(0, indexOfValue(cfg_kanbanWriteMode || "fields"))
                }
                onActivated: cfg_kanbanWriteMode = model[currentIndex].value
            }

            // Swimlanes section
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Swimlanes")
            }

            QQC2.ComboBox {
                id: swimlaneAxisCombo
                Kirigami.FormData.label: i18n("Row axis")
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
                id: swimlaneTimeCombo
                Kirigami.FormData.label: i18n("Column axis")
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

            // Project plan section
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Project plan")
            }

            QQC2.ComboBox {
                id: planTimeCombo
                Kirigami.FormData.label: i18n("Time grouping")
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("Day"), value: "day" },
                    { text: i18n("Week"), value: "week" },
                    { text: i18n("Month"), value: "month" }
                ]
                Component.onCompleted: {
                    currentIndex = Math.max(0, indexOfValue(cfg_planTimeBucket || "week"))
                }
                onActivated: cfg_planTimeBucket = model[currentIndex].value
            }

            QQC2.SpinBox {
                id: planHorizonSpin
                Kirigami.FormData.label: i18n("Planning horizon")
                Layout.fillWidth: true
                from: 0
                to: 52
                value: cfg_planHorizon !== undefined ? cfg_planHorizon : 8
                onValueModified: cfg_planHorizon = value
                QQC2.ToolTip.text: i18n("0 = show all time periods")
                QQC2.ToolTip.visible: hovered
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Show undated tasks")
                checked: cfg_planShowUndated !== undefined ? cfg_planShowUndated : true
                onCheckedChanged: cfg_planShowUndated = checked
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Show completed tasks")
                checked: cfg_planShowCompleted === true
                onCheckedChanged: cfg_planShowCompleted = checked
            }
        }
    }

    QQC2.Dialog {
        id: editorDialog
        parent: QQC2.Overlay.overlay
        title: i18n("Edit Smart View")
        modal: true
        width: Math.min(parent.width * 0.9, Kirigami.Units.gridUnit * 28)
        height: Math.min(parent.height * 0.85, contentHeight + footer.height + topPadding + bottomPadding)
        contentHeight: dialogLayout.implicitHeight
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)

        onOpened: {
            var arr = root.smartViewsArray()
            if (root.editingIndex < 0 || root.editingIndex >= arr.length) {
                return
            }
            var entry = arr[root.editingIndex]
            nameField.text = entry.name || ""
            // Icon: match by value, fall back to first item
            var iconVal = entry.icon || "view-filter"
            var iconIdx = iconCombo.indexOfValue(iconVal)
            iconCombo.currentIndex = iconIdx >= 0 ? iconIdx : 0
            modeCombo.currentIndex = Math.max(0, modeCombo.indexOfValue(entry.mode || "list"))
            // Sort: match by value
            var sortVal = entry.sort || ""
            var sortIdx = sortCombo.indexOfValue(sortVal)
            sortCombo.currentIndex = sortIdx >= 0 ? sortIdx : 0

            var rules = entry.rules || {}
            textRuleField.text = rules.text || ""
            // Project: match by collectionId
            var projId = rules.projectId !== undefined ? rules.projectId : -1
            var projIdx = projectCombo.indexOfValue(projId)
            projectCombo.currentIndex = projIdx >= 0 ? projIdx : 0
            // Label: match by name
            var labelVal = rules.label || ""
            var labelIdx = labelCombo.find(labelVal)
            labelCombo.currentIndex = labelIdx >= 0 ? labelIdx : 0
            statusCombo.currentIndex = Math.max(0, statusCombo.indexOfValue(rules.status || ""))
            dueCombo.currentIndex = Math.max(0, dueCombo.indexOfValue(rules.dueWindow || ""))
            priorityCombo.currentIndex = Math.max(0, priorityCombo.indexOfValue(String(rules.priority !== undefined ? rules.priority : -1)))
            recurringCheck.checked = !!rules.recurring
            // Day section: match by value
            var listVal = rules.list || ""
            var listIdx = listCombo.indexOfValue(listVal)
            listCombo.currentIndex = listIdx >= 0 ? listIdx : 0
            columnRuleField.text = rules.column || ""
        }

        QQC2.ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            contentWidth: availableWidth
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            ColumnLayout {
                id: dialogLayout
                width: scrollView.width
                spacing: Design.spaceSmall

                // ── Appearance ──
                Kirigami.Heading {
                    text: i18n("Appearance")
                    level: 4
                    Layout.fillWidth: true
                }

                QQC2.Label {
                    text: i18n("Choose how this Smart View looks and sorts tasks.")
                    opacity: 0.65
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Kirigami.FormLayout {
                    Layout.fillWidth: true

                    QQC2.TextField {
                        id: nameField
                        Kirigami.FormData.label: i18n("Name:")
                        Layout.fillWidth: true
                        placeholderText: i18n("Smart View name")
                        QQC2.ToolTip.text: i18n("The display name shown in the sidebar.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: iconCombo
                        Kirigami.FormData.label: i18n("Icon:")
                        Layout.fillWidth: true
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: i18n("Filter"), value: "view-filter" },
                            { text: i18n("Inbox"), value: "mail-folder-inbox" },
                            { text: i18n("Calendar"), value: "view-calendar-day" },
                            { text: i18n("Flag"), value: "flag" },
                            { text: i18n("Tag"), value: "tag" },
                            { text: i18n("Folder"), value: "folder" },
                            { text: i18n("Checkmark"), value: "task-complete" },
                            { text: i18n("Clock"), value: "chronometer" },
                            { text: i18n("Star"), value: "favorite" },
                            { text: i18n("Briefcase"), value: "briefcase" },
                            { text: i18n("Lightbulb"), value: "idea" },
                            { text: i18n("Heart"), value: "face-heart" },
                            { text: i18n("Warning"), value: "dialog-warning" },
                            { text: i18n("Work"), value: "system-run" },
                            { text: i18n("Home"), value: "user-home" },
                            { text: i18n("Search"), value: "edit-find" }
                        ]
                        QQC2.ToolTip.text: i18n("Icon displayed next to the Smart View in the sidebar.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: modeCombo
                        Kirigami.FormData.label: i18n("View mode:")
                        Layout.fillWidth: true
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: i18n("List"), value: "list" },
                            { text: i18n("Kanban"), value: "kanban" },
                            { text: i18n("Swimlanes"), value: "swimlane" },
                            { text: i18n("Project plan"), value: "plan" },
                            { text: i18n("Heatmap"), value: "heatmap" },
                            { text: i18n("Agenda"), value: "calendar" }
                        ]
                        QQC2.ToolTip.text: i18n("The main-pane view mode used when this Smart View is active.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: sortCombo
                        Kirigami.FormData.label: i18n("Sort by:")
                        Layout.fillWidth: true
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: 0
                        model: [
                            { text: i18n("Default (Priority → Due → Title)"), value: "" },
                            { text: i18n("Due date"), value: "due" },
                            { text: i18n("Due date (latest first)"), value: "dueDesc" },
                            { text: i18n("Priority"), value: "priority" },
                            { text: i18n("Title A–Z"), value: "title" },
                            { text: i18n("Title Z–A"), value: "titleDesc" },
                            { text: i18n("Project"), value: "project" },
                            { text: i18n("Label"), value: "label" },
                            { text: i18n("Start date"), value: "start" },
                            { text: i18n("Status"), value: "status" },
                            { text: i18n("Progress %"), value: "progress" },
                            { text: i18n("Custom (manual)"), value: "custom" }
                        ]
                        QQC2.ToolTip.text: i18n("How tasks are ordered in this view. Leave at Default to use Priority → Due → Title.")
                        QQC2.ToolTip.visible: hovered
                    }
                }

                // ── Filter Rules ──
                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                Kirigami.Heading {
                    text: i18n("Filter Rules")
                    level: 4
                    Layout.fillWidth: true
                }

                QQC2.Label {
                    text: i18n("Only tasks matching ALL active rules are shown. Leave a filter on \"Any\" to disable it.")
                    opacity: 0.65
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Kirigami.FormLayout {
                    Layout.fillWidth: true

                    QQC2.TextField {
                        id: textRuleField
                        Kirigami.FormData.label: i18n("Search text:")
                        Layout.fillWidth: true
                        placeholderText: i18n("Contains…")
                        QQC2.ToolTip.text: i18n("Filter tasks whose title or description contains this text. Leave empty to show all.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: projectCombo
                        Kirigami.FormData.label: i18n("Project:")
                        Layout.fillWidth: true
                        textRole: "text"
                        valueRole: "value"
                        model: root.availableProjectItems
                        currentIndex: 0
                        QQC2.ToolTip.text: i18n("Show only tasks from a specific project (Akonadi collection). \"Any project\" disables this filter.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: labelCombo
                        Kirigami.FormData.label: i18n("Label:")
                        Layout.fillWidth: true
                        currentIndex: 0
                        model: root.availableLabelItems
                        QQC2.ToolTip.text: i18n("Show only tasks with a specific label (Akonadi category). \"Any label\" disables this filter.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: statusCombo
                        Kirigami.FormData.label: i18n("Status:")
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
                        QQC2.ToolTip.text: i18n("Filter by task status. \"Any status\" shows tasks regardless of status.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: dueCombo
                        Kirigami.FormData.label: i18n("Due date:")
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
                        QQC2.ToolTip.text: i18n("Filter tasks by when they are due. \"Any due date\" shows all regardless of due date.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: priorityCombo
                        Kirigami.FormData.label: i18n("Priority:")
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
                        QQC2.ToolTip.text: i18n("Filter by priority level. \"Any priority\" shows all tasks.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.CheckBox {
                        id: recurringCheck
                        Layout.fillWidth: true
                        text: i18n("Recurring tasks only")
                        QQC2.ToolTip.text: i18n("When checked, only recurring tasks are shown.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.ComboBox {
                        id: listCombo
                        Kirigami.FormData.label: i18n("Day section:")
                        Layout.fillWidth: true
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: 0
                        model: [
                            { text: i18n("Any section"), value: "" },
                            { text: i18n("Morning"), value: "morning" },
                            { text: i18n("Afternoon"), value: "afternoon" },
                            { text: i18n("Evening"), value: "evening" }
                        ]
                        QQC2.ToolTip.text: i18n("Filter by KCURRENT/LIST day section. Used by the Today view to group tasks into Morning, Afternoon, and Evening buckets.")
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.TextField {
                        id: columnRuleField
                        Kirigami.FormData.label: i18n("Custom column:")
                        Layout.fillWidth: true
                        placeholderText: i18n("KCURRENT/COLUMN value…")
                        QQC2.ToolTip.text: i18n("Filter by a custom KCURRENT/COLUMN value. Only needed when using Kanban with \"Custom column\" as source. Leave empty to ignore.")
                        QQC2.ToolTip.visible: hovered
                    }
                }
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
            entry.icon = iconCombo.currentValue || "view-filter"
            entry.mode = modeCombo.currentValue
            entry.sort = sortCombo.currentValue || ""
            // Build rules — only include non-empty/non-default values
            var rules = {}
            var searchText = textRuleField.text.trim()
            if (searchText) {
                rules.text = searchText
            }
            var projVal = projectCombo.currentValue
            if (projVal !== undefined && projVal >= 0) {
                rules.projectId = projVal
            }
            if (labelCombo.currentIndex > 0) {
                rules.label = labelCombo.currentText
            }
            var statusVal = statusCombo.currentValue
            if (statusVal) {
                rules.status = statusVal
            }
            var dueVal = dueCombo.currentValue
            if (dueVal) {
                rules.dueWindow = dueVal
            }
            var prioVal = parseInt(priorityCombo.currentValue, 10)
            if (prioVal >= 0) {
                rules.priority = prioVal
            }
            if (recurringCheck.checked) {
                rules.recurring = true
            }
            var listVal = listCombo.currentValue
            if (listVal) {
                rules.list = listVal
            }
            var colVal = columnRuleField.text.trim()
            if (colVal) {
                rules.column = colVal
            }
            entry.rules = rules
            arr[root.editingIndex] = entry
            root.writeSmartViews(arr)
        }
    }
}
