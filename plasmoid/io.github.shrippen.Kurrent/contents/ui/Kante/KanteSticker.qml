import QtQuick
import "."

/**
 * Sticker: a cream "paper" label with dark ink and the small cut (version,
 * platform, licence). `dot` colours the square in front of the text.
 */
Item {
    id: sticker

    property string text: ""
    property color dot: ink
    readonly property color paper: KanteStyle.light ? KanteStyle.textColor : KantePalette.brand
    // Cream paper takes dark ink: off Kante the platform's highlighted text is white on a
    // dark scheme, so the Leinen text colour.
    readonly property color ink: KanteStyle.light ? KanteStyle.backgroundColor
                               : (KanteStyle.themed ? KanteStyle.accentForegroundColor : KantePalette.light.text)

    implicitHeight: KanteStyle.unit(28)
    implicitWidth: row.implicitWidth + KanteStyle.unit(24)

    KantePolygon {
        anchors.fill: parent
        fillColor: sticker.paper
        cutTopRight: KanteStyle.cutSmall
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: KanteStyle.unit(8)
        Rectangle {
            width: KanteStyle.unit(7)
            height: width
            color: sticker.dot
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sticker.text
            color: sticker.ink
            font: KanteStyle.labelFont()
        }
    }
}
