import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a menu or other popup: place inside it. Draws a nearly
 * opaque cut-corner card behind the content, hides the platform background
 * (it stays, so the popup keeps the platform's size) and hands the Kante
 * colors to the content (menu items). Nothing in Kante Light and System.
 */
Item {
    id: skin

    required property var popup

    visible: false

    KanteScope { target: skin.popup ? skin.popup.contentItem : null }

    /** Widest visible item of a menu (0 for other popups); re-read whenever it opens. */
    readonly property real widestItem: {
        var p = skin.popup
        if (!p || typeof p.itemAt !== "function" || !p.visible) {
            return 0
        }
        var w = 0
        for (var i = 0; i < p.count; i++) {
            var item = p.itemAt(i)
            if (item && item.visible) {
                w = Math.max(w, item.implicitWidth)
            }
        }
        return w
    }

    // Not a replacement of `background`: Qt hides a background it replaces,
    // so the platform one put back on leaving Kante stayed hidden and
    // unsized (a see-through menu in Kante Light, which starts from Kante).
    // A popup without a background still gets the card, behind its content.
    readonly property Item kanteCard: KanteCard {
        parent: !KanteStyle.themed || !skin.popup ? null
              : skin.popup.background ? skin.popup.background.parent
              : skin.popup.contentItem ? skin.popup.contentItem.parent : null
        visible: parent !== null
        anchors.fill: parent
        z: -0.5
        color: KanteStyle.dialogColor
        borderColor: KanteStyle.frameColor
        barColor: KanteStyle.focusColor
        barHeight: KanteStyle.unit(3)
        chamfer: KanteStyle.chamferSmall
    }

    // Styles like Material and Basic size a menu from its background: at
    // least the widest item, so its label is not cut.
    Binding {
        target: skin.popup ? skin.popup.background : null
        property: "implicitWidth"
        value: Math.max(Kirigami.Units.gridUnit * 11,
                        skin.widestItem + (skin.popup ? skin.popup.leftPadding + skin.popup.rightPadding : 0))
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: skin.popup ? skin.popup.background : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
