import QtQuick
import "."

/**
 * Scan reveal: the content is uncovered from top to bottom while a cyan line
 * travels down, like a flatbed scanner. Call `play()` (or set `autoPlay`).
 * Without motion the content simply shows.
 */
Item {
    id: reveal

    default property alias content: box.data
    property bool autoPlay: true
    property real progress: 1

    implicitWidth: box.childrenRect.width
    implicitHeight: box.childrenRect.height

    function play() {
        if (!KanteStyle.animate) {
            progress = 1
            return
        }
        anim.stop()
        progress = 0
        anim.start()
    }

    Component.onCompleted: {
        if (autoPlay) {
            play()
        }
    }

    NumberAnimation {
        id: anim
        target: reveal
        property: "progress"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }

    Item {
        width: reveal.width
        height: reveal.height * reveal.progress
        clip: true
        Item {
            id: box
            width: reveal.width
            height: reveal.height
        }
    }

    Rectangle {
        width: reveal.width
        height: 2
        y: reveal.height * reveal.progress
        color: KanteStyle.focusColor
        visible: anim.running
        opacity: reveal.progress < 0.9 ? 1 : (1 - reveal.progress) * 10
    }
}
