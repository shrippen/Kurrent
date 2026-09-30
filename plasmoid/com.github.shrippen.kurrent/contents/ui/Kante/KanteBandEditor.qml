import QtQuick
import QtQuick.Layouts
import "."

/**
 * Band editor: thresholds with a colour each, e.g. sensor ranges. `bands` is a list of
 * {value, color}; band i runs from its value to the next one (the last one to `max`). A
 * swatch cycles through `colors` (with `pick` it opens the choices as a row of swatches under the band instead), the field edits the value, × removes the row, the
 * button adds one. Rows stay sorted by value. A strip below previews the result.
 * Every change emits `edited(bands)`; `bands` is not written back.
 */
ColumnLayout {
    id: ed
    implicitWidth: KanteStyle.unit(260)

    property var bands: []
    property var colors: [KanteStyle.dataColor(3), KanteStyle.dataColor(1), KanteStyle.dataColor(4), KanteStyle.negativeTextColor]
    property real min: 0
    property real max: 100
    property string unit: ""
    property string addText: "Bereich hinzufügen"
    property int minBands: 1
    property bool pick: false
    property int picking: -1
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
    function setColor(i, color) {
        if (i < 0 || i >= bands.length) {
            return
        }
        var c = copy()
        c[i].color = color
        picking = -1
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
        delegate: ColumnLayout {
            id: row
            required property int index
            Layout.fillWidth: true
            spacing: KanteStyle.unit(6)

            RowLayout {
                Layout.fillWidth: true
                spacing: KanteStyle.unit(10)

                KanteSwatch {
                    swatchColor: ed.bands[row.index].color
                    selected: ed.picking === row.index
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        if (ed.pick) {
                            ed.picking = ed.picking === row.index ? -1 : row.index
                        } else {
                            ed.cycleColor(row.index)
                        }
                    }
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
                // A plain square: a KanteButton sets its own font, which kept the glyph tiny.
                Rectangle {
                    id: remove
                    readonly property bool live: ed.bands.length > ed.minBands
                    Layout.preferredWidth: KanteStyle.unit(32)
                    Layout.preferredHeight: KanteStyle.unit(32)
                    color: hover.hovered && live ? KanteStyle.tint1Color : "transparent"
                    opacity: live ? 1 : 0.4
                    border.width: activeFocus ? 2 : 0
                    border.color: KanteStyle.focusColor
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "×"
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: KanteStyle.mutedTextColor
                        font.pixelSize: KanteStyle.unit(20)
                    }
                    HoverHandler { id: hover }
                    TapHandler { enabled: remove.live; onTapped: ed.removeBand(row.index) }
                    Keys.onSpacePressed: if (live) ed.removeBand(row.index)
                    Keys.onReturnPressed: if (live) ed.removeBand(row.index)
                }
            }

            // The choices of the swatch (`pick`).
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: KanteStyle.unit(6)
                visible: ed.pick && ed.picking === row.index
                spacing: KanteStyle.unit(12)
                Repeater {
                    model: ed.colors
                    delegate: KanteSwatch {
                        required property var modelData
                        swatchColor: modelData
                        selected: Qt.colorEqual(modelData, ed.bands[row.index].color)
                        onClicked: ed.setColor(row.index, modelData)
                    }
                }
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
