import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import com.github.shrippen.kurrent 1.0
import "../components"
import "../colors.js" as Colors
import ".."
import "."

ColumnLayout {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property string hiddenProjects: ""
    property string newTaskProjectMode: "ask"
    property string newTaskDefaultCollectionId: ""

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

    property string scrollAnchorUid: ""
    property real scrollAnchorViewportY: 0

    function preserveScrollForUid(uid) {
        if (!uid) {
            return
        }
        var row = controller.taskModel.rowForUid(uid)
        if (row < 0) {
            return
        }
        var item = taskList.itemAtIndex(row)
        if (item) {
            scrollAnchorUid = uid
            scrollAnchorViewportY = item.y - taskList.contentY
            return
        }
        scrollAnchorUid = uid
        scrollAnchorViewportY = 0
        taskList.positionViewAtIndex(row, ListView.Beginning)
        item = taskList.itemAtIndex(row)
        if (item) {
            scrollAnchorViewportY = item.y - taskList.contentY
        }
    }

    function restoreScrollAnchor() {
        if (!scrollAnchorUid) {
            return
        }
        var uid = scrollAnchorUid
        var viewportY = scrollAnchorViewportY
        scrollAnchorUid = ""

        Qt.callLater(function() {
            var row = controller.taskModel.rowForUid(uid)
            if (row < 0) {
                return
            }
            taskList.positionViewAtIndex(row, ListView.Beginning)
            var item = taskList.itemAtIndex(row)
            if (item) {
                taskList.contentY = Math.max(0, item.y - viewportY)
            } else {
                scrollAnchorRetry.targetRow = row
                scrollAnchorRetry.viewportY = viewportY
                scrollAnchorRetry.start()
            }
        })
    }

    Timer {
        id: scrollAnchorRetry
        interval: 16
        repeat: false
        property int targetRow: -1
        property real viewportY: 0
        onTriggered: {
            if (targetRow < 0) {
                return
            }
            taskList.positionViewAtIndex(targetRow, ListView.Beginning)
            var item = taskList.itemAtIndex(targetRow)
            if (item) {
                taskList.contentY = Math.max(0, item.y - viewportY)
            }
            targetRow = -1
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Kirigami.ActionTextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: i18n("Search tasks…")
            onTextChanged: controller.searchQuery = text
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
            visible: controller.canUndo
            icon.name: "edit-undo"
            onClicked: controller.undo()
            QQC2.ToolTip.text: {
                switch (controller.undoKind) {
                case "complete": return i18n("Undo complete")
                case "reschedule": return i18n("Undo reschedule")
                case "move": return i18n("Undo move")
                case "delete": return i18n("Undo delete")
                default: return i18n("Undo")
                }
            }
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

    QQC2.BusyIndicator {
        Layout.alignment: Qt.AlignHCenter
        running: controller.loading && controller.emptyKind === "loading"
        visible: running && !Design.reducedMotion
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

    ListView {
        id: taskList
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 0
        clip: true
        spacing: Design.spaceSmall
        model: controller.taskModel
        visible: controller.emptyKind === "" || controller.emptyKind === "empty"
        reuseItems: true
        section.property: "bucket"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            required property string section
            width: taskList.width - taskList.leftMargin - taskList.rightMargin
            height: sectionLabel.implicitHeight + Design.spaceSmall
            QQC2.Label {
                id: sectionLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: {
                    switch (parent.section) {
                    case "catchup": return i18n("Still open")
                    case "morning": return i18n("Morning")
                    case "afternoon": return i18n("Afternoon")
                    case "evening": return i18n("Evening")
                    case "unspecified": return i18n("Anytime")
                    default: return parent.section
                    }
                }
                font.bold: true
                opacity: 0.7
                visible: text.length > 0
            }
        }
        // Small cache: fewer off-screen delegates to move/update while scrolling.
        cacheBuffer: Math.round(Kirigami.Units.gridUnit * 6)
        // Pixel-aligned scrolling reduces subpixel text relayout churn.
        pixelAligned: true
        boundsBehavior: Flickable.StopAtBounds

        // Narrow scrollbar + permanent gutter so edit icons never sit under it.
        readonly property int scrollBarExtent: Design.scrollBarExtent
        readonly property int scrollGutter: Design.scrollGutter
        rightMargin: scrollGutter

        QQC2.ScrollBar.vertical: ThinScrollBar {
            view: taskList
            parent: taskList
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
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

            ListView.onReused: {
                editorReserveHeight = (model.itemId === root.expandedItemId)
                    ? root.expandedEditorHeight
                    : 0
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
        }
    }

    readonly property real expandedEditorHeight: sharedInline.visible
        ? Math.ceil(sharedInline.implicitHeight) + Kirigami.Units.smallSpacing
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
        sharedInline.visible = true
        syncInlineGeometry()
        ensureExpandedVisible()
        geometrySettleTimer.restart()
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
        sharedInline.visible = false
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

        delegateItem.editorReserveHeight = root.expandedEditorHeight

        // Prefer the layout guide (checkbox.left → editButton.right); fall back to mapToItem.
        var left = 0
        var width = 0
        if (delegateItem.editorGuideItem && delegateItem.editorGuideItem.width > 1) {
            left = delegateItem.x + delegateItem.editorGuideItem.x
            width = delegateItem.editorGuideItem.width
        } else {
            left = delegateItem.x + delegateItem.editorContentX
            width = delegateItem.editorContentWidth
        }

        if (width < 1) {
            return
        }

        sharedInline.x = left
        sharedInline.y = delegateItem.y + delegateItem.collapsedHeight
        sharedInline.width = width
    }

    // Keep editor aligned when the expanded row finishes laying out.
    Connections {
        target: (sharedInline.visible && expandedIndex >= 0)
                ? taskList.itemAtIndex(expandedIndex)
                : null
        ignoreUnknownSignals: true
        function onWidthChanged() { root.syncInlineGeometry() }
        function onHeightChanged() { root.syncInlineGeometry() }
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
            // Model reset while editing — close to avoid stale geometry.
            if (sharedInline.visible && root.expandedIndex >= taskList.count) {
                root.collapseInline()
            }
            root.restoreScrollAnchor()
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
            onClicked: addTask()
            QQC2.ToolTip.text: i18n("Add task")
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
            padding: Kirigami.Units.smallSpacing
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
            z: 1500

        width: Math.min(Kirigami.Units.gridUnit * 18,
                        Math.max(Kirigami.Units.gridUnit * 12, parent.width - Kirigami.Units.largeSpacing * 2))
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - implicitHeight) / 2)

        background: Rectangle {
            radius: 4
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

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
                        spacing: Kirigami.Units.smallSpacing
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
