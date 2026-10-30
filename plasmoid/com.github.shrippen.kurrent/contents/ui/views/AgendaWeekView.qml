import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../Kante"
import "../datetime.js" as DateTime

// The Agenda's week board: one column per day with its appointments and open tasks as dense
// cards, a load bar (appointments plus task lengths against the workday) and done tasks folded.
// Overdue tasks wait in a tray above the week; past days fold theirs like the done ones. Weekend columns
// are narrower. Drop a card on a day to move it there (its time stays).
ColumnLayout {
    id: view

    required property TaskController controller
    property Item dragHost: null
    property bool interactionsSuspended: false
    /** Any day of the shown week. */
    property date day: new Date()
    property bool weekend: true
    property int revision: 0
    /** A click on a day's name opens that day in the day view. */
    signal openDay(date day)

    spacing: Design.spaceSmall

    property bool trayOpen: true
    // Days whose done tasks are unfolded, by ISO date.
    property var shownDone: ({})
    // Past days whose overdue tasks are unfolded, by ISO date.
    property var shownLate: ({})

    function toggled(map, key) {
        var next = Object.assign({}, map)
        next[key] = !next[key]
        return next
    }
    // Day with the inline quick-add field open, ISO date or "".
    property string addingOn: ""

    function today() {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), now.getDate())
    }
    function monday(d) {
        var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        r.setDate(r.getDate() - ((r.getDay() + 6) % 7))
        return r
    }
    readonly property int workMinutes: controller ? controller.agendaWorkMinutes : 480

    function duration(minutes) {
        var h = Math.floor(minutes / 60)
        var m = minutes % 60
        if (h === 0) {
            return i18n("%1 min", m)
        }
        return m === 0 ? i18n("%1 h", h) : i18n("%1 h %2", h, DateTime.pad2(m))
    }

    readonly property var days: {
        var _rev = view.revision
        if (!controller) {
            return []
        }
        var all = controller.agendaDays(monday(day), 7)
        return weekend ? all : all.slice(0, 5)
    }
    readonly property var overdue: {
        var _rev = view.revision
        return controller ? controller.agendaOverdue() : []
    }

    // ── Overdue tray ─────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        visible: view.overdue.length > 0
        implicitHeight: trayCol.implicitHeight + Design.spaceSmall * 2
        radius: Design.radius
        color: KanteStyle.tint(KanteStyle.negativeTextColor, KanteStyle.washLevel)
        border.width: KanteStyle.borderWidth
        border.color: KanteStyle.tint(KanteStyle.negativeTextColor, KanteStyle.edgeLevel)

        ColumnLayout {
            id: trayCol
            anchors.fill: parent
            anchors.margins: Design.spaceSmall
            spacing: Design.spaceSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.spaceSmall
                KanteToolButton {
                    icon.name: view.trayOpen ? "arrow-down" : "arrow-right"
                    text: i18n("Overdue")
                    onClicked: view.trayOpen = !view.trayOpen
                    QQC2.ToolTip.text: view.trayOpen ? i18n("Fold") : i18n("Unfold")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                CountBadge {
                    text: String(view.overdue.length)
                    negative: true
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("drag onto a day")
                    color: KanteStyle.mutedTextColor
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight
                }
                KanteButton {
                    text: i18n("All to today")
                    onClicked: {
                        var ids = view.overdue.map(function(t) { return t.itemId })
                        view.controller.bulkRescheduleTasks(ids, "today")
                    }
                }
            }

            // One row of cards, as tall as the tallest; scrolls sideways.
            Flickable {
                id: trayFlick
                Layout.fillWidth: true
                Layout.preferredHeight: trayRow.height + (trayScroll.visible ? trayScroll.height : 0)
                visible: view.trayOpen
                clip: true
                contentWidth: trayRow.width
                contentHeight: trayRow.height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.horizontal: QQC2.ScrollBar { id: trayScroll }
                Row {
                    id: trayRow
                    spacing: Design.spaceSmall
                    Repeater {
                        id: trayCards
                        model: view.overdue
                        delegate: AgendaCard {
                            required property var modelData
                            width: Kirigami.Units.gridUnit * 11
                            height: trayRow.tallest
                            controller: view.controller
                            dragHost: view.dragHost
                            interactionsSuspended: view.interactionsSuspended
                            task: modelData
                            showDate: true
                        }
                    }
                    readonly property real tallest: {
                        var h = 0
                        for (var i = 0; i < trayCards.count; ++i) {
                            var card = trayCards.itemAt(i)
                            if (card) {
                                h = Math.max(h, card.implicitHeight)
                            }
                        }
                        return h
                    }
                }
            }
        }
    }

    // ── Columns ──────────────────────────────────────────────────────────
    Flickable {
        id: weekFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: Math.max(width, columns.implicitWidth)
        contentHeight: columns.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: weekScroll }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {}

        Row {
            id: columns
            readonly property real usable: weekFlick.width - (weekScroll.visible ? weekScroll.width : 0)
                                            - spacing * (view.days.length - 1)
            // Weekdays weigh 4, Saturday and Sunday 3; a weekday column is at least 8 grid
            // units wide, a narrow widget scrolls sideways.
            readonly property real unit: Math.max(usable / (view.weekend ? 26 : 20), Kirigami.Units.gridUnit * 2)
            spacing: Design.spaceTiny

            Repeater {
                model: view.days
                delegate: Rectangle {
                    id: column
                    required property var modelData
                    readonly property date date: modelData.date
                    readonly property string key: DateTime.isoDateKey(date)
                    readonly property bool isToday: key === DateTime.isoDateKey(view.today())
                    readonly property bool past: key < DateTime.isoDateKey(view.today())
                    readonly property bool weekendDay: date.getDay() === 0 || date.getDay() === 6
                    readonly property int openCount: modelData.open.length
                    readonly property bool full: modelData.load > view.workMinutes

                    width: columns.unit * (weekendDay ? 3 : 4)
                    height: Math.max(colBody.implicitHeight + Design.spaceSmall * 2, weekFlick.height)
                    radius: Design.radius
                    color: drop.containsDrag ? KanteStyle.selectionColor
                                             : (isToday ? KanteStyle.tint1Color : (weekendDay || past ? KanteStyle.sunkenColor : "transparent"))
                    border.width: isToday ? KanteStyle.borderWidth : 0
                    border.color: KanteStyle.accentColor

                    DropArea {
                        id: drop
                        anchors.fill: parent
                        keys: ["application/x-kurrent-task"]
                        onEntered: function(drag) {
                            drag.acceptProposedAction()
                            if (view.dragHost) {
                                view.dragHost.setDropHint(i18n("Move to %1", Qt.locale().toString(column.date, "dddd, d. MMMM")))
                            }
                        }
                        onExited: {
                            if (view.dragHost) {
                                view.dragHost.clearDropHint()
                            }
                        }
                        onDropped: function(event) {
                            var task = view.dragHost ? view.dragHost.draggingTask : null
                            if (task) {
                                view.controller.agendaShiftToDay(task.itemId, column.date)
                                event.acceptProposedAction()
                            }
                        }
                    }

                    ColumnLayout {
                        id: colBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Design.spaceSmall
                        spacing: Design.spaceTiny

                        // Header: weekday (opens the day), date, Today, add.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Design.spaceTiny
                            QQC2.Label {
                                text: Qt.locale().toString(column.date, "ddd").toUpperCase()
                                font.bold: true
                                color: column.isToday ? KanteStyle.accentTextColor : KanteStyle.textColor
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: !view.interactionsSuspended
                                    onClicked: view.openDay(column.date)
                                    QQC2.ToolTip.text: i18n("Open day")
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                                }
                            }
                            QQC2.Label {
                                text: Qt.locale().toString(column.date, "d.M.")
                                color: KanteStyle.mutedTextColor
                            }
                            QQC2.Label {
                                visible: column.isToday
                                text: i18n("Today")
                                color: KanteStyle.accentTextColor
                                font: Kirigami.Theme.smallFont
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: !column.isToday }
                            KanteToolButton {
                                visible: !column.past
                                icon.name: "list-add"
                                icon.width: Kirigami.Units.iconSizes.small
                                icon.height: Kirigami.Units.iconSizes.small
                                onClicked: view.addingOn = column.key
                                QQC2.ToolTip.text: i18n("Add task for this day")
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }
                        }

                        // Load: appointments plus task lengths against 8 hours.
                        RowLayout {
                            Layout.fillWidth: true
                            visible: !column.past
                            spacing: Design.spaceTiny
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: KanteStyle.meterHeight
                                radius: KanteStyle.meterRadius
                                color: KanteStyle.tint2Color
                                Rectangle {
                                    width: parent.width * Math.min(1, column.modelData.load / view.workMinutes)
                                    height: parent.height
                                    radius: KanteStyle.meterRadius
                                    color: column.full ? KanteStyle.warningColor : KanteStyle.accentColor
                                }
                            }
                            QQC2.Label {
                                text: i18n("%1 / %2", view.duration(column.modelData.load), view.duration(view.workMinutes))
                                color: column.full ? KanteStyle.warningColor : KanteStyle.mutedTextColor
                                font: Kirigami.Theme.smallFont
                            }
                            HoverHandler { id: loadHover; enabled: !view.interactionsSuspended }
                            QQC2.ToolTip.text: i18n("Appointments plus estimated task time, against a %1 workday (Settings → Views)", view.duration(view.workMinutes))
                            QQC2.ToolTip.visible: loadHover.hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }

                        TaskQuickAdd {
                            Layout.fillWidth: true
                            visible: view.addingOn === column.key
                            placeholderText: i18n("New task, Enter saves")
                            controller: view.controller
                            popupHost: view.dragHost
                            day: column.date
                            onVisibleChanged: {
                                if (visible) {
                                    text = ""
                                    forceActiveFocus()
                                }
                            }
                            onCreated: view.addingOn = ""
                            takesEscape: true
                            onEscaped: view.addingOn = ""
                            onFieldFocusChanged: {
                                if (!fieldFocus && !asking && text.trim() === "") {
                                    view.addingOn = ""
                                }
                            }
                        }

                        // Appointments.
                        Repeater {
                            model: column.modelData.events
                            delegate: AgendaEventRow {
                                required property var modelData
                                Layout.fillWidth: true
                                event: modelData
                                interactionsSuspended: view.interactionsSuspended
                            }
                        }

                        // Open tasks; on past days they are overdue, folded like the done ones
                        // (they also wait in the tray above).
                        Repeater {
                            model: column.past && !view.shownLate[column.key] ? [] : column.modelData.open
                            delegate: AgendaCard {
                                required property var modelData
                                Layout.fillWidth: true
                                controller: view.controller
                                dragHost: view.dragHost
                                interactionsSuspended: view.interactionsSuspended
                                task: modelData
                            }
                        }
                        KanteToolButton {
                            visible: column.past && column.openCount > 0
                            Layout.fillWidth: true
                            text: view.shownLate[column.key] ? i18n("Hide overdue")
                                                             : i18np("↑ %1 in Overdue", "↑ %1 in Overdue", column.openCount)
                            onClicked: view.shownLate = view.toggled(view.shownLate, column.key)
                        }

                        // Done tasks, folded.
                        Repeater {
                            model: view.shownDone[column.key] ? column.modelData.done : []
                            delegate: AgendaCard {
                                required property var modelData
                                Layout.fillWidth: true
                                controller: view.controller
                                dragHost: view.dragHost
                                interactionsSuspended: view.interactionsSuspended
                                task: modelData
                            }
                        }
                        KanteToolButton {
                            visible: column.modelData.done.length > 0
                            Layout.fillWidth: true
                            text: view.shownDone[column.key] ? i18n("Hide done")
                                                             : i18np("✓ %1 done", "✓ %1 done", column.modelData.done.length)
                            onClicked: view.shownDone = view.toggled(view.shownDone, column.key)
                        }

                        QQC2.Label {
                            visible: column.modelData.events.length === 0 && column.openCount === 0
                                     && column.modelData.done.length === 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Design.spaceMedium
                            text: i18n("free")
                            color: KanteStyle.mutedTextColor
                        }
                    }
                }
            }
        }
    }
}
