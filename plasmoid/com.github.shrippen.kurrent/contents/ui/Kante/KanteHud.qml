import QtQuick
import "."

/**
 * HUD line: small mono uppercase label, optionally typed in like a teleprinter
 * (`typing`, a yellow block cursor that blinks and goes). Prefix with "// ".
 */
Text {
    id: hud

    /** Type the text in when it appears (or when `replay()` is called). */
    property bool typing: false
    property string fullText: ""
    property bool _typing: false
    property int _n: 0

    text: typing && KanteStyle.animate ? fullText.slice(0, _n) : fullText
    color: KanteStyle.mutedTextColor
    font: KanteStyle.labelFont()

    function replay() {
        if (!typing || !KanteStyle.animate) {
            return
        }
        _n = 0
        _typing = true
        typer.restart()
    }

    Component.onCompleted: replay()

    Timer {
        id: typer
        interval: 55
        repeat: true
        onTriggered: {
            hud._n = hud._n + 1
            if (hud._n >= hud.fullText.length) {
                stop()
                cursorOff.restart()
            }
        }
    }
    Timer {
        id: cursorOff
        interval: 2000
        onTriggered: hud._typing = false
    }

    Rectangle {
        x: hud.contentWidth + KanteStyle.unit(2)
        y: (hud.height - height) / 2
        width: KanteStyle.unit(8)
        height: hud.contentHeight * 0.95
        color: KanteStyle.accentColor
        visible: hud._typing && KanteStyle.animate
        SequentialAnimation on opacity {
            running: hud._typing && KanteStyle.animate
            loops: Animation.Infinite
            PropertyAction { value: 1 }
            PauseAnimation { duration: 500 }
            PropertyAction { value: 0 }
            PauseAnimation { duration: 500 }
        }
    }
}
