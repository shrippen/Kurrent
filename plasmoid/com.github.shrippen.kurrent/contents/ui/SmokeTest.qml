import QtQuick 2.15

Item {
    id: root

    property var plasmoidRoot: null
    property var backend: null
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
        running: !!(backend && backend.smokeTest)
        onTriggered: root.nextStep()
    }

    function nextStep() {
        if (!backend || !fullRoot) {
            return
        }

        var i = step
        step += 1

        if (i === 0) {
            backend.smokeTrace("KURRENT_SMOKE_START")
            if (plasmoidRoot) {
                plasmoidRoot.expanded = true
            }
            backend.refresh()
            return
        }

        if (i >= 1 && i <= views.length) {
            backend.currentView = views[i - 1]
            return
        }

        var base = views.length + 1
        switch (i - base) {
        case 0:
            backend.searchQuery = "qa-smoke"
            return
        case 1:
            backend.searchQuery = ""
            return
        case 2:
            backend.showCompleted = true
            return
        case 3:
            backend.showCompleted = false
            return
        case 4:
            backend.sortMode = "due"
            return
        case 5:
            backend.sortMode = "priority,title"
            return
        case 6:
            backend.sortMode = "default"
            return
        case 7:
            backend.selectedPriority = 1
            return
        case 8:
            backend.selectedPriority = 5
            return
        case 9:
            backend.selectedPriority = 0
            return
        case 10:
            backend.selectedPriority = -1
            return
        case 11:
            if (backend.availableLabels && backend.availableLabels.length > 0) {
                backend.selectedLabel = backend.availableLabels[0]
            }
            return
        case 12:
            backend.selectedLabel = ""
            return
        case 13:
            if (backend.collectionModel && backend.collectionModel.count > 0) {
                backend.selectedCollectionId = backend.collectionModel.collectionIdAt(0)
            }
            return
        case 14:
            backend.selectedCollectionId = -1
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
            backend.systemCursorSize()
            backend.dragScreenLimits()
            backend.dragProxyGap(24, 0)
            backend.clampDragProxyOffset(100, 100, 14, 14, 180, 48, 1920, 1080)
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
            backend.currentView = "inbox"
            backend.smokeTrace("KURRENT_SMOKE_DONE")
            runner.stop()
            return
        default:
            runner.stop()
        }
    }
}
