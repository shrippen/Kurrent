import QtQuick
import QtQuick.Shapes
import "."

/**
 * Pitch of a word or phrase (Kante 1.25, for Kaiwa; web: `svg.pitch`). The morae sit on the
 * x axis, the target pitch (high or low per mora) is a dashed muted step line, the learner's
 * pitch a line in the info colour (decision D-5: cyan, it is data). The accent kernel (the
 * last high mora before the fall) is a square in the accent colour; a missed kernel or a
 * mora said at the wrong height a square in the negative colour. Markers are square, as
 * everywhere in Kante; the read-out names the kernel in words.
 *
 *   morae    ["は", "し", "(が)"]
 *   target   [1, 0, 0]          1 high, 0 low, one per mora
 *   kernel   0                  index of the kernel mora, -1 flat (heiban)
 *   actual   [0.2, 0.3, …]      the learner's pitch, normalised 0..1 to their own range, any count of samples over the whole width
 *   missAt   -1                 index of the mora that went wrong, -1 none
 */
Item {
    id: pitch

    property var morae: []
    property var target: []
    property int kernel: -1
    property var actual: []
    property int missAt: -1
    property string targetLabel: "Soll"
    property string actualLabel: "Du"
    property string kernelLabel: "Akzentkern"
    property string flatText: "flach, ohne Abfall"
    property string fallText: "Abfall nach"
    property string missText: "abweichend bei"

    readonly property real labelWidth: KanteStyle.unit(24)
    readonly property real plotLeft: labelWidth
    readonly property real plotWidth: Math.max(1, width - labelWidth - KanteStyle.unit(8))
    readonly property real highY: KanteStyle.unit(14)
    readonly property real lowY: plotHeight - KanteStyle.unit(14)
    readonly property real plotHeight: Math.max(KanteStyle.unit(60), height - moraRow.height - legend.height - KanteStyle.unit(12))
    readonly property int count: Math.max(1, morae.length)
    function moraX(i) { return plotLeft + (i + 0.5) * plotWidth / count }
    function levelY(v) { return lowY + (highY - lowY) * Math.max(0, Math.min(1, v)) }

    readonly property string summary: {
        var t = kernel < 0 ? flatText : fallText + " " + (morae[kernel] || "")
        if (missAt >= 0) t += ", " + missText + " " + (morae[missAt] || "")
        return t
    }

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: KanteStyle.unit(170)

    Accessible.role: Accessible.Chart
    Accessible.name: targetLabel + ": " + morae.join("")
    Accessible.description: summary

    // H / L rules
    Repeater {
        model: [pitch.highY, pitch.lowY]
        delegate: Rectangle {
            required property real modelData
            x: pitch.plotLeft
            y: Math.round(modelData)
            width: pitch.plotWidth
            height: 1
            color: KanteStyle.ruleColor
        }
    }
    Text { x: 0; y: pitch.highY - height / 2; text: "H"; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }
    Text { x: 0; y: pitch.lowY - height / 2; text: "L"; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }

    Shape {
        anchors.fill: parent
        antialiasing: true
        // Target: a dashed step line, flat across each mora, vertical at the changes.
        ShapePath {
            strokeColor: KanteStyle.mutedTextColor
            strokeWidth: 2
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 2]
            PathSvg {
                path: {
                    var t = pitch.target || []
                    if (t.length === 0) return ""
                    var w = pitch.plotWidth / pitch.count
                    var p = "M " + (pitch.plotLeft + w * 0.15) + " " + pitch.levelY(t[0])
                    for (var i = 0; i < t.length; i++) {
                        var y = pitch.levelY(t[i])
                        if (i > 0) p += " L " + (pitch.plotLeft + w * i) + " " + y
                        p += " L " + (pitch.plotLeft + w * (i + (i === t.length - 1 ? 0.85 : 1))) + " " + y
                    }
                    return p
                }
            }
        }
        // Actual: the learner's pitch over the whole width.
        ShapePath {
            strokeColor: KanteStyle.infoColor
            strokeWidth: 2
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: {
                    var a = pitch.actual || []
                    if (a.length < 2) return ""
                    var w = pitch.plotWidth / pitch.count
                    var x0 = pitch.plotLeft + w * 0.15, x1 = pitch.plotLeft + pitch.plotWidth - w * 0.15
                    var p = ""
                    for (var i = 0; i < a.length; i++) {
                        p += (i === 0 ? "M " : " L ") + (x0 + (x1 - x0) * i / (a.length - 1)) + " " + pitch.levelY(a[i])
                    }
                    return p
                }
            }
        }
    }

    // Kernel and miss: squares on the high line at the end of the kernel mora / on the mora.
    Rectangle {
        visible: pitch.kernel >= 0 && pitch.kernel < pitch.count
        readonly property real s: KanteStyle.unit(8)
        width: s; height: s
        x: pitch.plotLeft + (pitch.kernel + 1) * pitch.plotWidth / pitch.count - s / 2
        y: pitch.highY - s / 2
        color: KanteStyle.accentColor
    }
    Rectangle {
        visible: pitch.missAt >= 0 && pitch.missAt < pitch.count
        readonly property real s: KanteStyle.unit(8)
        width: s; height: s
        x: pitch.moraX(pitch.missAt) - s / 2
        y: (pitch.target[pitch.missAt] === 0 ? pitch.highY : pitch.lowY) - s / 2
        color: KanteStyle.negativeTextColor
    }

    Item {
        id: moraRow
        y: pitch.plotHeight + KanteStyle.unit(4)
        width: parent.width
        height: KanteStyle.fontPixels(KanteStyle.defaultFont) * 1.6
        Repeater {
            model: pitch.morae
            delegate: Text {
                required property int index
                required property string modelData
                x: pitch.moraX(index) - width / 2
                text: modelData
                color: index === pitch.missAt ? KanteStyle.negativeTextColor : KanteStyle.textColor
                // One mora per Text: the Japanese family (Kante 1.34).
                font.family: KanteStyle.japaneseFamily
                font.pointSize: KanteStyle.defaultFont.pointSize * 1.15
                font.underline: index === pitch.missAt
            }
        }
    }

    Flow {
        id: legend
        y: moraRow.y + moraRow.height + KanteStyle.unit(4)
        x: pitch.plotLeft
        width: pitch.width - pitch.plotLeft
        spacing: KanteStyle.unit(14)
        Row {
            spacing: KanteStyle.unit(5)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater { model: 4; delegate: Rectangle { width: KanteStyle.unit(4); height: 2; color: KanteStyle.mutedTextColor } }
            }
            Text { text: pitch.targetLabel; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }
        }
        Row {
            spacing: KanteStyle.unit(5)
            visible: (pitch.actual || []).length > 1
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: KanteStyle.unit(18); height: 2; color: KanteStyle.infoColor }
            Text { text: pitch.actualLabel; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }
        }
        Row {
            spacing: KanteStyle.unit(5)
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: KanteStyle.unit(8); height: width; color: KanteStyle.accentColor }
            Text { text: pitch.kernelLabel; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }
        }
        Text { text: pitch.summary; color: KanteStyle.textColor; font: KanteStyle.labelFont() }
    }
}
