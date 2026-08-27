import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import "colors.js" as Colors
import "." as KurrentUi

PlasmoidItem {
    id: root

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 18
    preloadFullRepresentation: false
    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation

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

    onExpandedChanged: function () {
        if (root.expanded && fullRepresentationItem && fullRepresentationItem.loadUi) {
            fullRepresentationItem.loadUi()
        }
        applyPopupBackground()
    }
    onFullRepresentationItemChanged: applyPopupBackground()

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge
    ].includes(Plasmoid.location)

    // Async so plasmashell is not blocked on libkurrentplugin.so (~Akonadi).
    // Compact icon can paint while the plugin loads.
    Loader {
        id: pluginLoader
        width: 0
        height: 0
        asynchronous: true
        source: Qt.resolvedUrl("PluginBackend.qml")
        onStatusChanged: {
            if (status === Loader.Ready) {
                root.initPluginSettings()
            }
            var shell = root.fullRepresentationItem
            if (shell && shell.loadUi) {
                shell.loadUi()
            }
        }
        onLoaded: root.initPluginSettings()
    }

    readonly property bool pluginReady: pluginLoader.status === Loader.Ready && !!pluginLoader.item
    readonly property bool pluginMissing: pluginLoader.status === Loader.Error
    readonly property var backend: pluginReady ? pluginLoader.item.controller : null
    readonly property var sharedSettings: pluginReady ? pluginLoader.item.settings : null

    readonly property var activeFilters: {
        if (!backend) {
            return []
        }
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
        if (!backend) {
            return "kurrent"
        }
        switch (backend.currentView) {
        case "today": return "view-calendar-day"
        case "overdue": return "chronometer"
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
        if (!backend) {
            return i18n("Kurrent")
        }
        switch (backend.currentView) {
        case "today": return i18n("Today")
        case "overdue": return i18n("Overdue")
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
    toolTipSubText: root.panelBadgeCount > 0
        ? i18np("%1 open task", "%1 open tasks", root.panelBadgeCount)
        : i18n("No open tasks")

    readonly property int panelBadgeCount: {
        if (!backend) {
            return 0
        }
        var mode = Plasmoid.configuration.panelBadge || "open"
        var counts = backend.viewTaskCounts
        if (mode === "off") {
            return 0
        }
        if (mode === "today") {
            return counts["today"] || 0
        }
        if (mode === "overdue") {
            return counts["overdue"] || 0
        }
        return backend.pendingCount
    }

    function persistSharedSettings() {
        if (sharedSettings) {
            sharedSettings.copyFrom(Plasmoid.configuration)
        }
    }

    function applyColorsFromConfig() {
        var projects = {}
        var labels = {}
        try {
            projects = JSON.parse(Plasmoid.configuration.projectColors || "{}")
        } catch (e) { projects = {} }
        try {
            labels = JSON.parse(Plasmoid.configuration.labelColors || "{}")
        } catch (e) { labels = {} }
        Colors.setColorOverrides(projects, labels)
        KurrentUi.Design.setColorOverrides(projects, labels)
    }

    function applyDesignFromConfig() {
        KurrentUi.Design.density = Plasmoid.configuration.density || "auto"
        KurrentUi.Design.sidebarWidthUnits = Plasmoid.configuration.sidebarWidthUnits || 10
        KurrentUi.Design.overlayDimStep = Plasmoid.configuration.overlayDimStep !== undefined
                ? Plasmoid.configuration.overlayDimStep : 1
        KurrentUi.Design.reducedMotion = Plasmoid.configuration.reducedMotion === true
        KurrentUi.Design.scrollSpeed = Plasmoid.configuration.scrollSpeed !== undefined
                ? Plasmoid.configuration.scrollSpeed : 50
    }

    function loadSharedSettings() {
        if (sharedSettings) {
            sharedSettings.applyTo(Plasmoid.configuration)
        }
        applyDesignFromConfig()
        applyColorsFromConfig()
    }

    function initPluginSettings() {
        if (!sharedSettings) {
            applyDesignFromConfig()
            applyColorsFromConfig()
            return
        }
        sharedSettings.seedFromIfEmpty(Plasmoid.configuration)
        sharedSettings.applyTo(Plasmoid.configuration)
        applyDesignFromConfig()
        applyColorsFromConfig()
        if (backend && backend.smokeTest) {
            root.expanded = true
        }
        applyPopupBackground()
    }

    Component.onCompleted: {
        if (pluginReady) {
            initPluginSettings()
        } else {
            applyDesignFromConfig()
            applyColorsFromConfig()
        }
        applyPopupBackground()
    }

    Connections {
        target: backend
        function onDbusShowRequested() {
            root.expanded = true
        }
        function onDbusAddTaskRequested(summary) {
            root.expanded = true
            if (summary && String(summary).trim().length) {
                backend.createTask(summary, -1)
            } else {
                Qt.callLater(root.focusNewTaskField)
            }
        }
        function onDbusOpenViewRequested(view) {
            root.expanded = true
            if (view) {
                backend.currentView = view
            }
        }
    }

    function applyEnabledCollections() {
        if (!backend) {
            return
        }
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
            backend.setEnabledCollectionIds(ids)
        }
    }

    Connections {
        target: sharedSettings
        function onChanged() {
            root.loadSharedSettings()
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onShowCompletedChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.showCompleted = Plasmoid.configuration.showCompleted
            }
        }
        function onDefaultViewChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.currentView = Plasmoid.configuration.defaultView
            }
        }
        function onEnabledCollectionsChanged() {
            root.persistSharedSettings()
            root.applyEnabledCollections()
            if (backend) {
                backend.refresh()
            }
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
        function onCatchUpEnabledChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.catchUpEnabled = Plasmoid.configuration.catchUpEnabled !== false
            }
        }
        function onCatchUpDaysChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.catchUpDays = Plasmoid.configuration.catchUpDays || 14
            }
        }
        function onMorningHourChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.morningHour = Plasmoid.configuration.morningHour
            }
        }
        function onAfternoonHourChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.afternoonHour = Plasmoid.configuration.afternoonHour
            }
        }
        function onEveningHourChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.eveningHour = Plasmoid.configuration.eveningHour
            }
        }
        function onShowJoinButtonChanged() {
            root.persistSharedSettings()
        }
        function onRememberLastViewChanged() {
            root.persistSharedSettings()
        }
        function onLastViewChanged() {
            root.persistSharedSettings()
        }
        function onDensityChanged() {
            root.persistSharedSettings()
            root.applyDesignFromConfig()
        }
        function onSidebarWidthUnitsChanged() {
            root.persistSharedSettings()
            root.applyDesignFromConfig()
        }
        function onOverlayDimStepChanged() {
            root.persistSharedSettings()
            root.applyDesignFromConfig()
        }
        function onReducedMotionChanged() {
            root.persistSharedSettings()
            root.applyDesignFromConfig()
        }
        function onShowEmptyProjectsChanged() {
            root.persistSharedSettings()
        }
        function onShowSidebarCountsChanged() {
            root.persistSharedSettings()
        }
        function onShowDateChipChanged() {
            root.persistSharedSettings()
        }
        function onShowLabelChipsChanged() {
            root.persistSharedSettings()
        }
        function onShowPriorityChipChanged() {
            root.persistSharedSettings()
        }
        function onShowRecurringIconChanged() {
            root.persistSharedSettings()
        }
        function onDefaultDueModeChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.defaultDueMode = Plasmoid.configuration.defaultDueMode || "none"
            }
        }
        function onConfirmDeleteChanged() {
            root.persistSharedSettings()
        }
        function onClickActionChanged() {
            root.persistSharedSettings()
        }
        function onPanelBadgeChanged() {
            root.persistSharedSettings()
        }
        function onFlyoutWidthUnitsChanged() {
            root.persistSharedSettings()
        }
        function onFlyoutHeightUnitsChanged() {
            root.persistSharedSettings()
        }
        function onSearchTitleOnlyChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.searchTitleOnly = Plasmoid.configuration.searchTitleOnly === true
            }
        }
        function onCompleteChildrenChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.completeChildren = Plasmoid.configuration.completeChildren === true
            }
        }
        function onCountsExcludeCollapsedChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.countsExcludeCollapsed = Plasmoid.configuration.countsExcludeCollapsed === true
            }
        }
        function onNotificationsEnabledChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.notificationsEnabled = Plasmoid.configuration.notificationsEnabled !== false
            }
        }
        function onDefaultReminderMinutesChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.defaultReminderMinutes = Plasmoid.configuration.defaultReminderMinutes
            }
        }
        function onProjectColorsChanged() {
            root.persistSharedSettings()
            root.applyColorsFromConfig()
        }
        function onLabelColorsChanged() {
            root.persistSharedSettings()
            root.applyColorsFromConfig()
        }
        function onDescriptionPreviewLinesChanged() {
            root.persistSharedSettings()
        }
        function onSidebarSectionOrderChanged() { root.persistSharedSettings() }
        function onHiddenSidebarSectionsChanged() { root.persistSharedSettings() }
        function onSidebarViewOrderChanged() { root.persistSharedSettings() }
        function onHiddenViewsChanged() { root.persistSharedSettings() }
        function onSearchCaseSensitiveChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.searchCaseSensitive = Plasmoid.configuration.searchCaseSensitive === true
            }
        }
        function onRelativeDatesChanged() { root.persistSharedSettings() }
        function onShowTimeOnRowChanged() { root.persistSharedSettings() }
        function onCompleteNeedsModifierChanged() { root.persistSharedSettings() }
        function onQuietHoursEnabledChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.quietHoursEnabled = Plasmoid.configuration.quietHoursEnabled === true
            }
        }
        function onQuietHoursStartChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.quietHoursStart = Plasmoid.configuration.quietHoursStart
            }
        }
        function onQuietHoursEndChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.quietHoursEnd = Plasmoid.configuration.quietHoursEnd
            }
        }
    }

    Connections {
        target: backend
        function onCurrentViewChanged() {
            if (Plasmoid.configuration.rememberLastView && backend) {
                Plasmoid.configuration.lastView = backend.currentView
            }
        }
    }

    Timer {
        running: !!(backend && backend.smokeTest)
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
                visible: root.panelBadgeCount > 0
                text: root.panelBadgeCount
                font.pixelSize: parent.height * 0.4
                font.bold: true
                color: Kirigami.Theme.highlightColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }
    }

    // Plasma delayed-preloads fullRepresentation for panel popups. Keep that
    // shell a size-only stub; instantiate FullView.qml only after first expand
    // (or immediately on the desktop). Flyout chrome paints immediately with a
    // boot loader while PluginBackend / FullView catch up asynchronously.
    function focusNewTaskField() {
        var shell = fullRepresentationItem
        var item = shell && shell.uiItem ? shell.uiItem : null
        if (item && item.taskListItem && item.taskListItem.focusNewTask) {
            item.taskListItem.focusNewTask()
        }
    }

    fullRepresentation: Item {
        id: fullShell
        clip: false

        readonly property Item uiItem: fullLoader.item
        readonly property bool forceSyncUi: !!(root.backend && root.backend.smokeTest)
        readonly property bool showBootLoading: !root.pluginMissing
                && (fullLoader.status === Loader.Null
                    || fullLoader.status === Loader.Loading
                    || (fullLoader.status === Loader.Ready && !fullLoader.item))

        implicitWidth: Kirigami.Units.gridUnit * 52
        implicitHeight: Kirigami.Units.gridUnit * 40
        Layout.minimumWidth: root.inPanel ? Kirigami.Units.gridUnit * 28 : Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: root.inPanel ? Kirigami.Units.gridUnit * 20 : Kirigami.Units.gridUnit * 12
        Layout.preferredWidth: root.inPanel ? Kirigami.Units.gridUnit * (Plasmoid.configuration.flyoutWidthUnits || 32) : implicitWidth
        Layout.preferredHeight: root.inPanel ? Kirigami.Units.gridUnit * (Plasmoid.configuration.flyoutHeightUnits || 24) : implicitHeight
        Layout.maximumWidth: Infinity
        Layout.maximumHeight: Infinity

        function loadUi() {
            if (root.pluginMissing) {
                if (fullLoader.source.toString().indexOf("PluginMissingView.qml") >= 0) {
                    return
                }
                fullLoader.setSource(Qt.resolvedUrl("PluginMissingView.qml"))
                return
            }
            if (!root.pluginReady) {
                return
            }
            if (fullLoader.source.toString().indexOf("FullView.qml") >= 0) {
                return
            }
            fullLoader.setSource(Qt.resolvedUrl("FullView.qml"), { plasmoidRoot: root })
        }

        // Instant feedback: flyout opens with this shell while plugin/.so and
        // FullView load in the background (Akonadi connect stays async too).
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - KurrentUi.Design.spaceLarge * 2,
                            Kirigami.Units.gridUnit * 16)
            spacing: KurrentUi.Design.spaceMedium
            visible: fullShell.showBootLoading

            QQC2.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: parent.visible && !KurrentUi.Design.reducedMotion
                visible: running
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.pluginReady ? i18n("Loading tasks…") : i18n("Connecting to Akonadi…")
            }

            QQC2.ProgressBar {
                Layout.fillWidth: true
                indeterminate: true
                visible: parent.visible
            }
        }

        Loader {
            id: fullLoader
            anchors.fill: parent
            // Async so the flyout paints the boot loader immediately. Smoke tests
            // keep sync so the tree exists for sizing assertions.
            asynchronous: !fullShell.forceSyncUi
            opacity: status === Loader.Ready && item ? 1 : 0
            Behavior on opacity {
                enabled: !KurrentUi.Design.reducedMotion
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        Component.onCompleted: {
            if (!root.inPanel || root.expanded || (backend && backend.smokeTest) || root.pluginMissing) {
                loadUi()
            }
        }
    }
}
