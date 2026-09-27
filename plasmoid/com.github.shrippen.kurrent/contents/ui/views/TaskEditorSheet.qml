import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "../components"
import "../colors.js" as Colors
import "../datetime.js" as DateTime
import ".."
import "."
import "../Kante"

FocusScope {
    id: root

    required property var controller
    property var task: ({})
    // false: editor card stays on the task pane. Dim always covers the whole plasmoid.
    property bool coverSidebar: true
    property int sidebarReserve: 0
    // Extra inset when the overlay is parented onto the Plasma applet chrome.
    property int hostPadLeft: 0
    property int hostPadTop: 0
    property int hostPadRight: 0
    property int hostPadBottom: 0

    visible: false
    clip: false
    focus: true

    // Date pickers stay inside this item, not a separate overlay window.
    readonly property Item popupAnchor: root
    readonly property alias deleteButton: deleteButton
    readonly property alias saveButton: saveButton
    readonly property alias cancelButton: cancelButton

    property bool clearDueRequested: false
    property bool clearStartRequested: false
    property int statusValue: 0
    property int secrecyValue: 0

    Keys.onEscapePressed: root.reject()

    function open() {
        loadFields()
        visible = true
        forceActiveFocus()
    }

    function close() {
        visible = false
    }

    function reject() {
        close()
    }

    function loadFields() {
        clearDueRequested = false
        clearStartRequested = false
        summaryField.text = task.summary || ""
        summaryField.cursorPosition = 0
        descriptionField.text = task.description || ""
        locationPicker.selectedLocation = task.location || ""
        sectionField.text = task.section || ""
        allDayCheck.checked = task.allDay === true
        dueDateField.text = DateTime.formatDate(task.dueDate)
        dueTimeField.text = DateTime.formatTime(task.dueDate)
        startDateField.text = DateTime.formatDate(task.startDate)
        startTimeField.text = DateTime.formatTime(task.startDate)
        priorityPicker.priority = Colors.normalizePriority(task.priority || 0)
        labelPicker.selectedLabels = (task.categories || []).slice()
        percentSlider.value = task.percentComplete !== undefined ? task.percentComplete : (task.completed ? 100 : 0)
        statusValue = normalizeStatus(task.status || 0)
        secrecyValue = Math.max(0, Math.min(2, task.secrecy || 0))
        recurrenceBox.currentIndex = recurrenceIndexFor(task.recurrencePreset || "none")
        reminderBox.currentIndex = reminderIndexFor(task.reminderMinutes)
        projectPicker.collectionId = task.collectionId || -1
        projectPicker.hiddenProjects = Plasmoid.configuration.hiddenProjects || ""
        projectPicker.collectionModel = controller.collectionModel
        projectPicker.rebuild()
    }

    function normalizeStatus(status) {
        var values = [0, 4, 6, 3, 5]
        for (var i = 0; i < values.length; ++i) {
            if (values[i] === status) {
                return status
            }
        }
        return 0
    }

    function recurrenceIndexFor(preset) {
        switch (String(preset)) {
        case "daily":
            return 1
        case "weekly":
            return 2
        case "monthly":
            return 3
        case "yearly":
            return 4
        default:
            return 0
        }
    }

    function recurrenceValueFor(index) {
        switch (index) {
        case 1:
            return "daily"
        case 2:
            return "weekly"
        case 3:
            return "monthly"
        case 4:
            return "yearly"
        default:
            return "none"
        }
    }

    function reminderIndexFor(minutes) {
        var n = Number(minutes)
        if (n === 0) return 1
        if (n === 15) return 2
        if (n === 60) return 3
        if (n === 1440) return 4
        return 0
    }

    function reminderValueFor(index) {
        switch (index) {
        case 1: return 0
        case 2: return 15
        case 3: return 60
        case 4: return 1440
        default: return -1
        }
    }

    function accept() {
        var dueResult = DateTime.resolveDateFields(dueDateField.text, dueTimeField.text, allDayCheck.checked, clearDueRequested)
        if (!dueResult) {
            return
        }
        var startResult = DateTime.resolveDateFields(startDateField.text, startTimeField.text, allDayCheck.checked, clearStartRequested)
        if (!startResult) {
            return
        }

        var fields = {
            "summary": summaryField.text,
            "description": descriptionField.text,
            "location": locationPicker.selectedLocation,
            "section": sectionField.text,
            "allDay": allDayCheck.checked,
            "priority": Colors.normalizePriority(priorityPicker.priority),
            "categories": labelPicker.selectedLabels.slice(),
            "completed": statusValue === 3,
            "percentComplete": Math.round(percentSlider.value),
            "status": statusValue,
            "secrecy": secrecyValue,
            "recurrencePreset": recurrenceValueFor(recurrenceBox.currentIndex),
            "reminderMinutes": reminderValueFor(reminderBox.currentIndex),
            "clearDue": dueResult.clear,
            "clearStart": startResult.clear,
            "collectionId": projectPicker.collectionId
        }

        if (!dueResult.clear && dueResult.date) {
            fields.dueDate = dueResult.date
        }
        if (!startResult.clear && startResult.date) {
            fields.startDate = startResult.date
        }

        if (task.itemId > 0) {
            controller.updateTaskFull(task.itemId, fields)
        } else {
            controller.createTaskFull(fields)
        }
        close()
    }

    component FieldLabel: QQC2.Label {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 8
    }

    readonly property int overlayInset: Math.min(Design.overlayInset,
            Math.max(Design.spaceSmall, Math.round(Math.min(width, height) / 18)))
    readonly property int cardLeftInset: (coverSidebar ? 0 : sidebarReserve) + overlayInset + hostPadLeft

    // Reparented onto the applet container, i.e. outside FullView's KanteScope.
    KanteScope { target: root }

    Item {
        id: windowFrame
        anchors.fill: parent
        anchors.topMargin: root.overlayInset + root.hostPadTop
        anchors.bottomMargin: root.overlayInset + root.hostPadBottom
        anchors.rightMargin: root.overlayInset + root.hostPadRight
        anchors.leftMargin: root.cardLeftInset
        clip: true

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 1
            radius: KanteStyle.active ? 0 : Design.windowRadius
            color: Qt.rgba(0, 0, 0, 0.18)
            z: 0
        }

        Rectangle {
            id: windowChrome
            anchors.fill: parent
            visible: !KanteStyle.active
            radius: Design.windowRadius
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Design.windowBorderColor()
            z: 1
        }

        // Kante and Kante Light: dialog card with the cut corner and the accent bar.
        KanteCard {
            anchors.fill: parent
            visible: KanteStyle.active
            color: KanteStyle.dialogColor
            borderColor: KanteStyle.frameColor
            // Accent bar in the task's priority band; plain accent without a priority.
            barColor: priorityPicker.priority > 0 ? Design.priorityColor(priorityPicker.priority) : KanteStyle.accentColor
            z: 1
        }

        // The card itself needs no click-capturing MouseArea: the dim is a lower-z
        // sibling, so pointer events cannot fall through it. A full-card MouseArea
        // can otherwise win the gesture grab from footer buttons after reparenting.

        // Hovering the card: never let the wheel reach the task list or sidebar.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                event.accepted = true
            }
        }

        ColumnLayout {
            id: editorBody
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0
            z: 2
            clip: true

        readonly property int contentPad: Design.padEditor
        readonly property int footerPad: Design.padEditor

        // Header: dialog title and the task status as a segmented switch (e2, e5).
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: editorBody.footerPad
            Layout.rightMargin: editorBody.footerPad
            Layout.topMargin: editorBody.footerPad
            Layout.bottomMargin: Design.spaceSmall
            spacing: Design.spaceMedium

            Kirigami.Heading {
                level: 3
                text: task && task.itemId > 0 ? i18n("Edit task") : i18n("New task")
                height: statusSegments.height
                verticalAlignment: Text.AlignVCenter
            }

            Row {
                id: statusSegments
                spacing: 0
                Accessible.name: i18n("Status")

                Repeater {
                    model: [
                        { label: i18n("Needs action"), value: 4 },
                        { label: i18n("In process"), value: 6 },
                        { label: i18n("Completed"), value: 3 },
                        { label: i18n("Canceled"), value: 5 }
                    ]
                    delegate: KanteToolButton {
                        required property var modelData
                        text: modelData.label
                        checkable: true
                        checked: root.statusValue === modelData.value
                        onClicked: {
                            // Click on the active segment clears the status.
                            var next = root.statusValue === modelData.value ? 0 : modelData.value
                            if (next === 3 && percentSlider.value < 100) {
                                percentSlider.value = 100
                            } else if (next !== 3 && root.statusValue === 3 && percentSlider.value === 100) {
                                percentSlider.value = 0
                            }
                            root.statusValue = next
                            checked = Qt.binding(function() { return root.statusValue === modelData.value })
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Flickable {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            // Content-to-scrollbar gap matches content-to-left-edge (contentPad).
            rightMargin: editorBody.contentPad + Design.scrollBarExtent
            contentWidth: width - rightMargin
            contentHeight: form.implicitHeight + editorBody.contentPad * 2
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            QQC2.ScrollBar.vertical: ThinScrollBar {
                view: scrollView
                parent: scrollView
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }
            QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
                policy: QQC2.ScrollBar.AlwaysOff
            }

            GridLayout {
                id: form
                x: editorBody.contentPad
                y: editorBody.contentPad
                width: Math.max(0, scrollView.width - scrollView.rightMargin - editorBody.contentPad)
                columns: 2
                columnSpacing: Design.spaceMedium
                rowSpacing: Design.spaceSmall

            Kirigami.Heading {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                level: 3
                text: i18n("Basics")
            }

            FieldLabel { text: i18n("Title") }
            KanteTextField {
                id: summaryField
                Layout.fillWidth: true
                placeholderText: i18n("Title")
            }

            FieldLabel {
                text: i18n("Description")
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
            }
            ScrollableTextArea {
                id: descriptionField
                Layout.fillWidth: true
                preferredLines: 5
                placeholderText: i18n("Description")
                onEscapePressed: root.reject()
            }

            Kirigami.Heading {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                level: 3
                text: i18n("Schedule")
            }

            Item { implicitWidth: 1 }
            QQC2.CheckBox {
                id: allDayCheck
                KanteCheckSkin { control: parent }
                text: i18n("All day")
            }

            FieldLabel { text: i18n("Start") }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                DateTimeInput {
                    id: startDateField
                    Layout.fillWidth: true
                    mode: "date"
                    popupParent: root.popupAnchor
                    onTextEdited: root.clearStartRequested = false
                    onTextChanged: {
                        // Auto-check allDay when a date is entered but no time is set
                        if (text.length > 0 && startTimeField.text.length === 0 && !allDayCheck.checked) {
                            allDayCheck.checked = true
                        }
                    }
                }
                DateTimeInput {
                    id: startTimeField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 7
                    mode: "time"
                    visible: !allDayCheck.checked
                    onTextEdited: root.clearStartRequested = false
                }
                KanteToolButton {
                    icon.name: "edit-clear"
                    onClicked: {
                        startDateField.clear()
                        startTimeField.clear()
                        root.clearStartRequested = true
                    }
                    QQC2.ToolTip.text: i18n("Clear start")
                    QQC2.ToolTip.visible: hovered
                }
            }

            FieldLabel { text: i18n("Due") }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                DateTimeInput {
                    id: dueDateField
                    Layout.fillWidth: true
                    mode: "date"
                    popupParent: root.popupAnchor
                    onTextEdited: root.clearDueRequested = false
                    onTextChanged: {
                        // Auto-check allDay when a date is entered but no time is set
                        if (text.length > 0 && dueTimeField.text.length === 0 && !allDayCheck.checked) {
                            allDayCheck.checked = true
                        }
                    }
                }
                DateTimeInput {
                    id: dueTimeField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 7
                    mode: "time"
                    visible: !allDayCheck.checked
                    onTextEdited: root.clearDueRequested = false
                }
                KanteToolButton {
                    icon.name: "edit-clear"
                    onClicked: {
                        dueDateField.clear()
                        dueTimeField.clear()
                        root.clearDueRequested = true
                    }
                    QQC2.ToolTip.text: i18n("Clear due date")
                    QQC2.ToolTip.visible: hovered
                }
            }

            FieldLabel { text: i18n("Repeat") }
            QQC2.ComboBox {
                id: recurrenceBox
                KanteFieldSkin { control: parent }
                Layout.fillWidth: true
                model: [
                    i18n("None"),
                    i18n("Daily"),
                    i18n("Weekly"),
                    i18n("Monthly"),
                    i18n("Yearly")
                ]
            }

            FieldLabel { text: i18n("Reminder") }
            QQC2.ComboBox {
                id: reminderBox
                KanteFieldSkin { control: parent }
                Layout.fillWidth: true
                model: [
                    i18n("Off"),
                    i18n("At due time"),
                    i18n("15 minutes before"),
                    i18n("1 hour before"),
                    i18n("1 day before")
                ]
            }

            Kirigami.Heading {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                level: 3
                text: i18n("Classification")
            }

            // Slider plus figure; status lives in the header (e5, e6).
            FieldLabel { text: i18n("Progress") }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Slider {
                    id: percentSlider
                    KanteSliderSkin { control: parent }
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    live: true
                    stepSize: 5
                    snapMode: QQC2.Slider.SnapAlways
                }

                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(percentSlider.value) + " %"
                    font: KanteStyle.active ? KanteStyle.monoFont(Kirigami.Theme.defaultFont.pointSize) : Kirigami.Theme.defaultFont
                }
            }

            FieldLabel { text: i18n("Priority") }
            PriorityPicker {
                id: priorityPicker
                Layout.fillWidth: true
                showLabel: false
            }

            FieldLabel { text: i18n("Labels") }
            LabelPicker {
                id: labelPicker
                Layout.fillWidth: true
                availableLabels: controller.availableLabels
            }

            FieldLabel { text: i18n("Secrecy") }
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.ButtonGroup {
                    id: secrecyGroup
                }

                Repeater {
                    model: [
                        { label: i18n("Public"), value: 0 },
                        { label: i18n("Private"), value: 1 },
                        { label: i18n("Confidential"), value: 2 }
                    ]
                    delegate: QQC2.RadioButton {
                        KanteCheckSkin { control: parent; shape: KanteCheckSkin.Shape.Radio }
                        required property var modelData
                        text: modelData.label
                        checked: root.secrecyValue === modelData.value
                        QQC2.ButtonGroup.group: secrecyGroup
                        onClicked: root.secrecyValue = modelData.value
                    }
                }
            }

            FieldLabel { text: i18n("Location") }
            LocationPicker {
                id: locationPicker
                Layout.fillWidth: true
                availableLocations: controller.availableLocations
                boundsItem: root.popupAnchor
            }

            KanteButton {
                visible: !!(task.geoUrl && String(task.geoUrl).length > 0)
                Layout.fillWidth: true
                icon.name: "internet-services"
                text: i18n("Open map")
                onClicked: Qt.openUrlExternally(task.geoUrl)
            }

            FieldLabel {
                visible: !!(task.attendees && task.attendees.length > 0)
                text: i18n("Assignees")
            }
            QQC2.Label {
                visible: !!(task.attendees && task.attendees.length > 0)
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: (task.attendees || []).join(", ")
                opacity: 0.85
            }

            FieldLabel { text: i18n("Section") }
            KanteTextField {
                id: sectionField
                Layout.fillWidth: true
                placeholderText: i18n("Day section (morning / afternoon / …)")
                QQC2.ToolTip.text: i18n("Stores KURRENT/LIST for Today-view day sections (Morning, Afternoon, Evening). Also used as the Kanban “Day section” column source.")
                QQC2.ToolTip.visible: hovered
            }

            FieldLabel { text: i18n("Project") }
            ProjectPicker {
                id: projectPicker
                Layout.fillWidth: true
            }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: editorBody.footerPad
            Layout.rightMargin: editorBody.footerPad
            Layout.topMargin: editorBody.footerPad
            Layout.bottomMargin: editorBody.footerPad
            spacing: Design.spaceSmall

            KanteButton {
                id: deleteButton
                visible: !!(task && task.itemId > 0)
                text: i18n("Delete task")
                icon.name: "edit-delete"
                onClicked: {
                    if (task && task.itemId) {
                        controller.deleteTask(task.itemId)
                    }
                    root.close()
                }
            }

            Item { Layout.fillWidth: true }

            KanteButton {
                id: saveButton
                text: i18n("Save")
                icon.name: "document-save"
                highlighted: true
                onClicked: root.accept()
            }

            KanteButton {
                id: cancelButton
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                onClicked: root.reject()
            }
        }
        }
    }
}
