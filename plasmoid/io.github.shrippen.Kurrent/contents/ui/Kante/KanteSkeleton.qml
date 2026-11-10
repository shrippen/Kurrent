import QtQuick
import "."

/** Placeholder lines while content loads. */
Column {
    id: skel

    property int lines: 3
    property bool running: true

    spacing: KanteStyle.unit(8)
    opacity: 1

    SequentialAnimation on opacity {
        running: skel.running && KanteStyle.animate && skel.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.45; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.45; to: 1; duration: 800; easing.type: Easing.InOutSine }
    }

    Repeater {
        model: skel.lines
        delegate: Rectangle {
            required property int index
            width: skel.width * (index === 0 ? 1 : (index === 1 ? 0.8 : 0.55))
            height: KanteStyle.unit(12)
            color: KanteStyle.cardColor
        }
    }
}
