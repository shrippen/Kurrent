import QtQuick
import QtQuick.Shapes
import "."

/**
 * Bar chart in the data palette. `values` is a list of numbers (one series, colour
 * `series`) or of lists (stacked, one colour per part); `labels` sit under the bars.
 * `goal` draws a dashed yellow goal line (negative: none), `highlight` marks one bar
 * in the accent. No rounded bars, a 1 px grid, mono labels.
 */
Item {
    id: chart

    property var values: []
    property var labels: []
    property real goal: -1
    property int series: 0
    property int highlight: -1
    /** Top of the scale; 0 = the largest value or goal. */
    property real maxValue: 0

    readonly property real scaleMax: {
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
    readonly property real labelHeight: KanteStyle.unit(16)
    readonly property real plotHeight: height - labelHeight

    implicitWidth: KanteStyle.unit(260)
    implicitHeight: KanteStyle.unit(120)

    // Grid: base line and two more.
    Repeater {
        model: 3
        delegate: Rectangle {
            required property int index
            width: chart.width
            height: 1
            y: chart.plotHeight - index * chart.plotHeight / 3 - 1
            color: index === 0 ? KanteStyle.frameColor : KanteStyle.ruleColor
        }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: chart.values.length
            delegate: Item {
                id: col
                required property int index
                readonly property var value: chart.values[index]
                readonly property bool stacked: Array.isArray(value)
                width: chart.width / Math.max(1, chart.values.length)
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
                            color: col.stacked ? KanteStyle.dataColor(col.value.length - 1 - index)
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
            startX: 0
            startY: chart.plotHeight - chart.goal / chart.scaleMax * chart.plotHeight
            PathLine { x: chart.width; y: chart.plotHeight - chart.goal / chart.scaleMax * chart.plotHeight }
        }
    }
}
