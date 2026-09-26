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
// closes itself when the task disappears. Actions: complete, tomorrow, +1 week, full editor.
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

    onHasTaskChanged: {
        if (!hasTask && itemId >= 0) {
            closeRequested()
        }
    }

    function formatDue(d) {
        if (!d || isNaN(d)) {
            return i18n("No due date")
        }
        var fmt = task.allDay ? Qt.locale().dateFormat(Locale.LongFormat)
                              : Qt.locale().dateTimeFormat(Locale.ShortFormat)
        return task.allDay ? Qt.locale().toString(d, fmt) : Qt.locale().toString(d, fmt)
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
            level: 2
            text: inspector.hasTask ? (inspector.task.summary || i18n("(Untitled)")) : ""
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.strikeout: inspector.hasTask && inspector.task.completed === true
            color: KanteStyle.strongTextColor
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
                              tone: inspector.overdue ? KanteStyle.negativeTextColor : KanteStyle.textColor },
                            { k: i18n("Priority"), v: inspector.priorityText(inspector.task.priority),
                              tone: inspector.task.priority > 0 ? Design.priorityColor(inspector.task.priority) : KanteStyle.mutedTextColor },
                            { k: i18n("Project"), v: inspector.task.collectionName || "", tone: KanteStyle.textColor },
                            { k: i18n("Labels"), v: (inspector.task.categories || []).map(function(c) { return "#" + c }).join("  ") || "–",
                              tone: KanteStyle.textColor },
                            { k: i18n("Reminder"), v: inspector.reminderText(inspector.task.reminderMinutes), tone: KanteStyle.textColor },
                            { k: i18n("Progress"), v: (inspector.task.percentComplete || 0) + " %", tone: KanteStyle.textColor },
                            { k: i18n("Secrecy"), v: inspector.secrecyText(inspector.task.secrecy), tone: KanteStyle.mutedTextColor },
                            { k: i18n("Location"), v: inspector.task.location || "–", tone: KanteStyle.textColor }
                        ] : []

                        delegate: Item {
                            required property var modelData
                            required property int index
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            implicitHeight: propRow.implicitHeight

                            RowLayout {
                                id: propRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: Design.spaceMedium

                                QQC2.Label {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                                    Layout.alignment: Qt.AlignTop
                                    text: modelData.k
                                    elide: Text.ElideRight
                                    font: KanteStyle.active ? KanteStyle.labelFont() : Kirigami.Theme.smallFont
                                    color: KanteStyle.mutedTextColor
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData.v
                                    wrapMode: Text.Wrap
                                    color: modelData.tone
                                    font: KanteStyle.active && (index === 0 || index === 5)
                                          ? KanteStyle.monoFont(Kirigami.Theme.defaultFont.pointSize) : Kirigami.Theme.defaultFont
                                }
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

                // Notes
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: inspector.hasTask && !!inspector.task.description
                    spacing: Design.spaceTiny

                    QQC2.Label {
                        text: i18n("Description")
                        font: KanteStyle.active ? KanteStyle.labelFont() : Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Kirigami.Theme.smallFont.pointSize, bold: true })
                        color: KanteStyle.mutedTextColor
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: inspector.hasTask ? (inspector.task.description || "") : ""
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        color: KanteStyle.textColor
                    }
                }
            }
        }

        // Quick actions
        Flow {
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            KanteButton {
                icon.name: "checkmark"
                text: inspector.hasTask && inspector.task.completed ? i18n("Reopen") : i18n("Done")
                highlighted: true
                emphasis: KanteButton.Emphasis.Primary
                onClicked: inspector.controller.setTaskCompleted(inspector.itemId, !(inspector.task.completed === true))
            }
            KanteButton {
                text: i18n("Tomorrow")
                onClicked: inspector.controller.rescheduleTask(inspector.itemId, "tomorrow")
            }
            KanteButton {
                text: i18n("Next week")
                onClicked: inspector.controller.rescheduleTask(inspector.itemId, "next-week")
            }
            KanteButton {
                icon.name: "document-edit"
                text: i18n("Editor")
                onClicked: inspector.requestFullEditor(inspector.task)
            }
        }
    }
}
