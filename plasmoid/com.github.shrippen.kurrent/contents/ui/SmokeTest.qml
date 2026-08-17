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

        switch (i) {
        case 9:
            backend.searchQuery = "qa-smoke"
            return
        case 10:
            backend.searchQuery = ""
            return
        case 11:
            backend.showCompleted = true
            return
        case 12:
            backend.showCompleted = false
            return
        case 13:
            backend.sortMode = "due"
            return
        case 14:
            backend.sortMode = "priority,title"
            return
        case 15:
            backend.sortMode = "default"
            return
        case 16:
            backend.selectedPriority = 1
            return
        case 17:
            backend.selectedPriority = 5
            return
        case 18:
            backend.selectedPriority = 0
            return
        case 19:
            backend.selectedPriority = -1
            return
        case 20:
            if (backend.availableLabels && backend.availableLabels.length > 0) {
                backend.selectedLabel = backend.availableLabels[0]
            }
            return
        case 21:
            backend.selectedLabel = ""
            return
        case 22:
            if (backend.collectionModel && backend.collectionModel.count > 0) {
                backend.selectedCollectionId = backend.collectionModel.collectionIdAt(0)
            }
            return
        case 23:
            backend.selectedCollectionId = -1
            return
        case 24:
            fullRoot.openSortMenu()
            return
        case 25:
            if (sortMenu) {
                sortMenu.close()
            }
            return
        case 26:
            backend.systemCursorSize()
            backend.dragScreenLimits()
            backend.dragProxyGap(24, 0)
            backend.clampDragProxyOffset(100, 100, 14, 14, 180, 48, 1920, 1080)
            return
        case 27:
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
        case 28:
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
        case 29:
            if (taskFullEditor) {
                taskFullEditor.close()
            }
            return
        case 30:
            if (taskList && taskList.projectAskPopup) {
                taskList.askProjects = [{ collectionId: 1, name: "Smoke" }]
                taskList.projectAskPopup.open()
            }
            return
        case 31:
            if (taskList && taskList.projectAskPopup) {
                taskList.projectAskPopup.close()
            }
            return
        case 32:
            backend.currentView = "inbox"
            backend.smokeTrace("KURRENT_SMOKE_DONE")
            runner.stop()
            return
        default:
            runner.stop()
        }
    }
}
