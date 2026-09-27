import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../colors.js" as Colors
import "../components"
import ".."
import "../Kante"

// Direction B: details of the clicked task beside the task pane (wide layout).
// Reads the task live from the backend (taskSnapshotById), so edits made elsewhere show up;
// closes itself when the task disappears. Actions: complete, tomorrow, +1 week, inline edit
// (title, description, location in place), full editor. Values with a picker (due, priority,
// project, status, progress, secrecy) open a menu on click.
// Plasma: card with a hairline frame. Kante / Kante Light: KanteCard, priority bar on top.
Item {
    id: inspector

    required property var controller
    property var itemId: -1

    signal requestFullEditor(var task)
    signal closeRequested()

    // Re-read whenever the backend rebuilds (viewTaskCounts changes with every rebuild).
    readonly property var task: {
        var _rebuild = controller ? controller.viewTaskCounts : null
        return controller && itemId >= 0 ? controller.taskSnapshotById(itemId) : ({})
    }
    readonly property bool hasTask: task && task.itemId !== undefined
    readonly property var subtasks: {
        var _rebuild = controller ? controller.viewTaskCounts : null
        return hasTask && controller ? controller.childTasks(task.uid) : []
    }
    readonly property int subtasksDone: {
        var n = 0
        for (var i = 0; i < subtasks.length; ++i) {
            if (subtasks[i].completed) {
                n++
            }
        }
        return n
    }
    readonly property color priorityTone: hasTask && task.priority > 0 ? Design.priorityColor(task.priority) : KanteStyle.accentColor
    readonly property bool overdue: hasTask && !task.completed && task.dueDate && task.dueDate < new Date()

    // Inline editor: title, description and location become fields until saved or cancelled.
    property bool editing: false
    onItemIdChanged: editing = false

    onHasTaskChanged: {
        if (!hasTask && itemId >= 0) {
            closeRequested()
        }
    }

    function startEditing() {
        titleField.text = task.summary || ""
        descriptionField.text = task.description || ""
        locationField.text = task.location || ""
        editing = true
        titleField.forceActiveFocus()
    }

    function saveEditing() {
        controller.updateTaskFull(itemId, {
            summary: titleField.text,
            description: descriptionField.text,
            location: locationField.text
        })
        editing = false
    }

    function update(fields) {
        controller.updateTaskFull(itemId, fields)
    }

    // "today", "tomorrow", "in 3 days", "2 days ago" relative to the local day.
    function relativeDay(d) {
        if (!d || isNaN(d)) {
            return ""
        }
        var now = new Date()
        var a = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var b = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        var n = Math.round((b - a) / 86400000)
        if (n === 0) return i18n("today")
        if (n === 1) return i18n("tomorrow")
        if (n === -1) return i18n("yesterday")
        return n > 0 ? i18np("in %1 day", "in %1 days", n) : i18np("%1 day ago", "%1 days ago", -n)
    }

    // Short date ("Wed, 30 Sep"), plus the time for timed tasks.
    function formatDue(d) {
        if (!d || isNaN(d)) {
            return i18n("No due date")
        }
        var day = Qt.locale().toString(d, "ddd, d. MMM")
        return task.allDay ? day : day + ", " + Qt.locale().toString(d, Qt.locale().timeFormat(Locale.ShortFormat))
    }

    function priorityText(p) {
        switch (Colors.priorityLabel(p)) {
        case "high": return i18n("High")
        case "medium": return i18n("Medium")
        case "low": return i18n("Low")
        default: return i18n("None")
        }
    }

    function statusText(s) {
        switch (Number(s)) {
        case 4: return i18n("Needs action")
        case 6: return i18n("In process")
        case 3: return i18n("Completed")
        case 5: return i18n("Canceled")
        default: return ""
        }
    }

    function secrecyText(s) {
        switch (Number(s)) {
        case 1: return i18n("Private")
        case 2: return i18n("Confidential")
        default: return i18n("Public")
        }
    }

    function reminderText(m) {
        if (m === undefined || m < 0) {
            return i18n("Off")
        }
        if (m === 0) {
            return i18n("At due time")
        }
        if (m % 1440 === 0) {
            return i18np("%1 day before", "%1 days before", m / 1440)
        }
        if (m % 60 === 0) {
            return i18np("%1 hour before", "%1 hours before", m / 60)
        }
        return i18np("%1 minute before", "%1 minutes before", m)
    }

    readonly property font labelFont: KanteStyle.active ? KanteStyle.labelFont() : Kirigami.Theme.smallFont

    // Widest property label; its width sizes the label column.
    Column {
        id: labelProbe
        visible: false
        Repeater {
            model: [i18n("Due"), i18n("Priority"), i18n("Project"), i18n("Labels"), i18n("Status"),
                    i18n("Reminder"), i18n("Progress"), i18n("Secrecy"), i18n("Location")]
            QQC2.Label {
                required property string modelData
                text: modelData
                font: inspector.labelFont
            }
        }
    }

    // ── Value pickers (i5) ──────────────────────────────────────────
    QQC2.Menu {
        id: dueMenu
        KantePopupSkin { popup: dueMenu }
        QQC2.MenuItem { text: i18n("Today"); onTriggered: inspector.controller.rescheduleTask(inspector.itemId, "today") }
        QQC2.MenuItem { text: i18n("Tomorrow"); onTriggered: inspector.controller.rescheduleTask(inspector.itemId, "tomorrow") }
        QQC2.MenuItem { text: i18n("Next week"); onTriggered: inspector.controller.rescheduleTask(inspector.itemId, "next-week") }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("No due date"); onTriggered: inspector.update({ clearDue: true }) }
        QQC2.MenuItem { text: i18n("Open full editor"); onTriggered: inspector.requestFullEditor(inspector.task) }
    }

    QQC2.Menu {
        id: priorityMenu
        KantePopupSkin { popup: priorityMenu }
        Instantiator {
            model: [{ p: 1, t: i18n("High") }, { p: 5, t: i18n("Medium") }, { p: 9, t: i18n("Low") }, { p: 0, t: i18n("None") }]
            delegate: QQC2.MenuItem {
                required property var modelData
                text: modelData.t
                icon.name: modelData.p > 0 ? "flag" : ""
                icon.color: modelData.p > 0 ? Design.priorityColor(modelData.p) : "transparent"
                checkable: true
                checked: Colors.normalizePriority(inspector.task.priority) === modelData.p
                onTriggered: inspector.controller.setTaskPriority(inspector.itemId, modelData.p)
            }
            onObjectAdded: (index, object) => priorityMenu.insertItem(index, object)
        }
    }

    QQC2.Menu {
        id: projectMenu
        KantePopupSkin { popup: projectMenu }
        Instantiator {
            model: inspector.controller ? inspector.controller.collectionModel : null
            delegate: QQC2.MenuItem {
                required property var model
                visible: model.enabled && model.writable
                height: visible ? implicitHeight : 0
                text: model.name
                checkable: true
                checked: inspector.task.collectionId === model.collectionId
                onTriggered: inspector.controller.moveTaskToCollection(inspector.itemId, model.collectionId)
            }
            onObjectAdded: (index, object) => projectMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => projectMenu.removeItem(object)
        }
    }

    QQC2.Menu {
        id: statusMenu
        KantePopupSkin { popup: statusMenu }
        Instantiator {
            model: [4, 6, 3, 5]
            delegate: QQC2.MenuItem {
                required property int modelData
                text: inspector.statusText(modelData)
                checkable: true
                checked: Number(inspector.task.status) === modelData
                onTriggered: inspector.update({ status: modelData })
            }
            onObjectAdded: (index, object) => statusMenu.insertItem(index, object)
        }
    }

    QQC2.Menu {
        id: progressMenu
        KantePopupSkin { popup: progressMenu }
        Instantiator {
            model: [0, 25, 50, 75, 100]
            delegate: QQC2.MenuItem {
                required property int modelData
                text: modelData + " %"
                checkable: true
                checked: (inspector.task.percentComplete || 0) === modelData
                onTriggered: inspector.update({ percentComplete: modelData })
            }
            onObjectAdded: (index, object) => progressMenu.insertItem(index, object)
        }
    }

    QQC2.Menu {
        id: secrecyMenu
        KantePopupSkin { popup: secrecyMenu }
        Instantiator {
            model: [0, 1, 2]
            delegate: QQC2.MenuItem {
                required property int modelData
                text: inspector.secrecyText(modelData)
                checkable: true
                checked: Number(inspector.task.secrecy || 0) === modelData
                onTriggered: inspector.update({ secrecy: modelData })
            }
            onObjectAdded: (index, object) => secrecyMenu.insertItem(index, object)
        }
    }

    // ── Surface ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: !KanteStyle.active
        radius: Kirigami.Units.cornerRadius
        color: KanteStyle.tint(Kirigami.Theme.textColor, 0.04)
        border.width: 1
        border.color: KanteStyle.frameColor

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: parent.radius
            anchors.rightMargin: parent.radius
            height: 3
            radius: 1.5
            color: inspector.priorityTone
        }
    }

    KanteCard {
        anchors.fill: parent
        visible: KanteStyle.active
        color: KanteStyle.cardColor
        barColor: inspector.priorityTone
    }

    // ── Content ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Design.spaceMedium
        anchors.topMargin: Design.spaceMedium + 3
        visible: inspector.hasTask
        spacing: Design.spaceSmall

        // Breadcrumb (project · labels), status, close.
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            QQC2.Label {
                Layout.fillWidth: true
                text: inspector.hasTask
                      ? [inspector.task.collectionName || ""].concat(inspector.task.categories || []).filter(function(x) { return x.length > 0 }).join(" / ")
                      : ""
                elide: Text.ElideRight
                font: KanteStyle.active ? KanteStyle.labelFont() : Kirigami.Theme.smallFont
                color: KanteStyle.mutedTextColor
            }

            Rectangle {
                visible: statusChipText.text.length > 0
                implicitWidth: statusChipText.implicitWidth + Design.spaceSmall * 2
                implicitHeight: statusChipText.implicitHeight + 2
                radius: KanteStyle.themed ? 0 : height / 2
                color: "transparent"
                border.width: 1
                border.color: Number(inspector.task.status) === 6 ? KanteStyle.accentColor : KanteStyle.frameColor

                QQC2.Label {
                    id: statusChipText
                    anchors.centerIn: parent
                    text: inspector.hasTask ? inspector.statusText(inspector.task.status) : ""
                    font: KanteStyle.active ? KanteStyle.labelFont() : Kirigami.Theme.smallFont
                    color: Number(inspector.task.status) === 6 ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
                }
            }

            KanteToolButton {
                icon.name: "window-close"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Close inspector")
                onClicked: inspector.closeRequested()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
        }

        Kirigami.Heading {
            Layout.fillWidth: true
            visible: !inspector.editing
            level: 2
            text: inspector.hasTask ? (inspector.task.summary || i18n("(Untitled)")) : ""
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.strikeout: inspector.hasTask && inspector.task.completed === true
            color: KanteStyle.strongTextColor
        }

        QQC2.TextField {
            id: titleField
            Layout.fillWidth: true
            visible: inspector.editing
            placeholderText: i18n("Title")
            KanteFieldSkin { control: titleField }
            onAccepted: inspector.saveEditing()
            Keys.onEscapePressed: inspector.editing = false
        }

        QQC2.ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroller.availableWidth
                spacing: Design.spaceMedium

                // Properties
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Design.spaceMedium
                    rowSpacing: Design.spaceSmall

                    Repeater {
                        model: inspector.hasTask ? [
                            { k: i18n("Due"), v: inspector.formatDue(inspector.task.dueDate),
                              sub: inspector.relativeDay(inspector.task.dueDate), menu: dueMenu, mono: true,
                              tone: inspector.overdue ? KanteStyle.negativeTextColor : KanteStyle.textColor },
                            { k: i18n("Priority"), v: inspector.priorityText(inspector.task.priority), menu: priorityMenu,
                              icon: inspector.task.priority > 0 ? "flag" : "",
                              iconColor: inspector.task.priority > 0 ? Design.priorityColor(inspector.task.priority) : "transparent",
                              tone: inspector.task.priority > 0 ? KanteStyle.textColor : KanteStyle.mutedTextColor },
                            { k: i18n("Project"), v: inspector.task.collectionName || "", menu: projectMenu, tone: KanteStyle.textColor },
                            { k: i18n("Labels"), v: (inspector.task.categories || []).map(function(c) { return "#" + c }).join("  ") || "–",
                              tone: KanteStyle.textColor },
                            { k: i18n("Status"), v: inspector.statusText(inspector.task.status) || "–", menu: statusMenu,
                              tone: KanteStyle.textColor },
                            { k: i18n("Reminder"), v: inspector.reminderText(inspector.task.reminderMinutes), tone: KanteStyle.textColor },
                            { k: i18n("Progress"), v: (inspector.task.percentComplete || 0) + " %", menu: progressMenu, mono: true,
                              tone: KanteStyle.textColor },
                            { k: i18n("Secrecy"), v: inspector.secrecyText(inspector.task.secrecy), menu: secrecyMenu,
                              tone: KanteStyle.mutedTextColor },
                            { k: i18n("Location"), v: inspector.task.location || "–", tone: KanteStyle.textColor,
                              hidden: inspector.editing }
                        ] : []

                        delegate: Item {
                            id: propItem
                            required property var modelData
                            required property int index
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            visible: !modelData.hidden
                            implicitHeight: propRow.implicitHeight + 4

                            // Hover tint marks values that open a picker.
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: labelProbe.width + Design.spaceMedium - 4
                                radius: KanteStyle.active ? 0 : Kirigami.Units.cornerRadius
                                visible: !!propItem.modelData.menu && propHover.hovered
                                color: KanteStyle.tint(Kirigami.Theme.textColor, 0.07)
                            }

                            RowLayout {
                                id: propRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Design.spaceMedium

                                // Label column as wide as its widest label (i1).
                                QQC2.Label {
                                    Layout.preferredWidth: labelProbe.width
                                    Layout.alignment: Qt.AlignTop
                                    text: propItem.modelData.k
                                    font: inspector.labelFont
                                    color: KanteStyle.mutedTextColor
                                }
                                Kirigami.Icon {
                                    visible: !!propItem.modelData.icon
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 2
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    source: propItem.modelData.icon || ""
                                    color: propItem.modelData.iconColor || Kirigami.Theme.textColor
                                    isMask: true
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    QQC2.Label {
                                        Layout.fillWidth: true
                                        text: propItem.modelData.v
                                        wrapMode: Text.Wrap
                                        color: propItem.modelData.tone
                                        font: KanteStyle.active && propItem.modelData.mono
                                              ? KanteStyle.monoFont(Kirigami.Theme.defaultFont.pointSize) : Kirigami.Theme.defaultFont
                                    }
                                    QQC2.Label {
                                        Layout.fillWidth: true
                                        visible: !!propItem.modelData.sub
                                        text: propItem.modelData.sub || ""
                                        font: Kirigami.Theme.smallFont
                                        color: propItem.modelData.tone === KanteStyle.negativeTextColor
                                               ? KanteStyle.negativeTextColor : KanteStyle.mutedTextColor
                                    }
                                }
                            }

                            HoverHandler {
                                id: propHover
                                enabled: !!propItem.modelData.menu
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                enabled: !!propItem.modelData.menu
                                onTapped: propItem.modelData.menu.popup(propItem, labelProbe.width + Design.spaceMedium, propItem.height)
                            }
                        }
                    }
                }

                // Subtasks with a segmented progress bar
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: inspector.subtasks.length > 0
                    spacing: Design.spaceTiny

                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.Label {
                            text: i18n("Subtasks")
                            font: KanteStyle.active ? KanteStyle.labelFont() : Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Kirigami.Theme.smallFont.pointSize, bold: true })
                            color: KanteStyle.mutedTextColor
                        }
                        QQC2.Label {
                            text: inspector.subtasksDone + " / " + inspector.subtasks.length
                            font: KanteStyle.active ? KanteStyle.monoFont(Kirigami.Theme.smallFont.pointSize) : Kirigami.Theme.smallFont
                            color: KanteStyle.mutedTextColor
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            model: inspector.subtasks.length
                            Rectangle {
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                radius: KanteStyle.themed ? 0 : 2
                                color: index < inspector.subtasksDone ? KanteStyle.positiveTextColor : KanteStyle.frameColor
                            }
                        }
                    }

                    Repeater {
                        model: inspector.subtasks
                        delegate: QQC2.CheckBox {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.summary || i18n("(Untitled)")
                            checked: modelData.completed === true
                            onToggled: inspector.controller.setTaskCompleted(modelData.itemId, checked)
                            KanteCheckSkin { control: parent }
                        }
                    }
                }

                // Notes; in the inline editor also the location.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: inspector.editing || (inspector.hasTask && !!inspector.task.description)
                    spacing: Design.spaceTiny

                    QQC2.Label {
                        text: i18n("Description")
                        font: KanteStyle.active ? KanteStyle.labelFont() : Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Kirigami.Theme.smallFont.pointSize, bold: true })
                        color: KanteStyle.mutedTextColor
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: !inspector.editing
                        text: inspector.hasTask ? (inspector.task.description || "") : ""
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        color: KanteStyle.textColor
                    }
                    QQC2.TextArea {
                        id: descriptionField
                        Layout.fillWidth: true
                        Layout.minimumHeight: Kirigami.Units.gridUnit * 5
                        visible: inspector.editing
                        wrapMode: TextEdit.Wrap
                        placeholderText: i18n("Description")
                        KanteFieldSkin { control: descriptionField }
                    }

                    QQC2.Label {
                        visible: inspector.editing
                        Layout.topMargin: Design.spaceSmall
                        text: i18n("Location")
                        font: KanteStyle.active ? KanteStyle.labelFont() : Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Kirigami.Theme.smallFont.pointSize, bold: true })
                        color: KanteStyle.mutedTextColor
                    }
                    QQC2.TextField {
                        id: locationField
                        Layout.fillWidth: true
                        visible: inspector.editing
                        placeholderText: i18n("Location")
                        KanteFieldSkin { control: locationField }
                        onAccepted: inspector.saveEditing()
                    }
                }
            }
        }

        // Actions: "Done" as the main button, the rest as icon buttons (i4). Inline editor:
        // Save / Cancel instead.
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            KanteButton {
                visible: !inspector.editing
                icon.name: "checkmark"
                text: inspector.hasTask && inspector.task.completed ? i18n("Reopen") : i18n("Done")
                highlighted: true
                emphasis: KanteButton.Emphasis.Primary
                onClicked: inspector.controller.setTaskCompleted(inspector.itemId, !(inspector.task.completed === true))
            }

            Item { Layout.fillWidth: true; visible: !inspector.editing }

            Repeater {
                model: inspector.editing ? [] : [
                    { icon: "go-next", text: i18n("Tomorrow"), act: function() { inspector.controller.rescheduleTask(inspector.itemId, "tomorrow") } },
                    { icon: "view-calendar-week", text: i18n("Next week"), act: function() { inspector.controller.rescheduleTask(inspector.itemId, "next-week") } },
                    { icon: "edit-rename", text: i18n("Edit here"), act: function() { inspector.startEditing() } },
                    { icon: "document-edit", text: i18n("Open full editor"), act: function() { inspector.requestFullEditor(inspector.task) } }
                ]
                delegate: KanteToolButton {
                    required property var modelData
                    icon.name: modelData.icon
                    display: QQC2.AbstractButton.IconOnly
                    text: modelData.text
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    onClicked: modelData.act()
                }
            }

            KanteButton {
                visible: inspector.editing
                icon.name: "document-save"
                text: i18n("Save")
                highlighted: true
                emphasis: KanteButton.Emphasis.Primary
                onClicked: inspector.saveEditing()
            }
            KanteButton {
                visible: inspector.editing
                text: i18n("Cancel")
                onClicked: inspector.editing = false
            }
        }
    }
}
