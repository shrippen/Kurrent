import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "../colors.js" as Colors
import ".."

Item {
    id: root

    required property var controller
    required property var model
    required property int index

    property var task: model
    property bool expanded: false
    property bool deleteModeEnabled: false
    property real editorReserveHeight: 0
    property Item dragHost: null
    property var taskListRoot: null

    signal requestExpand(var itemId)
    signal requestCollapse
    signal requestOpenFullEditor(var task)
    signal requestDelete(var itemId)

    readonly property int labelIconSize: Kirigami.Units.iconSizes.small
    readonly property int pad: Design.taskRowPad
    readonly property bool listMoving: ListView.view && (ListView.view.moving || ListView.view.flicking)
    readonly property bool isDragSource: !!(dragHost && dragHost.draggingTask
                                            && dragHost.draggingTask.itemId === task.itemId)
    readonly property bool dropHighlight: taskDrop.containsDrag && !isDragSource

    readonly property var visibleCategories: {
        var cats = task.categories || []
        var selected = controller.selectedLabel || ""
        if (!selected) {
            return cats
        }
        var out = []
        for (var i = 0; i < cats.length; ++i) {
            if (cats[i] !== selected) {
                out.push(cats[i])
            }
        }
        return out
    }

    function taskSnapshot() {
        return {
            "itemId": task.itemId,
            "uid": task.uid,
            "parentUid": task.parentUid || "",
            "summary": task.summary,
            "description": task.description,
            "dueDate": task.dueDate,
            "startDate": task.startDate,
            "priority": task.priority,
            "completed": task.completed,
            "recurring": task.recurring,
            "allDay": task.allDay,
            "percentComplete": task.percentComplete,
            "location": task.location,
            "status": task.status,
            "secrecy": task.secrecy,
            "recurrencePreset": task.recurrencePreset,
            "joinUrl": task.joinUrl || "",
            "categories": task.categories,
            "collectionId": task.collectionId,
            "collectionName": task.collectionName,
            "indentLevel": task.indentLevel,
            "hasChildren": task.hasChildren,
            "section": task.section
        }
    }

    // ListView sizes the delegate from implicitHeight. Do not also bind height
    // to that value (height ↔ implicitHeight loop).
    implicitHeight: contentColumn.implicitHeight + pad * 2
            + (expanded && editorReserveHeight > 0 ? pad + editorReserveHeight : 0)
    readonly property bool awaitingAkonadi: task.syncing === true || task.pendingDelete === true
    opacity: isDragSource ? 0.45 : (task.pendingDelete ? 0.4 : (task.syncing ? 0.7 : 1.0))

    readonly property real collapsedHeight: pad + contentLayout.implicitHeight
            + (expanded && editorReserveHeight > 0 ? pad : 0)

    // Invisible guide spanning checkbox left → edit-button right (layout-accurate).
    // Must not use anchors to nested layout children (not siblings of this item).
    Item {
        id: editorGuide
        height: 1
        y: -1000
        visible: false
        width: 1
    }

    function syncEditorGuide() {
        if (!completedCheck || !editButton) {
            return
        }
        var left = completedCheck.mapToItem(root, 0, 0)
        var right = editButton.mapToItem(root, editButton.width, 0)
        editorGuide.x = left.x
        editorGuide.width = Math.max(1, right.x - left.x)
    }

    readonly property real editorContentX: editorGuide.x
    readonly property real editorContentWidth: editorGuide.width
    readonly property Item editorGuideItem: editorGuide

    Connections {
        target: contentLayout
        function onWidthChanged() { root.syncEditorGuide() }
        function onHeightChanged() { root.syncEditorGuide() }
    }
    Connections {
        target: completedCheck
        function onXChanged() { root.syncEditorGuide() }
        function onWidthChanged() { root.syncEditorGuide() }
    }
    Connections {
        target: editButton
        function onXChanged() { root.syncEditorGuide() }
        function onWidthChanged() { root.syncEditorGuide() }
    }
    Component.onCompleted: Qt.callLater(root.syncEditorGuide)
    onWidthChanged: Qt.callLater(root.syncEditorGuide)

    // Cheap hover; disabled while scrolling so rows sliding under the cursor
    // don't spam hover enter/leave.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.expanded ? Math.round(root.collapsedHeight) : parent.height
        radius: 3
        color: dropHighlight ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
        opacity: dropHighlight ? 0.22 : ((root.expanded || (!root.listMoving && hoverHandler.hovered && !Design.reducedMotion)) ? 0.12 : 0)
        visible: opacity > 0
        z: 0
    }

    HoverHandler {
        id: hoverHandler
        enabled: !root.listMoving
    }

    DragHandler {
        id: taskDrag
        target: null
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
        enabled: !root.awaitingAkonadi
        // Let a click still expand the row; only a real drag starts DND.
        dragThreshold: Math.round(Kirigami.Units.gridUnit * 0.6)
        grabPermissions: PointerHandler.CanTakeOverFromItems
                | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                | PointerHandler.ApprovesTakeOverByAnything

        onActiveChanged: {
            if (!root.dragHost || root.awaitingAkonadi) {
                return
            }
            if (active) {
                root.dragHost.beginTaskDrag({
                    "itemId": task.itemId,
                    "uid": task.uid,
                    "summary": task.summary || "",
                    "parentUid": task.parentUid || "",
                    "categories": task.categories || [],
                    "collectionId": task.collectionId,
                    "priority": task.priority
                })
                var c = centroid.position
                var g = root.mapToGlobal(c.x, c.y)
                root.dragHost.updateTaskDragPosition(g.x, g.y)
            } else {
                root.dragHost.endTaskDrag()
            }
        }

        onCentroidChanged: {
            if (!active || !root.dragHost) {
                return
            }
            var c = centroid.position
            var g = root.mapToGlobal(c.x, c.y)
            root.dragHost.updateTaskDragPosition(g.x, g.y)
        }
    }

    DropArea {
        id: taskDrop
        anchors.fill: parent
        keys: ["application/x-kurrent-task"]
        enabled: !root.isDragSource && !root.awaitingAkonadi

        readonly property string hintText: {
            var title = task.summary || i18n("(Untitled)")
            return i18n("Make subtask of “%1”", title)
        }

        onEntered: function(drag) {
            drag.acceptProposedAction()
            if (root.dragHost) {
                root.dragHost.setDropHint(hintText)
            }
        }
        onExited: {
            if (root.dragHost) {
                root.dragHost.clearDropHint(hintText)
            }
        }
        onDropped: function(drop) {
            if (!root.taskListRoot) {
                return
            }
            if (root.taskListRoot.acceptDropAsParent(task.uid)) {
                drop.acceptProposedAction()
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        // Left inset only — edit/delete button flush with the row's right edge.
        width: root.width - pad
        x: pad
        y: pad
        spacing: pad
        z: 1

        RowLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: pad

            Item {
                Layout.preferredWidth: (task.indentLevel || 0) * Kirigami.Units.gridUnit
            }

            QQC2.ToolButton {
                visible: task.hasChildren === true
                icon.name: task.treeCollapsed ? "arrow-right" : "arrow-down"
                display: QQC2.AbstractButton.IconOnly
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                enabled: !root.awaitingAkonadi
                onClicked: {
                    if (!task.treeCollapsed && root.taskListRoot) {
                        root.taskListRoot.preserveScrollForUid(task.uid)
                    }
                    controller.toggleTreeCollapsed(task.uid)
                }
                QQC2.ToolTip.text: task.treeCollapsed ? i18n("Expand subtasks") : i18n("Collapse subtasks")
                QQC2.ToolTip.visible: hovered && !root.listMoving
            }

            QQC2.CheckBox {
                id: completedCheck
                checked: task.completed === true
                enabled: !root.awaitingAkonadi
                onToggled: {
                    if (Plasmoid.configuration.completeNeedsModifier === true) {
                        var mods = Qt.keyboardModifiers()
                        if (!(mods & Qt.ShiftModifier) && !(mods & Qt.ControlModifier)) {
                            checked = task.completed === true
                            return
                        }
                    }
                    controller.setTaskCompleted(task.itemId, checked)
                }
            }

            QQC2.BusyIndicator {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                visible: root.awaitingAkonadi
                running: visible
                QQC2.ToolTip.text: i18n("Waiting for Akonadi…")
                QQC2.ToolTip.visible: hovered && visible
            }

            ColumnLayout {
                id: mainColumn
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing / 2

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        var action = Plasmoid.configuration.clickAction || "inline"
                        if (taskListRoot) {
                            taskListRoot.selectedItemId = task.itemId
                        }
                        if (tapCount >= 2) {
                            if (action === "full") {
                                root.requestExpand(task.itemId)
                            } else {
                                root.requestOpenFullEditor(root.taskSnapshot())
                            }
                            return
                        }
                        if (action === "full") {
                            root.requestOpenFullEditor(root.taskSnapshot())
                        } else if (action === "select") {
                            return
                        } else if (root.expanded) {
                            root.requestCollapse()
                        } else {
                            root.requestExpand(task.itemId)
                        }
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: rescheduleMenu.popup()
                }

                QQC2.Label {
                    id: titleLabel
                    Layout.fillWidth: true
                    text: task.summary || i18n("(Untitled)")
                    font.strikeout: task.completed === true
                    opacity: task.completed === true ? 0.65 : 1.0
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: (Plasmoid.configuration.descriptionPreviewLines || 0) > 0
                             && !!(task.description && String(task.description).trim().length)
                    text: task.description || ""
                    opacity: 0.7
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: Plasmoid.configuration.descriptionPreviewLines || 0
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                RowLayout {
                    id: statusRow
                    Layout.fillWidth: true
                    spacing: 2
                    visible: dateChip.visible || (Plasmoid.configuration.showLabelChips !== false && root.visibleCategories.length > 0)
                             || (Plasmoid.configuration.showPriorityChip !== false && task.priority > 0)
                             || (Plasmoid.configuration.showRecurringIcon !== false && task.recurring)
                             || (Plasmoid.configuration.showJoinButton !== false && task.joinUrl && task.joinUrl.length)

                    Rectangle {
                        id: dateChip
                        visible: Plasmoid.configuration.showDateChip !== false
                                 && task.dueDate !== undefined && task.dueDate !== null && task.dueDate.isValid === true
                        radius: 3
                        Layout.preferredHeight: dateChipLabel.implicitHeight + 2
                        Layout.preferredWidth: dateChipLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                        color: {
                            if (!visible) {
                                return "transparent"
                            }
                            var due = task.dueDate
                            var dueDay = Qt.formatDate(due, "yyyy-MM-dd")
                            var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
                            if (dueDay < today) {
                                return Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                                               Kirigami.Theme.negativeTextColor.g,
                                               Kirigami.Theme.negativeTextColor.b,
                                               0.22)
                            }
                            return Qt.rgba(Kirigami.Theme.highlightColor.r,
                                           Kirigami.Theme.highlightColor.g,
                                           Kirigami.Theme.highlightColor.b,
                                           dueDay === today ? 0.28 : 0.14)
                        }

                        QQC2.Label {
                            id: dateChipLabel
                            anchors.centerIn: parent
                            text: {
                                if (!dateChip.visible) {
                                    return ""
                                }
                                var due = task.dueDate
                                var dueDay = Qt.formatDate(due, "yyyy-MM-dd")
                                var todayDate = new Date()
                                var today = Qt.formatDate(todayDate, "yyyy-MM-dd")
                                var label = Qt.formatDate(due, Qt.DefaultLocaleShortDate)
                                if (Plasmoid.configuration.relativeDates === true) {
                                    if (dueDay === today) {
                                        label = i18n("Today")
                                    } else {
                                        var tomorrow = new Date(todayDate)
                                        tomorrow.setDate(tomorrow.getDate() + 1)
                                        var yesterday = new Date(todayDate)
                                        yesterday.setDate(yesterday.getDate() - 1)
                                        if (dueDay === Qt.formatDate(tomorrow, "yyyy-MM-dd")) {
                                            label = i18n("Tomorrow")
                                        } else if (dueDay === Qt.formatDate(yesterday, "yyyy-MM-dd")) {
                                            label = i18n("Yesterday")
                                        }
                                    }
                                }
                                if (Plasmoid.configuration.showTimeOnRow !== false && task.allDay !== true) {
                                    var timeText = Qt.formatTime(due, Qt.DefaultLocaleShortDate)
                                    if (timeText && timeText.length) {
                                        label += " " + timeText
                                    }
                                }
                                return label
                            }
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: {
                                if (!dateChip.visible) {
                                    return Kirigami.Theme.textColor
                                }
                                var dueDay = Qt.formatDate(task.dueDate, "yyyy-MM-dd")
                                var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
                                if (dueDay < today) {
                                    return Kirigami.Theme.negativeTextColor
                                }
                                return Kirigami.Theme.textColor
                            }
                        }
                    }

                    Repeater {
                        model: Plasmoid.configuration.showLabelChips !== false ? root.visibleCategories : []
                        delegate: Kirigami.Icon {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: root.labelIconSize
                            Layout.preferredHeight: root.labelIconSize
                            source: "tag"
                            color: Design.colorForKey(String(modelData), "label")
                            width: root.labelIconSize
                            height: root.labelIconSize

                            QQC2.ToolTip.text: modelData
                            QQC2.ToolTip.visible: tagHover.hovered && !root.listMoving
                            QQC2.ToolTip.delay: 400

                            HoverHandler {
                                id: tagHover
                                enabled: !root.listMoving
                            }
                        }
                    }

                    Kirigami.Icon {
                        visible: Plasmoid.configuration.showPriorityChip !== false && task.priority > 0
                        source: "flag"
                        color: Colors.colorForPriority(task.priority)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.labelIconSize
                        Layout.preferredHeight: root.labelIconSize
                        width: root.labelIconSize
                        height: root.labelIconSize

                        QQC2.ToolTip.text: {
                            var band = Colors.priorityLabel(task.priority)
                            if (band === "high") {
                                return i18n("High priority (%1)", task.priority)
                            }
                            if (band === "medium") {
                                return i18n("Medium priority (%1)", task.priority)
                            }
                            if (band === "low") {
                                return i18n("Low priority (%1)", task.priority)
                            }
                            return i18n("Priority %1", task.priority)
                        }
                        QQC2.ToolTip.visible: priorityHover.hovered && !root.listMoving
                        QQC2.ToolTip.delay: 400

                        HoverHandler {
                            id: priorityHover
                            enabled: !root.listMoving
                        }
                    }

                    Kirigami.Icon {
                        visible: Plasmoid.configuration.showRecurringIcon !== false && task.recurring === true
                        source: "media-playlist-repeat"
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.labelIconSize
                        Layout.preferredHeight: root.labelIconSize
                        width: root.labelIconSize
                        height: root.labelIconSize
                        QQC2.ToolTip.text: i18n("Recurring")
                        QQC2.ToolTip.visible: recurHover.hovered && !root.listMoving
                        HoverHandler {
                            id: recurHover
                            enabled: !root.listMoving
                        }
                    }

                    Item { Layout.fillWidth: true }

                    QQC2.ToolButton {
                        visible: Plasmoid.configuration.showJoinButton !== false && !!(task.joinUrl && task.joinUrl.length)
                        icon.name: "internet-services"
                        display: QQC2.AbstractButton.IconOnly
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        onClicked: Qt.openUrlExternally(task.joinUrl)
                        QQC2.ToolTip.text: i18n("Join")
                        QQC2.ToolTip.visible: joinHover.hovered && !root.listMoving
                        HoverHandler { id: joinHover }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: !!task.section
                    text: task.section || ""
                    opacity: 0.6
                    font.italic: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }

            QQC2.ToolButton {
                id: editButton
                icon.name: "document-edit"
                display: QQC2.AbstractButton.IconOnly
                enabled: !root.awaitingAkonadi
                onClicked: root.requestOpenFullEditor(root.taskSnapshot())
                QQC2.ToolTip.text: i18n("Edit task")
                QQC2.ToolTip.visible: hovered && !root.listMoving
            }

            QQC2.ToolButton {
                visible: root.deleteModeEnabled
                icon.name: "edit-delete"
                display: QQC2.AbstractButton.IconOnly
                enabled: !root.awaitingAkonadi
                onClicked: root.requestDelete(task.itemId)
                QQC2.ToolTip.text: i18n("Delete task")
                QQC2.ToolTip.visible: hovered && !root.listMoving
            }
        }
    }

    QQC2.Menu {
        id: rescheduleMenu
        popupType: Item
        enabled: !root.awaitingAkonadi
        QQC2.MenuItem {
            text: i18n("In 15 minutes")
            onTriggered: controller.rescheduleTask(task.itemId, "15m")
        }
        QQC2.MenuItem {
            text: i18n("In 1 hour")
            onTriggered: controller.rescheduleTask(task.itemId, "1h")
        }
        QQC2.MenuItem {
            text: i18n("In 4 hours")
            onTriggered: controller.rescheduleTask(task.itemId, "4h")
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: i18n("Tomorrow")
            onTriggered: controller.rescheduleTask(task.itemId, "tomorrow")
        }
        QQC2.MenuItem {
            text: i18n("Next week")
            onTriggered: controller.rescheduleTask(task.itemId, "next-week")
        }
    }

    function ensureVisibleInList() {
        var view = root.ListView.view
        if (!view) {
            return
        }
        var top = root.y
        var bottom = root.y + root.height
        if (bottom > view.contentY + view.height) {
            view.contentY = Math.max(0, bottom - view.height)
        }
        if (top < view.contentY) {
            view.contentY = Math.max(0, top)
        }
    }

    onExpandedChanged: if (expanded) ensureVisibleTimer.restart()
    onHeightChanged: if (expanded) ensureVisibleTimer.restart()
    onEditorReserveHeightChanged: if (expanded) ensureVisibleTimer.restart()

    Timer {
        id: ensureVisibleTimer
        interval: 16
        repeat: false
        onTriggered: root.ensureVisibleInList()
    }
}
