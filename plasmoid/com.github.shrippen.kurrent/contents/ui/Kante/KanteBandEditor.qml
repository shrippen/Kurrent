import QtQuick
import QtQuick.Layouts
import "."

/**
 * Band editor: thresholds with a colour each, e.g. sensor ranges. `bands` is a list of
 * {value, color}; band i runs from its value to the next one (the last one to `max`). A
 * swatch cycles through `colors`, the field edits the value, × removes the row, the
 * button adds one. Rows stay sorted by value. A strip below previews the result.
 * Every change emits `edited(bands)`; `bands` is not written back.
 */
ColumnLayout {
    id: ed

    property var bands: []
    property var colors: [KanteStyle.dataColor(3), KanteStyle.dataColor(1), KanteStyle.dataColor(4), KanteStyle.negativeTextColor]
    property real min: 0
    property real max: 100
    property string unit: ""
    property string addText: "Bereich hinzufügen"
    property int minBands: 1
    signal edited(var bands)

    spacing: KanteStyle.unit(8)

    function copy() {
        var c = []
        for (var i = 0; i < bands.length; i++) {
            c.push({ value: bands[i].value, color: bands[i].color })
        }
        return c
    }
    function sorted(c) {
        c.sort(function (a, b) { return a.value - b.value })
        return c
    }
    function setValue(i, v) {
        if (i < 0 || i >= bands.length || isNaN(v)) {
            return
        }
        var c = copy()
        c[i].value = Math.max(min, Math.min(max, v))
        edited(sorted(c))
    }
    function nextColor(current) {
        for (var k = 0; k < colors.length; k++) {
            if (Qt.colorEqual(colors[k], current)) {
                return colors[(k + 1) % colors.length]
            }
        }
        return colors[0]
    }
    function cycleColor(i) {
        if (i < 0 || i >= bands.length) {
            return
        }
        var c = copy()
        c[i].color = nextColor(c[i].color)
        edited(c)
    }
    function addBand() {
        var c = copy()
        var last = c.length > 0 ? c[c.length - 1].value : min
        c.push({ value: Math.min(max, last + (max - min) / 10), color: nextColor(c.length > 0 ? c[c.length - 1].color : "") })
        edited(sorted(c))
    }
    function removeBand(i) {
        if (bands.length <= minBands || i < 0 || i >= bands.length) {
            return
        }
        var c = copy()
        c.splice(i, 1)
        edited(c)
    }

    Repeater {
        model: ed.bands.length
        delegate: RowLayout {
            id: row
            required property int index
            Layout.fillWidth: true
            spacing: KanteStyle.unit(10)

            KanteSwatch {
                swatchColor: ed.bands[row.index].color
                Layout.alignment: Qt.AlignVCenter
                onClicked: ed.cycleColor(row.index)
            }
            KanteTextField {
                Layout.preferredWidth: KanteStyle.unit(90)
                text: String(ed.bands[row.index].value)
                horizontalAlignment: Text.AlignRight
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onEditingFinished: ed.setValue(row.index, parseFloat(text.replace(",", ".")))
            }
            Text {
                text: ed.unit
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
            }
            Item { Layout.fillWidth: true }
            KanteButton {
                text: "×"
                emphasis: KanteButton.Emphasis.Quiet
                size: KanteButton.Size.Small
                enabled: ed.bands.length > ed.minBands
                onClicked: ed.removeBand(row.index)
            }
        }
    }

    // Preview: the bands at their share of the scale.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: KanteStyle.unit(10)
        Rectangle { anchors.fill: parent; color: KanteStyle.sunkenColor }
        Repeater {
            model: ed.bands.length
            delegate: Rectangle {
                required property int index
                readonly property real from: ed.bands[index].value
                readonly property real to: index < ed.bands.length - 1 ? ed.bands[index + 1].value : ed.max
                x: (from - ed.min) / (ed.max - ed.min) * parent.width
                width: Math.max(1, (to - from) / (ed.max - ed.min) * parent.width)
                height: parent.height
                color: ed.bands[index].color
            }
        }
    }

    KanteButton {
        text: ed.addText
        emphasis: KanteButton.Emphasis.Data
        size: KanteButton.Size.Small
        onClicked: ed.addBand()
    }
}
