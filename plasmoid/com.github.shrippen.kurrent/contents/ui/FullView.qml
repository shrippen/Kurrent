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
    readonly property alias taskListItem: taskList

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
            + Kirigami.Units.gridUnit * 24
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
        dragProxy.Drag.active = true
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
        if (dragProxy.Drag.active) {
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
        { id: "due", label: i18n("Due date") },
        { id: "dueDesc", label: i18n("Due date (latest first)") },
        { id: "start", label: i18n("Start date") },
        { id: "priority", label: i18n("Priority") },
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

    readonly property var sortKeys: parseSortKeys(backend ? backend.sortMode : defaultSortMode)

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
        return id
    }

    function sortKeysConflict(a, b) {
        if (!a || !b || a === "none" || b === "none") {
            return false
        }
        return sortFieldFamily(a) === sortFieldFamily(b)
    }

    function sortKeyLabel(id) {
        if (!id || id === "none") {
            return i18n("None")
        }
        var options = sortOptions
        for (var i = 0; i < options.length; ++i) {
            if (options[i].id === id) {
                return options[i].label
            }
        }
        return id
    }

    function sortModeLabel(mode) {
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
        var out = []
        if (level > 0) {
            out.push({ id: "none", label: i18n("None") })
        }
        var options = sortOptions
        for (var j = 0; j < options.length; ++j) {
            var opt = options[j]
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

    function openSortMenu() {
        var margin = KurrentUi.Design.spaceSmall
        var maxWidth = Math.max(Kirigami.Units.gridUnit * 8, fullRoot.width - margin * 2)
        sortMenu.width = Math.min(Kirigami.Units.gridUnit * 16,
                                  Math.max(Kirigami.Units.gridUnit * 11, maxWidth))

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
            dragHost: fullRoot
                hiddenProjects: Plasmoid.configuration.hiddenProjects || ""
                hiddenLabels: Plasmoid.configuration.hiddenLabels || ""
                sidebarRowSize: Plasmoid.configuration.sidebarRowSize || "auto"
                showEmptyProjects: Plasmoid.configuration.showEmptyProjects === true
                showSidebarCounts: Plasmoid.configuration.showSidebarCounts !== false
                sectionOrder: Plasmoid.configuration.sidebarSectionOrder || "views,projects,labels,priorities"
                hiddenSections: Plasmoid.configuration.hiddenSidebarSections || ""
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

        ColumnLayout {
            id: mainPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            Layout.minimumHeight: 0
            Layout.maximumHeight: Infinity
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

                // Active filters inline with the view title (same colored icons as sidebar).
                Repeater {
                    model: plasmoidRoot.activeFilters
                    delegate: RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        QQC2.Label {
                            text: "·"
                            opacity: 0.5
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: modelData.kind === "project" ? "folder"
                                  : modelData.kind === "priority" ? "flag"
                                  : "tag"
                            color: modelData.kind === "priority"
                                   ? Colors.colorForPriority(modelData.key)
                                   : KurrentUi.Design.colorForKey(modelData.key, modelData.kind === "label" ? "label" : "project")
                            width: Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small
                        }

                        QQC2.Label {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                            text: modelData.text
                            opacity: 0.8
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                QQC2.ToolButton {
                    id: sortButton
                    Layout.alignment: Qt.AlignVCenter
                    icon.name: "view-sort"
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: fullRoot.openSortMenu()
                    QQC2.ToolTip.text: i18n("Sort: %1", fullRoot.sortModeLabel(backend.sortMode))
                    QQC2.ToolTip.visible: hovered
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
            }

            VersionMismatchBanner {
                visible: plasmoidRoot.backendVersionMismatch
                Layout.fillWidth: true
                widgetVersion: plasmoidRoot.widgetVersion
                backendVersion: plasmoidRoot.backendVersion
            }

            TaskListView {
                id: taskList
                controller: backend
                dragHost: fullRoot
                hiddenProjects: Plasmoid.configuration.hiddenProjects || ""
                newTaskProjectMode: Plasmoid.configuration.newTaskProjectMode || "ask"
                newTaskDefaultCollectionId: Plasmoid.configuration.newTaskDefaultCollectionId || ""
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
        visible: Drag.active && !!fullRoot.draggingTask
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

    QQC2.Popup {
        id: sortMenu
        parent: fullRoot
        popupType: QQC2.Popup.Item
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
                contentHeight: sortColumn.implicitHeight
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

                ColumnLayout {
                    id: sortColumn
                    width: sortFlick.width
                    spacing: KurrentUi.Design.spaceMedium

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
                                // Binding owns checked state; autoExclusive would prefer the
                                // first sibling ("None" on levels 2–3) and fight the binding.
                                autoExclusive: false
                                checked: currentId === modelData.id
                                onClicked: fullRoot.setSortLevel(level, modelData.id)
                            }
                        }
                    }

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
