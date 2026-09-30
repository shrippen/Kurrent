import QtQuick
import QtQuick.Effects
import "."

/**
 * Warm tube glow around one element (the main button of a page): a soft amber
 * halo that warms up from dark when it appears. Never more than one per view.
 * Kante only; without motion the glow is simply on.
 */
Item {
    id: tube

    default property alias content: box.data
    property color glowColor: KanteStyle.accentColor
    property bool autoPlay: true
    property real warm: 1

    implicitWidth: box.childrenRect.width
    implicitHeight: box.childrenRect.height

    function replay() {
        if (!KanteStyle.animate) {
            warm = 1
            return
        }
        anim.stop()
        warm = 0
        anim.start()
    }
    Component.onCompleted: {
        if (autoPlay) {
            replay()
        }
    }

    NumberAnimation {
        id: anim
        target: tube
        property: "warm"
        from: 0
        to: 1
        duration: 1400
        easing.type: Easing.InOutCubic
    }

    Item {
        id: box
        anchors.fill: parent
        layer.enabled: KanteStyle.themed
        layer.effect: MultiEffect {
            brightness: -0.45 * (1 - tube.warm)
            saturation: -0.4 * (1 - tube.warm)
            shadowEnabled: true
            shadowColor: tube.glowColor
            shadowOpacity: 0.42 * tube.warm
            shadowBlur: 1.0
            shadowScale: 1.04
        }
    }
}
