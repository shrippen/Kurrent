import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "views"
import "colors.js" as Colors
import "." as KurrentUi

PlasmoidItem {
    id: root

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 18

    // Desktop wallpaper blur: BasicAppletContainer only blurs with StandardBackground
    // (widgets/background + prefix "blurred"). Panel flyout blur is set separately on
    // the AppletPopup window in applyPopupBackground().
    Plasmoid.backgroundHints: Plasmoid.configuration.blurBackground
            ? PlasmaCore.Types.DefaultBackground
            : PlasmaCore.Types.TranslucentBackground

    function applyPopupBackground() {
        var item = root.fullRepresentationItem
        if (!item) {
            return
        }
        var w = item.Window.window
        // Panel flyout is PlasmaCore.AppletPopup (has popupDirection).
        // Do not touch the desktop containment window.
        if (!w || w.popupDirection === undefined) {
            return
        }
        w.backgroundHints = Plasmoid.configuration.blurBackground
                ? PlasmaCore.AppletPopup.StandardBackground
                : PlasmaCore.AppletPopup.SolidBackground
    }

    onExpandedChanged: applyPopupBackground()
    onFullRepresentationItemChanged: applyPopupBackground()

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge
    ].includes(Plasmoid.location)

    readonly property TaskController backend: taskController

    readonly property var activeFilters: {
        // Depend on filter properties so the UI updates when they change.
        var collectionId = backend.selectedCollectionId
        var label = backend.selectedLabel
        var priority = backend.selectedPriority
        var parts = []
        if (collectionId >= 0) {
            var projectName = backend.collectionNameForId(collectionId)
            if (projectName) {
                parts.push({ kind: "project", text: projectName, key: String(collectionId) })
            }
        }
        if (label && label !== "") {
            parts.push({ kind: "label", text: label, key: label })
        }
        if (priority >= 0) {
            var priorityText = i18n("None")
            if (priority >= 1 && priority <= 3) {
                priorityText = i18n("High")
            } else if (priority >= 4 && priority <= 6) {
                priorityText = i18n("Medium")
            } else if (priority >= 7 && priority <= 9) {
                priorityText = i18n("Low")
            }
            parts.push({ kind: "priority", text: priorityText, key: String(priority) })
        }
        return parts
    }

    function activeViewIconSource() {
        switch (backend.currentView) {
        case "today": return "view-calendar-day"
        case "tomorrow": return "go-next"
        case "scheduled": return "view-calendar"
        case "anytime": return "view-calendar-tasks"
        case "recurring": return "media-playlist-repeat"
        case "unlabeled": return "tag-delete"
        case "completed": return "checkmark"
        default: return "mail-folder-inbox"
        }
    }

    function activeViewTitle() {
        switch (backend.currentView) {
        case "today": return i18n("Today")
        case "tomorrow": return i18n("Tomorrow")
        case "scheduled": return i18n("Scheduled")
        case "anytime": return i18n("Anytime")
        case "recurring": return i18n("Recurring")
        case "unlabeled": return i18n("Unlabeled")
        case "completed": return i18n("Completed")
        default: return i18n("Inbox")
        }
    }

    Plasmoid.icon: "kurrent"
    toolTipMainText: i18n("Kurrent")
    toolTipSubText: taskController.pendingCount > 0
        ? i18np("%1 open task", "%1 open tasks", taskController.pendingCount)
        : i18n("No open tasks")

    function persistSharedSettings() {
        SharedSettings.copyFrom(Plasmoid.configuration)
    }

    function loadSharedSettings() {
        SharedSettings.applyTo(Plasmoid.configuration)
    }

    Component.onCompleted: {
        SharedSettings.seedFromIfEmpty(Plasmoid.configuration)
        SharedSettings.applyTo(Plasmoid.configuration)
        if (taskController.smokeTest) {
            root.expanded = true
        }
        applyPopupBackground()
    }

    TaskController {
        id: taskController
        showCompleted: Plasmoid.configuration.showCompleted
        Component.onCompleted: {
            var view = Plasmoid.configuration.defaultView || "inbox"
            currentView = view

            // For Inbox: start with Projects/Labels = "All" to ensure tasks show immediately.
            if (view === "inbox") {
                selectedCollectionId = -1
                selectedLabel = ""
                selectedPriority = -1
                managementView = ""
            }

            applyEnabledCollections()
            refresh()
        }
    }

    function applyEnabledCollections() {
        var raw = Plasmoid.configuration.enabledCollections || ""
        if (!raw.trim()) {
            return
        }
        var parts = raw.split(",")
        var ids = []
        for (var i = 0; i < parts.length; ++i) {
            var value = parseInt(parts[i].trim(), 10)
            if (!isNaN(value)) {
                ids.push(value)
            }
        }
        if (ids.length > 0) {
            taskController.setEnabledCollectionIds(ids)
        }
    }

    Connections {
        target: SharedSettings
        function onChanged() {
            root.loadSharedSettings()
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onShowCompletedChanged() {
            root.persistSharedSettings()
            taskController.showCompleted = Plasmoid.configuration.showCompleted
        }
        function onDefaultViewChanged() {
            root.persistSharedSettings()
            taskController.currentView = Plasmoid.configuration.defaultView
        }
        function onEnabledCollectionsChanged() {
            root.persistSharedSettings()
            root.applyEnabledCollections()
            taskController.refresh()
        }
        function onBlurBackgroundChanged() {
            root.persistSharedSettings()
            root.applyPopupBackground()
        }
        function onHiddenProjectsChanged() {
            root.persistSharedSettings()
        }
        function onHiddenLabelsChanged() {
            root.persistSharedSettings()
        }
        function onSidebarRowSizeChanged() {
            root.persistSharedSettings()
        }
        function onNewTaskProjectModeChanged() {
            root.persistSharedSettings()
        }
        function onNewTaskDefaultCollectionIdChanged() {
            root.persistSharedSettings()
        }
    }

    Timer {
        running: taskController.smokeTest
        interval: 200
        repeat: false
        onTriggered: root.expanded = true
    }

    compactRepresentation: MouseArea {
        // Square icon in the panel — do not inherit the desktop/full size hints.
        Layout.minimumWidth: height
        Layout.preferredWidth: height
        Layout.maximumWidth: height
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        acceptedButtons: Qt.LeftButton
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Qt.resolvedUrl("../icons/kurrent.svg")
            isMask: true
            color: Kirigami.Theme.textColor

            QQC2.Label {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -2
                visible: taskController.pendingCount > 0
                text: taskController.pendingCount
                font.pixelSize: parent.height * 0.4
                font.bold: true
                color: Kirigami.Theme.highlightColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }
    }

    fullRepresentation: Item {
        id: fullRoot
        clip: false

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
            root.applyPopupBackground()
        }

        readonly property var hostWindow: Window.window
        onHostWindowChanged: root.applyPopupBackground()

        Timer {
            interval: 1
            running: true
            repeat: false
            onTriggered: {
                fullRoot.resolveOverlayHost()
                root.applyPopupBackground()
            }
        }

        readonly property int editorMinOverallWidth: sidebar.sidebarWidth
                + Kirigami.Units.gridUnit * 24
                + KurrentUi.Design.panelGap
        readonly property bool editorCoversSidebar: fullRoot.width < editorMinOverallWidth

        implicitWidth: Kirigami.Units.gridUnit * 52
        implicitHeight: Kirigami.Units.gridUnit * 40

        Layout.minimumWidth: root.inPanel ? Kirigami.Units.gridUnit * 28 : Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: root.inPanel ? Kirigami.Units.gridUnit * 20 : Kirigami.Units.gridUnit * 12
        Layout.preferredWidth: root.inPanel ? Kirigami.Units.gridUnit * 32 : implicitWidth
        Layout.preferredHeight: root.inPanel ? Kirigami.Units.gridUnit * 24 : implicitHeight
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

        function computeDragProxyGap(cursorSize, shape) {
            return root.backend.dragProxyGap(cursorSize, shape)
        }

        function dragLimitRight() {
            var margin = Kirigami.Units.smallSpacing
            var sg = Plasmoid.screenGeometry
            var cpp = root.backend.dragScreenLimits()
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
            var margin = Kirigami.Units.smallSpacing
            var sg = Plasmoid.screenGeometry
            var ar = Plasmoid.availableScreenRect
            var cpp = root.backend.dragScreenLimits()
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
            dragCursorSize = root.backend.systemCursorSize()
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

            var off = root.backend.clampDragProxyOffset(globalX, globalY, gap.x, gap.y, w, h, limitRight, limitBottom)
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

        function sortModeLabel(mode) {
            var options = sortOptions
            for (var i = 0; i < options.length; ++i) {
                if (options[i].id === mode) {
                    return options[i].label
                }
            }
            return i18n("Default")
        }

        readonly property var sortOptions: [
            { id: "default", label: i18n("Default") },
            { id: "due", label: i18n("Due date") },
            { id: "due,priority", label: i18n("Due date, then priority") },
            { id: "due,title", label: i18n("Due date, then title") },
            { id: "priority", label: i18n("Priority") },
            { id: "priority,due", label: i18n("Priority, then due date") },
            { id: "priority,title", label: i18n("Priority, then title") },
            { id: "title", label: i18n("Title A–Z") },
            { id: "titleDesc", label: i18n("Title Z–A") },
            { id: "completed,due", label: i18n("Open first, then due date") },
            { id: "completed,priority", label: i18n("Open first, then priority") }
        ]

        function openSortMenu() {
            var margin = Kirigami.Units.smallSpacing
            var maxWidth = Math.max(Kirigami.Units.gridUnit * 8, fullRoot.width - margin * 2)
            sortMenu.width = Math.min(Kirigami.Units.gridUnit * 18,
                                      Math.max(Kirigami.Units.gridUnit * 12, maxWidth))

            var below = sortButton.mapToItem(fullRoot, 0, sortButton.height + margin)
            var buttonTop = sortButton.mapToItem(fullRoot, 0, 0)
            var buttonRight = sortButton.mapToItem(fullRoot, sortButton.width, 0).x
            var spaceBelow = fullRoot.height - below.y - margin
            var spaceAbove = buttonTop.y - margin
            var estimatedHeight = Kirigami.Units.gridUnit
                    + fullRoot.sortOptions.length * Kirigami.Units.gridUnit * 2
                    + sortMenu.topPadding + sortMenu.bottomPadding
            var measuredHeight = sortList.contentHeight + sortMenu.topPadding + sortMenu.bottomPadding
            var wantedHeight = measuredHeight > Kirigami.Units.gridUnit * 4 ? measuredHeight : estimatedHeight

            var openBelow = spaceBelow >= Math.min(wantedHeight, Kirigami.Units.gridUnit * 10)
                            || spaceBelow >= spaceAbove
            var available = Math.max(Kirigami.Units.gridUnit * 8, openBelow ? spaceBelow : spaceAbove)
            sortMenu.height = Math.min(wantedHeight, available)

            if (openBelow) {
                sortMenu.y = below.y
            } else {
                sortMenu.y = Math.max(margin, buttonTop.y - margin - sortMenu.height)
            }
            if (sortMenu.y + sortMenu.height > fullRoot.height - margin) {
                sortMenu.y = Math.max(margin, fullRoot.height - margin - sortMenu.height)
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
                controller: root.backend
                dragHost: fullRoot
                hiddenProjects: Plasmoid.configuration.hiddenProjects || ""
                hiddenLabels: Plasmoid.configuration.hiddenLabels || ""
                sidebarRowSize: Plasmoid.configuration.sidebarRowSize || "auto"
            }

            Kirigami.Separator {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
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
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: activeViewIconSource()
                        width: Kirigami.Units.iconSizes.smallMedium
                        height: Kirigami.Units.iconSizes.smallMedium
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Kirigami.Heading {
                        Layout.alignment: Qt.AlignVCenter
                        level: 3
                        text: activeViewTitle()
                        elide: Text.ElideRight
                    }

                    // Active filters inline with the view title (same colored icons as sidebar).
                    Repeater {
                        model: root.activeFilters
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
                                       : Colors.colorForKey(modelData.key)
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
                        QQC2.ToolTip.text: i18n("Sort: %1", fullRoot.sortModeLabel(root.backend.sortMode))
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.Label {
                        visible: root.backend.devBuild
                        text: i18n("Build") + " " + String(root.backend.buildNumber)
                        opacity: 0.6
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        elide: Text.ElideRight
                        Layout.alignment: Qt.AlignVCenter
                    }

                    QQC2.Label {
                        visible: !root.backend.akonadiAvailable
                        text: i18n("Akonadi offline")
                        color: Kirigami.Theme.negativeTextColor
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                TaskListView {
                    id: taskList
                    controller: root.backend
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
            readonly property int contentPad: Kirigami.Units.smallSpacing
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
                    spacing: Kirigami.Units.smallSpacing

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
                            color: Colors.colorForKey(String(modelData))
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
            clip: true
            padding: Kirigami.Units.smallSpacing
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
            z: 1500

            background: Rectangle {
                radius: 4
                color: Kirigami.Theme.backgroundColor
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
                border.width: 1
            }

            contentItem: ListView {
                id: sortList
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: fullRoot.sortOptions
                spacing: 0
                header: QQC2.Label {
                    width: sortList.width
                    leftPadding: Kirigami.Units.smallSpacing
                    rightPadding: Kirigami.Units.smallSpacing
                    bottomPadding: Kirigami.Units.smallSpacing
                    text: i18n("Sort tasks")
                    font.bold: true
                    opacity: 0.75
                }
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    width: sortList.width
                    text: modelData.label
                    highlighted: root.backend.sortMode === modelData.id
                    icon.name: root.backend.sortMode === modelData.id ? "checkmark" : ""
                    onClicked: {
                        root.backend.sortMode = modelData.id
                        sortMenu.close()
                    }
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                    policy: sortList.contentHeight > sortList.height
                            ? QQC2.ScrollBar.AlwaysOn
                            : QQC2.ScrollBar.AlwaysOff
                }
            }
        }

        TaskEditorSheet {
            id: taskFullEditor
            parent: fullRoot.overlayHost
            z: 2000
            controller: root.backend
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
            plasmoidRoot: root
            backend: root.backend
            fullRoot: fullRoot
            taskList: taskList
            taskFullEditor: taskFullEditor
            sortMenu: sortMenu
        }
    }
}
