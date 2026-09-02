import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import com.github.shrippen.kurrent 1.0
import "../components"
import "../colors.js" as Colors
import "../taskmeta.js" as TaskMeta
import ".."
import "."

ColumnLayout {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property string hiddenProjects: ""
    property string newTaskProjectMode: "ask"
    property string newTaskDefaultCollectionId: ""
    property bool multiSelectEnabled: false
    // Full-editor overlay: suppress row hover under the dim.
    property bool interactionsSuspended: false

    property var expandedItemId: -1
    property var selectedItemId: -1
    property int expandedIndex: -1
    property bool deleteModeEnabled: false
    property string pendingNewTask: ""
    property var askProjects: []

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    Layout.maximumHeight: Infinity
    implicitHeight: 0
    spacing: Design.spaceSmall

    readonly property bool isDragging: !!(dragHost && dragHost.draggingTask)
    readonly property bool canUnparentDrag: isDragging
        && dragHost.draggingTask.parentUid
        && String(dragHost.draggingTask.parentUid).length > 0

    // Close the shared inline editor when the list context changes or a drag starts.
    onIsDraggingChanged: {
        if (isDragging) {
            root.collapseInline()
        }
    }

    Connections {
        target: root.controller
        function onCurrentViewChanged() { root.collapseInline() }
        function onManagementViewChanged() { root.collapseInline() }
        function onSelectedCollectionIdChanged() { root.collapseInline() }
        function onSelectedLabelChanged() { root.collapseInline() }
        function onSelectedPriorityChanged() { root.collapseInline() }
        function onSearchQueryChanged() { root.collapseInline() }
        function onShowCompletedChanged() { root.collapseInline() }
        function onSortModeChanged() { root.collapseInline() }
    }

    function acceptDropAsParent(parentUid) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        var draggedId = dragHost.draggingTask.itemId
        var draggedUid = dragHost.draggingTask.uid
        if (parentUid && parentUid === draggedUid) {
            return false
        }
        controller.setTaskParent(draggedId, parentUid || "")
        return true
    }

    function focusSearch() {
        searchField.forceActiveFocus()
        searchField.selectAll()
    }

    function focusNewTask() {
        newTaskField.forceActiveFocus()
    }

    function bulkItemIds() {
        var ids = []
        for (var i = 0; i < controller.selectedTaskIds.length; ++i) {
            ids.push(parseInt(controller.selectedTaskIds[i], 10))
        }
        return ids
    }

    function openSelectedFullEditor() {
        if (selectedItemId < 0 || !dragHost || !dragHost.openFullEditor) {
            return
        }
        for (var i = 0; i < taskList.count; ++i) {
            var item = taskList.itemAtIndex(i)
            if (item && item.task && item.task.itemId === selectedItemId) {
                dragHost.openFullEditor(item.taskSnapshot ? item.taskSnapshot() : item.task)
                return
            }
        }
    }

    function requestDelete(itemId) {
        if (Plasmoid.configuration.confirmDelete) {
            pendingDeleteId = itemId
            confirmDeleteDialog.open()
            return
        }
        controller.deleteTask(itemId)
    }

    property var pendingDeleteId: -1

    Timer {
        id: searchDebounce
        interval: 150
        onTriggered: controller.searchQuery = searchField.text
    }

    // Show animated gear after 500ms of reorganization.
    Timer {
        id: reorgGearTimer
        interval: 500
        repeat: false
        running: controller && controller.listReorganizing
        onTriggered: reorgGearTimer.triggered = true
        property bool triggered: false
        onRunningChanged: {
            if (!running) triggered = false
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Kirigami.ActionTextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: i18n("Search tasks…")
            onTextChanged: searchDebounce.restart()
            rightActions: [
                Kirigami.Action {
                    icon.name: "edit-clear"
                    visible: searchField.text.length > 0
                    text: i18n("Clear search")
                    onTriggered: {
                        searchField.text = ""
                        searchField.forceActiveFocus()
                    }
                }
            ]
        }

        Kirigami.Icon {
            id: reorgGear
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: "view-refresh"
            visible: reorgGearTimer.triggered && searchField.text.length > 0
        }

        RotationAnimator {
            target: reorgGear
            running: reorgGear.visible
            from: 0
            to: 360
            duration: Kirigami.Units.longDuration * 6
            loops: Animation.Infinite
        }

        QQC2.ToolButton {
            id: deleteModeButton
            icon.name: "edit-delete"
            checkable: true
            checked: root.deleteModeEnabled
            onToggled: root.deleteModeEnabled = checked
            QQC2.ToolTip.text: checked ? i18n("Exit delete mode") : i18n("Delete mode")
            QQC2.ToolTip.visible: hovered
        }

        QQC2.ToolButton {
            icon.name: "view-refresh"
            onClicked: controller.syncNow()
            enabled: !controller.loading
            QQC2.ToolTip.text: i18n("Sync now")
            QQC2.ToolTip.visible: hovered
        }
    }

    QQC2.ProgressBar {
        Layout.fillWidth: true
        indeterminate: true
        visible: controller.loading
        from: 0
        to: 1
    }

    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: controller.emptyKind === "loading"
        icon.name: "view-refresh"
        text: i18n("Connecting to Akonadi…")
        explanation: i18n("The flyout is ready; tasks appear when the server answers.")
    }

    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: controller.emptyKind === "offline"
        icon.name: "state-offline"
        text: i18n("Akonadi is not running")
        explanation: i18n("Start it with akonadictl start, then add a CalDAV resource in Merkuro or KOrganizer.")
        helpfulAction: Kirigami.Action {
            icon.name: "view-refresh"
            text: i18n("Try again")
            onTriggered: controller.refresh()
        }
    }

    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: controller.emptyKind === "no-collections"
        icon.name: "view-calendar-tasks"
        text: i18n("No task lists")
        explanation: i18n("Enable a calendar in Configure Kurrent → Projects, or add a CalDAV resource in Merkuro or KOrganizer.")
    }

    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        visible: controller.emptyKind === "error"
        icon.name: "dialog-error"
        text: i18n("Could not load tasks")
        explanation: controller.errorMessage
        helpfulAction: Kirigami.Action {
            icon.name: "view-refresh"
            text: i18n("Try again")
            onTriggered: controller.refresh()
        }
    }

    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        visible: controller.emptyKind === "empty"
        icon.name: "checkmark"
        text: i18n("No tasks in this view.")
    }

    Rectangle {
        id: unparentDropZone
        Layout.fillWidth: true
        Layout.preferredHeight: root.canUnparentDrag ? Kirigami.Units.gridUnit * 2.2 : 0
        visible: root.canUnparentDrag
        radius: 4
        color: unparentDrop.containsDrag ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                                   Kirigami.Theme.highlightColor.g,
                                                   Kirigami.Theme.highlightColor.b,
                                                   0.25)
                                         : Qt.rgba(Kirigami.Theme.textColor.r,
                                                   Kirigami.Theme.textColor.g,
                                                   Kirigami.Theme.textColor.b,
                                                   0.08)
        border.width: 1
        border.color: unparentDrop.containsDrag ? Kirigami.Theme.highlightColor
                                                : Qt.rgba(Kirigami.Theme.textColor.r,
                                                          Kirigami.Theme.textColor.g,
                                                          Kirigami.Theme.textColor.b,
                                                          0.25)
        clip: true

        DropArea {
            id: unparentDrop
            anchors.fill: parent
            keys: ["application/x-kurrent-task"]

            readonly property string hintText: i18n("Make top-level task")

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
                if (root.acceptDropAsParent("")) {
                    drop.acceptProposedAction()
                }
            }
        }

        QQC2.Label {
            anchors.centerIn: parent
            text: i18n("Drop here to make a top-level task")
            opacity: 0.85
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 0

        ListView {
        id: taskList
        anchors.fill: parent
        implicitHeight: 0
        clip: true
        model: controller.taskModel
        visible: controller.emptyKind === "" || controller.emptyKind === "empty"
        reuseItems: true
        // True while Kirigami.WheelHandler is driving contentY (moving/flicking stay false).
        property bool wheelScrolling: false
        section.property: "bucket"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            id: sectionRoot
            required property string section
            width: taskList.width - taskList.leftMargin - taskList.rightMargin
            height: sectionRow.implicitHeight + Design.spaceSmall

            readonly property string groupMode: controller.listGroupMode || ""
            readonly property string sectionIconName: TaskMeta.listSectionIcon(groupMode, section)
            readonly property var sectionTint: TaskMeta.listSectionIconTint(groupMode, section)

            RowLayout {
                id: sectionRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Design.spaceSmall

                Kirigami.Icon {
                    visible: sectionRoot.sectionIconName.length > 0
                    Layout.preferredWidth: Design.listSectionIconSize
                    Layout.preferredHeight: Design.listSectionIconSize
                    source: sectionRoot.sectionIconName
                    opacity: sectionRoot.sectionTint.opacity !== undefined
                            ? sectionRoot.sectionTint.opacity : 0.7
                    color: {
                        var tint = sectionRoot.sectionTint
                        if (tint.kind === "project") {
                            return Design.colorForKey(tint.key)
                        }
                        if (tint.kind === "label") {
                            return Design.colorForKey(tint.key, "label")
                        }
                        if (tint.kind === "location") {
                            return Design.colorForKey(tint.key, "location")
                        }
                        if (tint.priority !== undefined) {
                            return Colors.colorForPriority(tint.priority)
                        }
                        return Kirigami.Theme.textColor
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: {
                        var gm = sectionRoot.groupMode
                        if (gm.length > 0 && gm !== "none") {
                            return controller.listGroupLabelForKey(sectionRoot.section)
                        }
                        switch (sectionRoot.section) {
                        case "catchup": return i18n("Still open")
                        case "morning": return i18n("Morning")
                        case "afternoon": return i18n("Afternoon")
                        case "evening": return i18n("Evening")
                        case "unspecified": return i18n("Anytime")
                        default: return sectionRoot.section
                        }
                    }
                    font.bold: true
                    opacity: 0.7
                    visible: text.length > 0
                }
            }
        }
        // Prefetch ~2 viewports so scroll rarely instantiates rows mid-gesture.
        cacheBuffer: Math.max(Math.round(height * 2), Math.round(Kirigami.Units.gridUnit * 24))
        spacing: 0

        // When the model is applying chunked row operations, snap rows
        // instantly (duration 0) to prevent displaced-transition overlap
        // artifacts.  Normal animated repositioning resumes when chunks
        // finish.
        readonly property bool chunksActive: controller.taskModel
                                             ? controller.taskModel.chunksActive : false

        // Allow flick/touchpad overshoot with rebound (StopAtBounds left the list
        // stuck past the edge when inertia ran out without a bounce-back).
        boundsBehavior: Flickable.OvershootBounds
        flickableDirection: Flickable.VerticalFlick

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: taskList.chunksActive ? 0 : Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        function settleScrollBounds() {
            var maxY = Math.max(0, contentHeight - height)
            if (Math.abs(verticalOvershoot) > 0.5
                    || contentY < -0.5
                    || contentY > maxY + 0.5) {
                returnToBounds()
            }
        }

        onFlickEnded: settleScrollBounds()
        onMovementEnded: settleScrollBounds()
        onContentHeightChanged: Qt.callLater(settleScrollBounds)

        // Narrow scrollbar + permanent gutter so edit icons never sit under it.
        readonly property int scrollBarExtent: Design.scrollBarExtent
        readonly property int scrollGutter: Design.scrollGutter
        rightMargin: scrollGutter

        // Same stack as Kirigami.ScrollablePage / ScrollView: WheelHandler owns wheel,
        // Flickable keeps touch flick; mouse does not flick the list.
        Kirigami.WheelHandler {
            id: taskWheelHandler
            target: taskList
            filterMouseEvents: true
            // Mark scroll activity so delegates can suppress hover (contentY anim does not set moving).
            onWheel: function(wheel) {
                taskList.wheelScrolling = true
                wheelScrollIdle.restart()
            }
        }
        Timer {
            id: wheelScrollIdle
            interval: 400
            repeat: false
            onTriggered: {
                taskList.wheelScrolling = false
                // WheelHandler can leave contentY past bounds after a fast touchpad burst.
                taskList.settleScrollBounds()
            }
        }

        QQC2.ScrollBar.vertical: ThinScrollBar {
            view: taskList
            parent: taskList
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            stepSize: taskList.contentHeight > 0
                    ? taskWheelHandler.verticalStepSize / taskList.contentHeight
                    : 0.1
        }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
            policy: QQC2.ScrollBar.AlwaysOff
        }

        // Drop on empty list background also unparents.
        DropArea {
            anchors.fill: parent
            z: -1
            keys: ["application/x-kurrent-task"]
            enabled: root.canUnparentDrag

            readonly property string hintText: i18n("Make top-level task")

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
                if (root.acceptDropAsParent("")) {
                    drop.acceptProposedAction()
                }
            }
        }

        delegate: TaskDelegate {
            width: taskList.width - taskList.leftMargin - taskList.rightMargin
            controller: root.controller
            dragHost: root.dragHost
            taskListRoot: root
            interactionsSuspended: root.interactionsSuspended
            expanded: root.expandedItemId === model.itemId
            deleteModeEnabled: root.deleteModeEnabled
            // Height applied imperatively for the expanded row only (see syncInlineGeometry).
            onRequestExpand: function(itemId) {
                root.selectedItemId = itemId
                root.expandTask(itemId, index)
            }
            onRequestCollapse: {
                root.collapseInline()
            }
            onRequestOpenFullEditor: function(taskObj) {
                root.collapseInline()
                if (root.dragHost && root.dragHost.openFullEditor) {
                    root.dragHost.openFullEditor(taskObj)
                }
            }
            onRequestDelete: function(itemId) {
                root.requestDelete(itemId)
            }
        }

        // One always-alive editor — opening is instant (no per-row Loader).
        TaskInlineEditor {
            id: sharedInline
            parent: taskList.contentItem
            x: 0
            z: 2
            visible: false
            enabled: visible
            controller: root.controller
            popupParent: root.Window.window ? root.Window.window.contentItem : root

            onSaved: root.collapseInline()
            onCancelled: root.collapseInline()
            onOpenFullEditor: {
                var snap = task
                root.collapseInline()
                if (root.dragHost && root.dragHost.openFullEditor) {
                    root.dragHost.openFullEditor(snap)
                }
            }

            onImplicitHeightChanged: {
                if (visible) {
                    root.syncInlineGeometry()
                    root.ensureExpandedVisible()
                    geometrySettleTimer.restart()
                }
            }
            onHeightChanged: {
                if (visible) {
                    root.syncInlineGeometry()
                }
            }
            onOpenRevealChanged: {
                if (visible) {
                    root.syncInlineGeometry()
                    root.ensureExpandedVisible()
                }
            }
        }
    }
    }

    readonly property real expandedEditorHeight: sharedInline.visible
        ? Math.ceil(sharedInline.height) + Design.spaceSmall
        : 0

    // Track the expanded row's guide so width settles after layout.
    property Item _expandedGuide: null
    Connections {
        target: root._expandedGuide
        function onWidthChanged() {
            root.syncInlineGeometry()
        }
        function onXChanged() {
            root.syncInlineGeometry()
        }
    }

    function expandTask(itemId, index) {
        // Clear previous spacer.
        if (expandedIndex >= 0) {
            var prev = taskList.itemAtIndex(expandedIndex)
            if (prev) {
                prev.editorReserveHeight = 0
            }
        }

        expandedItemId = itemId
        expandedIndex = index

        taskList.positionViewAtIndex(index, ListView.Contain)

        var delegateItem = taskList.itemAtIndex(index)
        root._expandedGuide = delegateItem ? delegateItem.editorGuideItem : null
        if (delegateItem && delegateItem.taskSnapshot) {
            sharedInline.task = delegateItem.taskSnapshot()
        }
        sharedInline.loadFromTask()
        // Start folded, then unfold (or snap open when reduced motion).
        sharedInline.openReveal = Design.reducedMotion ? 1 : 0
        sharedInline.visible = true
        syncInlineGeometry()
        ensureExpandedVisible()
        geometrySettleTimer.restart()
        if (!Design.reducedMotion) {
            Qt.callLater(function() {
                sharedInline.openReveal = 1
            })
        }
        Qt.callLater(function() {
            root.syncInlineGeometry()
            root.ensureExpandedVisible()
            geometrySettleTimer.restart()
        })
    }

    function collapseInline() {
        if (expandedIndex >= 0) {
            var prev = taskList.itemAtIndex(expandedIndex)
            if (prev) {
                prev.editorReserveHeight = 0
            }
        }
        expandedItemId = -1
        expandedIndex = -1
        root._expandedGuide = null
        sharedInline.openReveal = Design.reducedMotion ? 0 : sharedInline.openReveal
        sharedInline.visible = false
        sharedInline.openReveal = 1
    }

    // After model rebuilds (filter/view/DnD), keep the editor only if the task is still listed.
    function syncExpandedAfterModelChange() {
        if (expandedItemId < 0 || !sharedInline.visible) {
            return
        }
        var row = controller.taskModel.rowForItemId(expandedItemId)
        if (row < 0) {
            collapseInline()
            return
        }
        if (expandedIndex !== row) {
            expandedIndex = row
            root._expandedGuide = null
            var delegateItem = taskList.itemAtIndex(row)
            root._expandedGuide = delegateItem ? delegateItem.editorGuideItem : null
        }
        Qt.callLater(root.syncInlineGeometry)
    }

    function syncInlineGeometry() {
        if (expandedIndex < 0 || !sharedInline.visible) {
            return
        }
        var delegateItem = taskList.itemAtIndex(expandedIndex)
        if (!delegateItem) {
            taskList.positionViewAtIndex(expandedIndex, ListView.Contain)
            delegateItem = taskList.itemAtIndex(expandedIndex)
        }
        if (!delegateItem) {
            return
        }

        var reserve = root.expandedEditorHeight
        if (Math.abs(delegateItem.editorReserveHeight - reserve) > 0.5) {
            delegateItem.editorReserveHeight = reserve
        }

        // Full delegate width (same edges as row hover; ignore hierarchy indent).
        var left = 0
        var width = 0
        if (delegateItem.editorGuideItem && delegateItem.editorGuideItem.width > 1) {
            left = delegateItem.x + delegateItem.editorGuideItem.x
            width = delegateItem.editorGuideItem.width
        } else {
            left = delegateItem.x
            width = delegateItem.width
        }

        if (width < 1) {
            return
        }

        sharedInline.x = left
        sharedInline.y = delegateItem.y + delegateItem.collapsedHeight
        sharedInline.width = width
    }

    // Keep editor aligned when the expanded row finishes laying out (width only —
    // height changes often come from editorReserveHeight and must not re-enter sync).
    Connections {
        target: (sharedInline.visible && expandedIndex >= 0)
                ? taskList.itemAtIndex(expandedIndex)
                : null
        ignoreUnknownSignals: true
        function onWidthChanged() { root.syncInlineGeometry() }
    }

    Timer {
        id: geometrySettleTimer
        interval: 32
        repeat: false
        onTriggered: root.syncInlineGeometry()
    }

    function ensureExpandedVisible() {
        if (expandedIndex < 0) {
            return
        }
        var delegateItem = taskList.itemAtIndex(expandedIndex)
        if (!delegateItem) {
            return
        }
        var top = delegateItem.y
        var bottom = delegateItem.y + delegateItem.height
        if (bottom > taskList.contentY + taskList.height) {
            taskList.contentY = Math.max(0, bottom - taskList.height)
        }
        if (top < taskList.contentY) {
            taskList.contentY = Math.max(0, top)
        }
    }

    Connections {
        target: taskList
        function onContentYChanged() {
            if (sharedInline.visible) {
                root.syncInlineGeometry()
            }
        }
        function onWidthChanged() {
            if (sharedInline.visible) {
                root.syncInlineGeometry()
            }
        }
        function onHeightChanged() {
            if (sharedInline.visible) {
                root.ensureExpandedVisible()
            }
        }
        function onCountChanged() {
            root.syncExpandedAfterModelChange()
        }
        function onModelChanged() {
            root.syncExpandedAfterModelChange()
        }
    }

    Connections {
        target: controller.taskModel
        function onModelReset() {
            root.syncExpandedAfterModelChange()
        }
        function onRowsInserted() {
            root.syncExpandedAfterModelChange()
        }
        function onRowsRemoved() {
            root.syncExpandedAfterModelChange()
        }
        function onRowsMoved() {
            root.syncExpandedAfterModelChange()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: controller.emptyKind === "" || controller.emptyKind === "empty" || controller.emptyKind === "error"

        QuickAddField {
            id: newTaskField
            Layout.fillWidth: true
            placeholderText: i18n("Add a task…  tomorrow 18:00 !high #tag @project")
            controller: root.controller
            projects: root.writableProjects
            popupHost: root.dragHost || root
            onAccepted: root.addTask()
        }

        QQC2.ToolButton {
            icon.name: "list-add"
            onClicked: {
                if (!newTaskField.text.trim()) {
                    var colId = controller.selectedCollectionId
                    if (colId <= 0) {
                        var projs = root.writableProjects
                        if (projs && projs.length > 0) {
                            colId = projs[0].collectionId
                        }
                    }
                    if (dragHost && dragHost.openNewTaskEditor) {
                        dragHost.openNewTaskEditor(colId)
                    }
                } else {
                    addTask()
                }
            }
            QQC2.ToolTip.text: newTaskField.text.trim()
                ? i18n("Add task")
                : i18n("Open full editor")
            QQC2.ToolTip.visible: hovered
        }
    }

    QQC2.Dialog {
        id: confirmDeleteDialog
        parent: root.dragHost || root
        popupType: QQC2.Popup.Item
        modal: true
        title: i18n("Delete task?")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onAccepted: {
            if (root.pendingDeleteId >= 0) {
                controller.deleteTask(root.pendingDeleteId)
            }
            root.pendingDeleteId = -1
        }
        onRejected: root.pendingDeleteId = -1
        QQC2.Label {
            text: i18n("Delete this task?")
            wrapMode: Text.WordWrap
            width: Kirigami.Units.gridUnit * 16
        }
    }

    Item {
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        Layout.maximumWidth: 0
        Layout.maximumHeight: 0
        width: 0
        height: 0

        QQC2.Popup {
            id: projectAskPopup
            parent: root.dragHost || root
            popupType: QQC2.Popup.Item
            modal: true
            dim: true
            focus: true
            clip: true
            padding: Design.spaceSmall
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
            z: 1500

        width: Math.min(Kirigami.Units.gridUnit * 18,
                        Math.max(Kirigami.Units.gridUnit * 12, parent.width - Design.spaceMedium * 2))
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - implicitHeight) / 2)

        background: Rectangle {
            radius: 4
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Design.spaceSmall

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.bold: true
                text: root.pendingNewTask
                      ? i18n("Choose a project for “%1”", root.pendingNewTask)
                      : i18n("Choose a project")
            }

            ListView {
                id: projectAskList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight,
                                                 Kirigami.Units.gridUnit * 12)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.askProjects
                spacing: 0

                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    width: projectAskList.width
                    onClicked: root.confirmNewTask(modelData.collectionId)

                    contentItem: RowLayout {
                        spacing: Design.spaceSmall
                        Kirigami.Icon {
                            source: "folder"
                            color: Design.colorForKey(String(modelData.collectionId))
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            Layout.alignment: Qt.AlignVCenter
                            width: Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    policy: projectAskList.contentHeight > projectAskList.height
                            ? QQC2.ScrollBar.AlwaysOn
                            : QQC2.ScrollBar.AlwaysOff
                }
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignRight
                text: i18n("Cancel")
                onClicked: projectAskPopup.close()
            }
        }

        onClosed: {
            if (root.pendingNewTask) {
                newTaskField.text = root.pendingNewTask
                root.pendingNewTask = ""
            }
        }
        }
    }

    function isProjectHidden(collectionId) {
        if (!hiddenProjects) {
            return false
        }
        return hiddenProjects.split(",").indexOf(String(collectionId)) >= 0
    }

    function collectionExists(collectionId) {
        var model = controller.collectionModel
        if (!model || collectionId <= 0) {
            return false
        }
        var row = model.rowForCollectionId(collectionId)
        return row >= 0 && model.enabledAt(row)
    }

    function collectionWritable(collectionId) {
        var model = controller.collectionModel
        if (!model || collectionId <= 0) {
            return false
        }
        return model.writableForId(collectionId)
    }

    function firstSidebarProjectId() {
        var model = controller.collectionModel
        if (!model) {
            return -1
        }
        var firstNonHidden = -1
        for (var i = 0; i < model.count; ++i) {
            var id = model.collectionIdAt(i)
            if (!model.enabledAt(i) || isProjectHidden(id) || !model.writableAt(i)) {
                continue
            }
            if (firstNonHidden < 0) {
                firstNonHidden = id
            }
            if (model.taskCountAt(i) > 0) {
                return id
            }
        }
        return firstNonHidden
    }

    readonly property var writableProjects: {
        var _count = controller.collectionModel ? controller.collectionModel.count : 0
        var _hidden = hiddenProjects
        return askProjectList()
    }

    function askProjectList() {
        var model = controller.collectionModel
        var out = []
        if (!model) {
            return out
        }
        for (var i = 0; i < model.count; ++i) {
            var id = model.collectionIdAt(i)
            if (!model.enabledAt(i) || isProjectHidden(id) || !model.writableAt(i)) {
                continue
            }
            out.push({
                collectionId: id,
                name: model.nameAt(i)
            })
        }
        return out
    }

    function confirmNewTask(collectionId) {
        var text = pendingNewTask
        pendingNewTask = ""
        projectAskPopup.close()
        if (text && collectionId > 0) {
            controller.createTask(text, collectionId)
        }
    }

    function addTask() {
        var text = newTaskField.text.trim()
        if (!text) {
            return
        }
        var parsed = controller.parseQuickAdd(text, Qt.locale().name, writableProjects)
        if (parsed && parsed.collectionId > 0) {
            controller.createTask(text, parsed.collectionId)
            newTaskField.text = ""
            return
        }
        var collectionId = controller.selectedCollectionId
        if (collectionId > 0 && collectionWritable(collectionId)) {
            controller.createTask(text, collectionId)
            newTaskField.text = ""
            return
        }

        var mode = newTaskProjectMode || "ask"
        if (mode === "first") {
            collectionId = firstSidebarProjectId()
            if (collectionId > 0) {
                controller.createTask(text, collectionId)
                newTaskField.text = ""
                return
            }
            mode = "ask"
        } else if (mode === "fixed") {
            collectionId = Number(newTaskDefaultCollectionId)
            if (collectionId > 0 && collectionExists(collectionId) && collectionWritable(collectionId)) {
                controller.createTask(text, collectionId)
                newTaskField.text = ""
                return
            }
            mode = "ask"
        }

        var choices = askProjectList()
        if (choices.length === 1) {
            controller.createTask(text, choices[0].collectionId)
            newTaskField.text = ""
            return
        }
        if (choices.length === 0) {
            controller.createTask(text, -1)
            newTaskField.text = ""
            return
        }

        pendingNewTask = text
        newTaskField.text = ""
        askProjects = choices
        projectAskPopup.open()
    }
}
