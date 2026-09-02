import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../datetime.js" as DateTime
import "../colors.js" as Colors
import org.kde.plasma.plasmoid 2.0

ColumnLayout {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property bool interactionsSuspended: false

    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    spacing: Design.spaceMedium

    property bool weekMode: false
    property bool includeWeekend: true
    property bool weekStacked: true

    readonly property int chipIconSize: Kirigami.Units.iconSizes.small

    // ── Date sync ─────────────────────────────────────────────────
    property date selectedDay: {
        if (controller) {
            var d = controller.agendaSelectedDate
            // QDate from C++ maps to JS Date; guard against invalid
            if (d && !isNaN(d.getTime()))
                return d
        }
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), now.getDate())
    }

    onSelectedDayChanged: {
        if (controller && DateTime.isoDateKey(controller.agendaSelectedDate) !== DateTime.isoDateKey(selectedDay))
            controller.agendaSelectedDate = selectedDay
    }

    Connections {
        target: controller
        function onAgendaSelectedDateChanged() {
            if (controller && DateTime.isoDateKey(controller.agendaSelectedDate) !== DateTime.isoDateKey(root.selectedDay))
                root.selectedDay = controller.agendaSelectedDate
        }
    }

    Component.onCompleted: {
        if (controller) {
            controller.agendaSelectedDate = selectedDay
            // Force initial data load after async model rebuild completes
            Qt.callLater(function() {
                _eventsRev++
            })
        }
    }

    // Re-evaluate when the model rebuilds
    Connections {
        target: controller
        function onListReorganizingChanged() {
            if (!controller.listReorganizing)
                root._modelRev++
        }
    }
    property int _modelRev: 0

    // Startup safety net: re-evaluate after async data loads
    Timer {
        id: startupTimer
        interval: 800
        running: true
        onTriggered: {
            root._eventsRev++
            root._modelRev++
        }
    }

    // ── Helpers ────────────────────────────────────────────────────
    function addDays(d, n) {
        var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        r.setDate(r.getDate() + n)
        return r
    }

    function mondayOf(d) {
        var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        r.setDate(r.getDate() - ((r.getDay() + 6) % 7))
        return r
    }

    function formatWeekLabel(start, end) {
        var s = Qt.formatDate(start, "d MMM")
        var e = Qt.formatDate(end, "d MMM yyyy")
        return s + " \u2013 " + e
    }

    function formatDue(d) {
        if (!d) return ""
        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var diff = Math.round((d - today) / 86400000)
        if (diff === 0) return i18n("Today")
        if (diff === 1) return i18n("Tomorrow")
        if (diff === -1) return i18n("Yesterday")
        return Qt.formatDate(d, "d MMM")
    }

    // ── Visible days ──────────────────────────────────────────────
    readonly property var agendaDays: {
        if (weekMode) {
            var mon = mondayOf(selectedDay)
            var count = includeWeekend ? 7 : 5
            var arr = []
            for (var i = 0; i < count; ++i)
                arr.push(addDays(mon, i))
            return arr
        }
        return [selectedDay]
    }

    readonly property date rangeStart: agendaDays.length > 0 ? agendaDays[0] : selectedDay
    readonly property date rangeEnd: agendaDays.length > 0 ? agendaDays[agendaDays.length - 1] : selectedDay

    // ── Events ────────────────────────────────────────────────────
    property int _eventsRev: 0
    Connections {
        target: controller
        function onEventBusySettingsChanged() { root._eventsRev++ }
    }

    function eventsForDay(d) {
        var _r = root._eventsRev
        return controller ? controller.agendaEventsForDay(d) : []
    }

    // ── Tasks ─────────────────────────────────────────────────────
    readonly property var tasksByDay: {
        var _dep = _modelRev + (controller && controller.taskModel ? controller.taskModel.count : 0)
        var _reorg = controller ? controller.listReorganizing : false
        if (!controller) return {}
        var list = controller.agendaTasksForRange(rangeStart, rangeEnd)
        var result = {}
        for (var i = 0; i < list.length; ++i) {
            var t = list[i]
            var key = (t.completed && t.completedDate && !isNaN(new Date(t.completedDate).getTime()))
                ? DateTime.isoDateKey(t.completedDate) : DateTime.isoDateKey(t.due)
            if (!result[key]) result[key] = []
            result[key].push(t)
        }
        return result
    }

    function tasksForDay(d) {
        var l = tasksByDay[DateTime.isoDateKey(d)]
        if (!l || l.length === 0) return []
        var incomplete = []
        var done = []
        for (var i = 0; i < l.length; i++) {
            if (l[i].completed) done.push(l[i])
            else incomplete.push(l[i])
        }
        return incomplete.concat(done)
    }

    // ── Header ────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceTiny

        QQC2.ToolButton {
            icon.name: "go-previous"
            QQC2.ToolTip.text: i18n("Previous")
            QQC2.ToolTip.visible: hovered
            onClicked: {
                var d = new Date(root.selectedDay)
                d.setDate(d.getDate() + (root.weekMode ? -7 : -1))
                root.selectedDay = d
            }
        }

        QQC2.Label {
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: {
                if (root.weekMode)
                    return formatWeekLabel(root.agendaDays[0], root.agendaDays[root.agendaDays.length - 1])
                return Qt.formatDate(root.selectedDay, "dddd, d. MMMM yyyy")
            }
            font.bold: true
        }

        QQC2.ToolButton {
            icon.name: "go-next"
            QQC2.ToolTip.text: i18n("Next")
            QQC2.ToolTip.visible: hovered
            onClicked: {
                var d = new Date(root.selectedDay)
                d.setDate(d.getDate() + (root.weekMode ? 7 : 1))
                root.selectedDay = d
            }
        }

        QQC2.ToolButton {
            text: root.weekMode ? i18n("This week") : i18n("Today")
            onClicked: {
                if (root.weekMode) {
                    root.selectedDay = mondayOf(new Date())
                } else {
                    var now = new Date()
                    root.selectedDay = new Date(now.getFullYear(), now.getMonth(), now.getDate())
                }
            }
        }

        QQC2.ToolButton {
            id: pickerBtn
            icon.name: "go-jump-today"
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            QQC2.ToolTip.text: i18n("Pick date")
            QQC2.ToolTip.visible: hovered
            onClicked: datePicker.open()
        }

        // Day / Week segmented control
        QQC2.ButtonGroup { id: viewModeGroup }
        Item {
            Layout.preferredWidth: dayBtn.implicitWidth + weekBtn.implicitWidth + 4
            Layout.preferredHeight: Math.max(dayBtn.implicitHeight, weekBtn.implicitHeight) + 4
            Rectangle {
                anchors.fill: parent
                radius: Design.buttonRadius
                color: Kirigami.Theme.backgroundColor
            }
            Row {
                anchors.fill: parent
                anchors.margins: 2
                QQC2.ToolButton {
                    id: dayBtn
                    width: (parent.width - 4) / 2
                    height: parent.height
                    text: i18n("Day")
                    QQC2.ButtonGroup.group: viewModeGroup
                    checkable: true
                    checked: !root.weekMode
                    onClicked: root.weekMode = false
                }
                QQC2.ToolButton {
                    id: weekBtn
                    width: (parent.width - 4) / 2
                    height: parent.height
                    text: i18n("Week")
                    QQC2.ButtonGroup.group: viewModeGroup
                    checkable: true
                    checked: root.weekMode
                    onClicked: root.weekMode = true
                }
            }
        }

        QQC2.ToolButton {
            visible: root.weekMode
            icon.name: root.weekStacked ? "view-split-left-right" : "view-list-details"
            QQC2.ToolTip.text: root.weekStacked ? i18n("Days side by side") : i18n("Days stacked")
            QQC2.ToolTip.visible: hovered
            onClicked: root.weekStacked = !root.weekStacked
        }

        QQC2.ToolButton {
            visible: root.weekMode
            icon.name: "edit-select-all"
            checkable: true
            checked: root.includeWeekend
            QQC2.ToolTip.text: i18n("Include weekend")
            QQC2.ToolTip.visible: hovered
            onClicked: root.includeWeekend = !root.includeWeekend
        }

        QQC2.ToolButton {
            icon.name: "text-calendar"
            QQC2.ToolTip.text: i18n("Choose calendars")
            QQC2.ToolTip.visible: hovered
            onClicked: calMenu.popup()
        }
    }

    // ── Calendar chooser menu ─────────────────────────────────────
    QQC2.Menu {
        id: calMenu
        Instantiator {
            model: controller ? controller.eventCalendars : []
            delegate: QQC2.MenuItem {
                required property var modelData
                text: modelData.name
                checkable: true
                checked: modelData.enabled
                onToggled: root.setCalendarEnabled(modelData.id, checked)
            }
            onObjectAdded: calMenu.insertItem(index, object)
            onObjectRemoved: calMenu.removeItem(object)
        }
    }

    function setCalendarEnabled(id, enabled) {
        var cals = controller.eventCalendars
        var allIds = []
        for (var i = 0; i < cals.length; ++i)
            allIds.push(String(cals[i].id))
        var raw = String(controller.busyCalendarIds || "")
        var parts = raw.length > 0 ? raw.split(",") : []
        var set = {}
        if (parts.length === 0) {
            for (var j = 0; j < allIds.length; ++j) set[allIds[j]] = true
        } else {
            for (var k = 0; k < parts.length; ++k) set[parts[k]] = true
        }
        if (enabled) set[String(id)] = true
        else delete set[String(id)]
        var ids = Object.keys(set).filter(function(x) { return set[x] })
        var csv = (ids.length >= allIds.length && allIds.length > 0) ? "" : ids.join(",")
        Plasmoid.configuration.busyCalendarIds = csv
        controller.busyCalendarIds = csv
    }

    // ── Date picker popup ─────────────────────────────────────────
    QQC2.Popup {
        id: datePicker
        x: {
            var p = pickerBtn.mapToItem(root, 0, 0)
            return Math.max(0, Math.min(p.x - width + pickerBtn.width, root.width - width))
        }
        y: {
            var p = pickerBtn.mapToItem(root, 0, 0)
            var below = p.y + pickerBtn.height + Design.spaceTiny
            var above = p.y - height - Design.spaceTiny
            return (below + height < root.height) ? below : Math.max(0, above)
        }
        width: calGrid.implicitWidth + leftPadding + rightPadding
        height: calGrid.implicitHeight + topPadding + bottomPadding
        padding: Design.spaceSmall
        modal: true
        focus: true
        popupType: QQC2.Popup.Item
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        onAboutToShow: calGrid.resetToSelected()
        contentItem: CalendarGrid {
            id: calGrid
            selectedDate: root.selectedDay
            onDateSelected: { root.selectedDay = date; datePicker.close() }
        }
    }

    // ── Day content ───────────────────────────────────────────────
    component DayContent: ColumnLayout {
        id: dayRoot
        required property var dayDate
        required property bool compact
        required property bool showDivider
        readonly property bool isToday: DateTime.isoDateKey(dayDate) === DateTime.isoDateKey(new Date())
        readonly property var events: root.eventsForDay(dayDate)
        readonly property var tasks: root.tasksForDay(dayDate)
        spacing: Design.spaceSmall

        QQC2.Label {
            Layout.fillWidth: true
            text: dayRoot.compact
                  ? Qt.formatDate(dayRoot.dayDate, "ddd d. MMM")
                  : Qt.formatDate(dayRoot.dayDate, "dddd, d. MMMM yyyy")
            font.bold: true
            font.pointSize: dayRoot.compact ? Kirigami.Theme.smallFont.pointSize
                                            : Kirigami.Theme.defaultFont.pointSize
            opacity: dayRoot.isToday ? 1.0 : 0.8
            color: dayRoot.isToday ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

        // ── Event chips (Flow layout, max 2 lines) ────────────────
        Flow {
            Layout.fillWidth: true
            spacing: Design.spaceTiny
            visible: dayRoot.events.length > 0
            Repeater {
                model: dayRoot.events
                delegate: Rectangle {
                    required property var modelData
                    radius: Design.inputRadius
                    color: Kirigami.Theme.alternateBackgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    implicitWidth: evCol.implicitWidth + Design.padInner * 2
                    implicitHeight: evCol.implicitHeight + Design.padInner
                    ColumnLayout {
                        id: evCol
                        anchors.centerIn: parent
                        spacing: 0
                        QQC2.Label {
                            Layout.maximumWidth: root.showYear ? 180 : 260
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: {
                                var parts = []
                                if (!modelData.allDay) {
                                    var s = modelData.start
                                    var e = modelData.end
                                    var from = s ? Qt.formatDateTime(s, "HH:mm") : ""
                                    var to = e ? Qt.formatDateTime(e, "HH:mm") : ""
                                    parts.push(to ? from + " \u2013 " + to : from)
                                } else {
                                    parts.push(i18n("All day"))
                                }
                                if (modelData.summary) parts.push(modelData.summary)
                                return parts.join("  ")
                            }
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                        QQC2.Label {
                            visible: modelData.calendarName && modelData.calendarName.length > 0
                            text: modelData.calendarName
                            font.pointSize: Kirigami.Theme.smallFont.pixelSize
                            opacity: 0.5
                            Layout.maximumWidth: root.showYear ? 180 : 260
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ── Task cards ────────────────────────────────────────────
        Repeater {
            model: dayRoot.tasks
            delegate: Rectangle {
                id: taskCard
                required property var modelData
                Layout.fillWidth: true
                radius: Design.inputRadius
                color: taskHover.hovered
                       ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                 Kirigami.Theme.highlightColor.b, 0.08)
                       : Kirigami.Theme.alternateBackgroundColor
                implicitHeight: taskBody.implicitHeight + Design.padInner * 2

                RowLayout {
                    id: taskBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Design.padInner
                    anchors.rightMargin: Design.padInner
                    spacing: Design.spaceTiny

                    // Checkbox (clickable to toggle completed)
                    QQC2.Label {
                        text: modelData.completed ? "\u25A3" : "\u25A1"
                        color: modelData.completed ? Kirigami.Theme.highlightColor
                                                   : Kirigami.Theme.textColor
                        opacity: taskCheckArea.containsMouse ? 1.0 : (modelData.completed ? 0.6 : 1.0)
                        MouseArea {
                            id: taskCheckArea
                            anchors.fill: parent
                            hoverEnabled: !root.interactionsSuspended
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controller.setTaskCompleted(modelData.itemId, !modelData.completed)
                        }
                    }

                    // Title + chips
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.summary || i18n("(Untitled)")
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            opacity: modelData.completed ? 0.5 : 1.0
                            font.strikeout: modelData.completed
                        }

                        // Chips row (matching TaskDelegate style)
                        RowLayout {
                            visible: (modelData.due)
                                     || (modelData.priority > 0)
                                     || (modelData.categories && modelData.categories.length > 0)
                            spacing: Design.spaceTiny
                            Layout.maximumHeight: root.chipIconSize

                            // Label icons
                            Repeater {
                                model: modelData.categories || []
                                delegate: Kirigami.Icon {
                                    required property string modelData
                                    source: "tag"
                                    color: Colors.colorForKey(modelData, "label")
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: root.chipIconSize
                                    Layout.preferredHeight: root.chipIconSize
                                    width: root.chipIconSize
                                    height: root.chipIconSize
                                    QQC2.ToolTip.text: modelData
                                    QQC2.ToolTip.visible: labelHover.hovered
                                    QQC2.ToolTip.delay: 400
                                    HoverHandler { id: labelHover }
                                }
                            }

                            // Priority icon
                            Kirigami.Icon {
                                visible: modelData.priority > 0
                                source: "flag"
                                color: Colors.colorForPriority(modelData.priority)
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: root.chipIconSize
                                Layout.preferredHeight: root.chipIconSize
                                width: root.chipIconSize
                                height: root.chipIconSize
                                QQC2.ToolTip.text: {
                                    var band = Colors.priorityLabel(modelData.priority)
                                    return i18n("Priority %1 (%2)", modelData.priority, band)
                                }
                                QQC2.ToolTip.visible: prioHover.hovered
                                QQC2.ToolTip.delay: 400
                                HoverHandler { id: prioHover }
                            }
                        }
                    }
                }

                // Edit button overlay (appears on hover, no layout impact)
                QQC2.ToolButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Design.spaceTiny
                    opacity: taskHover.hovered ? 1.0 : 0.0
                    icon.name: "document-edit"
                    icon.width: root.chipIconSize
                    icon.height: root.chipIconSize
                    QQC2.ToolTip.text: i18n("Edit task")
                    QQC2.ToolTip.visible: hovered
                    onClicked: {
                        if (root.dragHost && root.dragHost.openFullEditor) {
                            var taskObj = {
                                itemId: modelData.itemId,
                                uid: modelData.uid,
                                summary: modelData.summary,
                                completed: modelData.completed,
                                due: modelData.due,
                                priority: modelData.priority || 0,
                                categories: modelData.categories || []
                            }
                            root.dragHost.openFullEditor(taskObj)
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                HoverHandler {
                    id: taskHover
                    enabled: !root.interactionsSuspended
                }
            }
        }

        QQC2.Label {
            visible: dayRoot.events.length === 0 && dayRoot.tasks.length === 0
            text: i18n("No events or tasks.")
            opacity: 0.5
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        // Horizontal divider between days (stacked mode)
        Kirigami.Separator {
            Layout.fillWidth: true
            visible: !dayRoot.compact && root.weekMode
        }
    }

    // ── Stacked layout ────────────────────────────────────────────
    ListView {
        id: stackedList
        visible: !root.weekMode || root.weekStacked
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Design.spaceMedium
        model: root.agendaDays
        delegate: DayContent {
            required property var modelData
            required property int index
            width: ListView.view ? ListView.view.width : 0
            dayDate: modelData
            compact: root.weekMode
            showDivider: false
        }
    }

    // ── Side-by-side layout (horizontally scrollable with ScrollBar) ──
    Item {
        visible: root.weekMode && !root.weekStacked
        Layout.fillWidth: true
        Layout.fillHeight: true

        Flickable {
            id: weekFlick
            anchors.fill: parent
            anchors.bottomMargin: weekScrollBar.height
            clip: true
            contentHeight: weekCol.implicitHeight
            contentWidth: weekCol.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: weekCol
                spacing: 0
                Row {
                    spacing: 1
                    Repeater {
                        model: root.agendaDays
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: Math.max(Kirigami.Units.gridUnit * 10,
                                            root.width / root.agendaDays.length)
                            height: dayLoader.item ? dayLoader.item.implicitHeight : 0
                            Loader {
                                id: dayLoader
                                anchors.fill: parent
                                sourceComponent: DayContent {
                                    dayDate: modelData
                                    compact: true
                                    showDivider: index < root.agendaDays.length - 1
                                }
                            }
                        }
                    }
                }
            }
        }

        QQC2.ScrollBar {
            id: weekScrollBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            orientation: Qt.Horizontal
            visible: weekFlick.contentWidth > weekFlick.width + 1
            size: weekFlick.width / weekFlick.contentWidth
            position: weekFlick.originX / weekFlick.contentWidth
            onPositionChanged: {
                if (weekScrollBar.pressed)
                    weekFlick.originX = weekScrollBar.position * weekFlick.contentWidth
            }
        }
    }
}
