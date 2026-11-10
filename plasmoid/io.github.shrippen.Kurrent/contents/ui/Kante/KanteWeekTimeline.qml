import QtQuick
import "."

/**
 * A week of hours: one row per day, the day from `spanFrom` to `spanTo` (0–24 h) left to right,
 * every entry a block in its colour at its time. For time tracking: what was worked when.
 * `entries` is a list of {day (row, 0 = first), start, end (hours, e.g. 9.5), color, title};
 * entries past midnight are the caller's to split. Without `color` an entry takes
 * `KanteStyle.entityFallbackColor`. `totals` adds the day's sum at the right (h:mm),
 * `today` marks a row (yellow label), `now` (hours) a cyan rule in that row.
 * `entryClicked(index)` on a tap. Blocks are square; a gap of 1 px keeps neighbours apart.
 * Hover (on touch a tap, or `hoverIndex` set by the caller) frames the block cyan and shows a
 * read-out as in KanteBarChart: a square in the entry's colour, its title, the time span and the
 * duration; `readout: false` keeps only the frame.
 *
 *        00    06    12    18    24
 *   MO   ┊     ┊ ███ ██┊██   ┊     ┊  7:30
 *   DI   ┊     ┊  ████ ┊ ███ ┊     ┊  6:45
 */
Item {
    id: timeline

    property var entries: []
    property var dayNames: ["MO", "DI", "MI", "DO", "FR", "SA", "SO"]
    property real spanFrom: 0
    property real spanTo: 24
    property real tickStep: 6
    /** Row of today, -1 for none. */
    property int today: -1
    /** Hours of now in today's row, -1 for none. */
    property real now: -1
    property bool totals: true
    property real rowHeight: KanteStyle.unit(22)
    property bool readout: true
    /** Entry under the pointer (or tapped on touch), -1 for none. */
    property int hoverIndex: -1
    signal entryClicked(int index)

    readonly property real range: Math.max(1, spanTo - spanFrom)
    readonly property real gutter: KanteStyle.unit(34)
    readonly property real headHeight: KanteStyle.unit(18)
    readonly property real totalWidth: totals ? totalMetrics.width + KanteStyle.unit(12) : 0
    readonly property real trackWidth: Math.max(1, width - gutter - totalWidth)

    implicitWidth: KanteStyle.unit(480)
    implicitHeight: headHeight + dayNames.length * (rowHeight + KanteStyle.unit(3))

    function xOf(hours) {
        return gutter + (Math.max(spanFrom, Math.min(spanTo, hours)) - spanFrom) / range * trackWidth
    }
    function rowY(day) {
        return headHeight + day * (rowHeight + KanteStyle.unit(3))
    }
    /** 7.5 -> "7:30". */
    function hoursText(h) {
        var total = Math.round(h * 60)
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
    }
    /** Sum of the day's entries in hours. */
    function dayTotal(day) {
        var sum = 0
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].day === day) {
                sum += Math.max(0, entries[i].end - entries[i].start)
            }
        }
        return sum
    }

    TextMetrics {
        id: totalMetrics
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        text: "00:00"
    }

    // Hour heads.
    Repeater {
        model: Math.floor(timeline.range / timeline.tickStep) + 1
        delegate: Text {
            required property int index
            readonly property real hours: timeline.spanFrom + index * timeline.tickStep
            x: Math.min(timeline.gutter + timeline.trackWidth - width, Math.max(timeline.gutter, timeline.xOf(hours) - width / 2))
            height: timeline.headHeight
            verticalAlignment: Text.AlignVCenter
            text: String(Math.round(hours)).padStart(2, "0")
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.8, false)
        }
    }

    // Rows: label, sunken track, total.
    Repeater {
        model: timeline.dayNames
        delegate: Item {
            required property int index
            required property string modelData
            readonly property bool isToday: timeline.today === index
            y: timeline.rowY(index)
            width: timeline.width
            height: timeline.rowHeight

            Text {
                width: timeline.gutter - KanteStyle.unit(6)
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: parent.modelData
                color: parent.isToday ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, parent.isToday)
            }
            Rectangle {
                x: timeline.gutter
                width: timeline.trackWidth
                height: parent.height
                color: KanteStyle.sunkenColor
                border.width: parent.isToday ? 1 : 0
                border.color: KanteStyle.tint(KanteStyle.accentColor, 0.6)
            }
            Text {
                visible: timeline.totals
                x: timeline.width - width
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: timeline.hoursText(timeline.dayTotal(parent.index))
                color: parent.isToday ? KanteStyle.strongTextColor
                     : (timeline.dayTotal(parent.index) > 0 ? KanteStyle.textColor : KanteStyle.disabledTextColor)
                font: totalMetrics.font
            }
        }
    }

    // Hour rules over the tracks.
    Repeater {
        model: Math.max(0, Math.floor(timeline.range / timeline.tickStep) - 1)
        delegate: Rectangle {
            required property int index
            x: Math.round(timeline.xOf(timeline.spanFrom + (index + 1) * timeline.tickStep))
            y: timeline.headHeight
            width: 1
            height: timeline.height - timeline.headHeight
            color: KanteStyle.ruleColor
        }
    }

    // Entries.
    Repeater {
        model: timeline.entries.length
        delegate: Rectangle {
            id: block
            required property int index
            readonly property var entry: timeline.entries[index]
            readonly property bool hasColor: entry.color !== undefined && entry.color !== ""
            visible: entry.end > entry.start && entry.day >= 0 && entry.day < timeline.dayNames.length
                     && entry.end > timeline.spanFrom && entry.start < timeline.spanTo
            x: timeline.xOf(entry.start)
            y: timeline.rowY(entry.day) + KanteStyle.unit(3)
            width: Math.max(2, timeline.xOf(entry.end) - x - 1)
            height: timeline.rowHeight - KanteStyle.unit(6)
            color: hasColor ? entry.color : KanteStyle.entityFallbackColor

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        timeline.hoverIndex = block.index
                    } else if (timeline.hoverIndex === block.index) {
                        timeline.hoverIndex = -1
                    }
                }
            }
            TapHandler {
                onTapped: {
                    // Without a pointer that hovers (touch) a tap opens and closes the read-out.
                    if (!hover.hovered) {
                        timeline.hoverIndex = timeline.hoverIndex === block.index ? -1 : block.index
                    }
                    timeline.entryClicked(block.index)
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                visible: timeline.hoverIndex === block.index
                color: "transparent"
                border.width: 2
                border.color: KanteStyle.focusColor
            }
            Accessible.role: Accessible.Button
            Accessible.name: (block.entry.title || "") + " " + timeline.hoursText(block.entry.start) + "–" + timeline.hoursText(block.entry.end)
        }
    }

    Rectangle {
        visible: timeline.today >= 0 && timeline.now >= timeline.spanFrom && timeline.now <= timeline.spanTo
        x: timeline.xOf(timeline.now) - 1
        y: timeline.rowY(Math.max(0, timeline.today)) - KanteStyle.unit(2)
        width: 2
        height: timeline.rowHeight + KanteStyle.unit(4)
        color: KanteStyle.focusColor
    }

    // Read-out of the entry under the pointer: beside the block, below it in the upper rows.
    Rectangle {
        id: box
        readonly property var entry: timeline.hoverIndex >= 0 && timeline.hoverIndex < timeline.entries.length
                                     ? timeline.entries[timeline.hoverIndex] : null
        readonly property real blockX: entry ? timeline.xOf(entry.start) : 0
        readonly property real blockEnd: entry ? timeline.xOf(entry.end) : 0
        readonly property bool below: entry ? entry.day < timeline.dayNames.length / 2 : true
        visible: timeline.readout && entry !== null
        x: Math.max(0, Math.min(timeline.width - width, (blockX + blockEnd) / 2 - width / 2))
        y: entry ? (below ? timeline.rowY(entry.day) + timeline.rowHeight + KanteStyle.unit(2)
                          : timeline.rowY(entry.day) - height - KanteStyle.unit(2)) : 0
        z: 2
        width: lines.implicitWidth + KanteStyle.unit(16)
        height: lines.implicitHeight + KanteStyle.unit(10)
        color: Qt.alpha(KanteStyle.dialogColor, 0.92)
        border.width: 1
        border.color: KanteStyle.frameColor
        Column {
            id: lines
            x: KanteStyle.unit(8)
            y: KanteStyle.unit(5)
            Row {
                spacing: KanteStyle.unit(5)
                visible: !!(box.entry && box.entry.title)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: KanteStyle.unit(8)
                    height: width
                    color: box.entry && box.entry.color !== undefined && box.entry.color !== ""
                           ? box.entry.color : KanteStyle.entityFallbackColor
                }
                Text {
                    text: box.entry ? (box.entry.title || "") : ""
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
                }
            }
            Text {
                text: box.entry
                      ? timeline.hoursText(box.entry.start) + "–" + timeline.hoursText(box.entry.end)
                        + "  " + timeline.hoursText(Math.max(0, box.entry.end - box.entry.start))
                      : ""
                color: KanteStyle.textColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.9, false)
            }
        }
    }
}
