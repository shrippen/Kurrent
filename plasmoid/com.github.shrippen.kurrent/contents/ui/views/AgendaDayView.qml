import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../Kante"
import "../datetime.js" as DateTime

// The Agenda's day view: 14 days from `listStart`, each an hour grid with its appointments,
// task blocks and free gaps; days without anything fold into one line. On the left a month
// calendar and suggestions for the target day (`targetDay`, the Agenda's selected date).
RowLayout {
    id: view

    required property TaskController controller
    property Item dragHost: null
    property bool interactionsSuspended: false
    /** Target day of the suggestions; a click on a day's header picks it. */
    property date targetDay: new Date()
    /** First of the 14 shown days. */
    property date listStart: new Date()
    /** Bumped by the Agenda when tasks or events change. */
    property int revision: 0
    /** Minutes since midnight, ticked while shown: the now line and today's free time follow it. */
    property int nowMinute: minuteNow()
    /** Today's date; when it turns, the days are built anew (today, past, free time). */
    property string todayKey: DateTime.isoDateKey(new Date())
    signal pickTarget(date day)
    signal jump(date day)

    /** Days shown from listStart. */
    property int dayCount: 14
    /** Room for the left column (month calendar, legend, suggestions); without it a day's
     *  header picks nothing, since there are no suggestions to show. */
    readonly property bool wide: width >= Kirigami.Units.gridUnit * 34
    spacing: Design.spaceMedium

    function addDays(d, n) {
        var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        r.setDate(r.getDate() + n)
        return r
    }
    function minuteNow() {
        var now = new Date()
        return now.getHours() * 60 + now.getMinutes()
    }
    Timer {
        interval: 60 * 1000
        repeat: true
        running: view.visible
        triggeredOnStart: true
        onTriggered: {
            view.nowMinute = view.minuteNow()
            view.todayKey = DateTime.isoDateKey(new Date())
        }
    }
    function today() {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), now.getDate())
    }
    function relDay(d) {
        var diff = Math.round((d - today()) / 86400000)
        if (diff === 0) {
            return i18n("Today")
        }
        if (diff === 1) {
            return i18n("Tomorrow")
        }
        if (diff === -1) {
            return i18n("Yesterday")
        }
        return Qt.locale().toString(d, "ddd d. MMM")
    }
    function hm(minute) {
        return DateTime.pad2(Math.floor(minute / 60)) + ":" + DateTime.pad2(minute % 60)
    }
    function timeOf(when) {
        return Qt.locale().toString(when, Qt.locale().timeFormat(Locale.ShortFormat))
    }

    readonly property var days: {
        var _rev = view.revision + view.todayKey
        return controller ? controller.agendaDays(listStart, dayCount) : []
    }

    // Days with something on them, and runs of empty days as one line. The target day always
    // shows, so it can take a drop.
    readonly property var entries: {
        var out = []
        var quiet = []
        var targetKey = DateTime.isoDateKey(targetDay)
        function flush() {
            if (quiet.length > 0) {
                out.push({ quiet: true, from: quiet[0], to: quiet[quiet.length - 1] })
                quiet = []
            }
        }
        for (var i = 0; i < days.length; ++i) {
            var d = days[i]
            var empty = d.items.length === 0 && d.loose.length === 0 && d.allDayEvents.length === 0
            if (empty && DateTime.isoDateKey(d.date) !== targetKey) {
                quiet.push(d.date)
                continue
            }
            flush()
            out.push({ quiet: false, day: d })
        }
        flush()
        return out
    }

    readonly property var suggestions: {
        var _rev = view.revision
        return controller ? controller.agendaSuggestions(targetDay) : []
    }

    // Dots for the month calendar: events, open tasks, overdue open tasks.
    readonly property var markers: {
        var _rev = view.revision
        if (!controller) {
            return ({})
        }
        var first = monthCal.shownMonth
        var last = new Date(first.getFullYear(), first.getMonth() + 1, 0)
        var byDay = controller.agendaTasksByDay(first, last)
        var todayKey = DateTime.isoDateKey(today())
        var out = {}
        for (var d = new Date(first); d <= last; d = addDays(d, 1)) {
            var key = DateTime.isoDateKey(d)
            var open = (byDay[key] || []).filter(function(t) { return !t.completed }).length
            var events = controller.agendaEventsForDay(d).length
            if (open > 0 || events > 0) {
                out[key] = { event: events > 0, task: open > 0, late: open > 0 && key < todayKey }
            }
        }
        return out
    }

    function reasonsOf(suggestion) {
        var out = []
        for (var i = 0; i < suggestion.reasons.length; ++i) {
            var r = suggestion.reasons[i]
            if (r.kind === "overdue") {
                out.push({ tone: "late", text: r.days === 1 ? i18n("Overdue since yesterday")
                                                            : i18np("%1 day overdue", "%1 days overdue", r.days) })
            } else if (r.kind === "dueSoon") {
                out.push({ tone: "", text: r.days === 1 ? i18n("Due the day after")
                                                        : i18np("Due %1 day later", "Due %1 days later", r.days) })
            } else if (r.kind === "undated") {
                out.push({ tone: "", text: i18n("No date") })
            } else if (r.kind === "highPriority") {
                out.push({ tone: "high", text: i18n("High priority") })
            } else if (r.kind === "fits") {
                out.push({ tone: "fit", text: i18n("Fits %1–%2", hm(r.start), hm(r.end)) })
            }
        }
        return out
    }

    // ── Left: month calendar and suggestions (not in a narrow widget) ──────
    ColumnLayout {
        visible: view.wide
        Layout.preferredWidth: Kirigami.Units.gridUnit * 15
        Layout.maximumWidth: Kirigami.Units.gridUnit * 15
        Layout.fillHeight: true
        spacing: Design.spaceMedium

        CalendarGrid {
            id: monthCal
            Layout.fillWidth: true
            selectedDate: view.targetDay
            markers: view.markers
            rangeStart: view.listStart
            rangeEnd: view.addDays(view.listStart, view.dayCount - 1)
            onDateSelected: function(date) { view.jump(date) }
        }
        // Legend for the dots.
        Flow {
            Layout.fillWidth: true
            spacing: Design.spaceMedium
            Repeater {
                model: [
                    { color: KanteStyle.mutedTextColor, text: i18n("Appointment") },
                    { color: KanteStyle.accentColor, text: i18n("Task") },
                    { color: KanteStyle.negativeTextColor, text: i18n("Overdue") }
                ]
                delegate: Row {
                    required property var modelData
                    spacing: Design.spaceTiny
                    Rectangle {
                        width: KanteStyle.markerSize
                        height: KanteStyle.markerSize
                        radius: KanteStyle.markerRadius
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.color
                    }
                    QQC2.Label {
                        text: modelData.text
                        color: KanteStyle.mutedTextColor
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ColumnLayout {
            spacing: 0
            QQC2.Label {
                text: i18n("Suggestions for")
                color: KanteStyle.mutedTextColor
                font: Kirigami.Theme.smallFont
            }
            Kirigami.Heading {
                level: 4
                text: Qt.locale().toString(view.targetDay, "dddd, d. MMMM")
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: i18n("Most important first. Click a day on the right to pick it; drag onto a green gap to give a time.")
                color: KanteStyle.mutedTextColor
                font: Kirigami.Theme.smallFont
            }
        }

        ListView {
            id: suggestionList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Design.spaceTiny
            model: view.suggestions
            section.property: "tier"
            section.criteria: ViewSection.FullString
            section.labelPositioning: ViewSection.InlineLabels | ViewSection.CurrentLabelAtStart
            section.delegate: Rectangle {
                required property string section
                width: ListView.view.width
                height: tierLabel.implicitHeight + Design.spaceSmall
                color: Kirigami.Theme.backgroundColor
                QQC2.Label {
                    id: tierLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: section === "first" ? i18n("First")
                          : section === "then" ? i18n("Then") : i18n("If time allows")
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    color: KanteStyle.mutedTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
            delegate: AgendaTaskRow {
                required property var modelData
                width: ListView.view.width - (suggestionScroll.visible ? suggestionScroll.width : 0)
                controller: view.controller
                dragHost: view.dragHost
                interactionsSuspended: view.interactionsSuspended
                task: modelData.task
                reasons: view.reasonsOf(modelData)
                actionText: "→ " + view.relDay(view.targetDay)
                onActionClicked: view.controller.agendaMoveToDay(modelData.task.itemId, view.targetDay)
            }
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Design.spaceLarge * 2
                visible: suggestionList.count === 0
                text: i18n("No suggestions for this day.")
            }
            QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: suggestionScroll }
        }
    }

    // ── Right: the days ────────────────────────────────────────────────────
    ListView {
        id: dayList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Design.spaceMedium
        model: view.entries
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: dayScroll }

        delegate: Loader {
            required property var modelData
            width: ListView.view.width - (dayScroll.visible ? dayScroll.width : 0)
            sourceComponent: modelData.quiet ? quietLine : dayBlock
            property var entry: modelData
        }
    }

    Component {
        id: quietLine
        Rectangle {
            readonly property var entry: parent ? parent.entry : null
            implicitHeight: quietLabel.implicitHeight + Design.spaceSmall * 2
            radius: Design.inputRadius
            color: KanteStyle.sunkenColor
            QQC2.Label {
                id: quietLabel
                anchors.verticalCenter: parent.verticalCenter
                x: Design.spaceMedium
                text: !parent.entry ? ""
                      : (DateTime.isoDateKey(parent.entry.from) === DateTime.isoDateKey(parent.entry.to)
                         ? i18n("%1: nothing planned", Qt.locale().toString(parent.entry.from, "dddd, d. MMMM"))
                         : i18n("%1 to %2: nothing planned", view.relDay(parent.entry.from), view.relDay(parent.entry.to)))
                color: KanteStyle.mutedTextColor
            }
            TapHandler {
                enabled: !view.interactionsSuspended && !!parent.entry
                onTapped: view.pickTarget(parent.entry.from)
            }
            DropArea {
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                onDropped: function(event) {
                    var task = view.dragHost ? view.dragHost.draggingTask : null
                    if (task) {
                        view.controller.agendaMoveToDay(task.itemId, parent.entry.from)
                        event.acceptProposedAction()
                    }
                }
            }
        }
    }

    Component {
        id: dayBlock
        ColumnLayout {
            id: dayCol
            readonly property var day: parent ? parent.entry.day : null
            readonly property bool isTarget: !!day && DateTime.isoDateKey(day.date) === DateTime.isoDateKey(view.targetDay)
            // Only marked where the suggestions show beside it.
            readonly property bool marked: view.wide && isTarget
            readonly property bool isToday: !!day && DateTime.isoDateKey(day.date) === view.todayKey
            readonly property bool past: !!day && DateTime.isoDateKey(day.date) < view.todayKey
            readonly property int openCount: {
                if (!day) {
                    return 0
                }
                var n = day.loose.filter(function(t) { return !t.completed }).length
                return n + day.items.filter(function(it) { return it.kind === "task" && !it.completed }).length
            }
            readonly property int eventCount: day ? day.allDayEvents.length + day.items.filter(function(it) { return it.kind === "event" }).length : 0
            spacing: Design.spaceSmall

            // Header: a click makes this day the suggestions' target (wide layout only).
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: head.implicitHeight + Design.spaceSmall * 2
                radius: Design.inputRadius
                color: dayCol.marked ? KanteStyle.selectionColor : (headHover.hovered ? KanteStyle.sunkenColor : "transparent")
                border.width: dayCol.marked ? KanteStyle.borderWidth : 0
                border.color: KanteStyle.accentColor
                RowLayout {
                    id: head
                    anchors.fill: parent
                    anchors.leftMargin: Design.spaceSmall
                    anchors.rightMargin: Design.spaceSmall
                    spacing: Design.spaceSmall
                    Kirigami.Heading {
                        level: 4
                        text: dayCol.day ? Qt.locale().toString(dayCol.day.date, "dddd, d. MMMM") : ""
                        color: dayCol.isToday ? KanteStyle.accentTextColor : KanteStyle.textColor
                    }
                    QQC2.Label {
                        visible: !!dayCol.day && (dayCol.isToday || view.relDay(dayCol.day.date) === i18n("Tomorrow"))
                        text: dayCol.isToday ? i18n("Today") : i18n("Tomorrow")
                        color: KanteStyle.accentTextColor
                        font: Kirigami.Theme.smallFont
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.Label {
                        text: (dayCol.marked ? i18n("Target") + " · " : "")
                              + i18np("%1 appointment", "%1 appointments", dayCol.eventCount)
                              + " · " + i18np("%1 task", "%1 tasks", dayCol.openCount)
                        color: dayCol.marked ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
                        font: Kirigami.Theme.smallFont
                    }
                }
                HoverHandler { id: headHover; enabled: view.wide && !view.interactionsSuspended }
                TapHandler {
                    enabled: view.wide && !view.interactionsSuspended && !!dayCol.day
                    onTapped: view.pickTarget(dayCol.day.date)
                }
                QQC2.ToolTip.text: i18n("Show suggestions for this day")
                QQC2.ToolTip.visible: headHover.hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            // All-day appointments.
            Flow {
                Layout.fillWidth: true
                spacing: Design.spaceTiny
                visible: dayCol.day && dayCol.day.allDayEvents.length > 0
                Repeater {
                    model: dayCol.day ? dayCol.day.allDayEvents : []
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: allDayLabel.implicitWidth + Design.padInner * 2
                        implicitHeight: allDayLabel.implicitHeight + Design.spaceTiny * 2
                        radius: Design.inputRadius
                        color: KanteStyle.sunkenColor
                        border.width: KanteStyle.borderWidth
                        border.color: KanteStyle.frameColor
                        QQC2.Label {
                            id: allDayLabel
                            anchors.centerIn: parent
                            text: i18n("All day") + " · " + modelData.summary
                            color: KanteStyle.mutedTextColor
                            font: Kirigami.Theme.smallFont
                        }
                    }
                }
            }

            // Tasks without a time; a drop here takes the time away.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.spaceTiny
                QQC2.Label {
                    visible: dayCol.day && dayCol.day.loose.length > 0
                    text: i18n("No time")
                    color: KanteStyle.mutedTextColor
                    font: Kirigami.Theme.smallFont
                }
                Repeater {
                    model: dayCol.day ? dayCol.day.loose : []
                    delegate: AgendaTaskRow {
                        required property var modelData
                        Layout.fillWidth: true
                        controller: view.controller
                        dragHost: view.dragHost
                        interactionsSuspended: view.interactionsSuspended
                        task: modelData
                        meta: modelData.allDay || !modelData.dueDate ? "" : i18n("due %1", view.timeOf(modelData.dueDate))
                    }
                }
                DropArea {
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 1.5
                    keys: ["application/x-kurrent-task"]
                    visible: !!(view.dragHost && view.dragHost.draggingTask)
                    Rectangle {
                        anchors.fill: parent
                        radius: Design.inputRadius
                        color: parent.containsDrag ? KanteStyle.selectionColor : "transparent"
                        border.width: KanteStyle.borderWidth
                        border.color: KanteStyle.frameColor
                        QQC2.Label {
                            anchors.centerIn: parent
                            text: i18n("Drop here for no time on this day")
                            color: KanteStyle.mutedTextColor
                            font: Kirigami.Theme.smallFont
                        }
                    }
                    onDropped: function(event) {
                        var task = view.dragHost ? view.dragHost.draggingTask : null
                        if (task) {
                            view.controller.agendaMoveToDay(task.itemId, dayCol.day.date)
                            event.acceptProposedAction()
                        }
                    }
                }
            }

            AgendaTimeline {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                controller: view.controller
                dragHost: view.dragHost
                interactionsSuspended: view.interactionsSuspended
                day: dayCol.day
                nowMinute: view.nowMinute
                showFree: !dayCol.past
                selectedItemId: view.selectedBlock
                onBlockClicked: function(task) {
                    view.selectedBlock = task.itemId
                    if (view.dragHost && view.dragHost.inspectorActive) {
                        view.dragHost.inspectTask(task.itemId)
                    }
                }
            }
        }
    }

    /** The block whose edges can be dragged; a click on a block picks it. */
    property var selectedBlock: -1
}
