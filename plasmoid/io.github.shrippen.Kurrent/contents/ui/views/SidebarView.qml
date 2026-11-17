import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kirigami.delegates as KirigamiDelegates
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import io.github.shrippen.Kurrent 1.0
import "../colors.js" as Colors
import "../sidebarheight.js" as SidebarHeight
import "../components"
import ".."
import "../Kante"

Item {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property string hiddenProjects: ""
    property string hiddenLabels: ""
    property string hiddenLocations: ""
    // "auto" | "compact" | "comfortable"
    property string sidebarRowSize: "auto"
    property bool showEmptyProjects: false
    property bool showSidebarCounts: true
    property string sectionOrder: "views,projects,labels,priorities"
    property string hiddenSections: ""
    property string viewOrder: ""
    property string hiddenViews: ""

    readonly property string sectionDefaults: "views,projects,labels,priorities,progress,status,secrecy,location"
    readonly property string primaryViewDefaults: "inbox,today,overdue,tomorrow,scheduled,anytime,completed"
    readonly property string maintenanceViewDefaults: "recurring,unlabeled,reminder,nolocation,nopriority,nostatus"
    readonly property string viewDefaults: primaryViewDefaults + "," + maintenanceViewDefaults
    readonly property var maintenanceViewIds: [
        "recurring", "unlabeled", "reminder", "nolocation", "nopriority", "nostatus"
    ]
    readonly property string maintenanceFolderId: "__maintenance__"
    readonly property string smartViewsFolderId: "__smart__"
    readonly property string viewsBackId: "__views_back__"

    readonly property string primaryFolder: "primary"
    readonly property string maintenanceFolder: "maintenance"
    readonly property string smartViewsFolder: "smartviews"
    property string currentSidebarFolder: primaryFolder
    readonly property var visibleSectionIdList: {
        var base = controller
                ? controller.visibleOrderedKeys(sectionOrder, hiddenSections, sectionDefaults, ",", "||")
                : ["views", "projects", "labels", "priorities", "progress", "status", "secrecy", "location"]
        var out = []
        for (var i = 0; i < base.length; ++i) {
            var id = base[i]
            if (id === "projects" && !filterEnabled("project")) {
                continue
            }
            if (id === "labels" && !filterEnabled("label")) {
                continue
            }
            if (id === "priorities" && !filterEnabled("priority")) {
                continue
            }
            if (id === "progress" && !filterEnabled("progress")) {
                continue
            }
            if (id === "status" && !filterEnabled("status")) {
                continue
            }
            out.push(id)
        }
        return out
    }
    readonly property int visibleSectionCount: visibleSectionIdList.length
    // Why sections left out above are gone in this view, e.g. "Projects are already swimlane rows." (g7).
    readonly property var hiddenSectionReasons: {
        var base = controller
                ? controller.visibleOrderedKeys(sectionOrder, hiddenSections, sectionDefaults, ",", "||")
                : []
        var kinds = { projects: "project", labels: "label", priorities: "priority", progress: "progress", status: "status" }
        var out = []
        for (var i = 0; i < base.length; ++i) {
            var kind = kinds[base[i]]
            if (kind && !filterEnabled(kind)) {
                out.push(filterDisabledReason(kind))
            }
        }
        return out
    }

    readonly property int sidebarWidth: Design.sidebarWidth
    readonly property bool isDragging: !!(dragHost && dragHost.draggingTask)
    // Full-editor overlay: no hover highlight under the dim.
    property bool interactionsSuspended: false
    readonly property bool rowHoverEnabled: !interactionsSuspended

    // The controller knows which filters the layout already shows (columns, lanes, rows).
    function filterEnabled(kind, extra) {
        return !controller.blockedFilters[filterKey(kind, extra)]
    }

    function filterKey(kind, extra) {
        return extra ? kind + ":" + extra : kind
    }

    function filterDisabledReason(kind, extra) {
        var layout = controller.blockedFilters[filterKey(kind, extra)]
        if (layout === "kanban") {
            switch (filterKey(kind, extra)) {
            case "label": return i18n("Labels are already Kanban columns.")
            case "project": return i18n("Projects are already Kanban columns.")
            case "priority": return i18n("Priorities are already Kanban columns.")
            case "status": return i18n("Status is already used for Kanban columns.")
            case "secrecy": return i18n("Secrecy is already used for Kanban columns.")
            case "progress": return i18n("Progress is already used for Kanban columns.")
            case "view:unlabeled": return i18n("Unlabeled view does not apply when Kanban uses labels as columns.")
            }
        } else if (layout === "swimlane") {
            switch (kind) {
            case "label": return i18n("Labels are already swimlane rows.")
            case "project": return i18n("Projects are already swimlane rows.")
            case "priority": return i18n("Priorities are already swimlane rows.")
            }
        } else if (layout === "plan" && kind === "project") {
            return i18n("Projects are already plan rows.")
        }
        return i18n("Not available in the current view.")
    }

    implicitWidth: sidebarWidth
    implicitHeight: 0
    Layout.preferredWidth: sidebarWidth
    Layout.minimumWidth: sidebarWidth
    Layout.maximumWidth: sidebarWidth
    Layout.fillWidth: false
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    Layout.maximumHeight: Infinity

    readonly property int availableHeight: Math.max(0, Math.floor(height - separatorStrip * Math.max(0, visibleSectionCount - 1)))

    // Shared left inset so Inbox/Today/Scheduled icons align with Projects/Labels icons.
    readonly property int rowLeftInset: Design.padInner

    readonly property bool touchFriendly: Kirigami.Settings.tabletMode
        || Kirigami.Settings.hasTransientTouchInput
        || Kirigami.Settings.isMobile

    readonly property bool comfortableRows: {
        if (sidebarRowSize === "comfortable") {
            return true
        }
        if (sidebarRowSize === "compact" || sidebarRowSize === "dense") {
            return false
        }
        // auto: roomier rows on touch / tablet
        return root.touchFriendly
    }

    /** Opt-in: Kante's dense list rows (24 px), more entries without scrolling. */
    readonly property bool denseRows: sidebarRowSize === "dense"
    readonly property int rowVPad: comfortableRows ? Design.spaceSmall : 1
    readonly property int sectionHeaderHeight: comfortableRows
        ? Math.round(Kirigami.Units.gridUnit * 2.4)
        : Math.round(Kirigami.Units.gridUnit * 1.25)
    readonly property int rowIconSize: comfortableRows
        ? Kirigami.Units.iconSizes.smallMedium
        : Kirigami.Units.iconSizes.small

    readonly property int separatorStrip: Design.spaceSmall + 1
    readonly property int scrollBarExtent: Design.scrollBarExtent
    readonly property int scrollGutter: Design.scrollGutter
    // Kante: the KanteListRow density height plus the list spacing.
    readonly property int sectionRowHeight: KanteStyle.active
        ? (comfortableRows ? KanteStyle.heightLarge : (denseRows ? Math.round(KanteStyle.heightSmall * 0.75) : KanteStyle.heightSmall)) + 1
        : rowIconSize + rowVPad * 2 + 4

    // Not yet allocated — sections share space equally so they can measure.
    property bool sectionsAllocated: false
    property var sectionAlloc: ({})

    function allocFor(id) {
        if (!sectionsAllocated) {
            var n = Math.max(1, visibleSectionCount)
            return Math.max(1, Math.floor(availableHeight / n))
        }
        return sectionAlloc[id] || 0
    }

    readonly property string sectionContentKey: JSON.stringify(controller.sidebarProjectCounts)
            + "|" + JSON.stringify(controller.sidebarLabelCounts)
            + "|" + JSON.stringify(controller.sidebarProgressCounts)
            + "|" + JSON.stringify(controller.sidebarStatusCounts)
            + "|" + JSON.stringify(controller.sidebarSecrecyCounts)
            + "|" + JSON.stringify(controller.sidebarLocationCounts)
            + "|" + (controller.collectionModel ? controller.collectionModel.count : 0)
            + "|" + controller.availableLabels.join("\n")
            + "|" + controller.availableLocations.join("\n")
            + "|" + hiddenProjects
            + "|" + String(showEmptyProjects)
            + "|" + String(showSidebarCounts)
            + "|" + hiddenLabels
            + "|" + hiddenLocations
            + "|" + sectionOrder
            + "|" + hiddenSections
            + "|" + viewOrder
            + "|" + hiddenViews
            + "|" + (controller ? controller.mainPaneMode : "")
            + "|" + (controller ? controller.kanbanColumnSource : "")
            + "|" + (controller ? controller.swimlaneLaneAxis : "")
            + "|" + String(root.currentSidebarFolder)

    // Order/visibility only — do not include counts. Reparenting on every count
    // refresh (via parent=null) tears down ListView delegates and leaves the
    // lower sections looking empty while their allocated height remains.
    readonly property string sectionLayoutKey: sectionOrder
            + "|" + hiddenSections
            + "|" + viewOrder
            + "|" + hiddenViews
            + "|" + (controller ? controller.mainPaneMode : "")
            + "|" + (controller ? controller.kanbanColumnSource : "")
            + "|" + (controller ? controller.swimlaneLaneAxis : "")
            + "|" + String(root.currentSidebarFolder)
            + "|" + visibleSectionIdList.join(",")

    property var visibleProjects: []
    property var visibleLabelItems: []
    property var visibleLocationItems: []

    onHeightChanged: Qt.callLater(redistributeSections)
    onAvailableHeightChanged: Qt.callLater(redistributeSections)
    onSectionContentKeyChanged: {
        rebuildVisibleLists()
        Qt.callLater(redistributeSections)
    }
    onSectionLayoutKeyChanged: Qt.callLater(applySectionOrder)
    Component.onCompleted: {
        rebuildSmartViewItems()
        rebuildVisibleLists()
        Qt.callLater(applySectionOrder)
        Qt.callLater(redistributeSections)
        // If the saved view belongs to a non-primary folder, open that folder on startup.
        root.currentSidebarFolder = root.folderForView(controller.currentView)
        Qt.callLater(viewsList.syncCurrentIndex)
    }
    onSectionHeaderHeightChanged: Qt.callLater(redistributeSections)
    onSectionRowHeightChanged: Qt.callLater(redistributeSections)
    onComfortableRowsChanged: Qt.callLater(redistributeSections)

    // Hidden projects, labels and locations (Settings › Organize) are left out by the controller.
    function rebuildVisibleLists() {
        visibleProjects = controller.sidebarProjects()
        visibleLabelItems = controller.sidebarLabels()
        visibleLocationItems = controller.sidebarLocations()
    }

    function visibleProjectCount() {
        return visibleProjects.length
    }

    function visibleLabelCount() {
        return visibleLabelItems.length
    }

    function visibleLocationCount() {
        return visibleLocationItems.length
    }

    function naturalListHeight(rowCount, hasHeader) {
        return SidebarHeight.naturalListHeight(rowCount, hasHeader, root.sectionHeaderHeight, root.sectionRowHeight)
    }

    function naturalHeightViews() {
        return root.naturalListHeight(root.visibleViewItems.length, false)
    }
    function naturalHeightProjects() {
        return root.naturalListHeight(root.visibleProjectCount(), true)
    }
    function naturalHeightLabels() {
        return root.naturalListHeight(root.visibleLabelCount(), true)
    }
    function naturalHeightPriorities() {
        return root.naturalListHeight(root.priorityItems.length, true)
    }
    function naturalHeightProgress() {
        return root.naturalListHeight(root.progressItems.length, true)
    }
    function naturalHeightStatus() {
        return root.naturalListHeight(root.statusItems.length, true)
    }
    function naturalHeightSecrecy() {
        return root.naturalListHeight(root.secrecyItems.length, true)
    }
    function naturalHeightLocation() {
        return root.naturalListHeight(root.visibleLocationCount(), true)
    }

    function listContentWidth(list) {
        if (!list) {
            return 1
        }
        return Math.max(1, list.width - list.leftMargin - list.rightMargin)
    }

    function listNeedsScroll(list) {
        return Design.listNeedsScroll(list)
    }

    function scrollMarginFor(list) {
        // Stable gutter: scrollbar fits inside Design.spaceSmall; do not grow/shrink margin.
        return Design.spaceSmall
    }

    function redistributeSections() {
        var available = root.availableHeight
        if (available < 4) {
            return
        }

        var ids = ["views", "projects", "labels", "priorities", "progress", "status", "secrecy", "location"]
        var sectionCount = ids.length
        var hasHeader = [false, true, true, true, true, true, true, true]
        var naturals = [
            root.naturalHeightViews(),
            root.naturalHeightProjects(),
            root.naturalHeightLabels(),
            root.naturalHeightPriorities(),
            root.naturalHeightProgress(),
            root.naturalHeightStatus(),
            root.naturalHeightSecrecy(),
            root.naturalHeightLocation()
        ]
        var visibleFlags = []
        for (var s = 0; s < sectionCount; ++s) {
            visibleFlags.push(root.sectionVisible(ids[s]))
        }

        var alloc = SidebarHeight.distribute(available, naturals, visibleFlags, hasHeader,
                                             root.sectionHeaderHeight, root.sectionRowHeight)
        if (!alloc) {
            sectionAlloc = {}
            sectionsAllocated = true
            return
        }

        var newAlloc = {}
        for (var a = 0; a < sectionCount; ++a) {
            newAlloc[ids[a]] = alloc[a]
        }
        sectionAlloc = newAlloc
        sectionsAllocated = true
    }

    function sectionVisible(id) {
        return root.visibleSectionIdList.indexOf(id) >= 0
    }

    function applySectionOrder() {
        var ids = root.visibleSectionIdList
        var blocks = {
            "views": viewsBlock,
            "projects": projectsBlock,
            "labels": labelsBlock,
            "priorities": prioritiesBlock,
            "progress": progressBlock,
            "status": statusBlock,
            "secrecy": secrecyBlock,
            "location": locationBlock
        }
        var key
        for (key in blocks) {
            if (!blocks[key]) {
                continue
            }
            blocks[key].visible = ids.indexOf(key) >= 0
        }
        // Re-assigning the same parent appends to the end (Qt Quick). Avoid
        // parent=null, which drops ListView delegates mid-refresh.
        for (var i = 0; i < ids.length; ++i) {
            var block = blocks[ids[i]]
            if (!block) {
                continue
            }
            block.parent = sectionColumn
            block.isLastVisible = (i === ids.length - 1)
        }
        Qt.callLater(redistributeSections)
    }

    function dropTaskOnProject(collectionId) {
        if (!dragHost || !dragHost.draggingTask || collectionId <= 0) {
            return false
        }
        if (controller.collectionModel && !controller.collectionModel.writableForId(collectionId)) {
            return false
        }
        controller.moveTaskToCollection(dragHost.draggingTask.itemId, collectionId)
        return true
    }

    function projectDropHint(project) {
        var drag = dragHost ? dragHost.draggingTask : null
        if (drag && Number(drag.collectionId) === Number(project.collectionId)) {
            return i18n("Already in project “%1”", project.name)
        }
        return i18n("Move to project “%1”", project.name)
    }

    function dropTaskOnLabel(label) {
        if (!dragHost || !dragHost.draggingTask || !label) {
            return false
        }
        if (taskHasLabel(label)) {
            pendingRemoveItemId = dragHost.draggingTask.itemId
            pendingRemoveLabel = label
            confirmRemoveLabelDialog.open()
            return true
        }
        controller.addTaskCategory(dragHost.draggingTask.itemId, label)
        return true
    }

    function taskHasLabel(label) {
        if (!dragHost || !dragHost.draggingTask || !label) {
            return false
        }
        var cats = dragHost.draggingTask.categories || []
        for (var i = 0; i < cats.length; ++i) {
            if (cats[i] === label) {
                return true
            }
        }
        return false
    }

    function labelDropHint(label) {
        if (taskHasLabel(label)) {
            return i18n("Remove label “%1”", label)
        }
        return i18n("Add label “%1”", label)
    }

    property string pendingRemoveLabel: ""
    property var pendingRemoveItemId: -1

    function priorityDropHint(priority) {
        var drag = dragHost ? dragHost.draggingTask : null
        var already = !!(drag && Colors.normalizePriority(drag.priority) === priority.value)
        if (priority.value === 0) {
            return already ? i18n("Already has no priority") : i18n("Clear priority")
        }
        return already
            ? i18n("Already priority “%1”", priority.label)
            : i18n("Set priority “%1”", priority.label)
    }

    function dropTaskOnPriority(priority) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        controller.setTaskPriority(dragHost.draggingTask.itemId, priority)
        return true
    }

    function progressIconForBand(band) {
        // Three-bar metaphor via battery fill levels (Breeze).
        switch (band) {
        case "0-25": return "battery-000"
        case "26-50": return "battery-040"
        case "51-75": return "battery-060"
        case "76-100": return "battery-100"
        default: return "battery-000"
        }
    }

    function statusIconForValue(value) {
        switch (Number(value)) {
        case 4: return "view-task"
        case 6: return "media-playback-start"
        case 3: return "task-complete"
        case 5: return "dialog-cancel"
        default: return "task-new"
        }
    }

    function secrecyIconForValue(value) {
        switch (Number(value)) {
        case 1: return "lock"
        case 2: return "security-high"
        default: return "unlock"
        }
    }

    function dropTaskOnProgress(band) {
        if (!dragHost || !dragHost.draggingTask || !band) {
            return false
        }
        controller.setTaskProgressBand(dragHost.draggingTask.itemId, band)
        return true
    }

    function dropTaskOnStatus(status) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        controller.setTaskStatus(dragHost.draggingTask.itemId, Number(status))
        return true
    }

    function dropTaskOnSecrecy(secrecy) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        controller.updateTaskFull(dragHost.draggingTask.itemId, {
            secrecy: Number(secrecy)
        })
        return true
    }

    function dropTaskOnLocation(location) {
        if (!dragHost || !dragHost.draggingTask || location === undefined || location === null) {
            return false
        }
        var current = (dragHost.draggingTask.location || "").trim()
        var next = String(location).trim()
        if (current === next) {
            controller.updateTaskFull(dragHost.draggingTask.itemId, { location: "" })
        } else {
            controller.updateTaskFull(dragHost.draggingTask.itemId, { location: next })
        }
        return true
    }

    function locationDropHint(location) {
        var current = dragHost && dragHost.draggingTask
                ? String(dragHost.draggingTask.location || "").trim() : ""
        if (current === String(location).trim()) {
            return i18n("Clear location “%1”", location)
        }
        return i18n("Set location “%1”", location)
    }

    readonly property var primaryViewItems: [
        { viewId: "inbox", label: i18n("Inbox"), icon: "mail-folder-inbox" },
        { viewId: "today", label: i18n("Today"), icon: "view-calendar-day" },
        { viewId: "overdue", label: i18n("Overdue"), icon: "chronometer" },
        { viewId: "tomorrow", label: i18n("Tomorrow"), icon: "go-next" },
        { viewId: "scheduled", label: i18n("Scheduled"), icon: "view-calendar" },
        { viewId: "anytime", label: i18n("Anytime"), icon: "view-calendar-tasks" },
        { viewId: "completed", label: i18n("Completed"), icon: "checkmark" }
    ]

    readonly property var maintenanceViewItems: [
        { viewId: "recurring", label: i18n("Recurring"), icon: "media-playlist-repeat" },
        { viewId: "unlabeled", label: i18n("Unlabeled"), icon: "tag-delete" },
        { viewId: "reminder", label: i18n("Has reminder"), icon: "appointment-reminder" },
        { viewId: "nolocation", label: i18n("Has no location"), icon: "find-location" },
        { viewId: "nopriority", label: i18n("No priority"), icon: "flag" },
        { viewId: "nostatus", label: i18n("No status"), icon: "task-new" }
    ]

    readonly property var viewItems: primaryViewItems.concat(maintenanceViewItems)

    readonly property var viewItemsById: {
        var byId = {}
        for (var i = 0; i < viewItems.length; ++i) {
            byId[viewItems[i].viewId] = viewItems[i]
        }
        return byId
    }

    function folderForView(viewId) {
        if (viewId === maintenanceFolderId || root.isMaintenanceViewId(viewId)) {
            return maintenanceFolder
        }
        if (viewId === smartViewsFolderId || root.isSmartViewId(viewId)) {
            return smartViewsFolder
        }
        return primaryFolder
    }

    function isMaintenanceViewId(viewId) {
        return maintenanceViewIds.indexOf(viewId) >= 0
    }

    function isSmartViewId(viewId) {
        return viewId.indexOf("smart:") === 0
    }

    function orderedViewItems(defaultsCsv) {
        if (!controller) {
            return []
        }
        var order = controller.visibleOrderedKeys(viewOrder, hiddenViews, defaultsCsv, ",", "||")
        var byId = viewItemsById
        var out = []
        for (var j = 0; j < order.length; ++j) {
            if (byId[order[j]] && root.filterEnabled("view", order[j])) {
                out.push(byId[order[j]])
            }
        }
        return out
    }

    property var smartViewSidebarItems: []

    Connections {
        target: root.controller
        function onSmartViewsJsonChanged() { Qt.callLater(root.rebuildSmartViewItems) }
    }

    function rebuildSmartViewItems() {
        var out = []
        var smartViews = controller.smartViews
        for (var k = 0; k < smartViews.length; ++k) {
            var sv = smartViews[k]
            if (!sv.id) {
                continue
            }
            out.push({
                viewId: sv.viewId,
                label: sv.name || sv.id,
                icon: sv.icon
            })
        }
        out.sort(function(a, b) {
            return a.label.localeCompare(b.label)
        })
        smartViewSidebarItems = out
    }

    function maintenanceFolderCountLabel() {
        if (!controller || !showSidebarCounts) {
            return ""
        }
        var sum = 0
        for (var i = 0; i < maintenanceViewIds.length; ++i) {
            var n = controller.viewTaskCounts[maintenanceViewIds[i]]
            if (n !== undefined) {
                sum += n
            }
        }
        return sum > 0 ? String(sum) : ""
    }

    readonly property var visiblePrimaryViewItems: orderedViewItems(primaryViewDefaults)

    readonly property var visibleMaintenanceViewItems: orderedViewItems(maintenanceViewDefaults)

    readonly property var visiblePrimaryViewsDisplay: {
        var out = visiblePrimaryViewItems.slice()
        out.push({
            viewId: maintenanceFolderId,
            label: i18n("Maintenance"),
            icon: "folder-documents",
            isNav: true
        })
        if (smartViewSidebarItems.length > 0) {
            out.push({
                viewId: smartViewsFolderId,
                label: i18n("Smart Views"),
                icon: "view-filter",
                isNav: true
            })
        }
        return out.length ? out : primaryViewItems
    }

    readonly property var visibleMaintenanceViewsDisplay: {
        var out = [{
            viewId: viewsBackId,
            label: i18n("Back"),
            icon: "go-previous",
            isNav: true
        }]
        for (var j = 0; j < visibleMaintenanceViewItems.length; ++j) {
            out.push(visibleMaintenanceViewItems[j])
        }
        return out
    }

    readonly property var visibleSmartViewsDisplay: {
        var out = [{
            viewId: viewsBackId,
            label: i18n("Back"),
            icon: "go-previous",
            isNav: true
        }]
        for (var m = 0; m < smartViewSidebarItems.length; ++m) {
            out.push(smartViewSidebarItems[m])
        }
        return out
    }

    readonly property var visibleViewItems: currentSidebarFolder === maintenanceFolder
            ? visibleMaintenanceViewsDisplay
            : currentSidebarFolder === smartViewsFolder
            ? visibleSmartViewsDisplay
            : visiblePrimaryViewsDisplay

    readonly property var priorityItems: [
        { value: 1, label: i18n("High") },
        { value: 5, label: i18n("Medium") },
        { value: 9, label: i18n("Low") }
    ]

    readonly property var progressItems: [
        { value: "0-25", label: i18n("0–25%") },
        { value: "26-50", label: i18n("26–50%") },
        { value: "51-75", label: i18n("51–75%") },
        { value: "76-100", label: i18n("76–100%") }
    ]
    readonly property var statusItems: [
        { value: 4, label: i18n("Needs action") },
        { value: 6, label: i18n("In process") },
        { value: 3, label: i18n("Completed") },
        { value: 5, label: i18n("Canceled") }
    ]
    readonly property var secrecyItems: [
        { value: 0, label: i18n("Public") },
        { value: 1, label: i18n("Private") },
        { value: 2, label: i18n("Confidential") }
    ]

    function indexForView(viewId) {
        for (var i = 0; i < visibleViewItems.length; ++i) {
            var row = visibleViewItems[i]
            if (row.viewId === viewId) {
                return i
            }
        }
        return -1
    }

    Connections {
        target: controller
        function onCurrentViewChanged() {
            root.currentSidebarFolder = root.folderForView(controller.currentView)
            viewsList.syncCurrentIndex()
        }
    }

    // Whole-section slide animation for folder entry/exit,
    // matching the MainPaneHost view-transition style.
    Connections {
        target: root
        function onCurrentSidebarFolderChanged() {
            if (Design.reducedMotion) {
                return
            }
            viewsSlideAnimation.stop()
            var slideFrom = root.currentSidebarFolder === primaryFolder
                    ? -viewsList.width
                    : viewsList.width
            viewsList.x = slideFrom
            viewsSlideAnimation.from = slideFrom
            viewsSlideAnimation.to = 0
            viewsSlideAnimation.start()
        }
    }

    NumberAnimation {
        id: viewsSlideAnimation
        target: viewsList
        property: "x"
        duration: Design.mainPaneTransitionDuration
        easing.type: Easing.OutCubic
    }

    function clearFilterSelections() {
        controller.selectedCollectionId = -1
        controller.selectedLabel = ""
        controller.selectedPriority = -1
        controller.selectedProgressBand = ""
        controller.selectedStatus = -1
        controller.selectedSecrecy = -1
        controller.selectedLocation = ""
    }

    Column {
        id: sectionColumn
        anchors.fill: parent
        spacing: 0
        clip: true

    // ── Views ──
    Item {
        id: viewsBlock
        width: parent ? parent.width : 0
        clip: true
        property bool isLastVisible: false
        height: viewsList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: viewsList
        width: parent ? parent.width : 0
        height: root.allocFor("views")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(viewsList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(viewsList)
        model: root.visibleViewItems

        function syncCurrentIndex() {
            var idx = root.indexForView(controller.currentView)
            if (idx < 0 || idx >= count) {
                currentIndex = -1
                return
            }
            var row = model[idx]
            if (row && (row.viewId === root.maintenanceFolderId
                    || row.viewId === root.smartViewsFolderId
                    || row.viewId === root.viewsBackId)) {
                currentIndex = -1
                return
            }
            currentIndex = idx
        }

        onModelChanged: Qt.callLater(syncCurrentIndex)

        Connections {
            target: root
            function onCurrentSidebarFolderChanged() {
                viewsList.syncCurrentIndex()
            }
        }

        highlight: StyledHighlight { visible: !KanteStyle.active }
        highlightMoveDuration: Kirigami.Units.longDuration

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: viewsList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: Design.mainPaneTransitionDuration
                easing.type: Easing.OutCubic
            }
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: viewDelegate
            width: root.listContentWidth(viewsList)
            hoverEnabled: root.rowHoverEnabled
            highlighted: ListView.isCurrentItem
            height: KanteStyle.active ? viewDelegateKante.implicitHeight : implicitHeight
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: SidebarHoverBackground {
                visible: !Kirigami.Settings.isMobile && !KanteStyle.active
                sidebar: root
                control: viewDelegate
            }

            onClicked: {
                if (modelData.viewId === root.viewsBackId) {
                    root.currentSidebarFolder = root.primaryFolder
                    return
                }
                if (modelData.viewId === root.maintenanceFolderId) {
                    root.currentSidebarFolder = root.maintenanceFolder
                    return
                }
                if (modelData.viewId === root.smartViewsFolderId) {
                    root.currentSidebarFolder = root.smartViewsFolder
                    return
                }
                root.currentSidebarFolder = root.folderForView(modelData.viewId)
                controller.currentView = modelData.viewId
                root.clearFilterSelections()
            }

            SidebarKanteRow {
                id: viewDelegateKante
                sidebar: root
                control: viewDelegate
                text: modelData.label
                count: root.showSidebarCounts ? viewDelegateCount.text : ""
                countKind: viewDelegateCount.negative ? KanteListRow.CountKind.Error : KanteListRow.CountKind.Quiet
                // Folder rows (Maintenance, Smart views) open a sub-list: a chevron at the end.
                trailing: Kirigami.Icon {
                    readonly property bool folder: modelData.viewId === root.maintenanceFolderId
                                                   || modelData.viewId === root.smartViewsFolderId
                    visible: folder
                    width: folder ? Kirigami.Units.iconSizes.small : 0
                    height: Kirigami.Units.iconSizes.small
                    source: "go-next"
                    color: KanteStyle.mutedTextColor
                }

                Kirigami.Icon {
                    source: modelData.icon
                    width: root.rowIconSize
                    height: root.rowIconSize
                }
            }

            contentItem: RowLayout {
                visible: !KanteStyle.active
                spacing: Design.spaceSmall

                Item { width: root.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.rowIconSize
                    Layout.preferredHeight: root.rowIconSize
                    source: modelData.icon
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData.label
                    selected: viewDelegate.highlighted || viewDelegate.down
                }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    visible: modelData.viewId === root.maintenanceFolderId
                            || modelData.viewId === root.smartViewsFolderId
                    source: "go-next"
                    opacity: 0.55
                }

                CountBadge {
                    id: viewDelegateCount
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.viewTaskCounts[modelData.viewId]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                            && modelData.viewId !== root.viewsBackId
                    selected: viewDelegate.highlighted || viewDelegate.down
                    negative: modelData.viewId === "overdue" && text !== "0" && !viewDelegate.highlighted
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !viewsBlock.isLastVisible
    }
    }

    // ── Filter sections ──
    SidebarSection {
        id: projectsBlock
        sidebar: root
        sectionId: "projects"
        title: i18n("Projects")
        filterKind: "project"
        items: root.visibleProjects
        keyRole: "collectionId"
        textRole: "name"
        selection: controller.selectedCollectionId
        allValue: -1
        counts: controller.sidebarProjectCounts
        iconOf: function(project) {
            return { source: "folder", color: Design.colorForKey(String(project.collectionId)) }
        }
        hintFor: root.projectDropHint
        canDropOn: function(project) { return controller.collectionModel.writableForId(project.collectionId) }
        dropOn: function(project) { return root.dropTaskOnProject(project.collectionId) }
        onChoose: function(value) { controller.selectedCollectionId = value }
    }

    SidebarSection {
        id: labelsBlock
        sidebar: root
        sectionId: "labels"
        title: i18n("Labels")
        filterKind: "label"
        items: root.visibleLabelItems
        keyRole: ""
        textRole: ""
        selection: controller.selectedLabel
        allValue: ""
        counts: controller.sidebarLabelCounts
        iconOf: function(label) {
            return { source: "tag", color: Design.colorForKey(String(label), "label") }
        }
        hintFor: root.labelDropHint
        dropOn: root.dropTaskOnLabel
        onChoose: function(value) { controller.selectedLabel = value }
    }

    SidebarSection {
        id: prioritiesBlock
        sidebar: root
        sectionId: "priorities"
        title: i18n("Priorities")
        filterKind: "priority"
        items: root.priorityItems
        keyRole: "value"
        textRole: "label"
        selection: controller.selectedPriority
        allValue: -1
        counts: controller.sidebarPriorityCounts
        iconOf: function(priority) {
            return {
                source: "flag",
                color: Design.priorityColor(priority.value),
                opacity: priority.value > 0 ? 1 : 0.55
            }
        }
        hintFor: root.priorityDropHint
        dropOn: function(priority) { return root.dropTaskOnPriority(priority.value) }
        onChoose: function(value) { controller.selectedPriority = value }
    }

    SidebarSection {
        id: progressBlock
        sidebar: root
        sectionId: "progress"
        title: i18n("Progress")
        filterKind: "progress"
        items: root.progressItems
        keyRole: "value"
        textRole: "label"
        selection: controller.selectedProgressBand
        allValue: ""
        counts: controller.sidebarProgressCounts
        iconOf: function(band) { return { source: root.progressIconForBand(band.value) } }
        hintFor: function(band) { return i18n("Set progress to %1", band.label) }
        dropOn: function(band) { return root.dropTaskOnProgress(band.value) }
        onChoose: function(value) { controller.selectedProgressBand = value }
    }

    SidebarSection {
        id: statusBlock
        sidebar: root
        sectionId: "status"
        title: i18n("Status")
        filterKind: "status"
        items: root.statusItems
        keyRole: "value"
        textRole: "label"
        selection: controller.selectedStatus
        allValue: -1
        counts: controller.sidebarStatusCounts
        iconOf: function(status) { return { source: root.statusIconForValue(status.value) } }
        hintFor: function(status) { return i18n("Set status “%1”", status.label) }
        dropOn: function(status) { return root.dropTaskOnStatus(status.value) }
        onChoose: function(value) { controller.selectedStatus = value }
    }

    SidebarSection {
        id: secrecyBlock
        sidebar: root
        sectionId: "secrecy"
        title: i18n("Secrecy")
        filterKind: "secrecy"
        items: root.secrecyItems
        keyRole: "value"
        textRole: "label"
        selection: controller.selectedSecrecy
        allValue: -1
        counts: controller.sidebarSecrecyCounts
        iconOf: function(secrecy) { return { source: root.secrecyIconForValue(secrecy.value) } }
        hintFor: function(secrecy) { return i18n("Set secrecy “%1”", secrecy.label) }
        dropOn: function(secrecy) { return root.dropTaskOnSecrecy(secrecy.value) }
        onChoose: function(value) { controller.selectedSecrecy = value }
    }

    SidebarSection {
        id: locationBlock
        sidebar: root
        sectionId: "location"
        title: i18n("Location")
        filterKind: "location"
        items: root.visibleLocationItems
        keyRole: ""
        textRole: ""
        selection: controller.selectedLocation
        allValue: ""
        counts: controller.sidebarLocationCounts
        iconOf: function(location) {
            return { source: "mark-location", color: Design.colorForKey(String(location), "location") }
        }
        hintFor: root.locationDropHint
        dropOn: root.dropTaskOnLocation
        onChoose: function(value) { controller.selectedLocation = value }
    }

    }

    QQC2.Dialog {
        id: confirmRemoveLabelDialog
        KanteDialogSkin { dialog: confirmRemoveLabelDialog }
        parent: root.dragHost || root
        anchors.centerIn: parent
        popupType: QQC2.Popup.Item
        modal: true
        title: i18n("Remove label?")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        padding: Design.spaceMedium

        readonly property int maxWidth: {
            var host = parent
            if (!host) {
                return Kirigami.Units.gridUnit * 22
            }
            return Math.max(Kirigami.Units.gridUnit * 12, host.width - 2 * Design.overlayInset)
        }

        width: Math.min(maxWidth, Math.max(Kirigami.Units.gridUnit * 14, removeLabelMessage.implicitWidth + leftPadding + rightPadding))

        onAccepted: {
            if (root.pendingRemoveItemId >= 0 && root.pendingRemoveLabel.length > 0) {
                controller.removeTaskCategory(root.pendingRemoveItemId, root.pendingRemoveLabel)
            }
            root.pendingRemoveItemId = -1
            root.pendingRemoveLabel = ""
        }
        onRejected: {
            root.pendingRemoveItemId = -1
            root.pendingRemoveLabel = ""
        }

        contentItem: QQC2.Label {
            id: removeLabelMessage
            text: i18n("Remove label “%1” from this task?", root.pendingRemoveLabel)
            wrapMode: Text.WordWrap
            width: confirmRemoveLabelDialog.availableWidth
        }
    }
}
