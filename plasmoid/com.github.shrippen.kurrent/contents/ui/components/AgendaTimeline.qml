import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import ".."
import "../Kante"
import "../datetime.js" as DateTime

// One day as an hour grid (07–22): appointments stay fixed, task blocks can be selected,
// resized at their edges (15-minute steps, up to the neighbours) and dragged; free gaps
// show in green. A task dropped on the grid lands in the next free stretch
// (TaskController::agendaPlaceTask). `day` is one entry of TaskController::agendaDays.
Item {
    id: grid

    required property TaskController controller
    required property var day
    property Item dragHost: null
    property bool interactionsSuspended: false
    property real px: Design.agendaMinutePx
    property bool showFree: true
    /** Minutes since midnight now; the Agenda ticks it, so the now line moves. */
    property int nowMinute: new Date().getHours() * 60 + new Date().getMinutes()
    /** Item id of the selected block; its edges get grips. */
    property var selectedItemId: -1
    signal blockClicked(var task)

    // The day's hours (AgendaLogic::gridRange: 07–22, wider for blocks outside), then the same
    // bounds as AgendaLogic (kWorkStart, kWorkEnd, kStep).
    readonly property int gridStart: day && day.gridStart !== undefined ? day.gridStart : 7 * 60
    readonly property int gridEnd: day && day.gridEnd !== undefined ? day.gridEnd : 22 * 60
    readonly property int workStart: 8 * 60
    readonly property int workEnd: 18 * 60
    readonly property int step: 15
    readonly property int gutter: Kirigami.Units.gridUnit * 2.5
    readonly property bool isToday: day && DateTime.isoDateKey(day.date) === DateTime.isoDateKey(new Date())

    implicitHeight: (gridEnd - gridStart) * px

    // Free gaps as of now: today they start at the next quarter hour, like AgendaLogic::planFrom
    // (kStep, kMinGap). Clipped here, so the minute tick needs no rebuild of the day.
    readonly property var freeNow: {
        var gaps = day && day.free ? day.free : []
        if (!isToday) {
            return gaps
        }
        var from = Math.ceil(nowMinute / step) * step
        var out = []
        for (var i = 0; i < gaps.length; ++i) {
            var start = Math.max(gaps[i].start, from)
            if (gaps[i].end - start >= 30) {
                out.push({ start: start, end: gaps[i].end })
            }
        }
        return out
    }

    function yOf(minute) {
        return (minute - gridStart) * px
    }
    function minuteAt(y) {
        return Math.round((gridStart + y / px) / step) * step
    }
    function hm(minute) {
        return DateTime.pad2(Math.floor(minute / 60)) + ":" + DateTime.pad2(minute % 60)
    }
    function duration(minutes) {
        var h = Math.floor(minutes / 60)
        var m = minutes % 60
        if (h === 0) {
            return i18n("%1 min", m)
        }
        return m === 0 ? i18n("%1 h", h) : i18n("%1 h %2", h, DateTime.pad2(m))
    }

    // Working hours, hour and half-hour lines.
    Rectangle {
        x: grid.gutter
        width: grid.width - grid.gutter
        y: grid.yOf(grid.workStart)
        height: (grid.workEnd - grid.workStart) * grid.px
        color: KanteStyle.tint1Color
        opacity: Design.agendaWorkHoursOpacity
    }
    Repeater {
        model: (grid.gridEnd - grid.gridStart) / 30 + 1
        delegate: Item {
            required property int index
            readonly property bool full: index % 2 === 0
            y: index * 30 * grid.px
            width: grid.width
            Rectangle {
                x: grid.gutter
                width: parent.width - grid.gutter
                height: Design.agendaHairline
                color: KanteStyle.ruleColor
                opacity: parent.full ? 1 : 0.4
            }
            QQC2.Label {
                visible: parent.full
                y: -height / 2
                width: grid.gutter - Design.spaceSmall
                horizontalAlignment: Text.AlignRight
                text: grid.hm(grid.gridStart + parent.index * 30)
                color: KanteStyle.mutedTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }

    // Free gaps of at least 30 minutes, from now (today) or 08:00.
    Repeater {
        model: grid.showFree && grid.day ? grid.freeNow : []
        delegate: Rectangle {
            required property var modelData
            x: grid.gutter + Design.spaceTiny
            width: grid.width - grid.gutter - Design.spaceTiny * 2
            y: grid.yOf(modelData.start) + 1
            height: (modelData.end - modelData.start) * grid.px - 2
            radius: Design.inputRadius
            color: KanteStyle.tint(KanteStyle.positiveTextColor, Design.agendaFreeFill)
            border.width: Design.agendaHairline
            border.color: KanteStyle.tint(KanteStyle.positiveTextColor, Design.agendaFreeEdge)
            QQC2.Label {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Design.spaceTiny
                visible: parent.height > height
                text: i18n("free %1–%2 · %3", grid.hm(modelData.start), grid.hm(modelData.end),
                            grid.duration(modelData.end - modelData.start))
                color: KanteStyle.positiveTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        anchors.leftMargin: grid.gutter
        keys: ["application/x-kurrent-task"]
        enabled: !!grid.dragHost
        property int minute: -1
        onEntered: function(drag) {
            drag.acceptProposedAction()
            minute = grid.minuteAt(drag.y)
            if (grid.dragHost) {
                grid.dragHost.setDropHint(i18n("Plan at %1 or the next free time", grid.hm(minute)))
            }
        }
        onPositionChanged: function(drag) {
            minute = grid.minuteAt(drag.y)
            if (grid.dragHost) {
                grid.dragHost.setDropHint(i18n("Plan at %1 or the next free time", grid.hm(minute)))
            }
        }
        onExited: {
            minute = -1
            if (grid.dragHost) {
                grid.dragHost.clearDropHint()
            }
        }
        onDropped: function(event) {
            var task = grid.dragHost ? grid.dragHost.draggingTask : null
            if (task) {
                grid.controller.agendaPlaceTask(task.itemId, grid.day.date, grid.minuteAt(event.y))
                event.acceptProposedAction()
            }
            minute = -1
        }
    }
    Rectangle {
        visible: drop.containsDrag && drop.minute >= 0
        x: grid.gutter
        width: grid.width - grid.gutter
        y: grid.yOf(drop.minute)
        height: Design.agendaMarkLine
        color: KanteStyle.accentColor
    }

    // Appointments and task blocks, overlapping ones side by side.
    Repeater {
        model: grid.day ? grid.day.items : []
        delegate: Rectangle {
            id: block
            required property var modelData
            readonly property bool isTask: modelData.kind === "task"
            readonly property bool selected: isTask && grid.selectedItemId === modelData.itemId
            readonly property real laneWidth: (grid.width - grid.gutter - Design.spaceTiny) / modelData.lanes
            // While resizing: the edges being dragged.
            property int liveStart: modelData.start
            property int liveEnd: modelData.end

            x: grid.gutter + Design.spaceTiny + modelData.lane * laneWidth
            width: laneWidth - Design.spaceTiny
            // Drawn inside the grid; the label keeps the real times (an evening shoot to 23:59).
            readonly property int shownStart: Math.max(liveStart, grid.gridStart)
            readonly property int shownEnd: Math.min(liveEnd, grid.gridEnd)
            visible: shownEnd > shownStart
            y: grid.yOf(shownStart)
            height: Math.max(Kirigami.Units.gridUnit, (shownEnd - shownStart) * grid.px - 2)
            z: selected ? 3 : 2
            radius: Design.inputRadius
            clip: true
            color: isTask ? KanteStyle.tint(Design.colorForKey(String(modelData.collectionId)), Design.agendaBlockFill) : KanteStyle.sunkenColor
            border.width: selected ? 2 : 1
            border.color: selected ? KanteStyle.accentColor
                                   : (isTask ? Design.colorForKey(String(modelData.collectionId)) : KanteStyle.frameColor)
            opacity: isTask && modelData.completed ? 0.55 : 1

            QQC2.Label {
                anchors.fill: parent
                anchors.margins: Design.spaceTiny
                anchors.leftMargin: Design.spaceSmall
                text: grid.hm(block.liveStart) + "–" + grid.hm(block.liveEnd)
                      + (block.liveEnd - block.liveStart !== block.modelData.end - block.modelData.start
                         ? " · " + grid.duration(block.liveEnd - block.liveStart) : "")
                      + "  " + (block.modelData.summary || i18n("(Untitled)"))
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.strikeout: block.isTask && block.modelData.completed
                color: block.isTask ? KanteStyle.textColor : KanteStyle.mutedTextColor
            }

            QQC2.ToolTip.text: isTask ? "" : i18n("%1–%2 %3 · %4 (fixed)",
                                                   grid.hm(modelData.start), grid.hm(modelData.end),
                                                   modelData.summary, modelData.calendarName)
            QQC2.ToolTip.visible: !isTask && blockHover.hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: blockHover }

            TapHandler {
                enabled: block.isTask && !grid.interactionsSuspended
                onTapped: grid.blockClicked(block.modelData)
                onDoubleTapped: {
                    if (grid.dragHost && grid.dragHost.openFullEditor) {
                        grid.dragHost.openFullEditor(grid.controller.taskSnapshotById(block.modelData.itemId))
                    }
                }
            }

            DragHandler {
                target: null
                enabled: block.isTask && !block.modelData.completed && !!grid.dragHost && !grid.interactionsSuspended
                dragThreshold: Math.round(Kirigami.Units.gridUnit * 0.6)
                onActiveChanged: {
                    if (active) {
                        grid.dragHost.beginTaskDrag({
                            "itemId": block.modelData.itemId,
                            "uid": block.modelData.uid,
                            "summary": block.modelData.summary || "",
                            "parentUid": block.modelData.parentUid || "",
                            "categories": block.modelData.categories || [],
                            "collectionId": block.modelData.collectionId,
                            "priority": block.modelData.priority
                        })
                        var g = block.mapToGlobal(centroid.position.x, centroid.position.y)
                        grid.dragHost.updateTaskDragPosition(g.x, g.y)
                    } else {
                        grid.dragHost.endTaskDrag()
                    }
                }
                onCentroidChanged: {
                    if (active) {
                        var g = block.mapToGlobal(centroid.position.x, centroid.position.y)
                        grid.dragHost.updateTaskDragPosition(g.x, g.y)
                    }
                }
            }

            // Grips at the top and bottom edge of the selected block.
            Repeater {
                model: block.selected && !block.modelData.completed ? ["top", "bottom"] : []
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool atTop: modelData === "top"
                    width: Kirigami.Units.gridUnit * 1.5
                    height: Design.spaceSmall
                    radius: height / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: atTop ? 0 : block.height - height
                    color: KanteStyle.accentColor

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Design.spaceTiny
                        cursorShape: Qt.SizeVerCursor
                        preventStealing: true
                        property real startY: 0
                        onPressed: function(mouse) {
                            startY = mapToItem(grid, mouse.x, mouse.y).y
                        }
                        onPositionChanged: function(mouse) {
                            // Hovering reports positions too; only a drag moves the edge.
                            if (!pressed) {
                                return
                            }
                            var dy = mapToItem(grid, mouse.x, mouse.y).y - startY
                            var delta = Math.round(dy / grid.px / grid.step) * grid.step
                            var m = block.modelData
                            if (parent.atTop) {
                                block.liveStart = Math.min(m.end - grid.step, Math.max(m.lo, m.start + delta))
                            } else {
                                block.liveEnd = Math.max(m.start + grid.step, Math.min(m.hi, m.end + delta))
                            }
                        }
                        onReleased: {
                            var m = block.modelData
                            if (block.liveStart !== m.start || block.liveEnd !== m.end) {
                                grid.controller.agendaSetBlock(m.itemId, grid.day.date, block.liveStart, block.liveEnd)
                            }
                        }
                        QQC2.ToolTip.text: parent.atTop ? i18n("Drag to change the start") : i18n("Drag to change the end")
                        QQC2.ToolTip.visible: containsMouse && !pressed
                        hoverEnabled: true
                    }
                }
            }
        }
    }

    // Now line on today.
    Rectangle {
        readonly property int now: grid.nowMinute
        visible: grid.isToday && now >= grid.gridStart && now <= grid.gridEnd
        x: grid.gutter
        width: grid.width - grid.gutter
        y: grid.yOf(now)
        height: Design.agendaMarkLine
        z: 4
        color: KanteStyle.negativeTextColor
    }
}
