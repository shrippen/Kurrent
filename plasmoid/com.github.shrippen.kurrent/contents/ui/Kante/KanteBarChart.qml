import QtQuick
import QtQuick.Shapes
import "."

/**
 * Bar chart in the data palette. `values` is a list of numbers (one series, colour
 * `series`) or of lists (stacked, one colour per part); `labels` sit under the bars.
 * `goal` draws a dashed yellow goal line (negative: none), `highlight` marks one bar
 * in the accent. No rounded bars, a 1 px grid, mono labels.
 * `stackColors` gives the parts of a stack their own colours (e.g. project colours; the
 * data palette where missing). `axis` labels the scale on the left at even steps;
 * `valueFormat` Hours shows durations as h:mm (values in hours, steps of whole or
 * quarter hours), or `formatter` (a function number -> string) formats every value.
 */
Item {
    id: chart

    enum ValueFormat {
        Number,
        Hours
    }

    property var values: []
    property var labels: []
    property real goal: -1
    property int series: 0
    property int highlight: -1
    /** Top of the scale; 0 = the largest value or goal. */
    property real maxValue: 0
    /** Colour of part k of every stack; the data palette where missing. */
    property var stackColors: []
    property bool axis: false
    property int valueFormat: KanteBarChart.ValueFormat.Number
    /** Optional function (number) -> string for the axis; overrides `valueFormat`. */
    property var formatter: null
    property string unit: ""

    /** Largest total (value or goal), before rounding to the axis steps. */
    readonly property real dataMax: {
        if (maxValue > 0) {
            return maxValue
        }
        var m = Math.max(goal, 0)
        for (var i = 0; i < values.length; i++) {
            var v = values[i]
            var total = 0
            if (Array.isArray(v)) {
                for (var k = 0; k < v.length; k++) {
                    total += v[k]
                }
            } else {
                total = v
            }
            m = Math.max(m, total)
        }
        return m > 0 ? m : 1
    }
    /** Distance between two axis labels: 1-2-5 steps, for hours ¼, ½, 1, 2, 4, 6, 8, 12, 24. */
    readonly property real axisStep: niceStep(dataMax / 4)
    /** Top of the scale: with an axis, rounded up to a whole step. */
    readonly property real scaleMax: axis && maxValue <= 0 ? Math.ceil(dataMax / axisStep - 1e-9) * axisStep : dataMax
    readonly property int gridLines: axis ? Math.round(scaleMax / axisStep) + 1 : 3
    readonly property real labelHeight: KanteStyle.unit(16)
    readonly property real plotHeight: height - labelHeight
    readonly property real padLeft: axis ? axisWidth.width + KanteStyle.unit(8) : 0
    readonly property real plotWidth: width - padLeft

    function niceStep(raw) {
        if (raw <= 0) {
            return 1
        }
        if (valueFormat === KanteBarChart.ValueFormat.Hours && formatter === null) {
            var hours = [0.25, 0.5, 1, 2, 4, 6, 8, 12, 24, 48, 168]
            for (var i = 0; i < hours.length; i++) {
                if (hours[i] >= raw) {
                    return hours[i]
                }
            }
            return Math.ceil(raw / 24) * 24
        }
        var p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10))
        var f = raw / p
        return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * p
    }

    /** A value as the axis shows it: 7.5 -> "7:30" in Hours, "7.5" + unit otherwise. */
    function format(v) {
        if (typeof formatter === "function") {
            return formatter(v)
        }
        if (valueFormat === KanteBarChart.ValueFormat.Hours) {
            var total = Math.round(v * 60)
            return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0") + unit
        }
        return Math.round(v * 100) / 100 + unit
    }

    function partColor(k) {
        if (stackColors && k < stackColors.length && stackColors[k] !== undefined) {
            return stackColors[k]
        }
        return KanteStyle.dataColor(k)
    }

    // Widest axis label, so the plot keeps room for it.
    TextMetrics {
        id: axisWidth
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
        text: chart.format(chart.scaleMax)
    }

    implicitWidth: KanteStyle.unit(260)
    implicitHeight: KanteStyle.unit(120)

    // Grid: base line and two more, or one per axis step.
    Repeater {
        model: chart.gridLines
        delegate: Rectangle {
            required property int index
            x: chart.padLeft
            width: chart.plotWidth
            height: 1
            y: chart.axis ? chart.plotHeight - index * chart.axisStep / chart.scaleMax * chart.plotHeight - (index === 0 ? 1 : 0)
                          : chart.plotHeight - index * chart.plotHeight / 3 - 1
            color: index === 0 ? KanteStyle.frameColor : KanteStyle.ruleColor
        }
    }
    Repeater {
        model: chart.axis ? chart.gridLines : 0
        delegate: Text {
            required property int index
            readonly property real lineY: chart.plotHeight - index * chart.axisStep / chart.scaleMax * chart.plotHeight
            x: chart.padLeft - width - KanteStyle.unit(6)
            y: Math.max(0, Math.min(chart.plotHeight - height / 2, lineY - height / 2))
            text: chart.format(index * chart.axisStep)
            color: KanteStyle.mutedTextColor
            font: axisWidth.font
        }
    }

    Row {
        x: chart.padLeft
        width: chart.plotWidth
        height: chart.height
        Repeater {
            model: chart.values.length
            delegate: Item {
                id: col
                required property int index
                readonly property var value: chart.values[index]
                readonly property bool stacked: Array.isArray(value)
                width: chart.plotWidth / Math.max(1, chart.values.length)
                height: chart.height

                Column {
                    id: stack
                    width: col.width * 0.55
                    x: (col.width - width) / 2
                    y: chart.plotHeight - height
                    height: {
                        var t = 0
                        if (col.stacked) {
                            for (var k = 0; k < col.value.length; k++) t += col.value[k]
                        } else {
                            t = col.value
                        }
                        return Math.max(0, t) / chart.scaleMax * chart.plotHeight
                    }
                    Behavior on height { NumberAnimation { duration: KanteStyle.durationSlow; easing.type: Easing.OutCubic } }
                    // A stacked column paints from the top; the first part is at the bottom.
                    Repeater {
                        model: col.stacked ? col.value.length : 1
                        delegate: Rectangle {
                            required property int index
                            readonly property real part: col.stacked ? col.value[col.value.length - 1 - index] : col.value
                            width: stack.width
                            height: chart.scaleMax > 0 ? Math.max(0, part) / chart.scaleMax * chart.plotHeight : 0
                            color: col.stacked ? chart.partColor(col.value.length - 1 - index)
                                : (col.index === chart.highlight ? KanteStyle.accentColor : KanteStyle.dataColor(chart.series))
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: chart.plotHeight + KanteStyle.unit(3)
                    text: chart.labels && chart.labels.length > col.index ? chart.labels[col.index] : ""
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
                }
            }
        }
    }

    // Goal line, dashed.
    Shape {
        visible: chart.goal >= 0
        anchors.fill: parent
        ShapePath {
            strokeColor: KanteStyle.accentColor
            strokeWidth: 1.5
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 3]
            fillColor: "transparent"
            startX: chart.padLeft
            startY: chart.plotHeight - chart.goal / chart.scaleMax * chart.plotHeight
            PathLine { x: chart.width; y: chart.plotHeight - chart.goal / chart.scaleMax * chart.plotHeight }
        }
    }
}
