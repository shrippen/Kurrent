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
 * `axis` labels the scale on the left (every quarter, in `unit`) and keeps room for it.
 * `thresholds` draw dashed horizontal lines (a limit, a target); `xStart`, `xEnd`, `xTitle` and
 * `yTitle` name the axes. The chart lays them out itself: it keeps a row below the plot for the
 * x labels and one above it for `yTitle`, so a caller needs no margins of its own.
 *
 *   yTitle (top left)
 *   ┌────────────────────────────┐
 * 8 │ - - - - - - - - - - - Limit│  threshold: dashed, `label` at the right end
 *   │      ╱╲    ╱■              │
 * 0 └────────────────────────────┘
 *   xStart       xTitle      xEnd
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
    property bool axis: false
    /** Captions of the points, e.g. the days; optional. */
    property var labels: []
    property string unit: ""
    /**
     * Horizontal reference lines: [{ value, color, series, label }]. `color` is the line's colour,
     * `series` (an index) takes that series' colour instead; neither: the accent colour, as the
     * goal line of `KanteBarChart`. `label` (optional) is written above the line at the right end, below it when there is no room above.
     * A line above the scale is not drawn; without `maxValue` the scale grows to hold it.
     */
    property var thresholds: []
    /** Caption at the left end of the x axis (e.g. the first day); optional. */
    property string xStart: ""
    /** Caption at the right end of the x axis; optional. */
    property string xEnd: ""
    /** Name of the x axis, centred under it; optional. */
    property string xTitle: ""
    /** Name of the y axis, above its labels at the left; optional. */
    property string yTitle: ""
    /** Index of the point under the pointer, -1 for none. */
    property int hoverIndex: -1

    readonly property real scaleTop: {
        if (maxValue > 0) {
            return maxValue
        }
        let m = minValue + 1
        for (let i = 0; i < series.length; i++) {
            for (let k = 0; k < series[i].length; k++) {
                m = Math.max(m, series[i][k])
            }
        }
        for (let t = 0; t < thresholds.length; t++) {
            m = Math.max(m, thresholds[t].value)
        }
        // A gap (NaN) in the values leaves the scale undefined.
        if (!axis || isNaN(m)) {
            return m
        }
        return minValue + 4 * KanteStyle.niceStep((m - minValue) / 4)
    }
    readonly property real mark: KanteStyle.unit(compact ? 5 : 6)
    /** Room for the axis labels on the left. */
    readonly property real padLeft: axis && !compact ? KanteStyle.unit(44) : 0
    readonly property real captionHeight: captionProbe.implicitHeight
    /** Room for the y title above the plot. */
    readonly property real padTop: yTitle !== "" && !compact ? captionHeight + KanteStyle.unit(4) : 0
    /** Room for the x captions and the x title below the plot. */
    readonly property real padBottom: compact ? 0
        : (xStart !== "" || xEnd !== "" ? captionHeight + KanteStyle.unit(4) : 0) + (xTitle !== "" ? captionHeight + KanteStyle.unit(2) : 0)
    readonly property real plotHeight: height - padTop - padBottom

    implicitWidth: KanteStyle.unit(compact ? 120 : 260)
    implicitHeight: KanteStyle.unit(compact ? 32 : 120)

    /** y of a value in the chart's coordinates. */
    function yOf(v) {
        return padTop + mark / 2 + (plotHeight - mark) - (v - minValue) / (scaleTop - minValue) * (plotHeight - mark)
    }

    function colorOfThreshold(t) {
        if (t.color !== undefined) {
            return t.color
        }
        return t.series !== undefined ? KanteStyle.dataColor(t.series) : KanteStyle.accentColor
    }

    Text {
        id: captionProbe
        visible: false
        text: "0"
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
    }

    function pointsOf(values) {
        const pts = []
        const n = values.length
        const w = width - padLeft - mark
        for (let i = 0; i < n; i++) {
            const x = padLeft + mark / 2 + (n > 1 ? i / (n - 1) * w : w / 2)
            pts.push(Qt.point(x, yOf(values[i])))
        }
        return pts
    }

    Repeater {
        model: chart.compact ? 0 : (chart.axis ? 5 : 3)
        delegate: Rectangle {
            required property int index
            x: chart.padLeft
            width: chart.width - chart.padLeft
            height: 1
            y: chart.padTop + chart.plotHeight - 1 - index * (chart.plotHeight - 1) / (chart.axis ? 4 : 3)
            color: index === 0 ? KanteStyle.frameColor : KanteStyle.ruleColor
        }
    }
    Repeater {
        model: chart.axis && !chart.compact ? 5 : 0
        delegate: Text {
            required property int index
            x: chart.padLeft - width - KanteStyle.unit(6)
            y: Math.max(chart.padTop, Math.min(chart.padTop + chart.plotHeight - height, chart.padTop + chart.plotHeight - 1 - index * (chart.plotHeight - 1) / 4 - height / 2))
            text: { const v = chart.minValue + index * (chart.scaleTop - chart.minValue) / 4; return Number(v).toLocaleString(Qt.locale(), 'f', (chart.scaleTop - chart.minValue) / 4 < 1 ? 1 : 0) + chart.unit }
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }

    // Axis captions: the y title above the labels, x start and end under the plot, the x title below them.
    Text {
        visible: chart.padTop > 0
        x: 0
        y: 0
        text: chart.yTitle
        color: KanteStyle.mutedTextColor
        font: captionProbe.font
    }
    Text {
        visible: chart.xStart !== "" && !chart.compact
        x: chart.padLeft
        y: chart.padTop + chart.plotHeight + KanteStyle.unit(4)
        text: chart.xStart
        color: KanteStyle.mutedTextColor
        font: captionProbe.font
    }
    Text {
        visible: chart.xEnd !== "" && !chart.compact
        x: chart.width - width
        y: chart.padTop + chart.plotHeight + KanteStyle.unit(4)
        text: chart.xEnd
        color: KanteStyle.mutedTextColor
        font: captionProbe.font
    }
    Text {
        visible: chart.xTitle !== "" && !chart.compact
        x: chart.padLeft + (chart.width - chart.padLeft - width) / 2
        y: chart.height - height
        text: chart.xTitle
        color: KanteStyle.mutedTextColor
        font: captionProbe.font
    }

    // Thresholds: dashed, under the series so a line stays readable where they meet.
    Repeater {
        model: chart.thresholds.length
        delegate: Item {
            id: limit
            required property int index
            readonly property var spec: chart.thresholds[index]
            readonly property real lineY: chart.yOf(spec.value)
            readonly property color tone: chart.colorOfThreshold(spec)
            objectName: "kanteThreshold"
            visible: spec.value >= chart.minValue && spec.value <= chart.scaleTop
            anchors.fill: parent

            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: limit.tone
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 3]
                    fillColor: "transparent"
                    startX: chart.padLeft
                    startY: limit.lineY
                    PathLine { x: chart.width; y: limit.lineY }
                }
            }
            Text {
                visible: text !== ""
                x: chart.width - width
                // Above the line; below it when the line is at the top and there is no room.
                y: limit.lineY - height - 1 >= 0 ? limit.lineY - height - 1 : Math.min(limit.lineY + 2, chart.height - height)
                text: limit.spec.label || ""
                color: KanteStyle.mutedTextColor
                font: captionProbe.font
            }
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
        let n = 0
        for (let i = 0; i < series.length; i++) {
            n = Math.max(n, series[i].length)
        }
        if (n === 0) {
            return -1
        }
        if (n === 1) {
            return 0
        }
        const f = (px - padLeft - mark / 2) / (width - padLeft - mark) * (n - 1)
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
            y: chart.padTop
            height: chart.plotHeight
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
            y: chart.padTop + KanteStyle.unit(4)
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
                    // Text colour for the value, a square in the series colour beside it.
                    delegate: Row {
                        required property int index
                        readonly property var values: chart.series[index]
                        visible: chart.hoverIndex >= 0 && chart.hoverIndex < values.length
                        spacing: KanteStyle.unit(5)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: KanteStyle.unit(8)
                            height: width
                            color: KanteStyle.dataColor(chart.series.length === 1 ? chart.colorIndex : parent.index)
                        }
                        Text {
                            text: parent.visible ? parent.values[chart.hoverIndex] + chart.unit : ""
                            color: KanteStyle.strongTextColor
                            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
                        }
                    }
                }
            }
        }
    }
}
