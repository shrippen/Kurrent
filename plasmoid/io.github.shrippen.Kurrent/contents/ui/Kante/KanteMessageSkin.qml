import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a Kirigami.InlineMessage: place inside it. Callout
 * tinted with the message type's color, a 4 px bar on top and the cut corner (Kante .callout). Nothing in the
 * System style.
 */
Item {
    id: skin

    required property var message

    visible: false

    readonly property color tone: {
        if (!message) {
            return KanteStyle.infoColor
        }
        switch (message.type) {
        case Kirigami.MessageType.Error:
            return KanteStyle.negativeTextColor
        case Kirigami.MessageType.Warning:
            return KanteStyle.warningColor
        case Kirigami.MessageType.Positive:
            return KanteStyle.positiveTextColor
        default:
            return KanteStyle.infoColor
        }
    }

    // Not a replacement of `background` (Kante 1.43): Qt hides a background it replaces and
    // leaves it hidden when it comes back, so after Kante the message lost its frame. The
    // platform background stays (hidden by opacity while Kante is on) and the card is drawn
    // behind the content.
    readonly property Item kanteBackground: KanteCard {
        parent: KanteStyle.themed && skin.message ? skin.message : null
        visible: parent !== null
        anchors.fill: parent
        z: -0.5
        color: KanteStyle.tint(skin.tone, 0.12)
        barColor: skin.tone
        chamfer: KanteStyle.chamferSmall
    }

    Binding {
        target: skin.message ? skin.message.background : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
