import QtQuick
import "."

/**
 * Kante look for a Kirigami or QQC2 dialog: place one inside the
 * dialog. Replaces the background with a cut-corner card and hands the Kante
 * colors to the dialog's content; does nothing in the System style.
 */
Item {
    id: skin

    required property var dialog

    visible: false

    KanteScope { target: skin.dialog ? skin.dialog.contentItem : null }

    // Not a child: only handed to `background` while Kante is on.
    readonly property Item kanteBackground: KanteCard {
        color: KanteStyle.dialogColor
        barColor: KanteStyle.accentColor
    }

    Binding {
        target: skin.dialog
        property: "background"
        value: skin.kanteBackground
        when: KanteStyle.themed && skin.dialog !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
