import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "views"
import "components"
import "colors.js" as Colors
import "." as KurrentUi

Item {
    id: fullRoot

    required property Item plasmoidRoot
    readonly property var backend: plasmoidRoot.backend
    readonly property alias taskListItem: mainPaneHost.taskList
    readonly property alias taskList: mainPaneHost.taskList

    clip: false
    anchors.fill: parent

    // Content stays inside Plasma's FrameSvg padding. Only the editor dim/card
    // reparent onto the applet container so they paint over that chrome.
    property Item overlayHost: fullRoot

    function resolveOverlayHost() {
        var p = fullRoot
        while (p) {
            if (p.isAppletContainer) {
                overlayHost = p
                return
            }
            p = p.parent
        }
        overlayHost = fullRoot
    }

    onParentChanged: resolveOverlayHost()
    Component.onCompleted: {
        resolveOverlayHost()
        plasmoidRoot.applyPopupBackground()
        initSortMenuCaches()
        Qt.callLater(function() {
            plasmoidRoot.applyMainPaneMode()
            plasmoidRoot.applySortForCurrentView()
        })
    }

    Connections {
        target: backend
        function onKanbanManualOrderJsonChanged() {
            if (!backend) {
                return
            }
            if (Plasmoid.configuration.kanbanManualOrder !== backend.kanbanManualOrderJson) {
                Plasmoid.configuration.kanbanManualOrder = backend.kanbanManualOrderJson
                plasmoidRoot.persistSharedSettings()
            }
        }
        function onSortModeChanged() {
            if (backend && backend.mainPaneMode === KurrentUi.Design.viewModeKanban
                    && backend.sortMode === "custom") {
                plasmoidRoot.persistSortMode("custom")
            }
        }
    }

    readonly property var hostWindow: Window.window
    onHostWindowChanged: plasmoidRoot.applyPopupBackground()

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            fullRoot.resolveOverlayHost()
            plasmoidRoot.applyPopupBackground()
        }
    }

    readonly property int editorMinOverallWidth: sidebar.sidebarWidth
            + Kirigami.Units.gridUnit * 48
            + KurrentUi.Design.panelGap
    readonly property bool editorCoversSidebar: fullRoot.width < editorMinOverallWidth

    implicitWidth: Kirigami.Units.gridUnit * 52
    implicitHeight: Kirigami.Units.gridUnit * 40

    Layout.minimumWidth: plasmoidRoot.inPanel ? Kirigami.Units.gridUnit * 28 : Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: plasmoidRoot.inPanel ? Kirigami.Units.gridUnit * 20 : Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.maximumWidth: Infinity
    Layout.maximumHeight: Infinity

    // Shared drag payload while a task is being dragged
    // ({ itemId, uid, summary, parentUid, categories, collectionId }).
    property var draggingTask: null
    property string dropHint: ""
    property real dragProxyOffsetX: 0
    property real dragProxyOffsetY: 0
    property int dragCursorSize: 24
    property int dragCursorShape: Qt.ClosedHandCursor
    property bool useTaskDragProxy: backend && backend.mainPaneMode !== KurrentUi.Design.viewModeKanban

    Shortcut {
        sequence: StandardKey.Undo
        enabled: backend.canUndo
        onActivated: backend.undo()
    }
    Shortcut {
        sequences: [StandardKey.Find, "/"]
        onActivated: taskList.focusSearch()
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: taskList.focusNewTask()
    }
    Shortcut {
        sequence: "1"; onActivated: backend.currentView = "inbox"
    }
    Shortcut {
        sequence: "2"; onActivated: backend.currentView = "today"
    }
    Shortcut {
        sequence: "3"; onActivated: backend.currentView = "overdue"
    }
    Shortcut {
        sequence: "4"; onActivated: backend.currentView = "tomorrow"
    }
    Shortcut {
        sequence: "5"; onActivated: backend.currentView = "scheduled"
    }
    Shortcut {
        sequence: "E"
        enabled: taskList.selectedItemId >= 0
        onActivated: taskList.openSelectedFullEditor()
    }
    Shortcut {
        sequence: "X"
        enabled: taskList.selectedItemId >= 0
        onActivated: backend.setTaskCompleted(taskList.selectedItemId, true)
    }
    Shortcut {
        sequence: "T"
        enabled: taskList.selectedItemId >= 0
        onActivated: backend.rescheduleTask(taskList.selectedItemId, "tomorrow")
    }
    Shortcut {
        sequence: StandardKey.Delete
        enabled: taskList.selectedItemId >= 0
        onActivated: taskList.requestDelete(taskList.selectedItemId)
    }

    function computeDragProxyGap(cursorSize, shape) {
        return backend.dragProxyGap(cursorSize, shape)
    }

    function dragLimitRight() {
        var margin = KurrentUi.Design.spaceSmall
        var sg = Plasmoid.screenGeometry
        var cpp = backend.dragScreenLimits()
        var right = Screen.virtualX + Screen.width
        if (sg && sg.width > 0) {
            right = sg.x + sg.width
        }
        if (cpp && cpp.right > 0) {
            right = Math.min(right, cpp.right)
        }
        return right - margin
    }

    function dragLimitBottom() {
        var margin = KurrentUi.Design.spaceSmall
        var sg = Plasmoid.screenGeometry
        var ar = Plasmoid.availableScreenRect
        var cpp = backend.dragScreenLimits()
        var screenBottom = Screen.virtualY + Screen.height
        if (sg && sg.height > 0) {
            screenBottom = sg.y + sg.height
        }

        // Prefer the work area (screen minus taskbar / panels).
        var bottoms = [screenBottom]
        var desktopAvailBottom = Screen.virtualY + Screen.desktopAvailableHeight
        if (desktopAvailBottom > Screen.virtualY) {
            bottoms.push(desktopAvailBottom)
        }
        if (cpp && cpp.bottom > 0) {
            bottoms.push(cpp.bottom)
        }
        if (ar && sg && ar.height > sg.height * 0.5) {
            var localBottom = sg.y + ar.y + ar.height
            var absBottom = ar.y + ar.height
            if (localBottom > sg.y && localBottom <= screenBottom + 1) {
                bottoms.push(localBottom)
            }
            if (absBottom > sg.y && absBottom <= screenBottom + 1) {
                bottoms.push(absBottom)
            }
        }

        var bottom = bottoms[0]
        for (var i = 1; i < bottoms.length; ++i) {
            if (bottoms[i] < bottom) {
                bottom = bottoms[i]
            }
        }
        return bottom - margin
    }

    function beginTaskDrag(payload) {
        dropHint = ""
        dragCursorShape = Qt.ClosedHandCursor
        dragCursorSize = backend.systemCursorSize()
        var gap = computeDragProxyGap(dragCursorSize, dragCursorShape)
        dragProxyOffsetX = gap.x
        dragProxyOffsetY = gap.y
        draggingTask = payload
        if (useTaskDragProxy) {
            dragProxy.Drag.active = true
        }
    }

    function updateTaskDragPosition(globalX, globalY) {
        var gap = computeDragProxyGap(dragCursorSize, dragCursorShape)
        var w = dragProxy.width
        var h = dragProxy.height
        var limitRight = dragLimitRight()
        var limitBottom = dragLimitBottom()

        var off = backend.clampDragProxyOffset(globalX, globalY, gap.x, gap.y, w, h, limitRight, limitBottom)
        dragProxyOffsetX = off.x
        dragProxyOffsetY = off.y
        var local = mapFromGlobal(globalX, globalY)
        dragProxy.x = local.x + off.x
        dragProxy.y = local.y + off.y
    }

    function endTaskDrag() {
        if (useTaskDragProxy && dragProxy.Drag.active) {
            dragProxy.Drag.drop()
        }
        dragProxy.Drag.active = false
        draggingTask = null
        dropHint = ""
    }

    function setDropHint(text) {
        dropHint = text || ""
    }

    function clearDropHint(text) {
        if (!text || dropHint === text) {
            dropHint = ""
        }
    }

    function openFullEditor(taskObj) {
        taskFullEditor.task = taskObj
        taskFullEditor.open()
    }

    function openNewTaskEditor(collectionId) {
        var taskObj = { itemId: -1, collectionId: collectionId || -1 }
        taskFullEditor.task = taskObj
        taskFullEditor.open()
    }

    readonly property string defaultSortMode: "priority,due,title"

    function parseSortKeys(mode) {
        var raw = String(mode || "").split(",").map(function(s) {
            return s.trim()
        }).filter(function(s) {
            return s.length > 0
        })
        // Legacy "default" / empty → Priority › Due › A–Z
        if (raw.length === 0 || (raw.length === 1 && raw[0] === "default")) {
            return ["priority", "due", "title"]
        }
        if (raw.length === 1 && raw[0] === "custom") {
            return ["custom", "none", "none"]
        }
        var keys = ["priority", "none", "none"]
        for (var i = 0; i < Math.min(3, raw.length); ++i) {
            keys[i] = raw[i] === "default" ? "priority" : raw[i]
        }
        for (var a = 0; a < 3; ++a) {
            for (var b = a + 1; b < 3; ++b) {
                if (keys[b] !== "none" && sortKeysConflict(keys[a], keys[b])) {
                    keys[b] = "none"
                }
            }
        }
        if (keys[1] === "none") {
            keys[2] = "none"
        }
        return keys
    }

    function buildSortMode(keys) {
        var first = keys[0] && keys[0] !== "none" && keys[0] !== "default"
                   ? keys[0] : "priority"
        var out = [first]
        if (keys[1] && keys[1] !== "none") {
            out.push(keys[1])
        }
        if (keys[2] && keys[2] !== "none") {
            out.push(keys[2])
        }
        return out.join(",")
    }

    // Shared atomic keys; compound modes like "due,priority" come from levels 1–3.
    // Opposite directions of the same field are mutually exclusive across levels.
    readonly property var sortOptions: [
        { id: "custom", label: i18n("Custom (manual)") },
        { id: "due", label: i18n("Due date") },
        { id: "dueDesc", label: i18n("Due date (latest first)") },
        { id: "start", label: i18n("Start date") },
        { id: "priority", label: i18n("Priority") },
        { id: "project", label: i18n("Project") },
        { id: "projectDesc", label: i18n("Project (Z–A)") },
        { id: "label", label: i18n("Label") },
        { id: "labelDesc", label: i18n("Label (Z–A)") },
        { id: "status", label: i18n("Status") },
        { id: "statusDesc", label: i18n("Status (reverse)") },
        { id: "secrecy", label: i18n("Secrecy") },
        { id: "secrecyDesc", label: i18n("Secrecy (reverse)") },
        { id: "location", label: i18n("Location") },
        { id: "locationDesc", label: i18n("Location (Z–A)") },
        { id: "title", label: i18n("Title A–Z") },
        { id: "titleDesc", label: i18n("Title Z–A") },
        { id: "reminder", label: i18n("Reminder first") },
        { id: "reminderDesc", label: i18n("Reminder last") },
        { id: "recurring", label: i18n("Recurring first") },
        { id: "recurringDesc", label: i18n("Recurring last") },
        { id: "progress", label: i18n("Progress %") },
        { id: "progressDesc", label: i18n("Progress % (high first)") },
        { id: "completed", label: i18n("Open first") }
    ]

    readonly property var kanbanColumnSourceOptions: [
        { id: "status", label: i18n("Status") },
        { id: "completion", label: i18n("Completion") },
        { id: "project", label: i18n("Project") },
        { id: "due", label: i18n("Due date buckets") },
        { id: "priority", label: i18n("Priority") },
        { id: "label", label: i18n("Label") },
        { id: "daysection", label: i18n("Day section") },
        { id: "secrecy", label: i18n("Secrecy") },
        { id: "column", label: i18n("Custom column (KURRENT/COLUMN)") }
    ]

    function kanbanColumnSourceLabel(source) {
        var label = kanbanColumnSourceLabelById[source]
        return label !== undefined ? label : source
    }

    function sortBlockedForKanban(sortId) {
        if (!backend || backend.mainPaneMode !== KurrentUi.Design.viewModeKanban) {
            return false
        }
        var src = backend.kanbanColumnSource
        if (src === "priority" && sortId === "priority") {
            return true
        }
        if (src === "due" && (sortId === "due" || sortId === "dueDesc")) {
            return true
        }
        if (src === "completion" && sortId === "completed") {
            return true
        }
        return false
    }

    function sortBlockedForListGroup(sortId) {
        if (!backend) {
            return false
        }
        var group = backend.listGroupMode || ""
        if (!group || group === "none") {
            return false
        }
        return sortFieldFamily(sortId) === group
    }

    readonly property var activeSortOptions: {
        var out = []
        var kanban = backend && backend.mainPaneMode === KurrentUi.Design.viewModeKanban
        var _group = backend ? (backend.listGroupMode || "") : ""
        for (var i = 0; i < sortOptions.length; ++i) {
            var id = sortOptions[i].id
            if (id === "custom" && !kanban) {
                continue
            }
            if (kanban && sortBlockedForKanban(id)) {
                continue
            }
            if (sortBlockedForListGroup(id)) {
                continue
            }
            out.push(sortOptions[i])
        }
        return out
    }

    readonly property var activeSortOptionIds: {
        var ids = {}
        var opts = activeSortOptions
        for (var i = 0; i < opts.length; ++i) {
            ids[opts[i].id] = true
        }
        return ids
    }

    readonly property var sortKeys: parseSortKeys(backend ? backend.sortMode : defaultSortMode)

    readonly property var viewModeOptions: [
        { id: KurrentUi.Design.viewModeList, label: i18n("List"), icon: "view-list-details" },
        { id: KurrentUi.Design.viewModeKanban, label: i18n("Kanban"), icon: "view-grid-symbolic" },
        { id: KurrentUi.Design.viewModeSwimlane, label: i18n("Swimlanes"), icon: "view-split-left-right" },
        { id: KurrentUi.Design.viewModePlan, label: i18n("Project plan"), icon: "view-pim-tasks" },
        { id: KurrentUi.Design.viewModeHeatmap, label: i18n("Heatmap"), icon: "view-statistics" },
        { id: KurrentUi.Design.viewModeCalendar, label: i18n("Agenda"), icon: "view-calendar-day" }
    ]

    function viewModeLabel(mode) {
        var label = viewModeLabelById[mode]
        return label !== undefined ? label : i18n("List")
    }

    readonly property int mainPaneIndex: {
        if (!backend) {
            return 0
        }
        switch (backend.mainPaneMode) {
        case KurrentUi.Design.viewModeKanban: return 1
        case KurrentUi.Design.viewModeSwimlane: return 2
        case KurrentUi.Design.viewModePlan: return 3
        case KurrentUi.Design.viewModeHeatmap: return 4
        case KurrentUi.Design.viewModeCalendar: return 5
        default: return 0
        }
    }

    readonly property var firstSortOptions: {
        var _ = sortKeys
        return optionsForSortLevel(0)
    }
    readonly property var secondSortOptions: {
        var _ = sortKeys
        return optionsForSortLevel(1)
    }
    readonly property var thirdSortOptions: {
        var _ = sortKeys
        return optionsForSortLevel(2)
    }

    function sortFieldFamily(id) {
        if (id === "title" || id === "titleDesc") {
            return "title"
        }
        if (id === "due" || id === "dueDesc") {
            return "due"
        }
        if (id === "start" || id === "startDesc") {
            return "start"
        }
        if (id === "reminder" || id === "reminderDesc") {
            return "reminder"
        }
        if (id === "recurring" || id === "recurringDesc") {
            return "recurring"
        }
        if (id === "progress" || id === "progressDesc") {
            return "progress"
        }
        if (id === "project" || id === "projectDesc") {
            return "project"
        }
        if (id === "label" || id === "labelDesc") {
            return "label"
        }
        if (id === "status" || id === "statusDesc") {
            return "status"
        }
        if (id === "secrecy" || id === "secrecyDesc") {
            return "secrecy"
        }
        if (id === "location" || id === "locationDesc") {
            return "location"
        }
        return id
    }

    readonly property var listGroupOptions: [
        { id: "none", label: i18n("None") },
        { id: "project", label: i18n("Project") },
        { id: "label", label: i18n("Label") },
        { id: "priority", label: i18n("Priority") },
        { id: "progress", label: i18n("Progress") },
        { id: "status", label: i18n("Status") },
        { id: "secrecy", label: i18n("Secrecy") },
        { id: "location", label: i18n("Location") }
    ]

    function listGroupLabel(mode) {
        var id = mode || "none"
        var label = listGroupLabelById[id]
        return label !== undefined ? label : i18n("None")
    }

    function stripSortKeysMatchingGroup(groupMode) {
        if (!groupMode) {
            return
        }
        var keys = parseSortKeys(backend.sortMode)
        var compacted = []
        var changed = false
        for (var i = 0; i < 3; ++i) {
            if (keys[i] === "none") {
                continue
            }
            if (sortFieldFamily(keys[i]) === groupMode) {
                changed = true
                continue
            }
            compacted.push(keys[i])
        }
        if (!changed) {
            return
        }
        if (compacted.length === 0) {
            compacted = ["due", "title"]
        }
        while (compacted.length < 3) {
            compacted.push("none")
        }
        applySortMode(buildSortMode(compacted))
    }

    function setListGroupMode(mode) {
        mainPaneHost.requestSortFeedback()
        var normalized = (!mode || mode === "none") ? "" : mode
        backend.listGroupMode = normalized
        Plasmoid.configuration.listGroupMode = normalized
        plasmoidRoot.persistSharedSettings()
        stripSortKeysMatchingGroup(normalized)
    }

    readonly property int mainPaneHeaderToolSize: KurrentUi.Design.mainPaneHeaderToolSize

    readonly property int viewModeToolbarExpandedWidth: KurrentUi.Design.viewModeToolbarStripWidth
    readonly property int viewModeToolbarCompactWidth: KurrentUi.Design.mainPaneHeaderToolSize

    readonly property int mainPaneHeaderToolsExpandedWidth: {
        var btn = KurrentUi.Design.mainPaneHeaderToolSize
        var s = KurrentUi.Design.spaceSmall
        var w = viewModeToolbarExpandedWidth
        if (backend && backend.mainPaneMode === KurrentUi.Design.viewModeKanban) w += btn + s
        if (backend && (backend.mainPaneMode === KurrentUi.Design.viewModeList
                || backend.mainPaneMode === KurrentUi.Design.viewModeKanban)) w += btn + s // Sort
        if (backend && backend.listGroupMode !== undefined
                && backend.mainPaneMode === KurrentUi.Design.viewModeList) w += btn + s
        if (backend && backend.canUndo) w += btn + s
        if (backend && backend.devBuild) w += devBuildLabelWidth + s
        if (!backend || !backend.akonadiAvailable) w += offlineLabelWidth + s
        if (backend && backend.akonadiAvailable && backend.syncingCount > 0)
                w += syncingLabelWidth + s
        return w
    }

    readonly property int mainPaneHeaderToolsCompactWidth: {
        var btn = KurrentUi.Design.mainPaneHeaderToolSize
        var s = KurrentUi.Design.spaceSmall
        var w = viewModeToolbarCompactWidth
        if (backend && backend.mainPaneMode === KurrentUi.Design.viewModeKanban) w += btn + s
        if (backend && (backend.mainPaneMode === KurrentUi.Design.viewModeList
                || backend.mainPaneMode === KurrentUi.Design.viewModeKanban)) w += btn + s // Sort
        if (backend && backend.listGroupMode !== undefined
                && backend.mainPaneMode === KurrentUi.Design.viewModeList) w += btn + s
        if (backend && backend.canUndo) w += btn + s
        if (backend && backend.devBuild) w += devBuildLabelWidth + s
        if (!backend || !backend.akonadiAvailable) w += offlineLabelWidth + s
        if (backend && backend.akonadiAvailable && backend.syncingCount > 0)
                w += syncingLabelWidth + s
        return w
    }

    // Measured label widths for conditional header items via hidden Text metrics.
    Text {
        id: devBuildMetrics
        visible: false
        parent: fullRoot
        text: i18n("Build") + " " + String(backend ? backend.buildNumber : 0)
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        font.bold: true
    }
    readonly property int devBuildLabelWidth: Math.round(devBuildMetrics.contentWidth
            + KurrentUi.Design.spaceSmall * 2)

    Text {
        id: offlineMetrics
        visible: false
        parent: fullRoot
        text: i18n("Akonadi offline")
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
    }
    readonly property int offlineLabelWidth: Math.round(offlineMetrics.contentWidth)

    Text {
        id: syncingMetrics
        visible: false
        parent: fullRoot
        text: i18n("Syncing…")
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
    }
    readonly property int syncingLabelWidth: Math.round(syncingMetrics.contentWidth)

    readonly property int mainPaneHeaderTitleMinWidth: Kirigami.Units.gridUnit * 3
    // View icon + spacing to the left of the title.
    readonly property int mainPaneHeaderLeftWidth:
            Kirigami.Units.iconSizes.smallMedium + KurrentUi.Design.spaceSmall

    // Filter chips: icon-only width (no text)
    readonly property int filterChipIconSize: Kirigami.Units.iconSizes.small
    readonly property int filterChipSpacing: 2
    readonly property int filterSeparatorWidth: KurrentUi.Design.spaceSmall
    readonly property int filterIconOnlyWidth: {
        var n = plasmoidRoot.activeFilters ? plasmoidRoot.activeFilters.length : 0
        return n * (filterChipIconSize + filterChipSpacing * 2)
    }

    // Expand toolbar when title + filter icons + separator + expanded tools fit.
    // Filter text elides into the remaining gap; only icon-only filters remain at the threshold.
    readonly property bool viewModeToolbarExpanded:
            mainPane.width >= mainPaneHeaderLeftWidth + mainPaneHeaderTitleMinWidth
                    + filterIconOnlyWidth + filterSeparatorWidth
                    + mainPaneHeaderToolsExpandedWidth

    // Dynamic maximum width for filter text labels: 0 = icon-only.
    readonly property int availableFilterTextWidth: {
        if (!plasmoidRoot.activeFilters || plasmoidRoot.activeFilters.length === 0) {
            return 0
        }
        var toolsWidth = viewModeToolbarExpanded
                ? mainPaneHeaderToolsExpandedWidth
                : mainPaneHeaderToolsCompactWidth
        var used = mainPaneHeaderLeftWidth + mainPaneHeaderTitleMinWidth
                + filterIconOnlyWidth + filterSeparatorWidth + toolsWidth
        var avail = mainPane.width - used
        if (avail <= 0) return 0
        return Math.min(avail, Kirigami.Units.gridUnit * 12)
    }

    function openGroupMenu() {
        const anchor = groupButton
        if (!anchor || !anchor.visible) {
            return
        }
        var margin = KurrentUi.Design.spaceSmall
        var below = anchor.mapToItem(fullRoot, 0, anchor.height + margin)
        var buttonTop = anchor.mapToItem(fullRoot, 0, 0)
        var buttonRight = anchor.mapToItem(fullRoot, anchor.width, 0).x
        var spaceBelow = fullRoot.height - below.y - margin
        var spaceAbove = buttonTop.y - margin
        var openBelow = spaceBelow >= Kirigami.Units.gridUnit * 8 || spaceBelow >= spaceAbove
        var y = openBelow ? below.y : Math.max(margin, buttonTop.y - margin)

        groupMenu.popup(fullRoot, 0, y)
        Qt.callLater(function() {
            groupMenu.x = Math.max(margin, Math.min(buttonRight - groupMenu.width,
                                                   fullRoot.width - groupMenu.width - margin))
            if (!openBelow) {
                groupMenu.y = Math.max(margin, buttonTop.y - margin - groupMenu.height)
            }
        })
    }

    function sortKeysConflict(a, b) {
        if (!a || !b || a === "none" || b === "none") {
            return false
        }
        return sortFieldFamily(a) === sortFieldFamily(b)
    }

    function sortKeyLabel(id) {
        if (!id || id === "none") {
            return sortKeyLabelById["none"] || i18n("None")
        }
        var label = sortKeyLabelById[id]
        return label !== undefined ? label : id
    }

    function sortModeLabel(mode) {
        if (String(mode) === "custom") {
            return i18n("Custom (manual)")
        }
        var keys = parseSortKeys(mode)
        var parts = [sortKeyLabel(keys[0])]
        if (keys[1] && keys[1] !== "none") {
            parts.push(sortKeyLabel(keys[1]))
        }
        if (keys[2] && keys[2] !== "none") {
            parts.push(sortKeyLabel(keys[2]))
        }
        return parts.join(" › ")
    }

    function optionsForSortLevel(level) {
        var keys = sortKeys
        var allowed = activeSortOptionIds
        var out = []
        var master = sortOptionsAlphabetical
        for (var m = 0; m < master.length; ++m) {
            var opt = master[m]
            if (opt.id === "none") {
                if (level === 0) {
                    continue
                }
            } else if (!allowed[opt.id]) {
                continue
            }
            var blocked = false
            for (var i = 0; i < level; ++i) {
                if (sortKeysConflict(keys[i], opt.id)) {
                    blocked = true
                    break
                }
            }
            if (!blocked) {
                out.push(opt)
            }
        }
        return out
    }

    function applySortMode(mode) {
        mainPaneHost.requestSortFeedback()
        backend.sortMode = mode
        plasmoidRoot.persistSortMode(mode)
    }

    function setSortLevel(level, id) {
        var keys = parseSortKeys(backend.sortMode)
        keys[level] = id
        if (level === 1 && id === "none") {
            keys[2] = "none"
        }
        if (id !== "none") {
            for (var i = level + 1; i < 3; ++i) {
                if (sortKeysConflict(id, keys[i])) {
                    keys[i] = "none"
                }
            }
        }
        applySortMode(buildSortMode(keys))
    }

    // Wide/narrow thresholds + sort lookups (once at startup — not on each open).
    property int sortMenuWideMinWidth: 0
    property int sortMenuNarrowMinWidth: 0
    property var sortOptionLabelWidthById: ({})
    property var sortOptionsAlphabetical: []
    property var sortKeyLabelById: ({})
    property var kanbanColumnSourceLabelById: ({})
    property var viewModeLabelById: ({})
    property var listGroupLabelById: ({})

    function sortMenuLabelWidth(label) {
        sortLabelMetrics.text = label || ""
        return sortLabelMetrics.width
    }

    function initOptionLabelMaps() {
        var kanban = {}
        for (var k = 0; k < kanbanColumnSourceOptions.length; ++k) {
            kanban[kanbanColumnSourceOptions[k].id] = kanbanColumnSourceOptions[k].label
        }
        kanbanColumnSourceLabelById = kanban

        var modes = {}
        for (var v = 0; v < viewModeOptions.length; ++v) {
            modes[viewModeOptions[v].id] = viewModeOptions[v].label
        }
        viewModeLabelById = modes

        var groups = {}
        for (var g = 0; g < listGroupOptions.length; ++g) {
            groups[listGroupOptions[g].id] = listGroupOptions[g].label
        }
        listGroupLabelById = groups
    }

    function initSortMenuCaches() {
        var chrome = KurrentUi.Design.sortMenuRadioChrome
        var pad = KurrentUi.Design.spaceSmall
        var widest = 0
        var widthById = {}
        var labelById = {}
        for (var i = 0; i < sortOptions.length; ++i) {
            var opt = sortOptions[i]
            var w = sortMenuLabelWidth(opt.label)
            widthById[opt.id] = w
            labelById[opt.id] = opt.label
            widest = Math.max(widest, w)
        }
        var noneLabel = i18n("None")
        var noneW = sortMenuLabelWidth(noneLabel)
        widthById["none"] = noneW
        labelById["none"] = noneLabel
        widest = Math.max(widest, noneW)
        sortOptionLabelWidthById = widthById
        sortKeyLabelById = labelById

        var all = sortOptions.slice()
        all.push({ id: "none", label: noneLabel })
        all.sort(function(a, b) {
            return a.label.localeCompare(b.label)
        })
        sortOptionsAlphabetical = all

        var col = widest + chrome + pad
        sortMenuWideMinWidth = 3 * col + 2 * KurrentUi.Design.spaceLarge + pad * 4
        sortMenuNarrowMinWidth = widest + chrome + pad * 3

        initOptionLabelMaps()
    }

    function openSortMenu() {
        var margin = KurrentUi.Design.spaceSmall
        var maxWidth = Math.max(Kirigami.Units.gridUnit * 8, fullRoot.width - margin * 2)
        var minWide = fullRoot.sortMenuWideMinWidth
        sortMenu.useWideLayout = maxWidth >= minWide
        sortMenu.width = sortMenu.useWideLayout
                ? Math.min(maxWidth, Math.max(minWide, KurrentUi.Design.sortMenuWideMaxWidth))
                : Math.min(KurrentUi.Design.sortMenuNarrowMaxWidth,
                           Math.max(Kirigami.Units.gridUnit * 11,
                                    Math.max(fullRoot.sortMenuNarrowMinWidth, maxWidth)))

        var below = sortButton.mapToItem(fullRoot, 0, sortButton.height + margin)
        var buttonTop = sortButton.mapToItem(fullRoot, 0, 0)
        var buttonRight = sortButton.mapToItem(fullRoot, sortButton.width, 0).x
        var spaceBelow = fullRoot.height - below.y - margin
        var spaceAbove = buttonTop.y - margin
        var wantedHeight = Math.min(Kirigami.Units.gridUnit * 22, Math.max(spaceBelow, spaceAbove))
        sortMenu.height = wantedHeight
        var openBelow = spaceBelow >= Math.min(wantedHeight, Kirigami.Units.gridUnit * 10)
                        || spaceBelow >= spaceAbove

        if (openBelow) {
            sortMenu.y = below.y
            sortMenu.height = Math.min(wantedHeight, spaceBelow)
        } else {
            sortMenu.height = Math.min(wantedHeight, spaceAbove)
            sortMenu.y = Math.max(margin, buttonTop.y - margin - sortMenu.height)
        }

        sortMenu.x = Math.max(margin, Math.min(buttonRight - sortMenu.width,
                                               fullRoot.width - sortMenu.width - margin))
        sortMenu.open()
    }

    function setKanbanColumnSource(source) {
        if (!backend) {
            return
        }
        backend.kanbanColumnSource = source
        if (source === "label") {
            backend.selectedLabel = ""
        } else if (source === "project") {
            backend.selectedCollectionId = -1
        } else if (source === "priority") {
            backend.selectedPriority = -1
        } else if (source === "status") {
            backend.selectedStatus = -1
        } else if (source === "completion") {
            backend.selectedProgressBand = ""
        }
        Plasmoid.configuration.kanbanColumnSource = source
        plasmoidRoot.persistSharedSettings()
        plasmoidRoot.applySortForCurrentView()
    }

    function openKanbanColumnsMenu() {
        var margin = KurrentUi.Design.spaceSmall
        var below = kanbanColumnsButton.mapToItem(fullRoot, 0, kanbanColumnsButton.height + margin)
        var buttonTop = kanbanColumnsButton.mapToItem(fullRoot, 0, 0)
        var buttonRight = kanbanColumnsButton.mapToItem(fullRoot, kanbanColumnsButton.width, 0).x
        var spaceBelow = fullRoot.height - below.y - margin
        var spaceAbove = buttonTop.y - margin
        var openBelow = spaceBelow >= Kirigami.Units.gridUnit * 8 || spaceBelow >= spaceAbove
        var y = openBelow ? below.y : Math.max(margin, buttonTop.y - margin)

        kanbanColumnsMenu.popup(fullRoot, 0, y)
        Qt.callLater(function() {
            kanbanColumnsMenu.x = Math.max(margin, Math.min(buttonRight - kanbanColumnsMenu.width,
                                                          fullRoot.width - kanbanColumnsMenu.width - margin))
            if (!openBelow) {
                kanbanColumnsMenu.y = Math.max(margin, buttonTop.y - margin - kanbanColumnsMenu.height)
            }
        })
    }

    function openViewModeMenu() {
        var margin = KurrentUi.Design.spaceSmall
        var below = viewModeToolbar.compactViewModeButton.mapToItem(fullRoot, 0,
                viewModeToolbar.compactViewModeButton.height + margin)
        var buttonTop = viewModeToolbar.compactViewModeButton.mapToItem(fullRoot, 0, 0)
        var buttonRight = viewModeToolbar.compactViewModeButton.mapToItem(fullRoot,
                viewModeToolbar.compactViewModeButton.width, 0).x
        var spaceBelow = fullRoot.height - below.y - margin
        var spaceAbove = buttonTop.y - margin
        var openBelow = spaceBelow >= Kirigami.Units.gridUnit * 8 || spaceBelow >= spaceAbove
        var y = openBelow ? below.y : Math.max(margin, buttonTop.y - margin)

        viewModeMenu.popup(fullRoot, 0, y)
        Qt.callLater(function() {
            viewModeMenu.x = Math.max(margin, Math.min(buttonRight - viewModeMenu.width,
                                                       fullRoot.width - viewModeMenu.width - margin))
            if (!openBelow) {
                viewModeMenu.y = Math.max(margin, buttonTop.y - margin - viewModeMenu.height)
            }
        })
    }

    Rectangle {
        id: editorDim
        parent: fullRoot.overlayHost
        anchors.fill: parent
        z: 1999
        visible: taskFullEditor.visible
        radius: parent && parent !== fullRoot ? KurrentUi.Design.overlayHostRadius : 0
        color: Qt.rgba(0, 0, 0, KurrentUi.Design.overlayDim)

        MouseArea {
            anchors.fill: parent
            // Capture hover so FrameSvg/HoverHandler under the dim do not flash.
            hoverEnabled: true
            onClicked: taskFullEditor.reject()
        }
    }

    RowLayout {
        id: shellRow
        anchors.fill: parent
        implicitWidth: 0
        implicitHeight: 0
        spacing: KurrentUi.Design.panelGap

        SidebarView {
            id: sidebar
            controller: backend
            filterPolicy: plasmoidRoot
            dragHost: fullRoot
            interactionsSuspended: taskFullEditor.visible
            hiddenProjects: Plasmoid.configuration.hiddenProjects || ""
            hiddenLabels: Plasmoid.configuration.hiddenLabels || ""
            hiddenLocations: Plasmoid.configuration.hiddenLocations || ""
            sidebarRowSize: Plasmoid.configuration.sidebarRowSize || "auto"
            showEmptyProjects: Plasmoid.configuration.showEmptyProjects === true
            showSidebarCounts: Plasmoid.configuration.showSidebarCounts !== false
            sectionOrder: Plasmoid.configuration.sidebarSectionOrder || "views,projects,labels,priorities,progress,status,secrecy,location"
            hiddenSections: Plasmoid.configuration.hiddenSidebarSections ?? "progress||status||secrecy||location"
            viewOrder: Plasmoid.configuration.sidebarViewOrder || ""
            hiddenViews: Plasmoid.configuration.hiddenViews || ""
        }

        Kirigami.Separator {
            id: sidebarSplitter
            Layout.fillHeight: true
            Layout.preferredWidth: 1

            // Drag hit area: resize sidebar width (6–20 grid units), persist to config.
            MouseArea {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(KurrentUi.Design.spaceMedium, Kirigami.Units.gridUnit)
                cursorShape: Qt.SplitHCursor
                hoverEnabled: true
                preventStealing: true
                property real pressGlobalX: 0
                property int pressUnits: 10

                onPressed: function(mouse) {
                    pressGlobalX = mapToItem(shellRow, mouse.x, 0).x
                    pressUnits = KurrentUi.Design.sidebarWidthUnits
                }
                onPositionChanged: function(mouse) {
                    if (!pressed) {
                        return
                    }
                    var x = mapToItem(shellRow, mouse.x, 0).x
                    var dx = x - pressGlobalX
                    var units = Math.round(pressUnits + dx / Kirigami.Units.gridUnit)
                    units = Math.max(6, Math.min(20, units))
                    if (units === KurrentUi.Design.sidebarWidthUnits) {
                        return
                    }
                    KurrentUi.Design.sidebarWidthUnits = units
                    Plasmoid.configuration.sidebarWidthUnits = units
                }
            }
        }

        Item {
            id: mainPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            Layout.minimumHeight: 0
            Layout.maximumHeight: Infinity

            ColumnLayout {
                anchors.fill: parent
                spacing: KurrentUi.Design.spaceSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: KurrentUi.Design.spaceSmall

                Kirigami.Icon {
                    source: plasmoidRoot.activeViewIconSource()
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: Kirigami.Units.iconSizes.smallMedium
                    Layout.alignment: Qt.AlignVCenter
                }

                Kirigami.Heading {
                    Layout.alignment: Qt.AlignVCenter
                    level: 3
                    text: plasmoidRoot.activeViewTitle()
                    elide: Text.ElideRight
                }

                // Active filters right of the title, separated by "|".
                // Filter text elides to icon-only when space is tight.
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: KurrentUi.Design.spaceSmall
                    visible: plasmoidRoot.activeFilters && plasmoidRoot.activeFilters.length > 0

                    QQC2.Label {
                        text: "|"
                        opacity: 0.4
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Repeater {
                        model: plasmoidRoot.activeFilters
                        delegate: RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: fullRoot.filterChipIconSize
                                Layout.preferredHeight: fullRoot.filterChipIconSize
                                source: modelData.kind === "project" ? "folder"
                                      : modelData.kind === "priority" ? "flag"
                                      : modelData.kind === "progress" ? "view-list-details"
                                      : modelData.kind === "status" ? "view-calendar-tasks"
                                      : modelData.kind === "secrecy" ? "object-unlocked"
                                      : modelData.kind === "location" ? "mark-location"
                                      : "tag"
                                color: modelData.kind === "priority"
                                       ? Colors.colorForPriority(modelData.key)
                                       : KurrentUi.Design.colorForKey(modelData.key, modelData.kind === "label" ? "label" : "project")
                                width: fullRoot.filterChipIconSize
                                height: fullRoot.filterChipIconSize
                            }

                            QQC2.Label {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.maximumWidth: fullRoot.availableFilterTextWidth
                                text: modelData.text
                                opacity: 0.8
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    id: headerTools
                    Layout.fillWidth: false
                    Layout.minimumWidth: implicitWidth
                    spacing: KurrentUi.Design.spaceSmall

                QQC2.ToolButton {
                    id: undoButton
                    visible: backend.canUndo
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: fullRoot.mainPaneHeaderToolSize
                    Layout.preferredHeight: fullRoot.mainPaneHeaderToolSize
                    Layout.minimumWidth: fullRoot.mainPaneHeaderToolSize
                    icon.name: "edit-undo"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: backend.undo()
                    QQC2.ToolTip.text: backend.undoLabel
                    QQC2.ToolTip.visible: hovered
                }

                QQC2.ToolButton {
                    id: groupButton
                    visible: backend && backend.listGroupMode !== undefined
                            && backend.mainPaneMode === KurrentUi.Design.viewModeList
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: fullRoot.mainPaneHeaderToolSize
                    Layout.preferredHeight: fullRoot.mainPaneHeaderToolSize
                    Layout.minimumWidth: fullRoot.mainPaneHeaderToolSize
                    icon.name: "view-list-tree"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: fullRoot.openGroupMenu()
                    QQC2.ToolTip.text: backend
                            ? i18n("Group: %1", fullRoot.listGroupLabel(backend.listGroupMode || "none"))
                            : ""
                    QQC2.ToolTip.visible: hovered
                }

                QQC2.ToolButton {
                    id: kanbanColumnsButton
                    visible: backend && backend.mainPaneMode === KurrentUi.Design.viewModeKanban
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: fullRoot.mainPaneHeaderToolSize
                    Layout.preferredHeight: fullRoot.mainPaneHeaderToolSize
                    Layout.minimumWidth: fullRoot.mainPaneHeaderToolSize
                    icon.name: "view-file-columns"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: fullRoot.openKanbanColumnsMenu()
                    QQC2.ToolTip.text: i18n("Kanban columns: %1", fullRoot.kanbanColumnSourceLabel(backend.kanbanColumnSource))
                    QQC2.ToolTip.visible: hovered
                }

                QQC2.ToolButton {
                    id: sortButton
                    visible: backend && (backend.mainPaneMode === KurrentUi.Design.viewModeList
                            || backend.mainPaneMode === KurrentUi.Design.viewModeKanban)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: fullRoot.mainPaneHeaderToolSize
                    Layout.preferredHeight: fullRoot.mainPaneHeaderToolSize
                    Layout.minimumWidth: fullRoot.mainPaneHeaderToolSize
                    icon.name: "view-sort"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: fullRoot.openSortMenu()
                    QQC2.ToolTip.text: i18n("Sort: %1", fullRoot.sortModeLabel(backend.sortMode))
                    QQC2.ToolTip.visible: hovered
                }

                ViewModeToolbar {
                    id: viewModeToolbar
                    Layout.alignment: Qt.AlignVCenter
                    expanded: fullRoot.viewModeToolbarExpanded
                    fullRoot: fullRoot
                    plasmoidRoot: plasmoidRoot
                    mainPaneHost: mainPaneHost
                }

                QQC2.Menu {
                    id: viewModeMenu
                    parent: fullRoot
                    popupType: QQC2.Popup.Item
                    title: i18n("View mode")

                    Repeater {
                        model: fullRoot.viewModeOptions
                        delegate: QQC2.MenuItem {
                            required property var modelData
                            text: modelData.label
                            icon.name: modelData.icon
                            checkable: true
                            checked: backend.mainPaneMode === modelData.id
                            onTriggered: {
                                mainPaneHost.beginViewTransition(modelData.id)
                                plasmoidRoot.setMainPaneMode(modelData.id)
                            }
                        }
                    }
                }

                QQC2.Menu {
                    id: kanbanColumnsMenu
                    parent: fullRoot
                    popupType: QQC2.Popup.Item
                    title: i18n("Kanban columns")

                    Repeater {
                        model: fullRoot.kanbanColumnSourceOptions
                        delegate: QQC2.MenuItem {
                            required property var modelData
                            text: modelData.label
                            checkable: true
                            checked: backend.kanbanColumnSource === modelData.id
                            onTriggered: fullRoot.setKanbanColumnSource(modelData.id)
                        }
                    }
                }

                QQC2.Menu {
                    id: groupMenu
                    parent: fullRoot
                    popupType: QQC2.Popup.Item
                    title: i18n("Group tasks")

                    Repeater {
                        model: fullRoot.listGroupOptions
                        delegate: QQC2.MenuItem {
                            required property var modelData
                            text: modelData.label
                            checkable: true
                            checked: (backend.listGroupMode || "none") === modelData.id
                            onTriggered: fullRoot.setListGroupMode(modelData.id)
                        }
                    }
                }

                QQC2.Label {
                    visible: backend.devBuild
                    text: i18n("Build") + " " + String(backend.buildNumber)
                    opacity: 0.85
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: KurrentUi.Design.spaceSmall
                }

                QQC2.Label {
                    visible: !backend.akonadiAvailable
                    text: i18n("Akonadi offline")
                    color: Kirigami.Theme.negativeTextColor
                    Layout.alignment: Qt.AlignVCenter
                }

                QQC2.Label {
                    visible: backend.akonadiAvailable && backend.syncingCount > 0
                    text: i18n("Syncing…")
                    opacity: 0.85
                    Layout.alignment: Qt.AlignVCenter
                }
                }
            }

            VersionMismatchBanner {
                visible: plasmoidRoot.backendVersionMismatch
                Layout.fillWidth: true
                widgetVersion: plasmoidRoot.widgetVersion
                backendVersion: plasmoidRoot.backendVersion
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: backend.conflictItemId >= 0
                type: Kirigami.MessageType.Warning
                text: i18n("This task was changed on the server. Reload to discard your edit.")
                actions: [
                    Kirigami.Action {
                        text: i18n("Reload")
                        onTriggered: backend.reloadTask(backend.conflictItemId)
                    },
                    Kirigami.Action {
                        text: i18n("Dismiss")
                        onTriggered: backend.dismissConflict()
                    }
                ]
            }

            BulkActionBar {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.multiSelectEnabled === true
                controller: backend
            }

            MainPaneHost {
                id: mainPaneHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 0
                Layout.minimumHeight: 0
                controller: backend
                dragHost: fullRoot
                interactionsSuspended: taskFullEditor.visible
                hiddenProjects: Plasmoid.configuration.hiddenProjects || ""
                newTaskProjectMode: Plasmoid.configuration.newTaskProjectMode || "ask"
                newTaskDefaultCollectionId: Plasmoid.configuration.newTaskDefaultCollectionId || ""
                multiSelectEnabled: Plasmoid.configuration.multiSelectEnabled === true
                onOpenFullEditor: function(taskObj) { fullRoot.openFullEditor(taskObj) }
            }
            }

            MainPaneWidgetChrome {
                active: mainPaneHost.widgetOverlayActive
                dimBehind: mainPaneHost.widgetOverlayDim
            }
        }
    }

    Rectangle {
        id: dragProxy
        z: 1000
        readonly property int contentPad: KurrentUi.Design.spaceSmall
        readonly property int moveIconSize: Kirigami.Units.iconSizes.small

        width: Math.min(Math.max(proxyContent.implicitWidth + contentPad * 2,
                                 Kirigami.Units.gridUnit * 8),
                        Kirigami.Units.gridUnit * 22)
        height: proxyContent.implicitHeight + contentPad * 2
        radius: 4
        visible: Drag.active && !!fullRoot.draggingTask && fullRoot.useTaskDragProxy
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.highlightColor
        border.width: fullRoot.dropHint !== "" ? 2 : 1
        opacity: 0.95

        Drag.keys: ["application/x-kurrent-task"]
        Drag.dragType: Drag.Internal
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot.x: -fullRoot.dragProxyOffsetX
        Drag.hotSpot.y: -fullRoot.dragProxyOffsetY
        Drag.mimeData: {
            "application/x-kurrent-task": fullRoot.draggingTask
                ? String(fullRoot.draggingTask.itemId)
                : ""
        }

        ColumnLayout {
            id: proxyContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: dragProxy.contentPad
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: KurrentUi.Design.spaceSmall

                Kirigami.Icon {
                    id: moveIcon
                    source: "transform-move"
                    Layout.preferredWidth: dragProxy.moveIconSize
                    Layout.preferredHeight: dragProxy.moveIconSize
                    Layout.alignment: Qt.AlignVCenter
                    width: dragProxy.moveIconSize
                    height: dragProxy.moveIconSize
                }

                Repeater {
                    model: fullRoot.draggingTask ? (fullRoot.draggingTask.categories || []) : []
                    delegate: Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "tag"
                        color: KurrentUi.Design.colorForKey(String(modelData), "label")
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: fullRoot.draggingTask ? (fullRoot.draggingTask.summary || i18n("(Untitled)")) : ""
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: fullRoot.dropHint !== ""
                text: fullRoot.dropHint
                color: Kirigami.Theme.textColor
                opacity: 0.92
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
        }
    }

    TextMetrics {
        id: sortLabelMetrics
        font: Kirigami.Theme.defaultFont
    }

    QQC2.Popup {
        id: sortMenu
        parent: fullRoot
        popupType: QQC2.Popup.Item
        property bool useWideLayout: false
        modal: false
        dim: false
        focus: true
        padding: KurrentUi.Design.spaceSmall
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        z: 1500

        background: Rectangle {
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.textColor,
                                                                  Kirigami.Theme.backgroundColor, 0.85)
            border.width: 1
            radius: KurrentUi.Design.inputRadius
        }

        contentItem: ColumnLayout {
            spacing: KurrentUi.Design.spaceSmall

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Sort tasks")
                font.bold: true
            }

            Flickable {
                id: sortFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: sortMenu.useWideLayout ? sortWideRow.implicitHeight : sortColumn.implicitHeight
                // Same stack as the task list: WheelHandler + overshoot rebound.
                boundsBehavior: Flickable.OvershootBounds
                flickableDirection: Flickable.VerticalFlick

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

                Kirigami.WheelHandler {
                    id: sortWheelHandler
                    target: sortFlick
                    filterMouseEvents: true
                    onWheel: function(wheel) {
                        sortWheelIdle.restart()
                    }
                }
                Timer {
                    id: sortWheelIdle
                    interval: 400
                    repeat: false
                    onTriggered: sortFlick.settleScrollBounds()
                }

                QQC2.ScrollBar.vertical: ThinScrollBar {
                    view: sortFlick
                    parent: sortFlick
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    stepSize: sortFlick.contentHeight > 0
                            ? sortWheelHandler.verticalStepSize / sortFlick.contentHeight
                            : 0.1
                }
                QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
                    policy: QQC2.ScrollBar.AlwaysOff
                }

                component SortLevelGroup: ColumnLayout {
                    property string heading
                    property var options
                    property int level
                    property string currentId
                    spacing: KurrentUi.Design.spaceTiny

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: heading
                        opacity: 0.8
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    Repeater {
                        model: options
                        delegate: QQC2.RadioButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label
                            autoExclusive: false
                            checked: currentId === modelData.id
                            onClicked: fullRoot.setSortLevel(level, modelData.id)
                        }
                    }
                }

                ColumnLayout {
                    id: sortColumn
                    width: sortFlick.width
                    spacing: KurrentUi.Design.spaceMedium
                    visible: !sortMenu.useWideLayout

                    SortLevelGroup {
                        Layout.fillWidth: true
                        heading: i18n("First sort")
                        options: fullRoot.firstSortOptions
                        level: 0
                        currentId: fullRoot.sortKeys[0]
                    }

                    SortLevelGroup {
                        Layout.fillWidth: true
                        heading: i18n("Second sort")
                        options: fullRoot.secondSortOptions
                        level: 1
                        currentId: fullRoot.sortKeys[1]
                    }

                    SortLevelGroup {
                        Layout.fillWidth: true
                        heading: i18n("Third sort")
                        options: fullRoot.thirdSortOptions
                        level: 2
                        currentId: fullRoot.sortKeys[2]
                        enabled: fullRoot.sortKeys[1] !== "none"
                        opacity: enabled ? 1 : 0.45
                    }
                }

                RowLayout {
                    id: sortWideRow
                    width: sortFlick.width
                    spacing: KurrentUi.Design.spaceLarge
                    visible: sortMenu.useWideLayout

                    SortLevelGroup {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        heading: i18n("First sort")
                        options: fullRoot.firstSortOptions
                        level: 0
                        currentId: fullRoot.sortKeys[0]
                    }

                    SortLevelGroup {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        heading: i18n("Second sort")
                        options: fullRoot.secondSortOptions
                        level: 1
                        currentId: fullRoot.sortKeys[1]
                    }

                    SortLevelGroup {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        heading: i18n("Third sort")
                        options: fullRoot.thirdSortOptions
                        level: 2
                        currentId: fullRoot.sortKeys[2]
                        enabled: fullRoot.sortKeys[1] !== "none"
                        opacity: enabled ? 1 : 0.45
                    }
                }
            }
        }
    }

    TaskEditorSheet {
        id: taskFullEditor
        parent: fullRoot.overlayHost
        z: 2000
        controller: backend
        coverSidebar: fullRoot.editorCoversSidebar
        sidebarReserve: sidebar.sidebarWidth + shellRow.spacing + 1
        hostPadLeft: (fullRoot.overlayHost && fullRoot.overlayHost !== fullRoot)
                     ? (fullRoot.overlayHost.leftPadding || 0) : 0
        hostPadTop: (fullRoot.overlayHost && fullRoot.overlayHost !== fullRoot)
                    ? (fullRoot.overlayHost.topPadding || 0) : 0
        hostPadRight: (fullRoot.overlayHost && fullRoot.overlayHost !== fullRoot)
                      ? (fullRoot.overlayHost.rightPadding || 0) : 0
        hostPadBottom: (fullRoot.overlayHost && fullRoot.overlayHost !== fullRoot)
                       ? (fullRoot.overlayHost.bottomPadding || 0) : 0
        anchors.fill: parent
    }

    SmokeTest {
        id: smokeTest
        plasmoidRoot: fullRoot.plasmoidRoot
        backend: fullRoot.backend
        fullRoot: fullRoot
        taskList: taskList
        taskFullEditor: taskFullEditor
        sortMenu: sortMenu
    }
}
