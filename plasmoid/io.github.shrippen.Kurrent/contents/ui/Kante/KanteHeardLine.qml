import QtQuick
import QtQuick.Layouts
import "."

/**
 * What a speech recogniser heard (Kante 1.25, for Kaiwa; web: `.heard`). Goes under your
 * own KanteMessage: a small mono line "gehört als · …". `unsure` turns it into a warning,
 * with the word "unsicher" in front (never colour alone), and offers the action
 * "falsch erkannt", which fires `misheard()`; the app then keeps the turn out of its
 * learner model and lets the person repeat it.
 *
 *   KanteMessage { from: KanteMessage.From.Own; text: "ふくろ、いりません。"
 *       KanteHeardLine { text: "ふくろ(?)いりません"; unsure: true; onMisheard: … } }
 */
RowLayout {
    id: line

    property string text: ""
    property bool unsure: false
    property string heardText: "gehört als"
    property string unsureText: "unsicher"
    property string actionText: "falsch erkannt"
    /** Show the action also when the recogniser was sure. */
    property bool alwaysOffer: false

    signal misheard()

    spacing: KanteStyle.unit(6)

    readonly property color tone: unsure ? KanteStyle.warningColor : KanteStyle.mutedTextColor
    readonly property font lineFont: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)

    Accessible.role: Accessible.StaticText
    Accessible.name: (unsure ? unsureText : heardText) + ": " + text

    Text {
        text: (line.unsure ? "! " + line.unsureText : line.heardText) + " ·"
        color: line.tone
        font: line.lineFont
        Accessible.ignored: true
    }
    Text {
        Layout.fillWidth: true
        text: line.text
        color: line.tone
        font: line.lineFont
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
    Text {
        id: action
        visible: line.unsure || line.alwaysOffer
        text: line.actionText
        color: KanteStyle.infoColor
        font.family: line.lineFont.family
        font.pointSize: line.lineFont.pointSize
        font.underline: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: line.actionText
        Accessible.onPressAction: line.misheard()
        Keys.onReturnPressed: line.misheard()
        Keys.onSpacePressed: line.misheard()
        TapHandler { onTapped: line.misheard() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        Rectangle {
            visible: action.activeFocus
            anchors.fill: parent
            anchors.margins: -KanteStyle.unit(2)
            color: "transparent"
            border.color: KanteStyle.focusColor
            border.width: 2
        }
    }
}
