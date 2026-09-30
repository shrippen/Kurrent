import QtQuick
import "."

/** Status lamp, a 10 px square with a rhythm: steady, pulse (1.2 s), breathe (3 s) or tick (a short dip like a disk LED). */
Rectangle {
    id: lamp

    enum Rhythm {
        Steady,
        Pulse,
        Breathe,
        Tick
    }

    property int rhythm: KanteLamp.Rhythm.Steady
    color: KanteStyle.infoColor
    width: KanteStyle.unit(10)
    height: width

    SequentialAnimation on opacity {
        running: (lamp.rhythm === KanteLamp.Rhythm.Pulse || lamp.rhythm === KanteLamp.Rhythm.Breathe) && KanteStyle.animate && lamp.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.25; duration: lamp.rhythm === KanteLamp.Rhythm.Pulse ? 600 : 1500; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.25; to: 1; duration: lamp.rhythm === KanteLamp.Rhythm.Pulse ? 600 : 1500; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on opacity {
        running: lamp.rhythm === KanteLamp.Rhythm.Tick && KanteStyle.animate && lamp.visible
        loops: Animation.Infinite
        PropertyAction { value: 0.25 }
        PauseAnimation { duration: 120 }
        PropertyAction { value: 1 }
        PauseAnimation { duration: 880 }
    }
}
