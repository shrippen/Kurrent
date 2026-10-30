import QtQuick
import QtQuick.Layouts
import "."

/** A command line in mono with a copy button (install commands, paths). `copy()` puts `text` on the clipboard. */
Item {
    id: box

    property string text: ""
    property string copyText: "Kopieren"
    property string copiedText: "Kopiert"
    property bool copied: false
    signal copiedToClipboard()

    function copy() {
        clipboard.text = box.text
        clipboard.selectAll()
        clipboard.copy()
        box.copied = true
        reset.restart()
        box.copiedToClipboard()
    }

    implicitWidth: KanteStyle.unit(360)
    implicitHeight: KanteStyle.heightMedium

    TextEdit { id: clipboard; visible: false }
    Timer { id: reset; interval: 1500; onTriggered: box.copied = false }

    Rectangle { anchors.fill: parent; color: KanteStyle.sunkenColor; border.width: 1; border.color: KanteStyle.frameColor }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: KanteStyle.unit(12)
        spacing: KanteStyle.unit(8)
        Text {
            Layout.fillWidth: true
            text: box.text
            color: KanteStyle.focusColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 0.9, false)
            elide: Text.ElideMiddle
            verticalAlignment: Text.AlignVCenter
        }
        KanteButton {
            text: box.copied ? box.copiedText : box.copyText
            emphasis: box.copied ? KanteButton.Emphasis.Data : KanteButton.Emphasis.Quiet
            size: KanteButton.Size.Small
            onClicked: box.copy()
        }
    }
}
