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

    readonly property int availableHeight: Math.max(0, Math.floor(height - separatorStrip * 3))

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
    property int viewsAlloc: -1
    property int projectsAlloc: -1
    property int labelsAlloc: -1
    property int prioritiesAlloc: -1

    readonly property string sectionContentKey: JSON.stringify(controller.sidebarProjectCounts)
            + "|" + JSON.stringify(controller.sidebarLabelCounts)
            + "|" + (controller.collectionModel ? controller.collectionModel.count : 0)
            + "|" + controller.availableLabels.join("\n")
            + "|" + hiddenProjects
            + "|" + hiddenLabels

    property var visibleProjects: []
    property var visibleLabelItems: []

    onHeightChanged: Qt.callLater(redistributeSections)
    onAvailableHeightChanged: Qt.callLater(redistributeSections)
    onSectionContentKeyChanged: {
        rebuildVisibleLists()
        Qt.callLater(redistributeSections)
    }
    onSectionHeaderHeightChanged: Qt.callLater(redistributeSections)
    onSectionRowHeightChanged: Qt.callLater(redistributeSections)
    Component.onCompleted: {
        rebuildVisibleLists()
        Qt.callLater(redistributeSections)
    }

    function rebuildVisibleLists() {
        var projects = []
        var model = controller.collectionModel
        if (model) {
            for (var i = 0; i < model.count; ++i) {
                var collectionId = model.collectionIdAt(i)
                if (model.taskCountAt(i) > 0 && !root._isProjectHidden(collectionId)) {
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
        return root.naturalListHeight(root.viewItems.length, false)
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

    function listContentWidth(list) {
        if (!list) {
            return 1
        }
        return Math.max(1, list.width - list.leftMargin - list.rightMargin)
    }

    function listNeedsScroll(list) {
        return !!(list && list.contentHeight > list.height + 1)
    }

    function scrollMarginFor(list) {
        if (!list) {
            return Kirigami.Units.smallSpacing
        }
        return root.listNeedsScroll(list) ? root.scrollGutter : Kirigami.Units.smallSpacing
    }

    function sectionMinHeight(list, estimated) {
        var measured = list ? Math.ceil(list.contentHeight) : 0
        if (measured <= 1) {
            return Math.max(1, estimated)
        }
        return Math.max(1, estimated, measured)
    }

    function redistributeSections() {
        var available = root.availableHeight
        if (available < 4) {
            return
        }

        var mins = [
            root.sectionMinHeight(viewsList, root.naturalHeightViews()),
            root.sectionMinHeight(projectsList, root.naturalHeightProjects()),
            root.sectionMinHeight(labelsList, root.naturalHeightLabels()),
            root.sectionMinHeight(prioritiesList, root.naturalHeightPriorities())
        ]

        var sumMins = mins[0] + mins[1] + mins[2] + mins[3]
        var alloc = [mins[0], mins[1], mins[2], mins[3]]

        if (sumMins > available) {
            // Not enough space: keep the previous lock/share shrink so sections that
            // fit stay compact and the rest share what is left (and scroll).
            var locked = [false, false, false, false]
            alloc = [0, 0, 0, 0]
            var remaining = available
            var open = 4
            var progress = true
            var guard = 0
            while (progress && open > 0 && guard < 8) {
                ++guard
                progress = false
                var share = remaining / open
                for (var j = 0; j < 4; ++j) {
                    if (!locked[j] && mins[j] <= share) {
                        locked[j] = true
                        alloc[j] = mins[j]
                        remaining -= mins[j]
                        open--
                        progress = true
                    }
                }
            }
            if (open > 0) {
                var even = Math.floor(remaining / open)
                var extra = remaining - even * open
                for (var k = 0; k < 4; ++k) {
                    if (!locked[k]) {
                        alloc[k] = even + (extra > 0 ? 1 : 0)
                        if (extra > 0) {
                            extra--
                        }
                    }
                }
            }
        } else {
            // Extra widget height goes into the lists so the plasmoid can grow
            // past "all sidebar rows visible".
            var leftover = available - sumMins
            var evenGrow = Math.floor(leftover / 4)
            var extraGrow = leftover - evenGrow * 4
            for (var i = 0; i < 4; ++i) {
                alloc[i] += evenGrow + (extraGrow > 0 ? 1 : 0)
                if (extraGrow > 0) {
                    extraGrow--
                }
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
    }

    function _isProjectHidden(collectionId) {
        if (!hiddenProjects) return false
        var parts = hiddenProjects.split(",")
        return parts.indexOf(String(collectionId)) >= 0
    }

    function _isLabelHidden(label) {
        if (!hiddenLabels) return false
        var parts = hiddenLabels.split("||")
        return parts.indexOf(label) >= 0
    }

    function indexForProject(collectionId) {
        if (collectionId < 0) {
            return -1
        }
        for (var i = 0; i < visibleProjects.length; ++i) {
            if (Number(visibleProjects[i].collectionId) === Number(collectionId)) {
                return i
            }
        }
        return -1
    }

    function indexForLabel(label) {
        if (!label) {
            return -1
        }
        return visibleLabelItems.indexOf(label)
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

    function syncProjectsIndex() {
        var idx = root.indexForProject(controller.selectedCollectionId)
        if (projectsList.currentIndex !== idx) {
            projectsList.currentIndex = idx
        }
    }

    function syncLabelsIndex() {
        var idx = root.indexForLabel(controller.selectedLabel)
        if (labelsList.currentIndex !== idx) {
            labelsList.currentIndex = idx
        }
    }

    function indexForPriority(priority) {
        if (priority < 0) {
            return -1
        }
        for (var i = 0; i < priorityItems.length; ++i) {
            if (priorityItems[i].value === priority) {
                return i
            }
        }
        return -1
    }

    function syncPrioritiesIndex() {
        var idx = root.indexForPriority(controller.selectedPriority)
        if (prioritiesList.currentIndex !== idx) {
            prioritiesList.currentIndex = idx
        }
    }

    readonly property var viewItems: [
        { viewId: "inbox", label: i18n("Inbox"), icon: "mail-folder-inbox" },
        { viewId: "today", label: i18n("Today"), icon: "view-calendar-day" },
        { viewId: "tomorrow", label: i18n("Tomorrow"), icon: "go-next" },
        { viewId: "scheduled", label: i18n("Scheduled"), icon: "view-calendar" },
        { viewId: "anytime", label: i18n("Anytime"), icon: "view-calendar-tasks" },
        { viewId: "recurring", label: i18n("Recurring"), icon: "media-playlist-repeat" },
        { viewId: "unlabeled", label: i18n("Unlabeled"), icon: "tag-delete" },
        { viewId: "completed", label: i18n("Completed"), icon: "checkmark" }
    ]

    readonly property var priorityItems: [
        { value: 1, label: i18n("High") },
        { value: 5, label: i18n("Medium") },
        { value: 9, label: i18n("Low") },
        { value: 0, label: i18n("None") }
    ]

    function indexForView(viewId) {
        for (var i = 0; i < viewItems.length; ++i) {
            if (viewItems[i].viewId === viewId) {
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
    }

    Column {
        id: sectionColumn
        anchors.fill: parent
        spacing: 0
        clip: true

    // ── Views ──
    ListView {
        id: viewsList
        width: parent.width
        height: root.viewsAlloc > 0 ? root.viewsAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(viewsList)
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(viewsList)
        model: root.viewItems
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
            rightPadding: Kirigami.Units.smallSpacing
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
                spacing: Kirigami.Units.smallSpacing

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
                    visible: text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }

    // ── Separator before Projects ──
    Item {
        width: parent.width
        height: root.separatorStrip
        Kirigami.Separator {
            width: parent.width
            anchors.bottom: parent.bottom
        }
    }

    // ── Projects section ──
    ListView {
        id: projectsList
        width: parent.width
        height: root.projectsAlloc > 0 ? root.projectsAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(projectsList)
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleProjects
        currentIndex: -1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(projectsList)

        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: projectsList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        Component.onCompleted: root.syncProjectsIndex()

            Connections {
                target: controller
                function onSelectedCollectionIdChanged() {
                    root.syncProjectsIndex()
                }
            }

            Connections {
                target: controller.collectionModel
                function onCountChanged() {
                    root.rebuildVisibleLists()
                    Qt.callLater(root.syncProjectsIndex)
                    Qt.callLater(root.redistributeSections)
                }
            }

            headerPositioning: ListView.InlineHeader
            header: RowLayout {
                width: root.listContentWidth(projectsList)
                height: root.sectionHeaderHeight
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
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
                        leftPadding: Kirigami.Units.smallSpacing
                        rightPadding: Kirigami.Units.smallSpacing
                    }
                }
            }

            delegate: PlasmaComponents3.ItemDelegate {
                id: projectDelegate
                width: root.listContentWidth(projectsList)
                hoverEnabled: true
                highlighted: ListView.isCurrentItem
                leftPadding: 0
                rightPadding: Kirigami.Units.smallSpacing
                topPadding: root.rowVPad
                bottomPadding: root.rowVPad

                background: Item {
                    anchors.fill: parent

                    SidebarHoverBackground {
                        control: projectDelegate
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
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
                    spacing: Kirigami.Units.smallSpacing

                    Item { width: root.rowLeftInset }

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.rowIconSize
                        Layout.preferredHeight: root.rowIconSize
                        source: "folder"
                        color: Colors.colorForKey(String(modelData.collectionId))
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
                        visible: text.length > 0
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
            }
        }

    // ── Separator before Labels ──
    Item {
        width: parent.width
        height: root.separatorStrip
        Kirigami.Separator {
            width: parent.width
            anchors.bottom: parent.bottom
        }
    }

    // ── Labels section ──
    ListView {
        id: labelsList
        width: parent.width
        height: root.labelsAlloc > 0 ? root.labelsAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(labelsList)
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: root.visibleLabelItems
        currentIndex: -1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(labelsList)

        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: labelsList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        Component.onCompleted: root.syncLabelsIndex()

            Connections {
                target: controller
                function onSelectedLabelChanged() {
                    root.syncLabelsIndex()
                }
                function onAvailableLabelsChanged() {
                    root.rebuildVisibleLists()
                    Qt.callLater(root.syncLabelsIndex)
                    Qt.callLater(root.redistributeSections)
                }
            }

            headerPositioning: ListView.InlineHeader
            header: RowLayout {
                width: root.listContentWidth(labelsList)
                height: root.sectionHeaderHeight
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
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
                        leftPadding: Kirigami.Units.smallSpacing
                        rightPadding: Kirigami.Units.smallSpacing
                    }
                }
            }

            delegate: PlasmaComponents3.ItemDelegate {
                id: labelDelegate
                width: root.listContentWidth(labelsList)
                hoverEnabled: true
                highlighted: ListView.isCurrentItem
                leftPadding: 0
                rightPadding: Kirigami.Units.smallSpacing
                topPadding: root.rowVPad
                bottomPadding: root.rowVPad

                background: Item {
                    anchors.fill: parent

                    SidebarHoverBackground {
                        control: labelDelegate
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
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
                    spacing: Kirigami.Units.smallSpacing

                    Item { width: root.rowLeftInset }

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.rowIconSize
                        Layout.preferredHeight: root.rowIconSize
                        source: "tag"
                        color: Colors.colorForKey(String(modelData))
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
                        visible: text.length > 0
                        opacity: 0.55
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
            }
        }

    // ── Separator before Priorities ──
    Item {
        width: parent.width
        height: root.separatorStrip
        Kirigami.Separator {
            width: parent.width
            anchors.bottom: parent.bottom
        }
    }

    // ── Priorities section ──
    ListView {
        id: prioritiesList
        width: parent.width
        height: root.prioritiesAlloc > 0 ? root.prioritiesAlloc : Math.max(1, Math.floor(root.availableHeight / 4))
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: root.listNeedsScroll(prioritiesList)
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        leftMargin: 0
        rightMargin: root.scrollMarginFor(prioritiesList)
        model: root.priorityItems
        currentIndex: -1

        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: Kirigami.Units.longDuration

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: prioritiesList }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(root.redistributeSections)

        Component.onCompleted: root.syncPrioritiesIndex()

        Connections {
            target: controller
            function onSelectedPriorityChanged() {
                root.syncPrioritiesIndex()
            }
        }

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: root.listContentWidth(prioritiesList)
            height: root.sectionHeaderHeight
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
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
                    leftPadding: Kirigami.Units.smallSpacing
                    rightPadding: Kirigami.Units.smallSpacing
                }
            }
        }

            delegate: PlasmaComponents3.ItemDelegate {
                id: priorityDelegate
                width: root.listContentWidth(prioritiesList)
            hoverEnabled: true
            highlighted: ListView.isCurrentItem
            leftPadding: 0
            rightPadding: Kirigami.Units.smallSpacing
            topPadding: root.rowVPad
            bottomPadding: root.rowVPad

            background: Item {
                anchors.fill: parent

                SidebarHoverBackground {
                    control: priorityDelegate
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 3
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
                spacing: Kirigami.Units.smallSpacing

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
                    visible: text.length > 0
                    opacity: 0.55
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }
        }
    }
    }
}
