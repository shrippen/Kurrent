import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../views"
import ".."

Item {
    id: host

    required property TaskController controller
    required property Item dragHost
    property var onOpenFullEditor: null
    property bool interactionsSuspended: false
    property string hiddenProjects: ""
    property string newTaskProjectMode: "ask"
    property string newTaskDefaultCollectionId: ""
    property bool multiSelectEnabled: false

    property alias taskList: taskListView

    // Editor-style dim + gear over main pane only (not sidebar).
    readonly property bool widgetOverlayActive: !Design.reducedMotion
            && (sortOverlayActive
                || (chromeWarranted && (_workPending || isTransitioning)))
    readonly property bool widgetOverlayDim: widgetOverlayActive && controller
            && controller.taskModel.count > 0
    readonly property bool sortOverlayActive: _sortOverlayHold
            || (controller && controller.listReorganizing)

    property int _settledModeIdx: 0
    property int _fromModeIdx: 0
    property int _toModeIdx: 0
    property real _transitionProgress: 1

    property bool _visitedKanban: false
    property bool _visitedSwimlane: false
    property bool _visitedPlan: false
    property bool _visitedHeatmap: false
    property bool _visitedCalendar: false

    property bool _sortOverlayHold: false
    property bool _workPending: false

    readonly property bool isTransitioning: _transitionProgress < 1

    readonly property bool chromeWarranted: {
        if (!controller || Design.reducedMotion) {
            return false
        }
        if (controller.listReorganizing || _sortOverlayHold) {
            return controller.estimatedRebuildMs >= Design.mainPaneBlurMinEstimateMs
        }
        if (isTransitioning || _workPending) {
            return controller.estimatedViewSwitchMs(isColdTargetLoad())
                    >= Design.mainPaneBlurMinEstimateMs
        }
        return false
    }

    function isColdTargetLoad() {
        switch (_toModeIdx) {
        case 1: return !_visitedKanban
        case 2: return !_visitedSwimlane
        case 3: return !_visitedPlan
        case 4: return !_visitedHeatmap
        case 5: return !_visitedCalendar
        default: return false
        }
    }

    function modeIndexFor(mode) {
        switch (mode) {
        case Design.viewModeKanban: return 1
        case Design.viewModeSwimlane: return 2
        case Design.viewModePlan: return 3
        case Design.viewModeHeatmap: return 4
        case Design.viewModeCalendar: return 5
        default: return 0
        }
    }

    function modeIdForIndex(idx) {
        switch (idx) {
        case 1: return Design.viewModeKanban
        case 2: return Design.viewModeSwimlane
        case 3: return Design.viewModePlan
        case 4: return Design.viewModeHeatmap
        case 5: return Design.viewModeCalendar
        default: return Design.viewModeList
        }
    }

    function markModeVisited(mode) {
        switch (mode) {
        case Design.viewModeKanban: _visitedKanban = true; break
        case Design.viewModeSwimlane: _visitedSwimlane = true; break
        case Design.viewModePlan: _visitedPlan = true; break
        case Design.viewModeHeatmap: _visitedHeatmap = true; break
        case Design.viewModeCalendar: _visitedCalendar = true; break
        default: break
        }
    }

    function loaderReady(loader) {
        return !loader.active || (loader.status === Loader.Ready && loader.item)
    }

    function modeReady(idx) {
        if (idx === 0) {
            return true
        }
        if (idx === 1) {
            return loaderReady(kanbanLoader)
        }
        if (idx === 2) {
            return loaderReady(swimlaneLoader)
        }
        if (idx === 3) {
            return loaderReady(planLoader)
        }
        if (idx === 4) {
            return loaderReady(heatmapLoader)
        }
        if (idx === 5) {
            return loaderReady(calendarLoader)
        }
        return true
    }

    function xForModeIdx(idx) {
        var w = host.width
        if (w <= 0) {
            return 0
        }
        if (_transitionProgress >= 1) {
            return idx === _settledModeIdx ? 0 : (idx < _settledModeIdx ? -w : w)
        }
        var dir = _toModeIdx > _fromModeIdx ? 1 : -1
        if (idx === _fromModeIdx) {
            return -dir * w * _transitionProgress
        }
        if (idx === _toModeIdx) {
            return dir * w * (1 - _transitionProgress)
        }
        return dir * w * 2
    }

    function modePaneVisible(idx) {
        if (_transitionProgress < 1) {
            return idx === _fromModeIdx || idx === _toModeIdx
        }
        return idx === _settledModeIdx
    }

    function beginViewTransition(modeId) {
        markModeVisited(modeId)
        var nextIdx = modeIndexFor(modeId)
        if (nextIdx === _toModeIdx && _transitionProgress < 1) {
            _workPending = true
            return
        }
        if (nextIdx === _settledModeIdx && _transitionProgress >= 1) {
            return
        }
        _fromModeIdx = _settledModeIdx
        _toModeIdx = nextIdx
        _workPending = true
        if (Design.reducedMotion) {
            _transitionProgress = 1
            _settledModeIdx = nextIdx
            settleWorkPending()
            return
        }
        _transitionProgress = 0
        paneTransition.restart()
    }

    function requestSortFeedback() {
        _sortOverlayHold = true
        _workPending = true
        sortOverlayHoldTimer.stop()
    }

    function settleWorkPending() {
        if (!controller) {
            _workPending = false
            return
        }
        var dataReady = !controller.listReorganizing && modeReady(_settledModeIdx)
        if (dataReady && _transitionProgress >= 1) {
            _workPending = false
        }
    }

    Connections {
        target: controller
        function onMainPaneModeChanged() {
            if (!controller) {
                return
            }
            beginViewTransition(controller.mainPaneMode)
        }
        function onListReorganizingChanged() {
            if (!controller) {
                return
            }
            if (controller.listReorganizing) {
                sortOverlayHoldTimer.stop()
                _sortOverlayHold = true
                _workPending = true
            } else {
                sortOverlayHoldTimer.restart()
                settleWorkPending()
            }
        }
        function onKanbanLayoutChanged() {
            settleWorkPending()
        }
    }

    Timer {
        id: sortOverlayHoldTimer
        interval: Design.mainPaneSortOverlayMinMs
        repeat: false
        onTriggered: host._sortOverlayHold = false
    }

    Timer {
        id: settleTimer
        interval: 1
        repeat: false
        onTriggered: host.settleWorkPending()
    }

    NumberAnimation {
        id: paneTransition
        target: host
        property: "_transitionProgress"
        from: 0
        to: 1
        duration: Design.mainPaneTransitionDuration
        easing.type: Easing.OutCubic
        onFinished: {
            host._settledModeIdx = host._toModeIdx
            settleTimer.restart()
        }
    }

    clip: true

    Item {
        id: viewStage
        anchors.fill: parent

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: host.xForModeIdx(0)
            visible: host.modePaneVisible(0)

            TaskListView {
                id: taskListView
                anchors.fill: parent
                controller: host.controller
                dragHost: host.dragHost
                interactionsSuspended: host.interactionsSuspended
                hiddenProjects: host.hiddenProjects
                newTaskProjectMode: host.newTaskProjectMode
                newTaskDefaultCollectionId: host.newTaskDefaultCollectionId
                multiSelectEnabled: host.multiSelectEnabled
            }
        }

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: host.xForModeIdx(1)
            visible: host.modePaneVisible(1)

            Loader {
                id: kanbanLoader
                anchors.fill: parent
                active: host._visitedKanban || host._toModeIdx === 1 || host._fromModeIdx === 1
                asynchronous: !host.controller || !host.controller.smokeTest
                sourceComponent: KanbanView {
                    controller: host.controller
                    dragHost: host.dragHost
                    interactionsSuspended: host.interactionsSuspended
                }
                onLoaded: {
                    if (item && host.onOpenFullEditor) {
                        item.onOpenFullEditor = host.onOpenFullEditor
                    }
                    host.settleWorkPending()
                }
                onStatusChanged: if (status === Loader.Ready) {
                    host.settleWorkPending()
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: host.xForModeIdx(2)
            visible: host.modePaneVisible(2)

            Loader {
                id: swimlaneLoader
                anchors.fill: parent
                active: host._visitedSwimlane || host._toModeIdx === 2 || host._fromModeIdx === 2
                asynchronous: !host.controller || !host.controller.smokeTest
                sourceComponent: SwimlaneView {
                    controller: host.controller
                    interactionsSuspended: host.interactionsSuspended
                }
                onStatusChanged: if (status === Loader.Ready) {
                    host.settleWorkPending()
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: host.xForModeIdx(3)
            visible: host.modePaneVisible(3)

            Loader {
                id: planLoader
                anchors.fill: parent
                active: host._visitedPlan || host._toModeIdx === 3 || host._fromModeIdx === 3
                asynchronous: !host.controller || !host.controller.smokeTest
                sourceComponent: PlanView {
                    controller: host.controller
                }
                onStatusChanged: if (status === Loader.Ready) {
                    host.settleWorkPending()
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: host.xForModeIdx(4)
            visible: host.modePaneVisible(4)

            Loader {
                id: heatmapLoader
                anchors.fill: parent
                active: host._visitedHeatmap || host._toModeIdx === 4 || host._fromModeIdx === 4
                asynchronous: !host.controller || !host.controller.smokeTest
                sourceComponent: HeatmapView {
                    controller: host.controller
                    interactionsSuspended: host.interactionsSuspended
                }
                onStatusChanged: if (status === Loader.Ready) {
                    host.settleWorkPending()
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: host.xForModeIdx(5)
            visible: host.modePaneVisible(5)

            Loader {
                id: calendarLoader
                anchors.fill: parent
                active: host._visitedCalendar || host._toModeIdx === 5 || host._fromModeIdx === 5
                asynchronous: !host.controller || !host.controller.smokeTest
                sourceComponent: CalendarAgendaView {
                    controller: host.controller
                    dragHost: host.dragHost
                }
                onStatusChanged: if (status === Loader.Ready) {
                    host.settleWorkPending()
                }
            }
        }
    }

    Component.onCompleted: {
        if (controller) {
            markModeVisited(controller.mainPaneMode)
            _settledModeIdx = modeIndexFor(controller.mainPaneMode)
            _toModeIdx = _settledModeIdx
        }
    }
}
