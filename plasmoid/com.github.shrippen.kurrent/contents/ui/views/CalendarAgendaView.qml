import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../datetime.js" as DateTime
import "../focus.js" as Focus
import "../Kante"

// The Agenda: day (hour grids and suggestions), week board and month, switched in the date
// bar. All three share one date (controller.agendaSelectedDate); the mode and the weekend
// switch persist. Keys: T, W, M switch the view, ← → step, H goes to today.
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

    readonly property string mode: controller ? controller.agendaMode : "day"
    readonly property bool weekend: controller ? controller.agendaWeekend : true
    readonly property var modes: [
        { id: "day", text: i18n("Day"), key: "T" },
        { id: "week", text: i18n("Week"), key: "W" },
        { id: "month", text: i18n("Month"), key: "M" }
    ]

    // ── Date sync ─────────────────────────────────────────────────
    property date selectedDay: {
        if (controller) {
            var d = controller.agendaSelectedDate
            // QDate from C++ maps to JS Date; guard against invalid
            if (d && !isNaN(d.getTime()))
                return d
        }
        return today()
    }

    onSelectedDayChanged: {
        if (controller && DateTime.isoDateKey(controller.agendaSelectedDate) !== DateTime.isoDateKey(selectedDay))
            controller.agendaSelectedDate = selectedDay
        // The day view keeps its 14 days while the target moves inside them.
        if (selectedDay < listStart || selectedDay > addDays(listStart, 13))
            listStart = selectedDay
    }

    // First of the day view's 14 days. Moves with the date bar and the view switch, not with a
    // click on a day inside the list.
    property date listStart: new Date()
    function jumpTo(d) {
        listStart = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        selectedDay = listStart
    }

    Connections {
        target: controller
        function onAgendaSelectedDateChanged() {
            if (controller && DateTime.isoDateKey(controller.agendaSelectedDate) !== DateTime.isoDateKey(root.selectedDay))
                root.selectedDay = controller.agendaSelectedDate
        }
    }

    Component.onCompleted: {
        listStart = selectedDay
        if (controller) {
            controller.agendaSelectedDate = selectedDay
            // Force initial data load after async model rebuild completes
            Qt.callLater(function() {
                _eventsRev++
            })
        }
    }

    // Re-evaluate when the model rebuilds (every task change ends with one).
    Connections {
        target: controller
        function onListReorganizingChanged() {
            if (!controller.listReorganizing)
                root._modelRev++
        }
        function onEventBusySettingsChanged() { root._eventsRev++ }
    }
    property int _modelRev: 0
    property int _eventsRev: 0
    readonly property int revision: _modelRev + _eventsRev
                                    + (controller && controller.taskModel ? controller.taskModel.count : 0)

    // Startup safety net: re-evaluate after async data loads
    Timer {
        interval: 800
        running: true
        onTriggered: {
            root._eventsRev++
            root._modelRev++
        }
    }

    // ── Helpers ────────────────────────────────────────────────────
    function today() {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), now.getDate())
    }
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
    readonly property bool onToday: DateTime.isoDateKey(selectedDay) === DateTime.isoDateKey(today())

    /** Switch the view, optionally to another day (drill-down); zooms in or out. */
    function go(nextMode, day) {
        jumpTo(day || selectedDay)
        if (nextMode !== mode && controller) {
            var order = ["day", "week", "month"]
            stage.zoomIn = order.indexOf(nextMode) < order.indexOf(mode)
            controller.selectAgendaMode(nextMode)
            if (!Design.reducedMotion) {
                zoom.restart()
            }
        }
    }
    function step(n) {
        if (!controller) {
            return
        }
        jumpTo(n === 0 ? today() : controller.agendaStep(selectedDay, n))
    }

    readonly property string title: {
        var d = selectedDay
        var week = controller ? controller.isoWeek(d) : 0
        if (mode === "week") {
            var mon = mondayOf(d)
            var end = addDays(mon, weekend ? 6 : 4)
            return i18n("Week %1 · %2 – %3", week, Qt.locale().toString(mon, "d. MMM"), Qt.locale().toString(end, "d. MMM yyyy"))
        }
        if (mode === "month") {
            return Qt.locale().toString(d, "MMMM yyyy")
        }
        return Qt.locale().toString(d, "dddd, d. MMMM yyyy") + " · " + i18n("Week %1", week)
    }
    // For a narrow date bar, instead of cutting the long title in the middle of a word.
    readonly property string shortTitle: {
        var d = selectedDay
        var week = controller ? controller.isoWeek(d) : 0
        if (mode === "week") {
            var mon = mondayOf(d)
            var end = addDays(mon, weekend ? 6 : 4)
            return i18n("Week %1 · %2 – %3", week, Qt.locale().toString(mon, "d.M."), Qt.locale().toString(end, "d.M."))
        }
        if (mode === "month") {
            return Qt.locale().toString(d, "MMM yyyy")
        }
        return Qt.locale().toString(d, "ddd d. MMM") + " · " + i18n("Week %1", week)
    }

    // Keys while the Agenda is shown (text fields keep their letters and arrows). On the desktop
    // Kurrent shares its window with the folder view and other widgets, so the keys only count
    // while the focus is inside Kurrent; a press in the Agenda takes it there (see focusTaker).
    readonly property bool ownsKeys: Focus.inside(Window.activeFocusItem, root.dragHost || root)
    Shortcut {
        sequence: "T"
        enabled: root.visible && root.ownsKeys && !root.interactionsSuspended
        onActivated: root.go("day")
    }
    Shortcut {
        sequence: "W"
        enabled: root.visible && root.ownsKeys && !root.interactionsSuspended
        onActivated: root.go("week")
    }
    Shortcut {
        sequence: "M"
        enabled: root.visible && root.ownsKeys && !root.interactionsSuspended
        onActivated: root.go("month")
    }
    Shortcut {
        sequence: "H"
        enabled: root.visible && root.ownsKeys && !root.interactionsSuspended
        onActivated: root.step(0)
    }
    Shortcut {
        sequence: "Left"
        enabled: root.visible && root.ownsKeys && !root.interactionsSuspended
        onActivated: root.step(-1)
    }
    Shortcut {
        sequence: "Right"
        enabled: root.visible && root.ownsKeys && !root.interactionsSuspended
        onActivated: root.step(1)
    }

    // ── Date bar: view, ‹ title ›, Today, weekend, picker, calendars ──
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceTiny

        Item {
            Layout.preferredWidth: modeRow.implicitWidth + Design.spaceTiny * 2
            Layout.preferredHeight: modeRow.implicitHeight + Design.spaceTiny * 2
            Rectangle {
                anchors.fill: parent
                radius: Design.inputRadius
                color: Design.withAlpha(Kirigami.Theme.textColor, Design.viewModeToolbarFillOpacity)
            }
            Row {
                id: modeRow
                anchors.centerIn: parent
                Repeater {
                    model: root.modes
                    delegate: KanteToolButton {
                        required property var modelData
                        text: modelData.text
                        checkable: true
                        checked: root.mode === modelData.id
                        onClicked: root.go(modelData.id)
                        QQC2.ToolTip.text: i18n("%1 (key %2)", modelData.text, modelData.key)
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }
            }
        }

        KanteToolButton {
            icon.name: "go-previous"
            onClicked: root.step(-1)
            QQC2.ToolTip.text: root.mode === "week" ? i18n("Previous week (←)")
                               : root.mode === "month" ? i18n("Previous month (←)") : i18n("Previous day (←)")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        QQC2.Label {
            id: dayLabel
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: fullTitle.width <= width ? root.title : root.shortTitle
            font.bold: true
            font.family: Design.headingFamily
            font.capitalization: KanteStyle.themed ? Font.AllUppercase : Font.MixedCase
            TextMetrics {
                id: fullTitle
                font: dayLabel.font
                text: root.title
            }
        }

        KanteToolButton {
            icon.name: "go-next"
            onClicked: root.step(1)
            QQC2.ToolTip.text: root.mode === "week" ? i18n("Next week (→)")
                               : root.mode === "month" ? i18n("Next month (→)") : i18n("Next day (→)")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        KanteToolButton {
            text: i18n("Today")
            enabled: !root.onToday
            onClicked: root.step(0)
            QQC2.ToolTip.text: i18n("Go to today (H)")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        KanteToolButton {
            visible: root.mode !== "day"
            icon.name: "view-calendar-week"
            checkable: true
            checked: root.weekend
            onClicked: root.controller.selectAgendaWeekend(!root.weekend)
            QQC2.ToolTip.text: root.weekend ? i18n("Hide weekend") : i18n("Show weekend")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        KanteToolButton {
            id: pickerBtn
            icon.name: "view-calendar-day"
            onClicked: datePicker.open()
            QQC2.ToolTip.text: i18n("Pick date")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        KanteToolButton {
            icon.name: "text-calendar"
            onClicked: calMenu.popup()
            QQC2.ToolTip.text: i18n("Choose calendars")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    // ── Calendar chooser menu ─────────────────────────────────────
    QQC2.Menu {
        id: calMenu
        KantePopupSkin { popup: calMenu }
        Instantiator {
            model: controller ? controller.eventCalendars : []
            delegate: QQC2.MenuItem {
                required property var modelData
                text: modelData.name
                checkable: true
                checked: modelData.enabled
                onToggled: {
                    if (checked !== modelData.enabled) {
                        controller.toggleBusyCalendar(modelData.id)
                    }
                }
            }
            onObjectAdded: calMenu.insertItem(index, object)
            onObjectRemoved: calMenu.removeItem(object)
        }
    }

    // ── Date picker popup ─────────────────────────────────────────
    // For the screenshot runner (plan key picker=1).
    function openDatePicker() {
        datePicker.open()
    }
    function datePickerGeometry() {
        var b = pickerBtn.mapToItem(root, 0, 0)
        return "opened=" + datePicker.opened + " popup=" + Math.round(datePicker.x) + "," + Math.round(datePicker.y)
                + " " + Math.round(datePicker.width) + "x" + Math.round(datePicker.height)
                + " button=" + Math.round(b.x) + "," + Math.round(b.y) + " " + Math.round(pickerBtn.width) + "x" + Math.round(pickerBtn.height)
                + " view=" + Math.round(root.width) + "x" + Math.round(root.height)
    }
    function openTaskGhost(minute) {
        if (modeLoader.item && modeLoader.item.openGhostAt) {
            modeLoader.item.openGhostAt(minute)
        }
    }
    function closeDatePicker() {
        datePicker.close()
    }
    QQC2.Popup {
        id: datePicker
        KantePopupSkin { popup: datePicker }
        // Placed when it opens: mapToItem is no binding dependency, so a bound x/y kept the
        // button's position from before layout (top left). Centred under the icon, above it
        // only when there is no room below.
        function place() {
            var p = pickerBtn.mapToItem(root, 0, 0)
            x = Math.max(0, Math.min(p.x + (pickerBtn.width - width) / 2, root.width - width))
            var below = p.y + pickerBtn.height + Design.spaceTiny
            var above = p.y - height - Design.spaceTiny
            y = (below + height <= root.height || above < 0) ? below : above
        }
        width: calGrid.implicitWidth + leftPadding + rightPadding
        height: calGrid.implicitHeight + topPadding + bottomPadding
        padding: Design.spaceSmall
        modal: true
        focus: true
        popupType: QQC2.Popup.Item
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        onAboutToShow: {
            calGrid.resetToSelected()
            place()
        }
        // The grid settles its size after opening (month header, six rows).
        onWidthChanged: if (visible) place()
        onHeightChanged: if (visible) place()
        contentItem: CalendarGrid {
            id: calGrid
            selectedDate: root.selectedDay
            onDateSelected: function(date) {
                root.jumpTo(date)
                datePicker.close()
            }
        }
    }

    // ── The view ──────────────────────────────────────────────────
    Item {
        id: stage
        Layout.fillWidth: true
        Layout.fillHeight: true
        property bool zoomIn: false

        ParallelAnimation {
            id: zoom
            NumberAnimation { target: stage; property: "scale"; from: stage.zoomIn ? 1.04 : 0.96; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "opacity"; from: 0.3; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }

        Loader {
            id: modeLoader
            anchors.fill: parent
            sourceComponent: root.mode === "week" ? weekView : root.mode === "month" ? monthView : dayView
        }
        // Over the views, passive: the press still reaches what is under it.
        Item {
            id: focusTaker
            anchors.fill: parent
            z: 1000
            TapHandler {
                gesturePolicy: TapHandler.DragThreshold
                onPressedChanged: {
                    if (pressed && !root.ownsKeys) {
                        root.forceActiveFocus()
                    }
                }
            }
        }
    }

    Component {
        id: dayView
        AgendaDayView {
            controller: root.controller
            dragHost: root.dragHost
            interactionsSuspended: root.interactionsSuspended
            targetDay: root.selectedDay
            listStart: root.listStart
            revision: root.revision
            onPickTarget: function(day) { root.selectedDay = day }
            onJump: function(day) { root.jumpTo(day) }
        }
    }
    Component {
        id: weekView
        AgendaWeekView {
            controller: root.controller
            dragHost: root.dragHost
            interactionsSuspended: root.interactionsSuspended
            day: root.selectedDay
            weekend: root.weekend
            revision: root.revision
            onOpenDay: function(day) { root.go("day", day) }
        }
    }
    Component {
        id: monthView
        AgendaMonthView {
            controller: root.controller
            dragHost: root.dragHost
            interactionsSuspended: root.interactionsSuspended
            day: root.selectedDay
            weekend: root.weekend
            revision: root.revision
            onPickDay: function(day) { root.selectedDay = day }
            onOpenDay: function(day) { root.go("day", day) }
        }
    }
}
