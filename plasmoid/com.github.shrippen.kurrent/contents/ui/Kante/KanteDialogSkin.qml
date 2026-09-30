import QtQuick
import "."

/**
 * Kante look for a Kirigami or QQC2 dialog: place one inside the dialog with
 * `dialog: <id>`. Replaces the background with a cut-corner card (top-right and
 * bottom-left) and hands the Kante colors to the dialog's content; does nothing in
 * the System style.
 *
 * A QtObject, not an Item: as a visual child of a Kirigami.Dialog an Item would
 * count as dialog content and size its ScrollView to 0.
 */
QtObject {
    id: skin

    required property var dialog

    readonly property KanteScope scope: KanteScope { target: skin.dialog ? skin.dialog.contentItem : null }

    // Not a child: only handed to `background` while Kante is on.
    readonly property Item kanteBackground: KanteCard {
        color: KanteStyle.dialogColor
        barColor: KanteStyle.accentColor
        chamferBottom: KanteStyle.chamfer
    }

    readonly property Binding backgroundBinding: Binding {
        target: skin.dialog
        property: "background"
        value: skin.kanteBackground
        when: KanteStyle.themed && skin.dialog !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
