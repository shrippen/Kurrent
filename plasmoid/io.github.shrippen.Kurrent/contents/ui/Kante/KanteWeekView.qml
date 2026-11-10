import QtQuick
import "."

/**
 * A week as seven columns over a time axis, Monday first. `events` is a list of
 * {day (0 = Monday), start, end (hours, e.g. 9.5), title, kind} with kind "", "warn",
 * "info" or "ok"; every block has a 4 px bar on the left in its state colour. Today's column has a
 * yellow head. `eventClicked(index)` on a tap. Overlaps are the caller's to avoid.
 */
Item {
    id: week

    property var events: []
    property int firstHour: 8
    property int lastHour: 18
    /** 0 = Monday; -1 for none. */
    property int today: -1
    property var dayNames: ["MO", "DI", "MI", "DO", "FR", "SA", "SO"]
    property real hourHeight: KanteStyle.unit(34)
    signal eventClicked(int index)

    readonly property real gutter: KanteStyle.unit(34)
    readonly property real headHeight: KanteStyle.unit(24)
    readonly property real colWidth: (width - gutter) / 7

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: headHeight + (lastHour - firstHour) * hourHeight

    function toneOf(kind) {
        switch (kind) {
        case "warn": return KanteStyle.warningColor
        case "info": return KanteStyle.focusColor
        case "ok": return KanteStyle.positiveTextColor
        default: return KanteStyle.accentColor
        }
    }

    // Day heads.
    Repeater {
        model: week.dayNames
        delegate: Text {
            required property int index
            required property string modelData
            x: week.gutter + index * week.colWidth
            width: week.colWidth
            height: week.headHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData
            color: week.today === index ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, week.today === index)
        }
    }

    // Columns: weekend sunken, today framed.
    Repeater {
        model: 7
        delegate: Rectangle {
            required property int index
            x: week.gutter + index * week.colWidth + 1
            y: week.headHeight
            width: week.colWidth - 2
            height: week.height - week.headHeight
            color: index >= 5 ? KanteStyle.sunkenColor : KanteStyle.cardColor
            border.width: week.today === index ? 2 : 0
            border.color: KanteStyle.accentColor
        }
    }

    // Hour rules and labels.
    Repeater {
        model: week.lastHour - week.firstHour
        delegate: Item {
            required property int index
            y: week.headHeight + index * week.hourHeight
            width: week.width
            Rectangle {
                x: week.gutter
                width: week.width - week.gutter
                height: 1
                color: KanteStyle.ruleColor
            }
            Text {
                x: 0
                y: -height / 2
                width: week.gutter - KanteStyle.unit(6)
                horizontalAlignment: Text.AlignRight
                text: (week.firstHour + index) + ":00"
                color: KanteStyle.disabledTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.8, false)
            }
        }
    }

    // Events.
    Repeater {
        model: week.events.length
        delegate: Rectangle {
            id: block
            required property int index
            readonly property var ev: week.events[index]
            readonly property real from: Math.max(week.firstHour, ev.start)
            readonly property real to: Math.min(week.lastHour, ev.end)
            visible: to > from && ev.day >= 0 && ev.day < 7
            x: week.gutter + ev.day * week.colWidth + 3
            y: week.headHeight + (from - week.firstHour) * week.hourHeight + 1
            width: week.colWidth - 6
            height: Math.max(KanteStyle.unit(14), (to - from) * week.hourHeight - 2)
            color: Qt.tint(KanteStyle.cardColor, Qt.alpha(week.toneOf(ev.kind), 0.18))
            clip: true

            Rectangle {
                width: 4
                height: parent.height
                color: week.toneOf(block.ev.kind)
            }
            Text {
                x: KanteStyle.unit(9)
                y: KanteStyle.unit(2)
                width: parent.width - KanteStyle.unit(12)
                elide: Text.ElideRight
                text: block.ev.title
                color: KanteStyle.textColor
                font: KanteStyle.labelFont()
            }
            TapHandler { onTapped: week.eventClicked(block.index) }
            Accessible.role: Accessible.Button
            Accessible.name: block.ev.title
        }
    }
}
