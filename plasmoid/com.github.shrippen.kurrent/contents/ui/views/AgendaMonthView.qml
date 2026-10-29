import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../Kante"
import "../datetime.js" as DateTime

// The Agenda's month: six weeks from the Monday before the 1st, each day with up to three
// entries and "+n more", tinted by how full it is. A click selects the day for the detail
// panel on the right (with quick add); the day number opens the day view. Drop a task on a
// day to move it there (its time stays).
RowLayout {
    id: view

    required property TaskController controller
    property Item dragHost: null
    property bool interactionsSuspended: false
    /** Selected day; its month is shown. */
    property date day: new Date()
    property bool weekend: true
    property int revision: 0
    signal pickDay(date day)
    signal openDay(date day)

    spacing: Design.spaceMedium

    readonly property int columns: weekend ? 7 : 5
    readonly property bool showDetail: width >= Kirigami.Units.gridUnit * 40

    function today() {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), now.getDate())
    }
    function hm(minute) {
        return DateTime.pad2(Math.floor(minute / 60)) + ":" + DateTime.pad2(minute % 60)
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
        return Qt.locale().toString(d, "dddd")
    }

    readonly property var cells: {
        var _rev = view.revision
        return controller ? controller.agendaMonth(day, weekend) : []
    }
    readonly property var selected: {
        var key = DateTime.isoDateKey(day)
        for (var i = 0; i < cells.length; ++i) {
            if (DateTime.isoDateKey(cells[i].date) === key) {
                return cells[i]
            }
        }
        return null
    }

    // Entries of a cell: appointments first, then tasks (open before done).
    function entriesOf(cell) {
        var out = []
        for (var i = 0; i < cell.events.length; ++i) {
            out.push({ event: true, data: cell.events[i] })
        }
        for (var j = 0; j < cell.open.length; ++j) {
            out.push({ event: false, data: cell.open[j] })
        }
        for (var k = 0; k < cell.done.length; ++k) {
            out.push({ event: false, data: cell.done[k] })
        }
        return out
    }

    // ── Grid ─────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Design.spaceTiny

        Row {
            Layout.fillWidth: true
            Repeater {
                model: view.columns
                delegate: QQC2.Label {
                    required property int index
                    width: grid.width / view.columns
                    horizontalAlignment: Text.AlignHCenter
                    // 2 November 2026 is a Monday.
                    text: Qt.locale().toString(new Date(2026, 10, 2 + index), "ddd").toUpperCase()
                    color: KanteStyle.mutedTextColor
                    font: Kirigami.Theme.smallFont
                }
            }
        }

        GridLayout {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: view.columns
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: view.cells
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    readonly property string key: DateTime.isoDateKey(modelData.date)
                    readonly property bool isToday: key === DateTime.isoDateKey(view.today())
                    readonly property bool isSelected: key === DateTime.isoDateKey(view.day)
                    readonly property bool past: key < DateTime.isoDateKey(view.today())
                    readonly property var entries: view.entriesOf(modelData)
                    readonly property int shown: Math.max(0, Math.min(entries.length,
                                                  Math.floor((height - dayRow.height - Design.spaceTiny * 2) / entryHeight) - (entries.length > 3 ? 1 : 0), 3))
                    readonly property real entryHeight: Kirigami.Units.gridUnit * 1.1

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 3
                    radius: Design.inputRadius
                    clip: true
                    color: drop.containsDrag ? KanteStyle.selectionColor
                                             : (modelData.tint > 0 ? KanteStyle.tint(KanteStyle.accentColor, modelData.tint)
                                                                   : (modelData.inMonth ? KanteStyle.cardColor : "transparent"))
                    opacity: modelData.inMonth ? 1 : 0.55
                    border.width: isSelected || isToday ? (isSelected ? 2 : 1) : 0
                    border.color: isSelected ? KanteStyle.focusColor : KanteStyle.accentColor

                    TapHandler {
                        enabled: !view.interactionsSuspended
                        onTapped: view.pickDay(cell.modelData.date)
                        onDoubleTapped: view.openDay(cell.modelData.date)
                    }

                    DropArea {
                        id: drop
                        anchors.fill: parent
                        keys: ["application/x-kurrent-task"]
                        onEntered: function(drag) {
                            drag.acceptProposedAction()
                            if (view.dragHost) {
                                view.dragHost.setDropHint(i18n("Move to %1", Qt.locale().toString(cell.modelData.date, "dddd, d. MMMM")))
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
                                view.controller.agendaShiftToDay(task.itemId, cell.modelData.date)
                                event.acceptProposedAction()
                            }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: Design.spaceTiny
                        spacing: 0

                        RowLayout {
                            id: dayRow
                            width: parent.width
                            QQC2.Label {
                                text: cell.modelData.date.getDate()
                                font.bold: cell.isToday
                                color: cell.isToday ? KanteStyle.accentTextColor : KanteStyle.textColor
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -Design.spaceTiny
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: view.openDay(cell.modelData.date)
                                    QQC2.ToolTip.text: i18n("Open day")
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                                }
                            }
                            Item { Layout.fillWidth: true }
                            QQC2.Label {
                                visible: cell.modelData.count > 0
                                text: cell.modelData.count
                                color: KanteStyle.mutedTextColor
                                font: Kirigami.Theme.smallFont
                            }
                        }

                        Repeater {
                            model: cell.entries.slice(0, cell.shown)
                            delegate: RowLayout {
                                id: entry
                                required property var modelData
                                readonly property bool late: !modelData.event && !modelData.data.completed && cell.past
                                width: parent.width
                                height: cell.entryHeight
                                spacing: Design.spaceTiny
                                Rectangle {
                                    visible: !entry.modelData.event
                                    implicitWidth: 6
                                    implicitHeight: 6
                                    color: Design.colorForKey(String(entry.modelData.data.collectionId))
                                }
                                QQC2.Label {
                                    visible: entry.modelData.event && !entry.modelData.data.allDay
                                    text: entry.modelData.event && !entry.modelData.data.allDay ? view.hm(entry.modelData.data.start) : ""
                                    color: KanteStyle.mutedTextColor
                                    font: Kirigami.Theme.smallFont
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: entry.modelData.data.summary || i18n("(Untitled)")
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.strikeout: !entry.modelData.event && entry.modelData.data.completed
                                    color: entry.late ? KanteStyle.negativeTextColor
                                                      : (entry.modelData.event ? KanteStyle.mutedTextColor : KanteStyle.textColor)
                                }
                                AgendaTaskDrag {
                                    task: entry.modelData.event ? null : entry.modelData.data
                                    dragHost: view.dragHost
                                    suspended: view.interactionsSuspended
                                }
                            }
                        }
                        QQC2.Label {
                            visible: cell.entries.length > cell.shown
                            text: i18np("+%1 more", "+%1 more", cell.entries.length - cell.shown)
                            color: KanteStyle.mutedTextColor
                            font: Kirigami.Theme.smallFont
                        }
                    }
                }
            }
        }

        // Legend for the tint and the red entries.
        RowLayout {
            Layout.fillWidth: true
            spacing: Design.spaceMedium
            Row {
                spacing: Design.spaceTiny
                Repeater {
                    model: [1, 3, 5]
                    delegate: Rectangle {
                        required property int modelData
                        width: Kirigami.Units.gridUnit * 0.7
                        height: width
                        color: KanteStyle.tint(KanteStyle.accentColor, view.controller ? view.controller.agendaTint(modelData) : 0)
                    }
                }
            }
            QQC2.Label {
                text: i18n("Tint: how full the day is")
                color: KanteStyle.mutedTextColor
                font: Kirigami.Theme.smallFont
            }
            QQC2.Label {
                text: i18n("Red: overdue")
                color: KanteStyle.negativeTextColor
                font: Kirigami.Theme.smallFont
            }
            Item { Layout.fillWidth: true }
        }
    }

    // ── Day detail ───────────────────────────────────────────────────────
    ColumnLayout {
        visible: view.showDetail && !!view.selected
        Layout.preferredWidth: Kirigami.Units.gridUnit * 15
        Layout.maximumWidth: Kirigami.Units.gridUnit * 15
        Layout.fillHeight: true
        spacing: Design.spaceSmall

        QQC2.Label {
            text: view.relDay(view.day)
            color: KanteStyle.mutedTextColor
            font: Kirigami.Theme.smallFont
        }
        Kirigami.Heading {
            Layout.fillWidth: true
            level: 4
            wrapMode: Text.Wrap
            text: Qt.locale().toString(view.day, "dddd, d. MMMM yyyy")
        }
        KanteButton {
            text: i18n("Open day →")
            onClicked: view.openDay(view.day)
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: Design.spaceTiny

                Repeater {
                    model: view.selected ? view.selected.events : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Design.spaceSmall
                        QQC2.Label {
                            text: modelData.allDay ? i18n("All day") : view.hm(modelData.start) + "–" + view.hm(modelData.end)
                            color: KanteStyle.mutedTextColor
                            font: Kirigami.Theme.smallFont
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.summary
                            wrapMode: Text.Wrap
                            color: KanteStyle.mutedTextColor
                        }
                    }
                }
                Repeater {
                    model: view.selected ? view.selected.open.concat(view.selected.done) : []
                    delegate: AgendaTaskRow {
                        required property var modelData
                        Layout.fillWidth: true
                        controller: view.controller
                        dragHost: view.dragHost
                        interactionsSuspended: view.interactionsSuspended
                        task: modelData
                        meta: modelData.start !== undefined ? view.hm(modelData.start) + "–" + view.hm(modelData.end) : ""
                    }
                }
                QQC2.Label {
                    visible: !!view.selected && view.selected.count === 0 && view.selected.done.length === 0
                    text: i18n("Nothing planned.")
                    color: KanteStyle.mutedTextColor
                }
            }
        }

        TaskQuickAdd {
            id: quickAdd
            Layout.fillWidth: true
            placeholderText: i18n("Task for this day, Enter saves")
            controller: view.controller
            popupHost: view.dragHost
            day: view.day
        }
    }
}
