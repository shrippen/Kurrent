import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "../colors.js" as Colors
import "../datetime.js" as DateTime
import ".."
import "."

Item {
    id: root

    required property var controller
    property var task: ({})
    property Item popupParent: null

    signal saved
    signal cancelled
    signal openFullEditor

    readonly property int innerPad: Design.padInner
    // Natural height of the editor contents; animated height opens/closes via openReveal.
    readonly property real naturalHeight: editorColumn.implicitHeight + innerPad * 2
    implicitHeight: naturalHeight
    height: Math.max(0, Math.round(naturalHeight * openReveal))
    clip: true
    opacity: 0.35 + 0.65 * openReveal

    // 0 → 1 unfold when opening; reduced motion snaps to 1.
    property real openReveal: 1
    Behavior on openReveal {
        enabled: !Design.reducedMotion
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    property bool clearDueRequested: false

    Component.onCompleted: loadFromTask()
    onVisibleChanged: {
        if (visible) {
            loadFromTask()
        }
    }

    function loadFromTask() {
        summaryField.text = task.summary || ""
        descriptionField.text = task.description || ""
        allDayCheck.checked = task.allDay === true
        dueDateField.text = DateTime.formatDate(task.dueDate)
        dueTimeField.text = DateTime.formatTime(task.dueDate)
        priorityPicker.priority = Colors.normalizePriority(task.priority || 0)
        labelPicker.selectedLabels = (task.categories || []).slice()
        clearDueRequested = false
    }

    function save() {
        var due = null
        var clearDue = clearDueRequested || dueDateField.text.trim().length === 0
        if (!clearDue) {
            due = DateTime.combineDateTime(dueDateField.text, dueTimeField.text, allDayCheck.checked)
            if (!due) {
                return
            }
        }

        var fields = {
            "summary": summaryField.text,
            "description": descriptionField.text,
            "priority": Colors.normalizePriority(priorityPicker.priority),
            "categories": labelPicker.selectedLabels.slice(),
            "allDay": allDayCheck.checked,
            "clearDue": clearDue
        }
        if (!clearDue && due) {
            fields.dueDate = due
        }
        controller.updateTaskFull(task.itemId, fields)
        root.saved()
    }

    Rectangle {
        anchors.fill: parent
        radius: Design.inputRadius
        color: Kirigami.Theme.highlightColor
        opacity: 0.12
    }

    ColumnLayout {
        id: editorColumn
        x: root.innerPad
        y: root.innerPad
        width: Math.max(0, root.width - root.innerPad * 2)
        spacing: Design.spaceSmall

        QQC2.TextField {
            id: summaryField
            Layout.fillWidth: true
            placeholderText: i18n("Title")
            Keys.onReturnPressed: root.save()
            Keys.onEnterPressed: root.save()
            Keys.onEscapePressed: root.cancelled()
        }

        ScrollableTextArea {
            id: descriptionField
            Layout.fillWidth: true
            preferredLines: 3
            placeholderText: i18n("Description")
            onEscapePressed: root.cancelled()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            QQC2.Label {
                text: i18n("Due")
                opacity: 0.8
            }

            DateTimeInput {
                id: dueDateField
                Layout.fillWidth: true
                mode: "date"
                popupParent: root.popupParent
                onTextEdited: root.clearDueRequested = false
            }

            DateTimeInput {
                id: dueTimeField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                mode: "time"
                enabled: !allDayCheck.checked
                onTextEdited: root.clearDueRequested = false
            }

            QQC2.CheckBox {
                id: allDayCheck
                text: i18n("All day")
            }

            QQC2.ToolButton {
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

        PriorityPicker {
            id: priorityPicker
            Layout.fillWidth: true
            showLabel: true
        }

        LabelPicker {
            id: labelPicker
            Layout.fillWidth: true
            availableLabels: controller.availableLabels
        }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("More…")
                flat: true
                onClicked: root.openFullEditor()
            }

            Item { Layout.fillWidth: true }

            QQC2.Button {
                text: i18n("Save")
                icon.name: "document-save"
                highlighted: true
                onClicked: root.save()
            }

            QQC2.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                onClicked: root.cancelled()
            }
        }
    }
}
