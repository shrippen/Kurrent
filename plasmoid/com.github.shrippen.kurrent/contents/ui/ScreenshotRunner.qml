import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "." as KurrentUi

// Screenshot mode for tests/screenshot.sh. Inactive unless KURRENT_SCREENSHOT_DIR is set.
// Opens the panel flyout (the only plasmoidviewer layout that owns a real window), then walks
// styles × widths × view modes (+ the full editor), saving one PNG per state via grabToImage.
// Styles and view modes go through the real configuration (like a user would set them), so the
// script backs up and restores kurrentrc and plasmoidviewer's applet config around the run.
Item {
    id: runner

    property var plasmoidRoot: null
    property var backend: null
    property var fullRoot: null
    property var taskFullEditor: null

    readonly property string outDir: backend ? backend.screenshotDir : ""
    readonly property bool active: outDir.length > 0

    width: 0
    height: 0
    visible: false

    readonly property var allStyles: ["plasma", "kante", "kanteLight"]
    // "calendar" is the Agenda's day view; "calendar-week" and "calendar-month" its other views.
    readonly property var allModes: ["list", "kanban", "swimlane", "plan", "heatmap", "calendar", "calendar-week", "calendar-month"]
    // Grid units: 30 = flyout default (narrow layout with tabs), 60 = wide layout with sidebar,
    // 80 = wide enough for the inspector beside the list.
    readonly property var allWidths: [30, 60, 80]

    function planValue(key, fallback) {
        var plan = backend ? (backend.screenshotPlan || "") : ""
        var parts = plan.split(";")
        for (var i = 0; i < parts.length; ++i) {
            var kv = parts[i].split("=")
            if (kv.length === 2 && kv[0].trim() === key) {
                return kv[1].trim().split(",").filter(function(x) { return x.length > 0 })
            }
        }
        return fallback
    }

    property var queue: []
    property int shotCount: 0

    function trace(msg) {
        if (backend) {
            backend.smokeTrace(msg)
        }
    }

    function buildQueue() {
        var styles = planValue("styles", allStyles)
        var modes = planValue("modes", allModes)
        var widths = planValue("widths", allWidths).map(Number)
        var editor = planValue("editor", ["1"])[0] === "1"
        var inspector = planValue("inspector", ["1"])[0] === "1"
        // Mid-animation frame of a view switch (list -> kanban), to see what slides where.
        var transition = planValue("transition", ["0"])[0] === "1"
        // The Agenda's date picker, opened from the toolbar (after the calendar modes).
        var picker = planValue("picker", ["0"])[0] === "1"
        // The day view's task ghost (tap on empty time) on the first day: ghost=1 at 12:00,
        // or ghost=<minute of day>.
        var ghostValue = Number(planValue("ghost", ["0"])[0])
        var ghost = ghostValue > 0
        var ghostMinute = ghostValue === 1 ? 12 * 60 : ghostValue
        var q = []
        q.push({ act: "expand" })
        // Settings for the run, e.g. set=agendaWorkMinutes:360,agendaWeekend:false (the config
        // home's kurrentrc is replaced by the widget's defaults at start).
        var settings = planValue("set", [])
        for (var k = 0; k < settings.length; ++k) {
            var pair = settings[k].split(":")
            if (pair.length === 2) {
                q.push({ act: "setting", key: pair[0], value: pair[1] })
            }
        }
        for (var w = 0; w < widths.length; ++w) {
            q.push({ act: "width", value: widths[w] })
            for (var s = 0; s < styles.length; ++s) {
                q.push({ act: "style", value: styles[s] })
                for (var m = 0; m < modes.length; ++m) {
                    q.push({ act: "mode", value: modes[m] })
                    q.push({ act: "shot", name: styles[s] + "-" + widths[w] + "gu-" + modes[m] })
                }
                if (ghost) {
                    q.push({ act: "mode", value: "calendar-day" })
                    q.push({ act: "ghost", value: ghostMinute })
                    q.push({ act: "shot", name: styles[s] + "-" + widths[w] + "gu-ghost" })
                }
                if (picker) {
                    q.push({ act: "mode", value: "calendar-day" })
                    q.push({ act: "picker" })
                                        q.push({ act: "closePicker" })
                }
                if (transition) {
                    q.push({ act: "mode", value: "list" })
                    q.push({ act: "modeMid", value: "kanban" })
                    q.push({ act: "shot", name: styles[s] + "-" + widths[w] + "gu-transition" })
                }
                if (inspector) {
                    q.push({ act: "mode", value: "list" })
                    q.push({ act: "inspect" })
                    q.push({ act: "shot", name: styles[s] + "-" + widths[w] + "gu-inspector" })
                    q.push({ act: "mode", value: "kanban" })
                    q.push({ act: "shot", name: styles[s] + "-" + widths[w] + "gu-inspector-kanban" })
                    q.push({ act: "closeInspector" })
                }
                if (editor) {
                    q.push({ act: "mode", value: "list" })
                    q.push({ act: "editor" })
                    q.push({ act: "shot", name: styles[s] + "-" + widths[w] + "gu-editor" })
                    q.push({ act: "closeEditor" })
                }
            }
        }
        q.push({ act: "done" })
        queue = q
    }

    function step() {
        if (queue.length === 0) {
            return
        }
        var item = queue[0]
        queue = queue.slice(1)
        var wait = 250
        switch (item.act) {
        case "expand":
            plasmoidRoot.expanded = true
            wait = 2500
            break
        case "width": {
            var shell = plasmoidRoot.fullRepresentationItem
            // The flyout follows the shell's Layout.preferred* hints, which bind to implicit*.
            if (shell) {
                shell.implicitWidth = Kirigami.Units.gridUnit * item.value
                shell.implicitHeight = Kirigami.Units.gridUnit * 38
            }
            wait = 1200
            break
        }
        case "modeMid":
            backend.selectMainPaneMode(item.value)
            wait = 110
            break
        case "setting": {
            var v = item.value
            backend.storeSetting(item.key, v === "true" ? true : v === "false" ? false : (isNaN(Number(v)) ? v : Number(v)))
            wait = 300
            break
        }
        case "style":
            // Through the settings: main.qml re-applies Design from them on every settings
            // change (e.g. the next view-mode switch), so an in-memory value would not stick.
            backend.storeSetting("uiStyle", item.value)
            wait = 800
            break
        case "mode": {
            var parts = item.value.split("-")
            backend.selectMainPaneMode(parts[0])
            if (parts[0] === "calendar") {
                backend.selectAgendaMode(parts.length > 1 ? parts[1] : "day")
            }
            wait = 1400
            break
        }
        case "editor": {
            var snap = fullRoot.taskList && fullRoot.taskList.firstTaskSnapshot
                    ? fullRoot.taskList.firstTaskSnapshot() : null
            if (snap) {
                fullRoot.openFullEditor(snap)
            } else {
                fullRoot.openNewTaskEditor(-1, null)
            }
            wait = 1200
            break
        }
        case "inspect": {
            var first = fullRoot.taskList && fullRoot.taskList.firstTaskSnapshot
                    ? fullRoot.taskList.firstTaskSnapshot() : null
            if (first) {
                fullRoot.inspectTask(first.itemId)
            }
            wait = 900
            break
        }
        case "ghost":
            if (fullRoot.calendarView) {
                fullRoot.calendarView.openTaskGhost(item.value)
            }
            wait = 700
            break
        case "picker":
            if (fullRoot.calendarView) {
                fullRoot.calendarView.openDatePicker()
            }
            wait = 700
            break
        case "closePicker":
            if (fullRoot.calendarView) {
                // The popup sits in the window overlay, which a shot does not catch: log where
                // it opened against its button instead.
                trace("KURRENT_SCREENSHOT_PICKER " + fullRoot.calendarView.datePickerGeometry())
                fullRoot.calendarView.closeDatePicker()
            }
            wait = 300
            break
        case "closeInspector":
            fullRoot.inspectedItemId = -1
            wait = 300
            break
        case "closeEditor":
            if (taskFullEditor && taskFullEditor.reject) {
                taskFullEditor.reject()
            }
            wait = 500
            break
        case "shot": {
            var name = item.name
            var target = fullRoot.overlayHost || fullRoot
            trace("KURRENT_SCREENSHOT " + name + " " + Math.round(target.width) + "x" + Math.round(target.height)
                  + " style=" + KurrentUi.Design.uiStyle + " mode=" + (backend ? backend.mainPaneMode : "?"))
            var ok = target.grabToImage(function(result) {
                result.saveToFile(runner.outDir + "/" + name + ".png")
                runner.shotCount += 1
                ticker.restart()
            })
            if (!ok) {
                trace("KURRENT_SCREENSHOT_FAILED " + name)
                ticker.restart()
            }
            return
        }
        case "done":
            trace("KURRENT_SCREENSHOT_DONE " + shotCount)
            Qt.quit()
            return
        }
        ticker.interval = wait
        ticker.restart()
    }

    Timer {
        id: ticker
        interval: 250
        repeat: false
        onTriggered: runner.step()
    }

    // Plasma's flyout frame is drawn outside the grabbed item; emulate it with the platform
    // window colour (not inheriting the Kante scope) so screenshots show text on a real ground.
    Rectangle {
        parent: runner.active && runner.fullRoot ? runner.fullRoot : null
        anchors.fill: parent
        z: -100
        visible: runner.active
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        color: Kirigami.Theme.backgroundColor
    }

    Timer {
        interval: 3000
        running: runner.active
        repeat: false
        onTriggered: {
            runner.trace("KURRENT_SCREENSHOT_START " + runner.outDir)
            runner.buildQueue()
            runner.step()
        }
    }
}
