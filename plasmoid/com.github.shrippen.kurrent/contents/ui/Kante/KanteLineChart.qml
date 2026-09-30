import QtQuick
import QtQuick.Shapes
import "."

/**
 * Line chart in the data palette. `series` is a list of lists of numbers, every
 * line its own colour; each ends in a square mark. Miter joins, 2 px lines, 1 px grid.
 * `compact` drops the grid and the marks' room for a sparkline; `accentIndex` picks the colour of
 * a single line (default: the first data colour).
 * Hover (or `hoverIndex` set by the caller) shows a read-out: a rule at the nearest point,
 * a square mark per line and a box with `labels[i]` and the values; `readout: false` turns it off.
 */
Item {
    id: chart

    property var series: []
    property real minValue: 0
    /** Top of the scale; 0 = the largest value. */
    property real maxValue: 0
    property bool compact: false
    property int colorIndex: 0
    property real lineWidth: compact ? 1.6 : 2
    property bool readout: !compact
    /** Captions of the points, e.g. the days; optional. */
    property var labels: []
    property string unit: ""
    /** Index of the point under the pointer, -1 for none. */
    property int hoverIndex: -1

    readonly property real scaleTop: {
        if (maxValue > 0) {
            return maxValue
        }
        var m = minValue + 1
        for (var i = 0; i < series.length; i++) {
            for (var k = 0; k < series[i].length; k++) {
                m = Math.max(m, series[i][k])
            }
        }
        return m
    }
    readonly property real mark: KanteStyle.unit(compact ? 5 : 6)

    implicitWidth: KanteStyle.unit(compact ? 120 : 260)
    implicitHeight: KanteStyle.unit(compact ? 32 : 120)

    function pointsOf(values) {
        var pts = []
        var n = values.length
        var w = width - mark
        var h = height - mark
        for (var i = 0; i < n; i++) {
            var x = mark / 2 + (n > 1 ? i / (n - 1) * w : w / 2)
            var y = mark / 2 + h - (values[i] - minValue) / (scaleTop - minValue) * h
            pts.push(Qt.point(x, y))
        }
        return pts
    }

    Repeater {
        model: chart.compact ? 0 : 3
        delegate: Rectangle {
            required property int index
            width: chart.width
            height: 1
            y: chart.height - 1 - index * (chart.height - 1) / 3
            color: index === 0 ? KanteStyle.frameColor : KanteStyle.ruleColor
        }
    }

    Repeater {
        model: chart.series.length
        delegate: Item {
            id: line
            required property int index
            readonly property var pts: chart.pointsOf(chart.series[index])
            readonly property color tone: KanteStyle.dataColor(chart.series.length === 1 ? chart.colorIndex : index)
            anchors.fill: parent

            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeColor: line.tone
                    strokeWidth: chart.lineWidth
                    fillColor: "transparent"
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline { path: line.pts }
                }
            }
            Rectangle {
                visible: line.pts.length > 0
                width: chart.mark
                height: chart.mark
                color: line.tone
                x: line.pts.length > 0 ? line.pts[line.pts.length - 1].x - width / 2 : 0
                y: line.pts.length > 0 ? line.pts[line.pts.length - 1].y - height / 2 : 0
            }
        }
    }

    function nearest(px) {
        var n = 0
        for (var i = 0; i < series.length; i++) {
            n = Math.max(n, series[i].length)
        }
        if (n === 0) {
            return -1
        }
        if (n === 1) {
            return 0
        }
        var f = (px - mark / 2) / (width - mark) * (n - 1)
        return Math.max(0, Math.min(n - 1, Math.round(f)))
    }

    HoverHandler {
        id: hover
        enabled: chart.readout
        onPointChanged: chart.hoverIndex = hovered ? chart.nearest(point.position.x) : -1
        onHoveredChanged: if (!hovered) chart.hoverIndex = -1
    }

    // Read-out: rule, marks, box.
    Item {
        id: probe
        anchors.fill: parent
        visible: chart.readout && chart.hoverIndex >= 0
        readonly property real px: chart.pointsOf(chart.series.length > 0 ? chart.series[0] : []).length > chart.hoverIndex && chart.hoverIndex >= 0
            ? chart.pointsOf(chart.series[0])[chart.hoverIndex].x : 0

        Rectangle {
            x: probe.px
            width: 1
            height: parent.height
            color: KanteStyle.focusColor
        }
        Repeater {
            model: chart.series.length
            delegate: Rectangle {
                required property int index
                readonly property var values: chart.series[index]
                visible: chart.hoverIndex >= 0 && chart.hoverIndex < values.length
                width: chart.mark + 2
                height: width
                color: KanteStyle.cardColor
                border.width: 2
                border.color: KanteStyle.dataColor(chart.series.length === 1 ? chart.colorIndex : index)
                x: visible ? chart.pointsOf(values)[chart.hoverIndex].x - width / 2 : 0
                y: visible ? chart.pointsOf(values)[chart.hoverIndex].y - height / 2 : 0
            }
        }
        Rectangle {
            id: box
            readonly property bool flip: probe.px > chart.width / 2
            x: flip ? probe.px - width - KanteStyle.unit(8) : probe.px + KanteStyle.unit(8)
            y: KanteStyle.unit(4)
            width: col.implicitWidth + KanteStyle.unit(16)
            height: col.implicitHeight + KanteStyle.unit(10)
            color: Qt.alpha(KanteStyle.dialogColor, 0.92)
            border.width: 1
            border.color: KanteStyle.frameColor
            Column {
                id: col
                x: KanteStyle.unit(8)
                y: KanteStyle.unit(5)
                Text {
                    visible: chart.hoverIndex >= 0 && chart.hoverIndex < chart.labels.length
                    text: visible ? chart.labels[chart.hoverIndex] : ""
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
                }
                Repeater {
                    model: chart.series.length
                    delegate: Text {
                        required property int index
                        readonly property var values: chart.series[index]
                        visible: chart.hoverIndex >= 0 && chart.hoverIndex < values.length
                        text: visible ? values[chart.hoverIndex] + chart.unit : ""
                        color: KanteStyle.dataColor(chart.series.length === 1 ? chart.colorIndex : index)
                        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
                    }
                }
            }
        }
    }
}
