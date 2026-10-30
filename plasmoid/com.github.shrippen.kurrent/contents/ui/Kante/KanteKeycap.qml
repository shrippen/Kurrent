import QtQuick
import "."

/**
 * Keycap (Kante 1.43, from lmix): a key or shortcut as a small cap, such as "Ctrl+S" in a
 * menu, "Esc" beside Cancel or a key on a shortcuts page. Mono figures on the sunken ground,
 * a 1 px frame and a 2 px bottom edge, the key's depth. `text` is shown as given (the app
 * passes the platform's native text, e.g. from a Shortcut's nativeText). Screen readers
 * read the text. System: the same cap in the platform's colours and monospace.
 */
Item {
    id: cap

    property string text: ""

    implicitWidth: label.implicitWidth + KanteStyle.unit(10)
    implicitHeight: label.implicitHeight + KanteStyle.unit(4) + 1

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Rectangle {
        anchors.fill: parent
        color: KanteStyle.sunkenColor
        border.color: KanteStyle.frameColor
        border.width: 1
    }
    // The bottom edge, a second pixel of frame.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: KanteStyle.frameColor
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: cap.text
        font: KanteStyle.monoFont(KanteStyle.smallFont.pointSize)
        color: KanteStyle.mutedTextColor
        Accessible.ignored: true
    }
}
