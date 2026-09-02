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
    preloadFullRepresentation: true
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

    function normalizeReleaseVersion(v) {
        if (!v) {
            return ""
        }
        var trimmed = String(v).trim()
        if (trimmed === "") {
            return ""
        }
        var parts = trimmed.split(".")
        if (parts.length >= 2) {
            return parts[0] + "." + parts[1]
        }
        return parts[0]
    }

    readonly property string widgetVersion: normalizeReleaseVersion(Plasmoid.metaData ? Plasmoid.metaData.version : "")
    readonly property string backendVersion: pluginReady && backend ? normalizeReleaseVersion(backend.pluginVersion) : ""
    readonly property bool backendVersionMismatch: pluginReady && !pluginMissing && widgetVersion !== ""
            && (backendVersion === "" || backendVersion !== widgetVersion)

    readonly property var activeFilters: {
        if (!backend) {
            return []
        }
        // Depend on filter properties so the UI updates when they change.
        var collectionId = backend.selectedCollectionId
        var label = backend.selectedLabel
        var priority = backend.selectedPriority
        var progressBand = backend.selectedProgressBand
        var status = backend.selectedStatus
        var secrecy = backend.selectedSecrecy
        var location = backend.selectedLocation
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
        if (progressBand && progressBand !== "") {
            parts.push({ kind: "progress", text: progressBand.replace("-", "–") + "%", key: progressBand })
        }
        if (status >= 0) {
            var statusText = i18n("None")
            if (status === 4) statusText = i18n("Needs action")
            else if (status === 6) statusText = i18n("In process")
            else if (status === 3) statusText = i18n("Completed")
            else if (status === 5) statusText = i18n("Canceled")
            parts.push({ kind: "status", text: statusText, key: String(status) })
        }
        if (secrecy >= 0) {
            var secrecyText = i18n("Public")
            if (secrecy === 1) secrecyText = i18n("Private")
            else if (secrecy === 2) secrecyText = i18n("Confidential")
            parts.push({ kind: "secrecy", text: secrecyText, key: String(secrecy) })
        }
        if (location && location !== "") {
            parts.push({ kind: "location", text: location, key: location })
        }
        return parts
    }

    function activeViewIconSource() {
        if (!backend) {
            return "kurrent"
        }
        if (backend.currentView.indexOf("smart:") === 0) {
            var smartId = backend.currentView.slice(6)
            var smart = smartViewById[smartId]
            return smart ? (smart.icon || "view-filter") : "view-filter"
        }
        var icon = builtinViewIconById[backend.currentView]
        return icon !== undefined ? icon : "mail-folder-inbox"
    }

    function activeViewTitle() {
        if (!backend) {
            return i18n("Kurrent")
        }
        if (backend.currentView.indexOf("smart:") === 0) {
            var smartId = backend.currentView.slice(6)
            var smart = smartViewById[smartId]
            return smart ? (smart.name || smartId) : smartId
        }
        var title = builtinViewTitleById[backend.currentView]
        return title !== undefined ? title : i18n("Inbox")
    }

    Plasmoid.icon: "kurrent"
    toolTipMainText: i18n("Kurrent")
    toolTipSubText: root.panelTooltipText

    readonly property var panelViewCounts: backend ? backend.viewTaskCounts : ({})

    function viewCountLabel(viewId) {
        var label = viewCountLabelById[viewId]
        return label !== undefined ? label : viewId
    }

    readonly property string panelTooltipText: {
        if (!backend) {
            return i18n("Loading…")
        }
        var mode = Plasmoid.configuration.panelTooltip || "open"
        if (mode === "off") {
            return ""
        }
        var counts = panelViewCounts
        if (mode === "today") {
            var todayN = counts["today"] || 0
            return todayN > 0
                    ? i18np("%1 due today", "%1 due today", todayN)
                    : i18n("Nothing due today")
        }
        if (mode === "today-overdue") {
            var t = counts["today"] || 0
            var o = counts["overdue"] || 0
            return i18n("Today: %1 · Overdue: %2", t, o)
        }
        if (mode === "overdue") {
            var overdueN = counts["overdue"] || 0
            return overdueN > 0
                    ? i18np("%1 overdue", "%1 overdue", overdueN)
                    : i18n("No overdue tasks")
        }
        if (mode === "high") {
            var highN = counts["high"] || 0
            return highN > 0
                    ? i18np("%1 high priority", "%1 high priority", highN)
                    : i18n("No high priority tasks")
        }
        if (mode === "views") {
            var viewIds = ["inbox", "today", "overdue", "tomorrow", "scheduled", "anytime", "recurring", "unlabeled"]
            var lines = []
            for (var i = 0; i < viewIds.length; ++i) {
                var id = viewIds[i]
                var n = counts[id] || 0
                if (n > 0) {
                    lines.push(viewCountLabel(id) + ": " + n)
                }
            }
            var completedN = counts["completed"] || 0
            if (completedN > 0) {
                lines.push(viewCountLabel("completed") + ": " + completedN)
            }
            return lines.length > 0 ? lines.join("\n") : i18n("No open tasks")
        }
        var openN = backend.pendingCount
        return openN > 0
                ? i18np("%1 open task", "%1 open tasks", openN)
                : i18n("No open tasks")
    }

    readonly property int panelBadgeCount: {
        if (!backend) {
            return 0
        }
        var mode = Plasmoid.configuration.panelBadge || "open"
        var counts = panelViewCounts
        if (mode === "off") {
            return 0
        }
        if (mode === "today") {
            return counts["today"] || 0
        }
        if (mode === "overdue") {
            return counts["overdue"] || 0
        }
        if (mode === "tomorrow") {
            return counts["tomorrow"] || 0
        }
        if (mode === "high") {
            return counts["high"] || 0
        }
        return backend.pendingCount
    }

    readonly property bool panelBadgeUseDot: (Plasmoid.configuration.panelBadgeStyle || "number") === "dot"

    readonly property color panelBadgeColor: {
        var mode = Plasmoid.configuration.panelBadge || "open"
        var colorMode = Plasmoid.configuration.panelBadgeOverdueColor || "highlight"
        var counts = panelViewCounts
        var useNegative = colorMode === "negative"
                && ((mode === "overdue")
                    || (mode === "today" && (counts["overdue"] || 0) > 0))
        return useNegative ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
    }

    function defaultSortMode() {
        return "priority,due,title"
    }

    function parseSmartViews() {
        return parsedSmartViews
    }

    readonly property var parsedSmartViews: {
        try {
            return JSON.parse(Plasmoid.configuration.smartViews || "[]")
        } catch (e) {
            return []
        }
    }

    readonly property var smartViewById: {
        var views = parsedSmartViews
        var byId = {}
        for (var i = 0; i < views.length; ++i) {
            var sv = views[i]
            if (sv && sv.id) {
                byId[sv.id] = sv
            }
        }
        return byId
    }

    readonly property var builtinViewTitleById: ({
        "inbox": i18n("Inbox"),
        "today": i18n("Today"),
        "overdue": i18n("Overdue"),
        "tomorrow": i18n("Tomorrow"),
        "scheduled": i18n("Scheduled"),
        "anytime": i18n("Anytime"),
        "recurring": i18n("Recurring"),
        "unlabeled": i18n("Unlabeled"),
        "completed": i18n("Completed"),
        "reminder": i18n("Has reminder"),
        "nolocation": i18n("Has no location"),
        "nopriority": i18n("No priority"),
        "nostatus": i18n("No status")
    })

    readonly property var builtinViewIconById: ({
        "inbox": "mail-folder-inbox",
        "today": "view-calendar-day",
        "overdue": "chronometer",
        "tomorrow": "go-next",
        "scheduled": "view-calendar",
        "anytime": "view-calendar-tasks",
        "recurring": "media-playlist-repeat",
        "unlabeled": "tag-delete",
        "completed": "checkmark",
        "reminder": "appointment-reminder",
        "nolocation": "find-location",
        "nopriority": "flag",
        "nostatus": "task-new"
    })

    readonly property var viewCountLabelById: ({
        "inbox": i18n("Inbox"),
        "today": i18n("Today"),
        "overdue": i18n("Overdue"),
        "tomorrow": i18n("Tomorrow"),
        "scheduled": i18n("Scheduled"),
        "anytime": i18n("Anytime"),
        "recurring": i18n("Recurring"),
        "unlabeled": i18n("Unlabeled"),
        "completed": i18n("Completed"),
        "reminder": i18n("Has reminder"),
        "nolocation": i18n("Has no location"),
        "nopriority": i18n("No priority"),
        "nostatus": i18n("No status")
    })

    function sortModeForView(viewId) {
        var scope = Plasmoid.configuration.sortScope || "global"
        if (scope === "perView") {
            var byView = {}
            try {
                byView = JSON.parse(Plasmoid.configuration.sortModeByView || "{}")
            } catch (e) {
                byView = {}
            }
            var perViewMode = byView[viewId]
            if (perViewMode && perViewMode !== "") {
                return perViewMode
            }
            return defaultSortMode()
        }
        var stored = Plasmoid.configuration.sortMode || ""
        return stored !== "" ? stored : defaultSortMode()
    }

    function storedMainPaneMode() {
        var mode = Plasmoid.configuration.mainPaneMode || ""
        return mode !== "" ? mode : KurrentUi.Design.viewModeList
    }

    function isSidebarFilterEnabled(kind, extra) {
        if (!backend) {
            return true
        }
        var mode = backend.mainPaneMode
        if (mode === KurrentUi.Design.viewModeKanban) {
            if (kind === "label" && backend.kanbanColumnSource === "label") {
                return false
            }
            if (kind === "project" && backend.kanbanColumnSource === "project") {
                return false
            }
            if (kind === "priority" && backend.kanbanColumnSource === "priority") {
                return false
            }
            if (kind === "status" && backend.kanbanColumnSource === "status") {
                return false
            }
            if (kind === "secrecy" && backend.kanbanColumnSource === "secrecy") {
                return false
            }
            if (kind === "progress" && backend.kanbanColumnSource === "completion") {
                return false
            }
            if (kind === "view" && extra === "unlabeled" && backend.kanbanColumnSource === "label") {
                return false
            }
        }
        if (mode === KurrentUi.Design.viewModeSwimlane) {
            if (kind === "label" && backend.swimlaneLaneAxis === "label") {
                return false
            }
            if (kind === "project" && backend.swimlaneLaneAxis === "project") {
                return false
            }
            if (kind === "priority" && backend.swimlaneLaneAxis === "priority") {
                return false
            }
        }
        if (mode === KurrentUi.Design.viewModePlan && kind === "project") {
            return false
        }
        return true
    }

    function sidebarFilterDisabledReason(kind, extra) {
        if (!backend) {
            return ""
        }
        var mode = backend.mainPaneMode
        if (mode === KurrentUi.Design.viewModeKanban) {
            if (kind === "label" && backend.kanbanColumnSource === "label") {
                return i18n("Labels are already Kanban columns.")
            }
            if (kind === "project" && backend.kanbanColumnSource === "project") {
                return i18n("Projects are already Kanban columns.")
            }
            if (kind === "priority" && backend.kanbanColumnSource === "priority") {
                return i18n("Priorities are already Kanban columns.")
            }
            if (kind === "status" && backend.kanbanColumnSource === "status") {
                return i18n("Status is already used for Kanban columns.")
            }
            if (kind === "secrecy" && backend.kanbanColumnSource === "secrecy") {
                return i18n("Secrecy is already used for Kanban columns.")
            }
            if (kind === "progress" && backend.kanbanColumnSource === "completion") {
                return i18n("Progress is already used for Kanban columns.")
            }
            if (kind === "view" && extra === "unlabeled" && backend.kanbanColumnSource === "label") {
                return i18n("Unlabeled view does not apply when Kanban uses labels as columns.")
            }
        }
        if (mode === KurrentUi.Design.viewModeSwimlane) {
            if (kind === "label" && backend.swimlaneLaneAxis === "label") {
                return i18n("Labels are already swimlane rows.")
            }
            if (kind === "project" && backend.swimlaneLaneAxis === "project") {
                return i18n("Projects are already swimlane rows.")
            }
            if (kind === "priority" && backend.swimlaneLaneAxis === "priority") {
                return i18n("Priorities are already swimlane rows.")
            }
        }
        if (mode === KurrentUi.Design.viewModePlan && kind === "project") {
            return i18n("Projects are already plan rows.")
        }
        return i18n("Not available in the current view.")
    }

    function persistMainPaneMode(mode) {
        Plasmoid.configuration.mainPaneMode = mode || KurrentUi.Design.viewModeList
    }

    function applyMainPaneMode() {
        if (!backend) {
            return
        }
        backend.mainPaneMode = storedMainPaneMode()
    }

    function setMainPaneMode(mode) {
        if (!backend) {
            return
        }
        // Persist FIRST: the onMainPaneModeChanged handler calls
        // applyMainPaneMode() → storedMainPaneMode(), which reads
        // Plasmoid.configuration.  If we persist after setting the
        // backend property, the synchronous signal handler reads
        // the OLD value and immediately resets the mode.
        persistMainPaneMode(mode)
        backend.mainPaneMode = mode
        applySortForCurrentView()
    }

    function persistSortMode(mode) {
        persistKanbanComboSort(mode)
        if (mode === "custom") {
            persistSharedSettings()
            return
        }
        var def = defaultSortMode()
        var scope = Plasmoid.configuration.sortScope || "global"
        if (scope === "perView") {
            var byView = {}
            try {
                byView = JSON.parse(Plasmoid.configuration.sortModeByView || "{}")
            } catch (e) {
                byView = {}
            }
            var viewId = backend ? backend.currentView : ""
            if (mode === def) {
                delete byView[viewId]
            } else {
                byView[viewId] = mode
            }
            Plasmoid.configuration.sortModeByView = JSON.stringify(byView)
        } else {
            Plasmoid.configuration.sortMode = mode === def ? "" : mode
        }
        persistSharedSettings()
    }

    function kanbanComboKey() {
        if (!backend) {
            return ""
        }
        return backend.currentView + "|" + backend.kanbanColumnSource
    }

    function persistKanbanComboSort(mode) {
        if (!backend || backend.mainPaneMode !== KurrentUi.Design.viewModeKanban) {
            return
        }
        var map = {}
        try {
            map = JSON.parse(Plasmoid.configuration.kanbanSortModeByViewColumn || "{}")
        } catch (e) {
            map = {}
        }
        map[kanbanComboKey()] = mode
        Plasmoid.configuration.kanbanSortModeByViewColumn = JSON.stringify(map)
    }

    function applySortForCurrentView() {
        if (!backend) {
            return
        }
        if (backend.mainPaneMode === KurrentUi.Design.viewModeKanban) {
            var map = {}
            try {
                map = JSON.parse(Plasmoid.configuration.kanbanSortModeByViewColumn || "{}")
            } catch (e) {
                map = {}
            }
            var combo = kanbanComboKey()
            if (map[combo]) {
                backend.sortMode = map[combo]
                return
            }
        }
        backend.sortMode = sortModeForView(backend.currentView)
    }

    function persistSharedSettings() {
        if (sharedSettings) {
            sharedSettings.copyFrom(Plasmoid.configuration)
        }
    }

    function applyColorsFromConfig() {
        var projects = {}
        var labels = {}
        var locations = {}
        try {
            projects = JSON.parse(Plasmoid.configuration.projectColors || "{}")
        } catch (e) { projects = {} }
        try {
            labels = JSON.parse(Plasmoid.configuration.labelColors || "{}")
        } catch (e) { labels = {} }
        try {
            locations = JSON.parse(Plasmoid.configuration.locationColors || "{}")
        } catch (e) { locations = {} }
        Colors.setColorOverrides(projects, labels, locations)
        KurrentUi.Design.setColorOverrides(projects, labels, locations)
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
        if (backend) {
            backend.smartViewsJson = Plasmoid.configuration.smartViews || "[]"
            backend.kanbanColumnSource = Plasmoid.configuration.kanbanColumnSource || "status"
            backend.kanbanWriteMode = Plasmoid.configuration.kanbanWriteMode || "fields"
            backend.kanbanManualOrderJson = Plasmoid.configuration.kanbanManualOrder || "{}"
            backend.swimlaneLaneAxis = Plasmoid.configuration.swimlaneLaneAxis || "project"
            backend.swimlaneTimeBucket = Plasmoid.configuration.swimlaneTimeBucket || "day"
            backend.planTimeBucket = Plasmoid.configuration.planTimeBucket || "week"
            backend.planHorizon = Plasmoid.configuration.planHorizon !== undefined ? Plasmoid.configuration.planHorizon : 8
            backend.planShowUndated = Plasmoid.configuration.planShowUndated !== undefined ? Plasmoid.configuration.planShowUndated : true
            backend.planShowCompleted = Plasmoid.configuration.planShowCompleted === true
            backend.multiSelectEnabled = Plasmoid.configuration.multiSelectEnabled === true
            backend.listGroupMode = Plasmoid.configuration.listGroupMode || ""
            applyMainPaneMode()
            applySortForCurrentView()
        }
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
        function onDbusSearchRequested(query) {
            root.expanded = true
            if (backend) {
                backend.searchQuery = query || ""
            }
            Qt.callLater(root.focusSearchField)
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
        function onSuppressRemindersDuringEventsChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.suppressRemindersDuringEvents = Plasmoid.configuration.suppressRemindersDuringEvents === true
            }
        }
        function onBusyCalendarIdsChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.busyCalendarIds = Plasmoid.configuration.busyCalendarIds || ""
            }
        }
        function onSortScopeChanged() {
            root.persistSharedSettings()
            root.applySortForCurrentView()
        }
        function onSortModeChanged() {
            root.persistSharedSettings()
        }
        function onSortModeByViewChanged() {
            root.persistSharedSettings()
        }
        function onViewModeByViewChanged() {
            root.persistSharedSettings()
        }
        function onSmartViewsChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.smartViewsJson = Plasmoid.configuration.smartViews || "[]"
            }
        }
        function onMainPaneModeChanged() {
            root.persistSharedSettings()
            root.applyMainPaneMode()
            root.applySortForCurrentView()
        }
        function onKanbanColumnSourceChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.kanbanColumnSource = Plasmoid.configuration.kanbanColumnSource || "status"
            }
            root.applySortForCurrentView()
        }
        function onKanbanSortModeByViewColumnChanged() {
            root.persistSharedSettings()
        }
        function onKanbanWriteModeChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.kanbanWriteMode = Plasmoid.configuration.kanbanWriteMode || "fields"
            }
        }
        function onKanbanManualOrderChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.kanbanManualOrderJson = Plasmoid.configuration.kanbanManualOrder || "{}"
            }
        }
        function onSwimlaneLaneAxisChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.swimlaneLaneAxis = Plasmoid.configuration.swimlaneLaneAxis || "project"
            }
        }
        function onSwimlaneTimeBucketChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.swimlaneTimeBucket = Plasmoid.configuration.swimlaneTimeBucket || "day"
            }
        }
        function onPlanTimeBucketChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.planTimeBucket = Plasmoid.configuration.planTimeBucket || "week"
            }
        }
        function onPlanHorizonChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.planHorizon = Plasmoid.configuration.planHorizon !== undefined ? Plasmoid.configuration.planHorizon : 8
            }
        }
        function onPlanShowUndatedChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.planShowUndated = Plasmoid.configuration.planShowUndated !== undefined ? Plasmoid.configuration.planShowUndated : true
            }
        }
        function onPlanShowCompletedChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.planShowCompleted = Plasmoid.configuration.planShowCompleted === true
            }
        }
        function onMultiSelectEnabledChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.multiSelectEnabled = Plasmoid.configuration.multiSelectEnabled === true
            }
        }
        function onVerboseJournalLoggingChanged() {
            root.persistSharedSettings()
        }
        function onInfoJournalLoggingChanged() {
            root.persistSharedSettings()
        }
        function onListGroupModeChanged() {
            root.persistSharedSettings()
            if (backend) {
                backend.listGroupMode = Plasmoid.configuration.listGroupMode || ""
            }
        }
    }

    Connections {
        target: backend
        function onCurrentViewChanged() {
            if (Plasmoid.configuration.rememberLastView && backend) {
                Plasmoid.configuration.lastView = backend.currentView
            }
            // Apply smart view default mode if set.
            if (backend && backend.currentView.indexOf("smart:") === 0) {
                var smartId = backend.currentView.slice(6)
                var smart = smartViewById[smartId]
                if (smart && smart.mode && smart.mode !== backend.mainPaneMode) {
                    setMainPaneMode(smart.mode)
                }
                // Apply smart view sort override if set.
                if (smart && smart.sort) {
                    var currentSort = sortModeForView(backend.currentView)
                    if (currentSort === defaultSortMode()) {
                        backend.sortMode = smart.sort
                    }
                }
            }
            root.applySortForCurrentView()
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
                visible: root.panelBadgeCount > 0 && !root.panelBadgeUseDot
                text: root.panelBadgeCount
                font.pixelSize: parent.height * 0.4
                font.bold: true
                color: root.panelBadgeColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 1
                visible: root.panelBadgeCount > 0 && root.panelBadgeUseDot
                width: Math.max(4, parent.height * 0.22)
                height: width
                radius: width / 2
                color: root.panelBadgeColor
                border.width: 1
                border.color: Kirigami.Theme.backgroundColor
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

    function focusSearchField() {
        var shell = fullRepresentationItem
        var item = shell && shell.uiItem ? shell.uiItem : null
        if (item && item.taskListItem && item.taskListItem.focusSearch) {
            item.taskListItem.focusSearch()
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
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
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

            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                Layout.alignment: Qt.AlignHCenter

                Kirigami.Icon {
                    id: bootGearIcon
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../icons/boot-gear.svg")
                    isMask: true
                    color: Kirigami.Theme.textColor
                    opacity: 0.75
                }

                RotationAnimator {
                    target: bootGearIcon
                    running: fullShell.showBootLoading && !KurrentUi.Design.reducedMotion
                    from: 0
                    to: 360
                    duration: Kirigami.Units.longDuration * 6
                    loops: Animation.Infinite
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.pluginReady ? i18n("Loading tasks…") : i18n("Connecting to Akonadi…")
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
            // Panel + desktop: begin FullView load at applet startup (async loaders;
            // Akonadi/plugin still non-blocking). First flyout open is then instant.
            Qt.callLater(fullShell.loadUi)
        }
    }
}
