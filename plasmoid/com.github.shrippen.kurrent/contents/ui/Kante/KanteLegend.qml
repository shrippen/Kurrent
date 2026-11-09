import QtQuick
import "."

/**
 * The legend of a chart (Kante 1.61, for Mitori): a key and a word per item, wrapping onto more
 * lines when narrow. Every visualisation without axes needs one, such as
 * the shares by level in a KanteProgressBar or the steps of a KanteHeatmap.
 *
 *   model   [{color, text}, …], drawn in this order; an item may carry `value` ("3"), shown
 *           before the word; `frame: false` (1.63) draws its key without the frame, a blank key
 *           for a blank place (as the gaps of a KanteHeatGrid)
 *   keySize the key, KanteStyle.swatchSize; square in the Kante style, round elsewhere (as
 *           markerRadius)
 * A word longer than the legend is wide wraps under its key.
 *
 * Screen readers hear each item as "value text".
 */
Flow {
    id: legend

    property var model: []
    property real keySize: KanteStyle.swatchSize

    spacing: KanteStyle.unit(12)

    Repeater {
        model: legend.model
        delegate: Row {
            id: item
            required property var modelData
            readonly property string words: (modelData.value !== undefined ? modelData.value + " " : "") + (modelData.text || "")
            spacing: KanteStyle.unit(6)
            Accessible.role: Accessible.StaticText
            Accessible.name: words

            Rectangle {
                objectName: "kanteLegendKey"
                anchors.verticalCenter: parent.verticalCenter
                width: legend.keySize
                height: legend.keySize
                radius: KanteStyle.markerRadius > 0 ? width / 2 : 0
                color: item.modelData.color || KanteStyle.sunkenColor
                border.width: item.modelData.frame === false ? 0 : KanteStyle.borderWidth
                border.color: KanteStyle.frameColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: legend.width > 0 ? Math.min(implicitWidth, legend.width - legend.keySize - item.spacing) : implicitWidth
                wrapMode: Text.Wrap
                text: item.words
                font: KanteStyle.smallFont
                color: KanteStyle.mutedTextColor
            }
        }
    }
}
