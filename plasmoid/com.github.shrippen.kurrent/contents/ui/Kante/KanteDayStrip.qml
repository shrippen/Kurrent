import QtQuick
import "."

/**
 * One day as a bar: `segments` (a list of {from, to, kind}, hours as numbers, kind "work",
 * "dim" or "event") sit at their time on a sunken track, a 2 px cyan mark shows `now`
 * (hours, -1: none) and hour labels sit below. Yellow work, 60 % yellow dim, thin cyan events.
 */
Item {
    id: strip

    property var segments: []
    property real spanFrom: 0
    property real spanTo: 24
    property real now: -1
    property real tickStep: 6
    readonly property real range: Math.max(1, spanTo - spanFrom)

    function xOf(hours) { return (hours - spanFrom) / range * width }

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: KanteStyle.unit(44) + KanteStyle.unit(18)

    Rectangle { id: track; width: parent.width; height: KanteStyle.unit(44); color: KanteStyle.sunkenColor }

    Repeater {
        model: strip.segments
        delegate: Rectangle {
            required property var modelData
            readonly property bool event: modelData.kind === "event"
            x: strip.xOf(Math.max(strip.spanFrom, modelData.from))
            width: Math.max(1, strip.xOf(Math.min(strip.spanTo, modelData.to)) - x)
            y: event ? track.height - height : 0
            height: event ? KanteStyle.unit(12) : track.height
            color: event ? KanteStyle.focusColor : KanteStyle.accentColor
            opacity: modelData.kind === "dim" ? 0.6 : 1
        }
    }

    Rectangle {
        visible: strip.now >= strip.spanFrom && strip.now <= strip.spanTo
        x: strip.xOf(strip.now) - 1
        y: -KanteStyle.unit(4)
        width: 2
        height: track.height + KanteStyle.unit(8)
        color: KanteStyle.focusColor
    }

    Repeater {
        model: Math.floor(strip.range / strip.tickStep) + 1
        delegate: Text {
            required property int index
            readonly property real hours: strip.spanFrom + index * strip.tickStep
            x: Math.min(strip.width - width, Math.max(0, strip.xOf(hours) - width / 2))
            y: track.height + KanteStyle.unit(4)
            text: String(Math.round(hours)).padStart(2, "0")
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.8, false)
        }
    }
}
