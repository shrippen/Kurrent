import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kirigami.delegates as KirigamiDelegates
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.ksvg as KSvg
import com.github.shrippen.kurrent 1.0
import "../colors.js" as Colors
import "../components"
import ".."

Item {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property var filterPolicy: null
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
    readonly property string viewsBackId: "__views_back__"

    readonly property string primaryFolder: "primary"
    readonly property string maintenanceFolder: "maintenance"
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

    readonly property int sidebarWidth: Design.sidebarWidth
    readonly property bool isDragging: !!(dragHost && dragHost.draggingTask)
    // Full-editor overlay: no hover highlight under the dim.
    property bool interactionsSuspended: false
    readonly property bool rowHoverEnabled: !interactionsSuspended

    function filterEnabled(kind, extra) {
        if (!filterPolicy || typeof filterPolicy.isSidebarFilterEnabled !== "function") {
            return true
        }
        return filterPolicy.isSidebarFilterEnabled(kind, extra || "")
    }

    function filterDisabledReason(kind, extra) {
        if (!filterPolicy || typeof filterPolicy.sidebarFilterDisabledReason !== "function") {
            return ""
        }
        return filterPolicy.sidebarFilterDisabledReason(kind, extra || "")
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
        if (sidebarRowSize === "compact") {
            return false
        }
        // auto: roomier rows on touch / tablet
        return root.touchFriendly
    }

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
    readonly property int sectionRowHeight: rowIconSize + rowVPad * 2 + 4

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

    function rebuildVisibleLists() {
        var projects = []
        var model = controller.collectionModel
        if (model) {
            for (var i = 0; i < model.count; ++i) {
                var collectionId = model.collectionIdAt(i)
                if ((root.showEmptyProjects || model.taskCountAt(i) > 0) && !root._isProjectHidden(collectionId)) {
                    projects.push({
                        collectionId: collectionId,
                        name: model.nameAt(i),
                        taskCount: model.taskCountAt(i)
                    })
                }
            }
        }
        visibleProjects = projects

        var labels = []
        var allLabels = controller.availableLabels
        for (var j = 0; j < allLabels.length; ++j) {
            if (!root._isLabelHidden(allLabels[j])) {
                labels.push(allLabels[j])
            }
        }
        visibleLabelItems = labels

        var locations = []
        var allLocations = controller.availableLocations
        for (var loc = 0; loc < allLocations.length; ++loc) {
            if (!root._isLocationHidden(allLocations[loc])) {
                locations.push(allLocations[loc])
            }
        }
        visibleLocationItems = locations
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
        var rows = Math.max(0, rowCount)
        var header = hasHeader ? root.sectionHeaderHeight : 0
        var parts = rows + (hasHeader ? 1 : 0)
        var gaps = Math.max(0, parts - 1)
        return header + rows * root.sectionRowHeight + gaps
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

    function sectionFloorHeight(hasHeader) {
        var header = hasHeader ? root.sectionHeaderHeight : 0
        return Math.max(1, header + root.sectionRowHeight + 1)
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
        var visibleCount = 0
        var sumNatural = 0
        for (var s = 0; s < sectionCount; ++s) {
            var vis = root.sectionVisible(ids[s])
            visibleFlags.push(vis)
            if (vis) {
                ++visibleCount
                sumNatural += naturals[s]
            }
        }
        if (visibleCount <= 0) {
            sectionAlloc = {}
            sectionsAllocated = true
            return
        }

        var alloc = []
        for (var z = 0; z < sectionCount; ++z) {
            alloc.push(0)
        }
        // Slack is only for scrollbar visibility (Design.listNeedsScroll), not allocation —
        // otherwise resizing feels sticky near the fit boundary then jumps.
        if (sumNatural <= available) {
            var leftover = available - sumNatural
            var evenGrow = Math.floor(leftover / visibleCount)
            var extraGrow = leftover - evenGrow * visibleCount
            for (var i = 0; i < sectionCount; ++i) {
                if (!visibleFlags[i]) {
                    continue
                }
                alloc[i] = naturals[i] + evenGrow + (extraGrow > 0 ? 1 : 0)
                if (extraGrow > 0) {
                    extraGrow--
                }
            }
        } else {
            // Short widget: keep relative content sizes (not equal floors).
            var mins = []
            var sumMins = 0
            for (var m = 0; m < sectionCount; ++m) {
                var floorH = visibleFlags[m] ? root.sectionFloorHeight(hasHeader[m]) : 0
                mins.push(floorH)
                sumMins += floorH
            }

            if (sumMins >= available) {
                for (var mc = 0; mc < sectionCount; ++mc) {
                    alloc[mc] = mins[mc]
                }
                var over = sumMins - available
                if (over > 0) {
                    for (var t = 0; t < sectionCount && over > 0; ++t) {
                        if (!visibleFlags[t]) {
                            continue
                        }
                        var cut = Math.min(over, Math.max(0, alloc[t] - 1))
                        alloc[t] -= cut
                        over -= cut
                    }
                }
            } else {
                var flex = available - sumMins
                var flexNatural = 0
                for (var f = 0; f < sectionCount; ++f) {
                    if (visibleFlags[f]) {
                        flexNatural += Math.max(0, naturals[f] - mins[f])
                    }
                }
                var remain = flex
                for (var p = 0; p < sectionCount; ++p) {
                    if (!visibleFlags[p]) {
                        continue
                    }
                    var extraNeed = Math.max(0, naturals[p] - mins[p])
                    var share = (flexNatural > 0)
                        ? Math.floor(flex * extraNeed / flexNatural)
                        : Math.floor(flex / visibleCount)
                    alloc[p] = mins[p] + share
                    remain -= share
                }
                for (var r = 0; r < sectionCount && remain > 0; ++r) {
                    if (visibleFlags[r]) {
                        alloc[r] += 1
                        remain--
                    }
                }
            }
        }

        // Near-fit: if a section is short by at most one row, give it full natural
        // height by stealing from sections that still overflow by more than one row.
        var oneRow = root.sectionRowHeight + 1
        for (var g = 0; g < sectionCount; ++g) {
            if (!visibleFlags[g]) {
                continue
            }
            var shortfall = naturals[g] - alloc[g]
            if (shortfall <= 0 || shortfall > oneRow) {
                continue
            }
            var need = shortfall
            for (var donor = 0; donor < sectionCount && need > 0; ++donor) {
                if (!visibleFlags[donor] || donor === g) {
                    continue
                }
                var donorOverflow = naturals[donor] - alloc[donor]
                var floorH = root.sectionFloorHeight(hasHeader[donor])
                var spare = Math.max(0, alloc[donor] - floorH)
                // Prefer donors that must scroll anyway (more than one row short).
                if (donorOverflow <= oneRow && spare <= 0) {
                    continue
                }
                var take = Math.min(need, spare)
                if (take <= 0) {
                    continue
                }
                alloc[donor] -= take
                need -= take
            }
            if (need === 0) {
                alloc[g] = naturals[g]
            }
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

    function _isProjectHidden(collectionId) {
        if (!hiddenProjects) {
            return false
        }
        var parts = hiddenProjects.split(",")
        return parts.indexOf(String(collectionId)) >= 0
    }

    function _isLabelHidden(label) {
        if (!hiddenLabels) {
            return false
        }
        var parts = hiddenLabels.split("||")
        return parts.indexOf(label) >= 0
    }

    function _isLocationHidden(location) {
        if (!hiddenLocations) {
            return false
        }
        var parts = hiddenLocations.split("||")
        return parts.indexOf(location) >= 0
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

    function dropTaskOnPriority(priority) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        controller.setTaskPriority(dragHost.draggingTask.itemId, priority)
        return true
    }

    function progressMidpoint(band) {
        switch (band) {
        case "0-25": return 12
        case "26-50": return 38
        case "51-75": return 63
        case "76-100": return 88
        default: return 0
        }
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
        controller.updateTaskFull(dragHost.draggingTask.itemId, {
            percentComplete: progressMidpoint(band)
        })
        return true
    }

    function dropTaskOnStatus(status) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        var fields = { status: Number(status) }
        if (Number(status) === 3) {
            fields.completed = true
            fields.percentComplete = 100
        } else {
            fields.completed = false
        }
        controller.updateTaskFull(dragHost.draggingTask.itemId, fields)
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
        return primaryFolder
    }

    function isMaintenanceViewId(viewId) {
        return maintenanceViewIds.indexOf(viewId) >= 0
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

    readonly property var smartViewSidebarItems: {
        var out = []
        try {
            var smartViews = JSON.parse(Plasmoid.configuration.smartViews || "[]")
            for (var k = 0; k < smartViews.length; ++k) {
                var sv = smartViews[k]
                if (!sv || !sv.id) {
                    continue
                }
                out.push({
                    viewId: "smart:" + sv.id,
                    label: sv.name || sv.id,
                    icon: sv.icon || "view-filter"
                })
            }
        } catch (e) {
        }
        return out
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
        for (var m = 0; m < smartViewSidebarItems.length; ++m) {
            out.push(smartViewSidebarItems[m])
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

    readonly property var visibleViewItems: currentSidebarFolder === maintenanceFolder
            ? visibleMaintenanceViewsDisplay
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
        function onSelectedCollectionIdChanged() { projectsList.syncIndex() }
        function onSelectedLabelChanged() { labelsList.syncIndex() }
        function onSelectedPriorityChanged() { prioritiesList.syncIndex() }
        function onSelectedProgressBandChanged() { progressList.syncIndex() }
        function onSelectedStatusChanged() { statusList.syncIndex() }
        function onSelectedSecrecyChanged() { secrecyList.syncIndex() }
        function onSelectedLocationChanged() { locationList.syncIndex() }
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
            var slideFrom = root.currentSidebarFolder === maintenanceFolder
                    ? viewsList.width
                    : -viewsList.width
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

    component SidebarHoverBackground: KSvg.FrameSvgItem {
        required property Item control
        imagePath: "widgets/listitem"
        prefix: "hover"
        anchors.fill: parent
        visible: !Kirigami.Settings.isMobile
        opacity: root.rowHoverEnabled && control.hovered && !control.down ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.veryShortDuration
                easing.type: Easing.OutQuad
            }
        }
    }

    component SelectionBackground: Item {
        id: selectionBg
        required property Item control
        required property bool selected

        anchors.fill: parent

        PlasmaExtras.Highlight {
            anchors.fill: parent
            visible: selectionBg.selected
            hovered: true
            pressed: selectionBg.control.down
        }

        SidebarHoverBackground {
            control: selectionBg.control
        }
    }

    component SidebarScrollBar: ThinScrollBar {
        required property Flickable view
        parent: view
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        // Fit inside the fixed rightMargin (Design.spaceSmall); do not widen the gutter.
        extent: Design.spaceSmall
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

        highlight: PlasmaExtras.Highlight {}
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
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: SidebarHoverBackground {
                control: viewDelegate
            }

            onClicked: {
                if (modelData.viewId === root.viewsBackId) {
                    root.currentSidebarFolder = root.primaryFolder
                    controller.currentView = "inbox"
                    return
                }
                if (modelData.viewId === root.maintenanceFolderId) {
                    root.currentSidebarFolder = root.maintenanceFolder
                    return
                }
                root.currentSidebarFolder = root.folderForView(modelData.viewId)
                controller.currentView = modelData.viewId
                root.clearFilterSelections()
            }

            contentItem: RowLayout {
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
                    source: "go-next"
                    opacity: 0.55
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        if (modelData.viewId === root.maintenanceFolderId) {
                            return root.maintenanceFolderCountLabel()
                        }
                        var n = controller.viewTaskCounts[modelData.viewId]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                            && modelData.viewId !== root.viewsBackId
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
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

    // ── Projects section ──
    Item {
        id: projectsBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: projectsList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: projectsList
        width: parent ? parent.width : 0
        height: root.allocFor("projects")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(projectsList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleProjects
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration
        leftMargin: 0
        rightMargin: root.scrollMarginFor(projectsList)

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            if (controller.selectedCollectionId < 0) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (Number(m[i].collectionId) === controller.selectedCollectionId) {
                    currentIndex = i; return
                }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: projectsList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

            headerPositioning: ListView.InlineHeader
            header: RowLayout {
                width: root.listContentWidth(projectsList)
                height: root.sectionHeaderHeight
                Layout.leftMargin: Design.spaceSmall
                Layout.rightMargin: Design.spaceSmall
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: i18n("Projects")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.65
                    verticalAlignment: Text.AlignVCenter
                }

                PlasmaComponents3.ItemDelegate {
                    id: allProjectsDelegate
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    Layout.preferredHeight: root.sectionHeaderHeight
                    hoverEnabled: root.rowHoverEnabled
                    highlighted: controller.selectedCollectionId < 0
                    readonly property bool filterUsable: root.filterEnabled("project")
                    enabled: filterUsable
                    opacity: filterUsable ? 1.0 : 0.45

                    onClicked: {
                        if (filterUsable) {
                            controller.selectedCollectionId = -1
                        }
                    }

                    QQC2.ToolTip {
                        visible: !allProjectsDelegate.filterUsable && allProjectsDelegate.hovered
                        text: root.filterDisabledReason("project")
                    }

                    background: SelectionBackground {
                        control: allProjectsDelegate
                        selected: allProjectsDelegate.highlighted
                    }

                    contentItem: QQC2.Label {
                        text: i18n("All")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: allProjectsDelegate.highlighted || allProjectsDelegate.down ? 1.0 : 0.75
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: Design.spaceSmall
                        rightPadding: Design.spaceSmall
                    }
                }
            }

            delegate: PlasmaComponents3.ItemDelegate {
                id: projectDelegate
                width: root.listContentWidth(projectsList)
                hoverEnabled: root.rowHoverEnabled
                readonly property bool filterUsable: root.filterEnabled("project")
                highlighted: ListView.isCurrentItem
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45
                leftPadding: 0
                rightPadding: Design.spaceSmall
                topPadding: root.rowVPad
                bottomPadding: root.rowVPad

                background: Item {
                    anchors.fill: parent

                    SidebarHoverBackground {
                        control: projectDelegate
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Design.inputRadius
                        color: Kirigami.Theme.highlightColor
                        opacity: projectDrop.containsDrag ? 0.28 : 0
                        visible: opacity > 0
                    }
                }

                DropArea {
                    id: projectDrop
                    anchors.fill: parent
                    keys: ["application/x-kurrent-task"]
                    enabled: root.isDragging && filterUsable
                            && controller.collectionModel.writableForId(modelData.collectionId)

                    readonly property bool alreadyInProject: {
                        var drag = root.dragHost ? root.dragHost.draggingTask : null
                        return !!(drag && Number(drag.collectionId) === Number(modelData.collectionId))
                    }
                    readonly property string hintText: alreadyInProject
                        ? i18n("Already in project “%1”", modelData.name)
                        : i18n("Move to project “%1”", modelData.name)

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
                        if (root.dropTaskOnProject(modelData.collectionId)) {
                            drop.acceptProposedAction()
                        }
                    }
                }

                onClicked: {
                    if (!filterUsable) {
                        return
                    }
                    if (controller.selectedCollectionId === modelData.collectionId) {
                        controller.selectedCollectionId = -1
                    } else {
                        controller.selectedCollectionId = modelData.collectionId
                    }
                }

                QQC2.ToolTip {
                    visible: !projectDelegate.filterUsable && projectDelegate.hovered
                    text: root.filterDisabledReason("project")
                }

                contentItem: RowLayout {
                    spacing: Design.spaceSmall

                    Item { width: root.rowLeftInset }

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.rowIconSize
                        Layout.preferredHeight: root.rowIconSize
                        source: "folder"
                        color: Design.colorForKey(String(modelData.collectionId))
                        width: root.rowIconSize
                        height: root.rowIconSize
                    }

                    KirigamiDelegates.TitleSubtitle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: root.listContentWidth(projectsList)
                        Layout.alignment: Qt.AlignVCenter
                        title: modelData.name
                        selected: projectDelegate.highlighted || projectDelegate.down || projectDrop.containsDrag
                    }

                    QQC2.Label {
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        text: {
                            var n = controller.sidebarProjectCounts[String(modelData.collectionId)]
                            return n === undefined ? "" : String(n)
                        }
                        visible: root.showSidebarCounts && text.length > 0
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !projectsBlock.isLastVisible
    }
    }

    // ── Labels section ──
    Item {
        id: labelsBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: labelsList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: labelsList
        width: parent ? parent.width : 0
        height: root.allocFor("labels")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(labelsList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleLabelItems
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration
        leftMargin: 0
        rightMargin: root.scrollMarginFor(labelsList)

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            var sel = controller.selectedLabel || ""
            if (!sel.length) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (String(m[i]) === sel) { currentIndex = i; return }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: labelsList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

            headerPositioning: ListView.InlineHeader
            header: RowLayout {
                width: root.listContentWidth(labelsList)
                height: root.sectionHeaderHeight
                Layout.leftMargin: Design.spaceSmall
                Layout.rightMargin: Design.spaceSmall
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: i18n("Labels")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.65
                    verticalAlignment: Text.AlignVCenter
                }

                PlasmaComponents3.ItemDelegate {
                    id: allLabelsDelegate
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    Layout.preferredHeight: root.sectionHeaderHeight
                    hoverEnabled: root.rowHoverEnabled
                    highlighted: controller.selectedLabel === ""
                    readonly property bool filterUsable: root.filterEnabled("label")
                    enabled: filterUsable
                    opacity: filterUsable ? 1.0 : 0.45

                    onClicked: {
                        if (filterUsable) {
                            controller.selectedLabel = ""
                        }
                    }

                    QQC2.ToolTip {
                        visible: !allLabelsDelegate.filterUsable && allLabelsDelegate.hovered
                        text: root.filterDisabledReason("label")
                    }

                    background: SelectionBackground {
                        control: allLabelsDelegate
                        selected: allLabelsDelegate.highlighted
                    }

                    contentItem: QQC2.Label {
                        text: i18n("All")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: allLabelsDelegate.highlighted || allLabelsDelegate.down ? 1.0 : 0.75
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: Design.spaceSmall
                        rightPadding: Design.spaceSmall
                    }
                }
            }

            delegate: PlasmaComponents3.ItemDelegate {
                id: labelDelegate
                width: root.listContentWidth(labelsList)
                hoverEnabled: root.rowHoverEnabled
                readonly property bool filterUsable: root.filterEnabled("label")
                highlighted: ListView.isCurrentItem
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45
                leftPadding: 0
                rightPadding: Design.spaceSmall
                topPadding: root.rowVPad
                bottomPadding: root.rowVPad

                background: Item {
                    anchors.fill: parent

                    SidebarHoverBackground {
                        control: labelDelegate
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Design.inputRadius
                        color: Kirigami.Theme.highlightColor
                        opacity: labelDrop.containsDrag ? 0.28 : 0
                        visible: opacity > 0
                    }
                }

                DropArea {
                    id: labelDrop
                    anchors.fill: parent
                    keys: ["application/x-kurrent-task"]
                    enabled: root.isDragging

                    readonly property string hintText: root.labelDropHint(modelData)

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
                        if (root.dropTaskOnLabel(modelData)) {
                            drop.acceptProposedAction()
                        }
                    }
                }

                onClicked: {
                    if (!filterUsable) {
                        return
                    }
                    if (controller.selectedLabel === modelData) {
                        controller.selectedLabel = ""
                    } else {
                        controller.selectedLabel = modelData
                    }
                }

                QQC2.ToolTip {
                    visible: !labelDelegate.filterUsable && labelDelegate.hovered
                    text: root.filterDisabledReason("label")
                }

                contentItem: RowLayout {
                    spacing: Design.spaceSmall

                    Item { width: root.rowLeftInset }

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.rowIconSize
                        Layout.preferredHeight: root.rowIconSize
                        source: "tag"
                        color: Design.colorForKey(String(modelData), "label")
                        width: root.rowIconSize
                        height: root.rowIconSize
                    }

                    KirigamiDelegates.TitleSubtitle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: root.listContentWidth(labelsList)
                        Layout.alignment: Qt.AlignVCenter
                        title: modelData
                        selected: labelDelegate.highlighted || labelDelegate.down || labelDrop.containsDrag
                    }

                    QQC2.Label {
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        text: {
                            var n = controller.sidebarLabelCounts[modelData]
                            return n === undefined ? "" : String(n)
                        }
                        visible: root.showSidebarCounts && text.length > 0
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !labelsBlock.isLastVisible
    }
    }

    // ── Priorities section ──
    Item {
        id: prioritiesBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: prioritiesList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: prioritiesList
        width: parent ? parent.width : 0
        height: root.allocFor("priorities")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(prioritiesList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(prioritiesList)
        model: root.priorityItems
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            if (controller.selectedPriority < 0) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (m[i].value === controller.selectedPriority) { currentIndex = i; return }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: prioritiesList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: root.listContentWidth(prioritiesList)
            height: root.sectionHeaderHeight
            Layout.leftMargin: Design.spaceSmall
            Layout.rightMargin: Design.spaceSmall
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: i18n("Priorities")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                verticalAlignment: Text.AlignVCenter
            }

            PlasmaComponents3.ItemDelegate {
                id: allPrioritiesDelegate
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.preferredHeight: root.sectionHeaderHeight
                hoverEnabled: root.rowHoverEnabled
                highlighted: controller.selectedPriority < 0
                readonly property bool filterUsable: root.filterEnabled("priority")
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45

                onClicked: {
                    if (filterUsable) {
                        controller.selectedPriority = -1
                    }
                }

                QQC2.ToolTip {
                    visible: !allPrioritiesDelegate.filterUsable && allPrioritiesDelegate.hovered
                    text: root.filterDisabledReason("priority")
                }

                background: SelectionBackground {
                    control: allPrioritiesDelegate
                    selected: allPrioritiesDelegate.highlighted
                }

                contentItem: QQC2.Label {
                    text: i18n("All")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: allPrioritiesDelegate.highlighted || allPrioritiesDelegate.down ? 1.0 : 0.75
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                }
            }
        }

            delegate: PlasmaComponents3.ItemDelegate {
                id: priorityDelegate
                width: root.listContentWidth(prioritiesList)
            hoverEnabled: root.rowHoverEnabled
            readonly property bool filterUsable: root.filterEnabled("priority")
            highlighted: ListView.isCurrentItem
            enabled: filterUsable
            opacity: filterUsable ? 1.0 : 0.45
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SidebarHoverBackground {
                        control: priorityDelegate
                    }

                Rectangle {
                    anchors.fill: parent
                    radius: Design.inputRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: priorityDrop.containsDrag ? 0.28 : 0
                    visible: opacity > 0
                }
            }

            DropArea {
                id: priorityDrop
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                enabled: root.isDragging && filterUsable

                readonly property bool alreadyPriority: {
                    var drag = root.dragHost ? root.dragHost.draggingTask : null
                    return !!(drag && Colors.normalizePriority(drag.priority) === modelData.value)
                }
                readonly property string hintText: {
                    if (modelData.value === 0) {
                        return alreadyPriority
                            ? i18n("Already has no priority")
                            : i18n("Clear priority")
                    }
                    return alreadyPriority
                        ? i18n("Already priority “%1”", modelData.label)
                        : i18n("Set priority “%1”", modelData.label)
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
                    if (root.dropTaskOnPriority(modelData.value)) {
                        drop.acceptProposedAction()
                    }
                }
            }

            onClicked: {
                if (!filterUsable) {
                    return
                }
                if (controller.selectedPriority === modelData.value) {
                    controller.selectedPriority = -1
                } else {
                    controller.selectedPriority = modelData.value
                }
            }

            QQC2.ToolTip {
                visible: !priorityDelegate.filterUsable && priorityDelegate.hovered
                text: root.filterDisabledReason("priority")
            }

            contentItem: RowLayout {
                spacing: Design.spaceSmall

                Item { width: root.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.rowIconSize
                    Layout.preferredHeight: root.rowIconSize
                    source: "flag"
                    color: Colors.colorForPriority(modelData.value)
                    opacity: modelData.value > 0 ? 1 : 0.55
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.listContentWidth(prioritiesList)
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData.label
                    selected: priorityDelegate.highlighted || priorityDelegate.down || priorityDrop.containsDrag
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.sidebarPriorityCounts[String(modelData.value)]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !prioritiesBlock.isLastVisible
    }
    }

    // ── Progress section ──
    Item {
        id: progressBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: progressList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: progressList
        width: parent ? parent.width : 0
        height: root.allocFor("progress")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(progressList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(progressList)
        model: root.progressItems
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            if (!controller.selectedProgressBand || !controller.selectedProgressBand.length) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (m[i].value === controller.selectedProgressBand) { currentIndex = i; return }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: progressList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: root.listContentWidth(progressList)
            height: root.sectionHeaderHeight
            Layout.leftMargin: Design.spaceSmall
            Layout.rightMargin: Design.spaceSmall
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: i18n("Progress")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                verticalAlignment: Text.AlignVCenter
            }

            PlasmaComponents3.ItemDelegate {
                id: allProgressDelegate
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.preferredHeight: root.sectionHeaderHeight
                hoverEnabled: root.rowHoverEnabled
                highlighted: controller.selectedProgressBand === ""
                readonly property bool filterUsable: root.filterEnabled("progress")
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45

                onClicked: {
                    if (filterUsable) {
                        controller.selectedProgressBand = ""
                    }
                }

                QQC2.ToolTip {
                    visible: !allProgressDelegate.filterUsable && allProgressDelegate.hovered
                    text: root.filterDisabledReason("progress")
                }

                background: SelectionBackground {
                    control: allProgressDelegate
                    selected: allProgressDelegate.highlighted
                }

                contentItem: QQC2.Label {
                    text: i18n("All")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: allProgressDelegate.highlighted || allProgressDelegate.down ? 1.0 : 0.75
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                }
            }
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: progressDelegate
            width: root.listContentWidth(progressList)
            hoverEnabled: root.rowHoverEnabled
            readonly property bool filterUsable: root.filterEnabled("progress")
            highlighted: ListView.isCurrentItem
            enabled: filterUsable
            opacity: filterUsable ? 1.0 : 0.45
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SidebarHoverBackground {
                        control: progressDelegate
                    }

                Rectangle {
                    anchors.fill: parent
                    radius: Design.inputRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: progressDrop.containsDrag ? 0.28 : 0
                    visible: opacity > 0
                }
            }

            DropArea {
                id: progressDrop
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                enabled: root.isDragging && filterUsable

                readonly property string hintText: i18n("Set progress to %1", modelData.label)

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
                    if (root.dropTaskOnProgress(modelData.value)) {
                        drop.acceptProposedAction()
                    }
                }
            }

            onClicked: {
                if (!filterUsable) {
                    return
                }
                if (controller.selectedProgressBand === modelData.value) {
                    controller.selectedProgressBand = ""
                } else {
                    controller.selectedProgressBand = modelData.value
                }
            }

            QQC2.ToolTip {
                visible: !progressDelegate.filterUsable && progressDelegate.hovered
                text: root.filterDisabledReason("progress")
            }

            contentItem: RowLayout {
                spacing: Design.spaceSmall

                Item { width: root.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.rowIconSize
                    Layout.preferredHeight: root.rowIconSize
                    source: root.progressIconForBand(modelData.value)
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.listContentWidth(progressList)
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData.label
                    selected: progressDelegate.highlighted || progressDelegate.down || progressDrop.containsDrag
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.sidebarProgressCounts[modelData.value]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !progressBlock.isLastVisible
    }
    }

    // ── Status section ──
    Item {
        id: statusBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: statusList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: statusList
        width: parent ? parent.width : 0
        height: root.allocFor("status")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(statusList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(statusList)
        model: root.statusItems
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            if (controller.selectedStatus < 0) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (m[i].value === controller.selectedStatus) { currentIndex = i; return }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: statusList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: root.listContentWidth(statusList)
            height: root.sectionHeaderHeight
            Layout.leftMargin: Design.spaceSmall
            Layout.rightMargin: Design.spaceSmall
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: i18n("Status")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                verticalAlignment: Text.AlignVCenter
            }

            PlasmaComponents3.ItemDelegate {
                id: allStatusDelegate
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.preferredHeight: root.sectionHeaderHeight
                hoverEnabled: root.rowHoverEnabled
                highlighted: controller.selectedStatus < 0
                readonly property bool filterUsable: root.filterEnabled("status")
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45

                onClicked: {
                    if (filterUsable) {
                        controller.selectedStatus = -1
                    }
                }

                QQC2.ToolTip {
                    visible: !allStatusDelegate.filterUsable && allStatusDelegate.hovered
                    text: root.filterDisabledReason("status")
                }

                background: SelectionBackground {
                    control: allStatusDelegate
                    selected: allStatusDelegate.highlighted
                }

                contentItem: QQC2.Label {
                    text: i18n("All")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: allStatusDelegate.highlighted || allStatusDelegate.down ? 1.0 : 0.75
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                }
            }
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: statusDelegate
            width: root.listContentWidth(statusList)
            hoverEnabled: root.rowHoverEnabled
            readonly property bool filterUsable: root.filterEnabled("status")
            highlighted: ListView.isCurrentItem
            enabled: filterUsable
            opacity: filterUsable ? 1.0 : 0.45
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SidebarHoverBackground {
                        control: statusDelegate
                    }

                Rectangle {
                    anchors.fill: parent
                    radius: Design.inputRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: statusDrop.containsDrag ? 0.28 : 0
                    visible: opacity > 0
                }
            }

            DropArea {
                id: statusDrop
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                enabled: root.isDragging && filterUsable

                readonly property string hintText: i18n("Set status “%1”", modelData.label)

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
                    if (root.dropTaskOnStatus(modelData.value)) {
                        drop.acceptProposedAction()
                    }
                }
            }

            onClicked: {
                if (!filterUsable) {
                    return
                }
                if (controller.selectedStatus === modelData.value) {
                    controller.selectedStatus = -1
                } else {
                    controller.selectedStatus = modelData.value
                }
            }

            QQC2.ToolTip {
                visible: !statusDelegate.filterUsable && statusDelegate.hovered
                text: root.filterDisabledReason("status")
            }

            contentItem: RowLayout {
                spacing: Design.spaceSmall

                Item { width: root.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.rowIconSize
                    Layout.preferredHeight: root.rowIconSize
                    source: root.statusIconForValue(modelData.value)
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.listContentWidth(statusList)
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData.label
                    selected: statusDelegate.highlighted || statusDelegate.down || statusDrop.containsDrag
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.sidebarStatusCounts[String(modelData.value)]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !statusBlock.isLastVisible
    }
    }

    // ── Secrecy section ──
    Item {
        id: secrecyBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: secrecyList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: secrecyList
        width: parent ? parent.width : 0
        height: root.allocFor("secrecy")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(secrecyList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(secrecyList)
        model: root.secrecyItems
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            if (controller.selectedSecrecy < 0) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (m[i].value === controller.selectedSecrecy) { currentIndex = i; return }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: secrecyList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: root.listContentWidth(secrecyList)
            height: root.sectionHeaderHeight
            Layout.leftMargin: Design.spaceSmall
            Layout.rightMargin: Design.spaceSmall
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: i18n("Secrecy")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                verticalAlignment: Text.AlignVCenter
            }

            PlasmaComponents3.ItemDelegate {
                id: allSecrecyDelegate
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.preferredHeight: root.sectionHeaderHeight
                hoverEnabled: root.rowHoverEnabled
                highlighted: controller.selectedSecrecy < 0
                readonly property bool filterUsable: root.filterEnabled("secrecy")
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45

                onClicked: {
                    if (filterUsable) {
                        controller.selectedSecrecy = -1
                    }
                }

                QQC2.ToolTip {
                    visible: !allSecrecyDelegate.filterUsable && allSecrecyDelegate.hovered
                    text: root.filterDisabledReason("secrecy")
                }

                background: SelectionBackground {
                    control: allSecrecyDelegate
                    selected: allSecrecyDelegate.highlighted
                }

                contentItem: QQC2.Label {
                    text: i18n("All")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: allSecrecyDelegate.highlighted || allSecrecyDelegate.down ? 1.0 : 0.75
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                }
            }
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: secrecyDelegate
            width: root.listContentWidth(secrecyList)
            hoverEnabled: root.rowHoverEnabled
            readonly property bool filterUsable: root.filterEnabled("secrecy")
            highlighted: ListView.isCurrentItem
            enabled: filterUsable
            opacity: filterUsable ? 1.0 : 0.45
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SidebarHoverBackground {
                        control: secrecyDelegate
                    }

                Rectangle {
                    anchors.fill: parent
                    radius: Design.inputRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: secrecyDrop.containsDrag ? 0.28 : 0
                    visible: opacity > 0
                }
            }

            DropArea {
                id: secrecyDrop
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                enabled: root.isDragging && filterUsable

                readonly property string hintText: i18n("Set secrecy “%1”", modelData.label)

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
                    if (root.dropTaskOnSecrecy(modelData.value)) {
                        drop.acceptProposedAction()
                    }
                }
            }

            onClicked: {
                if (!filterUsable) {
                    return
                }
                if (controller.selectedSecrecy === modelData.value) {
                    controller.selectedSecrecy = -1
                } else {
                    controller.selectedSecrecy = modelData.value
                }
            }

            QQC2.ToolTip {
                visible: !secrecyDelegate.filterUsable && secrecyDelegate.hovered
                text: root.filterDisabledReason("secrecy")
            }

            contentItem: RowLayout {
                spacing: Design.spaceSmall

                Item { width: root.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.rowIconSize
                    Layout.preferredHeight: root.rowIconSize
                    source: root.secrecyIconForValue(modelData.value)
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.listContentWidth(secrecyList)
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData.label
                    selected: secrecyDelegate.highlighted || secrecyDelegate.down || secrecyDrop.containsDrag
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.sidebarSecrecyCounts[String(modelData.value)]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !secrecyBlock.isLastVisible
    }
    }

    // ── Location section ──
    Item {
        id: locationBlock
        width: parent ? parent.width : 0
        property bool isLastVisible: false
        height: locationList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: locationList
        width: parent ? parent.width : 0
        height: root.allocFor("location")
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(locationList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleLocationItems
        currentIndex: -1
        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        function syncIndex() {
            if (!controller) { currentIndex = -1; return }
            var sel = controller.selectedLocation || ""
            if (!sel.length) { currentIndex = -1; return }
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (String(m[i]) === sel) { currentIndex = i; return }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        leftMargin: 0
        rightMargin: root.scrollMarginFor(locationList)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: locationList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: root.listContentWidth(locationList)
            height: root.sectionHeaderHeight
            Layout.leftMargin: Design.spaceSmall
            Layout.rightMargin: Design.spaceSmall
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: i18n("Location")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                verticalAlignment: Text.AlignVCenter
            }

            PlasmaComponents3.ItemDelegate {
                id: allLocationsDelegate
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.preferredHeight: root.sectionHeaderHeight
                hoverEnabled: root.rowHoverEnabled
                highlighted: controller.selectedLocation === ""
                readonly property bool filterUsable: root.filterEnabled("location")
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45

                onClicked: {
                    if (filterUsable) {
                        controller.selectedLocation = ""
                    }
                }

                QQC2.ToolTip {
                    visible: !allLocationsDelegate.filterUsable && allLocationsDelegate.hovered
                    text: root.filterDisabledReason("location")
                }

                background: SelectionBackground {
                    control: allLocationsDelegate
                    selected: allLocationsDelegate.highlighted
                }

                contentItem: QQC2.Label {
                    text: i18n("All")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: allLocationsDelegate.highlighted || allLocationsDelegate.down ? 1.0 : 0.75
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                }
            }
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: locationDelegate
            width: root.listContentWidth(locationList)
            hoverEnabled: root.rowHoverEnabled
            readonly property bool filterUsable: root.filterEnabled("location")
            highlighted: ListView.isCurrentItem
            enabled: filterUsable
            opacity: filterUsable ? 1.0 : 0.45
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SidebarHoverBackground {
                        control: locationDelegate
                    }

                Rectangle {
                    anchors.fill: parent
                    radius: Design.inputRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: locationDrop.containsDrag ? 0.28 : 0
                    visible: opacity > 0
                }
            }

            DropArea {
                id: locationDrop
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                enabled: root.isDragging && filterUsable

                readonly property string hintText: root.locationDropHint(modelData)

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
                    if (root.dropTaskOnLocation(modelData)) {
                        drop.acceptProposedAction()
                    }
                }
            }

            onClicked: {
                if (!filterUsable) {
                    return
                }
                if (controller.selectedLocation === modelData) {
                    controller.selectedLocation = ""
                } else {
                    controller.selectedLocation = modelData
                }
            }

            QQC2.ToolTip {
                visible: !locationDelegate.filterUsable && locationDelegate.hovered
                text: root.filterDisabledReason("location")
            }

            contentItem: RowLayout {
                spacing: Design.spaceSmall

                Item { width: root.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.rowIconSize
                    Layout.preferredHeight: root.rowIconSize
                    source: "mark-location"
                    color: Design.colorForKey(String(modelData), "location")
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.listContentWidth(locationList)
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData
                    selected: locationDelegate.highlighted || locationDelegate.down || locationDrop.containsDrag
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.sidebarLocationCounts[modelData]
                        return n === undefined ? "" : String(n)
                    }
                    visible: root.showSidebarCounts && text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !locationBlock.isLastVisible
    }
    }

    }

    QQC2.Dialog {
        id: confirmRemoveLabelDialog
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
