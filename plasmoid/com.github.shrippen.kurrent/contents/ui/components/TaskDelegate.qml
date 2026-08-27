import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "../colors.js" as Colors
import "../datetime.js" as DateTime
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
    // Kirigami.WheelHandler animates contentY without setting moving/flicking.
    readonly property bool listMoving: {
        var v = ListView.view
        if (!v) {
            return false
        }
        return v.moving || v.flicking || v.wheelScrolling === true
    }
    readonly property bool isDragSource: !!(dragHost && dragHost.draggingTask
                                            && dragHost.draggingTask.itemId === task.itemId)
    readonly property bool dropHighlight: taskDrop.containsDrag && !isDragSource
    // Keep statusRow.visible off dateChip.visible — Layout.width ↔ visible loops otherwise.
    readonly property bool showDueChip: Plasmoid.configuration.showDateChip !== false
            && DateTime.isValidDate(task.dueDate)

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
    readonly property bool treeHidden: task.treeHidden === true
    // Latched at toggle time so mid-animation layout shifts do not restart Behavior.
    property int collapseAnimMs: 0
    function latchCollapseAnimMs() {
        if (Design.reducedMotion) {
            collapseAnimMs = 0
            return
        }
        var v = ListView.view
        if (!v || v.height <= 0) {
            collapseAnimMs = 150
            return
        }
        // Height is still full at toggle; use that for viewport overlap.
        var top = y
        var bottom = y + Math.max(height, fullContentHeight)
        if (bottom < v.contentY - 2 || top > v.contentY + v.height + 2) {
            collapseAnimMs = 0
            return
        }
        collapseAnimMs = 150
    }
    function applyTreeHidden() {
        latchCollapseAnimMs()
        reveal = treeHidden ? 0 : 1
    }
    onTreeHiddenChanged: applyTreeHidden()
    // Instant reveal when the ListView recycles this delegate onto another row.
    ListView.onReused: {
        collapseAnimMs = 0
        reveal = treeHidden ? 0 : 1
        Qt.callLater(root.syncEditorGuide)
    }
    readonly property real fullContentHeight: contentColumn.implicitHeight + pad * 2
            + (expanded && editorReserveHeight > 0 ? pad + editorReserveHeight : 0)
            + Design.spaceSmall

    // Animated collapse: height and opacity go to 0 while the row stays in the model.
    property real reveal: 1
    Behavior on reveal {
        enabled: root.collapseAnimMs > 0
        NumberAnimation {
            duration: root.collapseAnimMs
            easing.type: Easing.OutCubic
        }
    }

    implicitHeight: Math.round(fullContentHeight * reveal)
    // clip only while collapsing — full-height rows skip an expensive clip node.
    clip: reveal < 1
    // Keep enabled until fully collapsed — disabling mid-animation makes QQC2
    // Labels pick up highlight/disabled palette (brief blue/washed text).
    enabled: reveal > 0.02
    opacity: {
        var base = isDragSource ? 0.45 : (task.pendingDelete ? 0.4 : (task.syncing ? 0.7 : 1.0))
        return base * reveal
    }

    readonly property bool awaitingAkonadi: task.syncing === true || task.pendingDelete === true
    readonly property real collapsedHeight: pad + contentLayout.implicitHeight
            + (expanded && editorReserveHeight > 0 ? pad : 0)

    // Invisible guide for the shared inline editor: full delegate width (same as
    // row hover), ignoring hierarchy indent.
    Item {
        id: editorGuide
        height: 1
        y: -1000
        visible: false
        width: 1
    }

    function syncEditorGuide() {
        editorGuide.x = 0
        editorGuide.width = Math.max(1, root.width)
    }

    readonly property real editorContentX: editorGuide.x
    readonly property real editorContentWidth: editorGuide.width
    readonly property Item editorGuideItem: editorGuide

    Connections {
        target: contentColumn
        function onWidthChanged() { root.syncEditorGuide() }
        function onXChanged() { root.syncEditorGuide() }
    }
    Component.onCompleted: {
        // First paint / model load: no collapse animation.
        collapseAnimMs = 0
        reveal = treeHidden ? 0 : 1
        Qt.callLater(root.syncEditorGuide)
    }
    onWidthChanged: Qt.callLater(root.syncEditorGuide)

    // Cheap hover; off while scrolling or collapsing so rows sliding under the
    // cursor do not flash highlight blue.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.expanded ? Math.round(root.collapsedHeight) : parent.height
        radius: Design.inputRadius
        color: dropHighlight ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
        opacity: dropHighlight ? 0.22 : ((root.expanded || (!root.listMoving && root.reveal >= 1 && hoverHandler.hovered && !Design.reducedMotion)) ? 0.12 : 0)
        visible: opacity > 0
        z: 0
    }

    HoverHandler {
        id: hoverHandler
        enabled: !root.listMoving && root.reveal >= 1 && !root.treeHidden
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

            // Hierarchy indent, then reserved collapse column (keeps checkboxes aligned),
            // then checkbox — arrow no longer shifts the parent checkbox.
            Item {
                Layout.preferredWidth: (task.indentLevel || 0) * Design.taskIndentUnit
                Layout.minimumWidth: Layout.preferredWidth
            }

            Item {
                Layout.preferredWidth: Design.taskCollapseCol
                Layout.preferredHeight: Design.taskCollapseCol
                Layout.alignment: Qt.AlignVCenter

                QQC2.ToolButton {
                    anchors.centerIn: parent
                    width: Design.taskCollapseCol
                    height: Design.taskCollapseCol
                    visible: task.hasChildren === true
                    icon.name: task.treeCollapsed ? "arrow-right" : "arrow-down"
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !root.awaitingAkonadi
                    onClicked: {
                        controller.toggleTreeCollapsed(task.uid)
                    }
                    QQC2.ToolTip.text: task.treeCollapsed ? i18n("Expand subtasks") : i18n("Collapse subtasks")
                    QQC2.ToolTip.visible: hovered && !root.listMoving
                }
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
                spacing: Design.spaceTiny

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
                    visible: root.showDueChip
                             || (Plasmoid.configuration.showLabelChips !== false && (root.visibleCategories ? root.visibleCategories.length > 0 : false))
                             || (Plasmoid.configuration.showPriorityChip !== false && task.priority > 0)
                             || (Plasmoid.configuration.showRecurringIcon !== false && task.recurring)
                             || (Plasmoid.configuration.showJoinButton !== false && (task.joinUrl ? task.joinUrl.length > 0 : false))

                    QQC2.ToolButton {
                        visible: Plasmoid.configuration.showJoinButton !== false && !!(task.joinUrl && task.joinUrl.length)
                        icon.name: "internet-services"
                        display: QQC2.AbstractButton.IconOnly
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: Qt.openUrlExternally(task.joinUrl)
                        QQC2.ToolTip.text: i18n("Open / Join")
                        QQC2.ToolTip.visible: joinHover.hovered && !root.listMoving
                        HoverHandler { id: joinHover }
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

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                    }

                    // Due date/time: flush right, accent (overdue stays negative).
                    QQC2.Label {
                        id: dateChip
                        visible: root.showDueChip
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        Layout.maximumWidth: Math.max(Kirigami.Units.gridUnit * 6,
                                                      statusRow.width * 0.45)
                        elide: Text.ElideLeft
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        text: {
                            if (!root.showDueChip) {
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
                        color: {
                            if (!visible) {
                                return Kirigami.Theme.textColor
                            }
                            var dueDay = Qt.formatDate(task.dueDate, "yyyy-MM-dd")
                            var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
                            if (dueDay < today) {
                                return Kirigami.Theme.negativeTextColor
                            }
                            return Kirigami.Theme.highlightColor
                        }
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
        popupType: QQC2.Popup.Item
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
