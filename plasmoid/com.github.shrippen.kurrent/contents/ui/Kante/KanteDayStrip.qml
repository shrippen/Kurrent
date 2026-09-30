import QtQuick
import QtQuick.Shapes
import "."

/**
 * One day as a bar: `segments` (a list of {from, to, kind, color}, hours as numbers, kind "work",
 * "dim" or "event") sit at their time on a sunken track, a 2 px cyan mark shows `now`
 * (hours, -1: none) and hour labels sit below. Yellow work, 60 % yellow dim, thin cyan events;
 * a segment's `color` (e.g. its project colour) replaces the colour of its kind.
 *
 * Optional (all hours, -1: none):
 *   sunrise, sunset   daylight: the track is warm between them (`KanteStyle.daylightColor`),
 *                     a sun mark sits above sunrise and a moon mark above sunset
 *   workFrom, workTo  work hours: a 4 px band under the track (`KanteStyle.workBandColor`)
 *
 *   ┌ ☼ ──────────────── ☾ ┐   sky lane (marks)
 *   ░░▓▓▓▓████▓▓▓▓▓▓▓▓▓▓░░░   track: night, daylight, segments
 *       ▬▬▬▬▬▬▬▬▬▬▬▬           work band
 *   00    06    12    18  24  ticks
 */
Item {
    id: strip

    property var segments: []
    property real spanFrom: 0
    property real spanTo: 24
    property real now: -1
    property real tickStep: 6
    property real sunrise: -1
    property real sunset: -1
    property real workFrom: -1
    property real workTo: -1
    readonly property real range: Math.max(1, spanTo - spanFrom)
    readonly property bool hasSky: sunrise >= 0 && sunset > sunrise
    readonly property bool hasWork: workFrom >= 0 && workTo > workFrom
    readonly property real skyHeight: hasSky ? KanteStyle.unit(16) : 0
    readonly property real workHeight: hasWork ? KanteStyle.unit(8) : 0

    function xOf(hours) { return (hours - spanFrom) / range * width }

    /** Width of the span [from, to] clipped to the strip. */
    function spanWidth(from, to) {
        return Math.max(0, xOf(Math.min(spanTo, to)) - xOf(Math.max(spanFrom, from)))
    }

    function toneOf(segment) {
        if (segment.color !== undefined && segment.color !== "") {
            return segment.color
        }
        return segment.kind === "event" ? KanteStyle.focusColor : KanteStyle.accentColor
    }

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: skyHeight + KanteStyle.unit(44) + workHeight + KanteStyle.unit(18)

    Rectangle { id: track; y: strip.skyHeight; width: parent.width; height: KanteStyle.unit(44); color: KanteStyle.sunkenColor }

    // Daylight: warm between sunrise and sunset, night stays sunken.
    Rectangle {
        visible: strip.hasSky
        x: strip.xOf(Math.max(strip.spanFrom, strip.sunrise))
        y: track.y
        width: strip.spanWidth(strip.sunrise, strip.sunset)
        height: track.height
        color: KanteStyle.daylightColor
    }

    Repeater {
        model: strip.segments
        delegate: Rectangle {
            required property var modelData
            readonly property bool event: modelData.kind === "event"
            x: strip.xOf(Math.max(strip.spanFrom, modelData.from))
            width: Math.max(1, strip.spanWidth(modelData.from, modelData.to))
            y: event ? track.y + track.height - height : track.y
            height: event ? KanteStyle.unit(12) : track.height
            color: strip.toneOf(modelData)
            opacity: modelData.kind === "dim" ? 0.6 : 1
        }
    }

    // Sun above sunrise, moon above sunset (icons: the only round shapes).
    Shape {
        id: sun
        visible: strip.hasSky
        readonly property real r: KanteStyle.unit(3)
        readonly property real ray: KanteStyle.unit(6)
        width: ray * 2
        height: ray * 2
        x: Math.max(0, Math.min(strip.width - width, strip.xOf(strip.sunrise) - width / 2))
        y: (strip.skyHeight - height) / 2 - KanteStyle.unit(1)
        antialiasing: true
        ShapePath {
            strokeColor: "transparent"
            fillColor: KanteStyle.sunColor
            PathAngleArc { centerX: sun.ray; centerY: sun.ray; radiusX: sun.r; radiusY: sun.r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: KanteStyle.sunColor
            strokeWidth: Math.max(1, KanteStyle.unit(1.5))
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathMultiline {
                paths: {
                    var out = []
                    for (var i = 0; i < 8; i++) {
                        var a = i * Math.PI / 4
                        var inner = sun.r + KanteStyle.unit(1.5)
                        out.push([Qt.point(sun.ray + Math.cos(a) * inner, sun.ray + Math.sin(a) * inner),
                                  Qt.point(sun.ray + Math.cos(a) * sun.ray, sun.ray + Math.sin(a) * sun.ray)])
                    }
                    return out
                }
            }
        }
    }
    Shape {
        id: moon
        visible: strip.hasSky
        readonly property real r: KanteStyle.unit(6)
        width: r * 2
        height: r * 2
        x: Math.max(0, Math.min(strip.width - width, strip.xOf(strip.sunset) - width / 2))
        y: (strip.skyHeight - height) / 2 - KanteStyle.unit(1)
        antialiasing: true
        // A crescent: the left half of a disc, less an arc that bulges the same way.
        ShapePath {
            strokeColor: "transparent"
            fillColor: KanteStyle.moonColor
            startX: moon.r
            startY: 0
            PathArc { x: moon.r; y: moon.r * 2; radiusX: moon.r; radiusY: moon.r; direction: PathArc.Counterclockwise }
            PathArc { x: moon.r; y: 0; radiusX: moon.r * 1.7; radiusY: moon.r * 1.7; direction: PathArc.Clockwise }
        }
    }

    Rectangle {
        visible: strip.hasWork
        x: strip.xOf(Math.max(strip.spanFrom, strip.workFrom))
        y: track.y + track.height + KanteStyle.unit(3)
        width: strip.spanWidth(strip.workFrom, strip.workTo)
        height: KanteStyle.unit(4)
        color: KanteStyle.workBandColor
    }

    Rectangle {
        visible: strip.now >= strip.spanFrom && strip.now <= strip.spanTo
        x: strip.xOf(strip.now) - 1
        y: track.y - KanteStyle.unit(4)
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
            y: track.y + track.height + strip.workHeight + KanteStyle.unit(4)
            text: String(Math.round(hours)).padStart(2, "0")
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.8, false)
        }
    }
}
