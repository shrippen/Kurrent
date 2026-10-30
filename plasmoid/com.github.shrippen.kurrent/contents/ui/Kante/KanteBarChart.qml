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
 * Hover (or `hoverIndex` / `hoverPart` set by the caller) shows a read-out as in
 * KanteLineChart: the bar on a tint band, the part under the pointer framed cyan, and a box
 * with `labels[i]`, every part (`partNames[k]`, its value) and the total; `readout: false`
 * turns it off.
 * `compact` is a bar sparkline: no grid but the base line, no labels under the bars (they
 * still title the read-out, which then opens above the chart), thinner gaps, small size.
 * Histograms (1.23): `edgeLabels` label the column edges (values.length + 1 labels, ""
 * skips one) instead of the bar centres, `edgeUnit` names their unit at the right end,
 * `markers` draw vertical lines [{at, label, dashed}] where `at` counts columns from the
 * left edge (2.5 = the middle of the third bar), `barFill` is the share of a column the
 * bar fills (1 = bars touch), `wholeSteps` keeps the axis on whole numbers (counts).
 * KanteTimingHistogram is configured this way.
 * `ranges` (1.44) shade spans behind the bars [{from, to, label}], in columns as `markers`
 * (e.g. a target band): a tint, dashed edges and the label at the top, not colour alone.
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
    /** Title of the value axis, written upwards left of its labels (1.49; e.g. "Noten"). */
    property string axisTitle: ""
    property int valueFormat: KanteBarChart.ValueFormat.Number
    /** Optional function (number) -> string for the axis; overrides `valueFormat`. */
    property var formatter: null
    property string unit: ""
    property bool readout: true
    /** Bar under the pointer, -1 for none. */
    property int hoverIndex: -1
    /** Part of that stack under the pointer (0 = bottom), -1 for none. */
    property int hoverPart: -1
    /** Names of the stack parts in the read-out (e.g. the projects); optional. */
    property var partNames: []
    property bool compact: false
    /** Labels at the column edges (histogram bins); replaces the labels under the bars. */
    property var edgeLabels: []
    /** Unit of the edge labels, at the right end of their row. */
    property string edgeUnit: ""
    /** Vertical lines [{at, label, dashed}], `at` in columns from the left edge. */
    property var markers: []
    property var ranges: []
    /** Axis steps on whole numbers only (counts): 1, 2, 5, 10, … */
    property bool wholeSteps: false
    /** Share of a column the bar fills. */
    property real barFill: compact ? 0.72 : 0.55

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
    readonly property real labelHeight: compact ? 0 : KanteStyle.unit(16)
    readonly property real plotHeight: height - labelHeight
    readonly property real padLeft: axis ? axisWidth.width + KanteStyle.unit(8)
                                           + (axisTitleText.visible ? axisTitleText.height + KanteStyle.unit(4) : 0) : 0
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
        if (wholeSteps) {
            return Math.max(1, (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p)
        }
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

    function partsOf(i) {
        var v = i >= 0 && i < values.length ? values[i] : []
        return Array.isArray(v) ? v : [v]
    }
    function totalOf(i) {
        return partsOf(i).reduce(function (a, b) { return a + b }, 0)
    }
    readonly property real columnWidth: plotWidth / Math.max(1, values.length)
    /** Bar at x, or -1 outside the plot. */
    function barAt(px) {
        var i = Math.floor((px - padLeft) / columnWidth)
        return px < padLeft || i >= values.length ? -1 : i
    }
    /** Part of bar i at y (0 = bottom), or -1 above the bar. */
    function partAt(i, py) {
        var parts = partsOf(i)
        var v = (plotHeight - py) / plotHeight * scaleMax
        var sum = 0
        for (var k = 0; k < parts.length; k++) {
            sum += Math.max(0, parts[k])
            if (v >= 0 && v <= sum) {
                return k
            }
        }
        return -1
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

    // Axis title, turned upwards; rotation keeps the centre, so x and y place the turned box
    // at the left edge, centred on the plot.
    Text {
        id: axisTitleText
        objectName: "kanteAxisTitle"
        visible: chart.axis && !chart.compact && chart.axisTitle !== ""
        width: Math.min(implicitWidth, chart.plotHeight)
        elide: Text.ElideRight
        text: chart.axisTitle
        color: KanteStyle.mutedTextColor
        font: axisWidth.font
        rotation: -90
        x: (height - width) / 2
        y: (chart.plotHeight - height) / 2
    }

    implicitWidth: KanteStyle.unit(compact ? 120 : 260)
    implicitHeight: KanteStyle.unit(compact ? 32 : 120)

    // Grid: base line and two more, or one per axis step.
    Repeater {
        model: chart.compact ? 1 : chart.gridLines
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

    // Ranges behind the bars: tint and dashed edges; their labels follow the markers'.
    Repeater {
        model: chart.ranges
        delegate: Item {
            id: range
            required property var modelData
            required property int index
            readonly property real from: Math.max(0, Math.min(chart.values.length, Number(modelData.from)))
            readonly property real to: Math.max(0, Math.min(chart.values.length, Number(modelData.to)))
            objectName: "kanteRange"
            visible: !isNaN(from) && !isNaN(to) && to > from
            x: chart.padLeft + from * chart.columnWidth
            width: (to - from) * chart.columnWidth
            height: chart.plotHeight
            Rectangle {
                anchors.fill: parent
                color: KanteStyle.tint1Color
            }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: KanteStyle.mutedTextColor
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 3]
                    fillColor: "transparent"
                    startX: 0.5; startY: 0
                    PathLine { x: 0.5; y: chart.plotHeight }
                    PathMove { x: range.width - 0.5; y: 0 }
                    PathLine { x: range.width - 0.5; y: chart.plotHeight }
                }
            }
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
                width: chart.columnWidth
                height: chart.height

                // Read-out band behind the bar under the pointer.
                Rectangle {
                    visible: chart.readout && chart.hoverIndex === col.index
                    width: parent.width
                    height: chart.plotHeight
                    color: KanteStyle.tint1Color
                }
                Column {
                    id: stack
                    width: col.width * Math.max(0.05, Math.min(1, chart.barFill))
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
                            readonly property int partIndex: col.stacked ? col.value.length - 1 - index : 0
                            color: col.stacked ? chart.partColor(partIndex)
                                : (col.index === chart.highlight ? KanteStyle.accentColor : KanteStyle.dataColor(chart.series))
                            border.width: chart.readout && chart.hoverIndex === col.index && chart.hoverPart === partIndex ? 2 : 0
                            border.color: KanteStyle.focusColor
                        }
                    }
                }
                Text {
                    visible: !chart.compact && !(chart.edgeLabels && chart.edgeLabels.length > 0)
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

    // Edge labels (histogram bins) with a tick each, and their unit at the right end.
    Repeater {
        model: !chart.compact && chart.edgeLabels ? chart.edgeLabels.length : 0
        delegate: Item {
            required property int index
            readonly property string label: String(chart.edgeLabels[index])
            visible: label !== ""
            x: chart.padLeft + index * chart.columnWidth
            y: chart.plotHeight
            Rectangle { x: 0; width: 1; height: KanteStyle.unit(3); color: KanteStyle.frameColor }
            Text {
                x: Math.max(-parent.x, Math.min(chart.width - parent.x - width - (chart.edgeUnit !== "" ? unitText.width + KanteStyle.unit(6) : 0), -width / 2))
                y: KanteStyle.unit(3)
                text: parent.label
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
            }
        }
    }
    Text {
        id: unitText
        visible: !chart.compact && chart.edgeUnit !== "" && chart.edgeLabels && chart.edgeLabels.length > 0
        x: chart.width - width
        y: chart.plotHeight + KanteStyle.unit(3)
        text: chart.edgeUnit
        color: KanteStyle.mutedTextColor
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, true)
    }

    // Markers: vertical lines with a label at the top (e.g. zero and mean of a histogram).
    Repeater {
        model: chart.markers
        delegate: Item {
            id: marker
            required property var modelData
            required property int index
            readonly property real mx: chart.padLeft + Number(modelData.at) * chart.columnWidth
            visible: !isNaN(mx) && Number(modelData.at) >= 0 && Number(modelData.at) <= chart.values.length
            x: Math.round(mx)
            width: 1
            height: chart.plotHeight
            z: 1
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: KanteStyle.strongTextColor
                    strokeWidth: Math.max(1.5, KanteStyle.unit(2))
                    strokeStyle: marker.modelData.dashed ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: [3, 2]
                    fillColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: 0; y: chart.plotHeight }
                }
            }
            Rectangle {
                visible: !!marker.modelData.label
                readonly property bool flip: marker.mx + width + KanteStyle.unit(4) > chart.width
                x: flip ? -width - KanteStyle.unit(3) : KanteStyle.unit(3)
                // One row per marker, so labels of close lines do not cover each other.
                y: marker.index * (height + KanteStyle.unit(2))
                width: markerText.implicitWidth + KanteStyle.unit(8)
                height: markerText.implicitHeight + KanteStyle.unit(2)
                color: Qt.alpha(KanteStyle.dialogColor, 0.85)
                Text {
                    id: markerText
                    anchors.centerIn: parent
                    text: marker.modelData.label || ""
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, true)
                }
            }
        }
    }

    // Range labels above the bars, one row each below the marker labels.
    Repeater {
        model: chart.ranges
        delegate: Rectangle {
            id: rangeLabel
            required property var modelData
            required property int index
            readonly property real from: Math.max(0, Math.min(chart.values.length, Number(modelData.from)))
            readonly property real to: Math.max(0, Math.min(chart.values.length, Number(modelData.to)))
            // Only with its band: a range clipped to nothing has no label either.
            objectName: "kanteRangeLabel"
            visible: !!modelData.label && !isNaN(from) && !isNaN(to) && to > from
            x: Math.min(chart.padLeft + from * chart.columnWidth + KanteStyle.unit(3), chart.width - width)
            y: (chart.markers.length + index) * (height + KanteStyle.unit(2))
            z: 1
            width: rangeText.implicitWidth + KanteStyle.unit(8)
            height: rangeText.implicitHeight + KanteStyle.unit(2)
            color: Qt.alpha(KanteStyle.dialogColor, 0.85)
            Text {
                id: rangeText
                anchors.centerIn: parent
                text: rangeLabel.modelData.label || ""
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, true)
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: chart.readout
        onPointChanged: {
            if (!hovered) {
                return
            }
            chart.hoverIndex = chart.barAt(point.position.x)
            chart.hoverPart = chart.hoverIndex >= 0 ? chart.partAt(chart.hoverIndex, point.position.y) : -1
        }
        onHoveredChanged: {
            if (!hovered) {
                chart.hoverIndex = -1
                chart.hoverPart = -1
            }
        }
    }

    // Read-out box: label, the parts (stacked: bottom part last, as drawn) and the total.
    Rectangle {
        id: box
        readonly property real cx: chart.padLeft + (chart.hoverIndex + 0.5) * chart.columnWidth
        readonly property var parts: chart.partsOf(chart.hoverIndex)
        readonly property bool stacked: chart.hoverIndex >= 0 && Array.isArray(chart.values[chart.hoverIndex])
        readonly property bool flip: cx > chart.width / 2
        visible: chart.readout && chart.hoverIndex >= 0 && chart.hoverIndex < chart.values.length
        x: flip ? Math.max(0, cx - chart.columnWidth * 0.3 - width - KanteStyle.unit(6))
                : Math.min(chart.width - width, cx + chart.columnWidth * 0.3 + KanteStyle.unit(6))
        y: chart.compact ? -height - KanteStyle.unit(4) : KanteStyle.unit(4)
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
            Text {
                visible: chart.hoverIndex >= 0 && chart.hoverIndex < chart.labels.length
                text: visible ? chart.labels[chart.hoverIndex] : ""
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
            }
            Repeater {
                model: box.visible ? box.parts.length : 0
                // The text keeps the text colour (a part colour can be unreadable on the box);
                // a square in the part's colour says which part a line is.
                delegate: Row {
                    required property int index
                    readonly property int part: box.parts.length - 1 - index
                    readonly property string name: chart.partNames && part < chart.partNames.length ? chart.partNames[part] : ""
                    // Empty parts of a stack are not listed ("Ops 0:00" says nothing).
                    visible: !box.stacked || box.parts[part] !== 0
                    spacing: KanteStyle.unit(5)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: KanteStyle.unit(8)
                        height: width
                        color: box.stacked ? chart.partColor(part)
                             : (chart.hoverIndex === chart.highlight ? KanteStyle.accentColor : KanteStyle.dataColor(chart.series))
                    }
                    Text {
                        text: (parent.name !== "" ? parent.name + "  " : "") + chart.format(box.parts[parent.part])
                        color: !box.stacked || chart.hoverPart === parent.part ? KanteStyle.strongTextColor : KanteStyle.textColor
                        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, !box.stacked || chart.hoverPart === parent.part)
                    }
                }
            }
            Text {
                // Only with two or more non-empty parts: one part would repeat its own value.
                visible: box.stacked && box.parts.filter(function (v) { return v !== 0 }).length > 1
                text: "Σ " + chart.format(chart.totalOf(chart.hoverIndex))
                color: KanteStyle.strongTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
            }
        }
    }
}
