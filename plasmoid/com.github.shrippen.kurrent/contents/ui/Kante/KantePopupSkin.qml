import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a menu or other popup: place inside it. Replaces the
 * background with a nearly opaque cut-corner card and hands the Kante colors
 * to the content (menu items). Nothing in the System style.
 */
Item {
    id: skin

    required property var popup

    visible: false

    KanteScope { target: skin.popup ? skin.popup.contentItem : null }

    // Not a child: only handed to `background` while Kante is on.
    readonly property Item kanteBackground: KanteCard {
        // Styles like Material and Basic size a menu from its background:
        // at least the widest item, so its label is not cut.
        implicitWidth: Math.max(Kirigami.Units.gridUnit * 11,
                                skin.widestItem + (skin.popup ? skin.popup.leftPadding + skin.popup.rightPadding : 0))
        implicitHeight: Kirigami.Units.gridUnit * 2.5
        color: KanteStyle.dialogColor
        borderColor: KanteStyle.frameColor
        barColor: KanteStyle.focusColor
        barHeight: KanteStyle.unit(3)
        chamfer: KanteStyle.chamferSmall
    }

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

    Binding {
        target: skin.popup
        property: "background"
        value: skin.kanteBackground
        when: KanteStyle.themed && skin.popup !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
