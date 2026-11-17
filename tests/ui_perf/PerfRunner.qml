import QtQuick 2.15

// Timing probe for tests/ui_perf.sh (staged copy only, never in the package). Logs
// "PERF begin <phase> at=<ms>" and "PERF end at=<ms> <phase> ..." lines; the script adds the
// main thread's CPU time per phase from /proc. Phases: first open of the flyout once the data
// is in, then searches (a query that keeps the rows, one that changes them, none, cleared).
Item {
    id: probe

    property var plasmoidRoot: null
    property var controller: null
    property var fullRoot: null

    width: 0
    height: 0
    visible: false

    readonly property var plan: ["a", "", "e", "xyzq", "", "e", ""]
    // Debounce (150 ms) and rebuild delay (50 ms) pass before a search can be done.
    readonly property int searchSettleMs: 220
    // A phase ends when the model is done and no frame came for this long.
    readonly property int quietMs: 250

    property string phase: "boot"
    property double phaseStart: 0
    property double modelDone: 0
    property double lastFrame: 0
    property int minWait: 0
    property int step: 0

    function log(message) {
        console.log("PERF " + message)
    }

    function busy() {
        return !controller || controller.loading || controller.listReorganizing || controller.taskModel.chunksActive
    }

    function begin(name, wait) {
        phase = name
        minWait = wait
        modelDone = 0
        phaseStart = Date.now()
        log("begin " + name + " at=" + phaseStart)
    }

    function finish(now) {
        log("end at=" + now + " " + phase + " rows=" + controller.taskModel.rowCount())
        phase = "idle"
        pause.restart()
    }

    function next() {
        const field = fullRoot && fullRoot.taskList ? fullRoot.taskList.perfSearchField : null
        if (!field || step >= plan.length) {
            log(field ? "done" : "done (no search field)")
            return
        }
        const query = plan[step++]
        begin("search '" + query + "'", searchSettleMs)
        field.text = query
    }

    Component.onCompleted: log("fullview_created at=" + Date.now())

    Connections {
        target: probe.fullRoot ? probe.fullRoot.Window.window : null
        function onFrameSwapped() {
            probe.lastFrame = Date.now()
        }
    }

    Timer {
        interval: 8
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now()
            if (probe.phase === "boot") {
                if (probe.controller && !probe.controller.loading && probe.controller.taskModel.rowCount() > 0) {
                    probe.log("data_ready at=" + now + " rows=" + probe.controller.taskModel.rowCount())
                    probe.phase = "idle"
                    openLater.start()
                }
                return
            }
            if (probe.phase === "idle") {
                return
            }
            if (!probe.modelDone && !probe.busy() && now - probe.phaseStart > probe.minWait) {
                probe.modelDone = now
            }
            if (probe.modelDone && now - Math.max(probe.lastFrame, probe.modelDone) > probe.quietMs) {
                probe.finish(now)
            }
        }
    }

    // Open a while after the data, as a user would: the startup work is done by then.
    Timer {
        id: openLater
        interval: 3000
        onTriggered: {
            probe.begin("first_open", 0)
            probe.plasmoidRoot.expanded = true
        }
    }

    Timer {
        id: pause
        interval: 800
        onTriggered: probe.next()
    }
}
