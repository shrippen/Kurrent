import QtQuick
import "."

/** Three squares hopping in turn: short waits, busy buttons and data. Static without motion. */
Row {
    id: loader

    property bool running: true
    property color color: KanteStyle.accentColor
    property int size: KanteStyle.unit(8)

    spacing: Math.round(size / 2)

    Repeater {
        model: 3
        delegate: Rectangle {
            id: sq
            required property int index
            width: loader.size
            height: loader.size
            color: loader.color
            SequentialAnimation {
                running: loader.running && KanteStyle.animate && loader.visible
                loops: Animation.Infinite
                PauseAnimation { duration: sq.index * 150 }
                ParallelAnimation {
                    NumberAnimation { target: sq; property: "opacity"; from: 0.25; to: 1; duration: 360 }
                    NumberAnimation { target: sq; property: "y"; from: 0; to: -loader.size / 2; duration: 360; easing.type: Easing.OutCubic }
                }
                ParallelAnimation {
                    NumberAnimation { target: sq; property: "opacity"; to: 0.25; duration: 540 }
                    NumberAnimation { target: sq; property: "y"; to: 0; duration: 540 }
                }
                PauseAnimation { duration: (2 - sq.index) * 150 }
            }
        }
    }
}
