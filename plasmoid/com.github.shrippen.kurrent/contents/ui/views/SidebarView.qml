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
    property string hiddenProjects: ""
    property string hiddenLabels: ""
    // "auto" | "compact" | "comfortable"
    property string sidebarRowSize: "auto"
    property bool showEmptyProjects: false
    property bool showSidebarCounts: true
    property string sectionOrder: "views,projects,labels,priorities"
    property string hiddenSections: ""
    property string viewOrder: ""
    property string hiddenViews: ""

    readonly property string sectionDefaults: "views,projects,labels,priorities"
    readonly property string viewDefaults: "inbox,today,overdue,tomorrow,scheduled,anytime,recurring,unlabeled,completed"
    readonly property var visibleSectionIdList: controller
            ? controller.visibleOrderedKeys(sectionOrder, hiddenSections, sectionDefaults, ",", "||")
            : ["views", "projects", "labels", "priorities"]
    readonly property int visibleSectionCount: visibleSectionIdList.length

    readonly property int sidebarWidth: Design.sidebarWidth
    readonly property bool isDragging: !!(dragHost && dragHost.draggingTask)

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

    // -1: not yet allocated — sections share space (fillHeight) so they can measure.
    property bool sectionsAllocated: false
    property int viewsAlloc: -1
    property int projectsAlloc: -1
    property int labelsAlloc: -1
    property int prioritiesAlloc: -1

    readonly property string sectionContentKey: JSON.stringify(controller.sidebarProjectCounts)
            + "|" + JSON.stringify(controller.sidebarLabelCounts)
            + "|" + (controller.collectionModel ? controller.collectionModel.count : 0)
            + "|" + controller.availableLabels.join("\n")
            + "|" + hiddenProjects
            + "|" + String(showEmptyProjects)
            + "|" + String(showSidebarCounts)
            + "|" + hiddenLabels
            + "|" + sectionOrder
            + "|" + hiddenSections
            + "|" + viewOrder
            + "|" + hiddenViews

    property var visibleProjects: []
    property var visibleLabelItems: []

    onHeightChanged: Qt.callLater(redistributeSections)
    onAvailableHeightChanged: Qt.callLater(redistributeSections)
    onSectionContentKeyChanged: {
        rebuildVisibleLists()
        Qt.callLater(redistributeSections)
        Qt.callLater(applySectionOrder)
    }
    Component.onCompleted: {
        rebuildVisibleLists()
        Qt.callLater(applySectionOrder)
        Qt.callLater(redistributeSections)
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
    }

    function visibleProjectCount() {
        return visibleProjects.length
    }

    function visibleLabelCount() {
        return visibleLabelItems.length
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

        var ids = ["views", "projects", "labels", "priorities"]
        var hasHeader = [false, true, true, true]
        var naturals = [
            root.naturalHeightViews(),
            root.naturalHeightProjects(),
            root.naturalHeightLabels(),
            root.naturalHeightPriorities()
        ]
        var visibleFlags = []
        var visibleCount = 0
        var sumNatural = 0
        for (var s = 0; s < 4; ++s) {
            var vis = root.sectionVisible(ids[s])
            visibleFlags.push(vis)
            if (vis) {
                ++visibleCount
                sumNatural += naturals[s]
            }
        }
        if (visibleCount <= 0) {
            viewsAlloc = 0
            projectsAlloc = 0
            labelsAlloc = 0
            prioritiesAlloc = 0
            sectionsAllocated = true
            return
        }

        var alloc = [0, 0, 0, 0]
        // Slack is only for scrollbar visibility (Design.listNeedsScroll), not allocation —
        // otherwise resizing feels sticky near the fit boundary then jumps.
        if (sumNatural <= available) {
            var leftover = available - sumNatural
            var evenGrow = Math.floor(leftover / visibleCount)
            var extraGrow = leftover - evenGrow * visibleCount
            for (var i = 0; i < 4; ++i) {
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
            for (var m = 0; m < 4; ++m) {
                var floorH = visibleFlags[m] ? root.sectionFloorHeight(hasHeader[m]) : 0
                mins.push(floorH)
                sumMins += floorH
            }

            if (sumMins >= available) {
                alloc = mins.slice(0)
                var over = sumMins - available
                if (over > 0) {
                    for (var t = 0; t < 4 && over > 0; ++t) {
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
                for (var f = 0; f < 4; ++f) {
                    if (visibleFlags[f]) {
                        flexNatural += Math.max(0, naturals[f] - mins[f])
                    }
                }
                var remain = flex
                for (var p = 0; p < 4; ++p) {
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
                for (var r = 0; r < 4 && remain > 0; ++r) {
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
        for (var g = 0; g < 4; ++g) {
            if (!visibleFlags[g]) {
                continue
            }
            var shortfall = naturals[g] - alloc[g]
            if (shortfall <= 0 || shortfall > oneRow) {
                continue
            }
            var need = shortfall
            for (var donor = 0; donor < 4 && need > 0; ++donor) {
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

        if (viewsAlloc !== alloc[0]) {
            viewsAlloc = alloc[0]
        }
        if (projectsAlloc !== alloc[1]) {
            projectsAlloc = alloc[1]
        }
        if (labelsAlloc !== alloc[2]) {
            labelsAlloc = alloc[2]
        }
        if (prioritiesAlloc !== alloc[3]) {
            prioritiesAlloc = alloc[3]
        }
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
            "priorities": prioritiesBlock
        }
        var key
        for (key in blocks) {
            if (!blocks[key]) {
                continue
            }
            blocks[key].visible = ids.indexOf(key) >= 0
        }
        for (var i = 0; i < ids.length; ++i) {
            var block = blocks[ids[i]]
            if (!block) {
                continue
            }
            block.parent = null
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
        controller.addTaskCategory(dragHost.draggingTask.itemId, label)
        return true
    }

    function dropTaskOnPriority(priority) {
        if (!dragHost || !dragHost.draggingTask) {
            return false
        }
        controller.setTaskPriority(dragHost.draggingTask.itemId, priority)
        return true
    }

    readonly property var viewItems: [
        { viewId: "inbox", label: i18n("Inbox"), icon: "mail-folder-inbox" },
        { viewId: "today", label: i18n("Today"), icon: "view-calendar-day" },
        { viewId: "overdue", label: i18n("Overdue"), icon: "chronometer" },
        { viewId: "tomorrow", label: i18n("Tomorrow"), icon: "go-next" },
        { viewId: "scheduled", label: i18n("Scheduled"), icon: "view-calendar" },
        { viewId: "anytime", label: i18n("Anytime"), icon: "view-calendar-tasks" },
        { viewId: "recurring", label: i18n("Recurring"), icon: "media-playlist-repeat" },
        { viewId: "unlabeled", label: i18n("Unlabeled"), icon: "tag-delete" },
        { viewId: "completed", label: i18n("Completed"), icon: "checkmark" }
    ]

    readonly property var visibleViewItems: {
        if (!controller) {
            return viewItems
        }
        var order = controller.visibleOrderedKeys(viewOrder, hiddenViews, viewDefaults, ",", "||")
        var byId = {}
        for (var i = 0; i < viewItems.length; ++i) {
            byId[viewItems[i].viewId] = viewItems[i]
        }
        var out = []
        for (var j = 0; j < order.length; ++j) {
            if (byId[order[j]]) {
                out.push(byId[order[j]])
            }
        }
        return out.length ? out : viewItems
    }

    readonly property var priorityItems: [
        { value: 1, label: i18n("High") },
        { value: 5, label: i18n("Medium") },
        { value: 9, label: i18n("Low") },
        { value: 0, label: i18n("None") }
    ]

    function indexForView(viewId) {
        for (var i = 0; i < visibleViewItems.length; ++i) {
            if (visibleViewItems[i].viewId === viewId) {
                return i
            }
        }
        return 0
    }

    function clearFilterSelections() {
        controller.selectedCollectionId = -1
        controller.selectedLabel = ""
        controller.selectedPriority = -1
    }

    component SidebarHoverBackground: KSvg.FrameSvgItem {
        required property Item control
        imagePath: "widgets/listitem"
        prefix: "hover"
        anchors.fill: parent
        visible: !Kirigami.Settings.isMobile
        opacity: control.hovered && !control.down ? 1 : 0
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
        property bool isLastVisible: false
        height: viewsList.height + (visible && !isLastVisible ? root.separatorStrip : 0)

    ListView {
        id: viewsList
        width: parent ? parent.width : 0
        height: root.sectionsAllocated ? root.viewsAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(viewsList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(viewsList)
        model: root.visibleViewItems
        currentIndex: root.indexForView(controller.currentView)

        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: viewsList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        delegate: PlasmaComponents3.ItemDelegate {
            id: viewDelegate
            width: root.listContentWidth(viewsList)
            hoverEnabled: true
            highlighted: ListView.isCurrentItem
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: SidebarHoverBackground {
                control: viewDelegate
            }

            onClicked: {
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
                    // Keep icon box fixed so glyphs like mail-folder-inbox don't look top-heavy.
                    width: root.rowIconSize
                    height: root.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    title: modelData.label
                    selected: viewDelegate.highlighted || viewDelegate.down
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = controller.viewTaskCounts[modelData.viewId]
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
        height: root.sectionsAllocated ? root.projectsAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(projectsList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleProjects
        currentIndex: -1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(projectsList)

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
                    hoverEnabled: true
                    highlighted: controller.selectedCollectionId < 0

                    onClicked: controller.selectedCollectionId = -1

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
                hoverEnabled: true
                readonly property bool filterSelected: controller.selectedCollectionId === modelData.collectionId
                highlighted: filterSelected
                leftPadding: 0
                rightPadding: Design.spaceSmall
                topPadding: root.rowVPad
                bottomPadding: root.rowVPad

                background: Item {
                    anchors.fill: parent

                    SelectionBackground {
                        control: projectDelegate
                        selected: projectDelegate.filterSelected
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
                    enabled: root.isDragging && controller.collectionModel.writableForId(modelData.collectionId)

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
                    if (controller.selectedCollectionId === modelData.collectionId) {
                        controller.selectedCollectionId = -1
                    } else {
                        controller.selectedCollectionId = modelData.collectionId
                    }
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
        height: root.sectionsAllocated ? root.labelsAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(labelsList) || root.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleLabelItems
        currentIndex: -1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(labelsList)

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
                    hoverEnabled: true
                    highlighted: controller.selectedLabel === ""

                    onClicked: controller.selectedLabel = ""

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
                hoverEnabled: true
                readonly property bool filterSelected: controller.selectedLabel === modelData
                highlighted: filterSelected
                leftPadding: 0
                rightPadding: Design.spaceSmall
                topPadding: root.rowVPad
                bottomPadding: root.rowVPad

                background: Item {
                    anchors.fill: parent

                    SelectionBackground {
                        control: labelDelegate
                        selected: labelDelegate.filterSelected
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

                    readonly property string hintText: i18n("Add label “%1”", modelData)

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
                    if (controller.selectedLabel === modelData) {
                        controller.selectedLabel = ""
                    } else {
                        controller.selectedLabel = modelData
                    }
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
        height: root.sectionsAllocated ? root.prioritiesAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
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
                hoverEnabled: true
                highlighted: controller.selectedPriority < 0

                onClicked: controller.selectedPriority = -1

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
            hoverEnabled: true
            readonly property bool filterSelected: controller.selectedPriority === modelData.value
            highlighted: filterSelected
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SelectionBackground {
                    control: priorityDelegate
                    selected: priorityDelegate.filterSelected
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
                enabled: root.isDragging

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
                if (controller.selectedPriority === modelData.value) {
                    controller.selectedPriority = -1
                } else {
                    controller.selectedPriority = modelData.value
                }
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
    }
    }
    }
