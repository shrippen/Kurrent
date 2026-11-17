import QtQuick 2.15

Item {
    id: root

    property var plasmoidRoot: null
    property var controller: null
    property var fullRoot: null
    property var taskList: null
    property var taskFullEditor: null
    property var sortMenu: null

    width: 0
    height: 0
    visible: false

    property int step: 0
    readonly property var views: [
        "inbox", "today", "overdue", "tomorrow", "scheduled",
        "anytime", "recurring", "unlabeled", "completed"
    ]

    Timer {
        id: runner
        interval: 280
        repeat: true
        running: !!(controller && controller.smokeTest)
        onTriggered: root.nextStep()
    }

    function nextStep() {
        if (!controller || !fullRoot) {
            return
        }

        var i = step
        step += 1

        if (i === 0) {
            controller.smokeTrace("KURRENT_SMOKE_START")
            if (plasmoidRoot) {
                plasmoidRoot.expanded = true
            }
            controller.refresh()
            return
        }

        if (i >= 1 && i <= views.length) {
            controller.currentView = views[i - 1]
            return
        }

        var base = views.length + 1
        switch (i - base) {
        case 0:
            controller.searchQuery = "qa-smoke"
            return
        case 1:
            controller.searchQuery = ""
            return
        case 2:
            controller.showCompleted = true
            return
        case 3:
            controller.showCompleted = false
            return
        case 4:
            controller.sortMode = "due"
            return
        case 5:
            controller.sortMode = "priority,title"
            return
        case 6:
            controller.sortMode = "default"
            return
        case 7:
            controller.selectedPriority = 1
            return
        case 8:
            controller.selectedPriority = 5
            return
        case 9:
            controller.selectedPriority = 0
            return
        case 10:
            controller.selectedPriority = -1
            return
        case 11:
            if (controller.availableLabels && controller.availableLabels.length > 0) {
                controller.selectedLabel = controller.availableLabels[0]
            }
            return
        case 12:
            controller.selectedLabel = ""
            return
        case 13:
            if (controller.collectionModel && controller.collectionModel.count > 0) {
                controller.selectedCollectionId = controller.collectionModel.collectionIdAt(0)
            }
            return
        case 14:
            controller.selectedCollectionId = -1
            return
        case 15:
            fullRoot.openSortMenu()
            return
        case 16:
            if (sortMenu) {
                sortMenu.close()
            }
            return
        case 17:
            controller.systemCursorSize()
            controller.dragScreenLimits()
            controller.dragProxyGap(24, 0)
            controller.clampDragProxyOffset(100, 100, 14, 14, 180, 48, 1920, 1080)
            return
        case 18:
            fullRoot.beginTaskDrag({
                itemId: -1,
                uid: "smoke-uid",
                summary: "Smoke drag",
                parentUid: "",
                categories: ["qa"],
                collectionId: -1,
                priority: 1
            })
            fullRoot.updateTaskDragPosition(120, 160)
            fullRoot.updateTaskDragPosition(800, 500)
            fullRoot.setDropHint("smoke")
            fullRoot.clearDropHint("smoke")
            fullRoot.endTaskDrag()
            return
        case 19:
            if (taskFullEditor) {
                taskFullEditor.task = {
                    summary: "Smoke editor",
                    description: "QA",
                    location: "",
                    allDay: false,
                    priority: 5,
                    categories: [],
                    completed: false,
                    percentComplete: 0,
                    status: 0,
                    secrecy: 0,
                    recurrencePreset: "none",
                    collectionId: -1
                }
                taskFullEditor.open()
            }
            return
        case 20:
            if (taskFullEditor) {
                taskFullEditor.close()
            }
            return
        case 21:
            if (taskList && taskList.projectAskPopup) {
                taskList.askProjects = [{ collectionId: 1, name: "Smoke" }]
                taskList.projectAskPopup.open()
            }
            return
        case 22:
            if (taskList && taskList.projectAskPopup) {
                taskList.projectAskPopup.close()
            }
            return
        case 23:
            if (controller && plasmoidRoot) {
                controller.selectMainPaneMode("kanban")
            }
            return
        case 24:
            if (controller && plasmoidRoot) {
                controller.selectMainPaneMode("list")
            }
            return
        case 25:
            controller.listGroupMode = "priority"
            return
        case 26:
            controller.listGroupMode = "none"
            return
        case 27:
            controller.currentView = "scheduled"
            return
        case 28:
            // Matrix views: every axis / bucket combination must build and render.
            controller.currentView = "inbox"
            controller.selectMainPaneMode("swimlane")
            return
        case 29:
            controller.swimlaneLaneAxis = "priority"
            return
        case 30:
            controller.swimlaneLaneAxis = "label"
            return
        case 31:
            controller.swimlaneLaneAxis = "parent"
            return
        case 32:
            controller.swimlaneLaneAxis = "project"
            controller.swimlaneTimeBucket = "day"
            return
        case 33:
            controller.swimlaneTimeBucket = "month"
            return
        case 34:
            controller.swimlaneTimeBucket = "week"
            controller.setMatrixDrilldown("swimlane", "", "unscheduled", "smoke")
            controller.selectMainPaneMode("list")
            return
        case 35:
            controller.clearMatrixDrilldown()
            controller.selectMainPaneMode("plan")
            return
        case 36:
            controller.planTimeBucket = "day"
            return
        case 37:
            controller.planTimeBucket = "month"
            controller.planShowCompleted = true
            return
        case 38:
            controller.planTimeBucket = "week"
            controller.planShowCompleted = false
            controller.selectMainPaneMode("heatmap")
            return
        case 39:
            controller.selectMainPaneMode("list")
            controller.currentView = "inbox"
            controller.smokeTrace("KURRENT_SMOKE_DONE")
            runner.stop()
            return
        default:
            runner.stop()
        }
    }
}
