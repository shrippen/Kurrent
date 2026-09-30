import QtQuick
import "."

/**
 * Kante look for a sheet or drawer (a QQC2.Drawer or Popup that comes from an edge):
 * a cut-corner card with the yellow bar and the Kante colours for its content.
 * Give it `popup: <id>`; a QtObject, so it is no content of the popup.
 */
QtObject {
    id: skin

    required property var popup
    /** Bar colour; negative for a destructive question. */
    property color barColor: KanteStyle.accentColor

    readonly property KanteScope scope: KanteScope { target: skin.popup ? skin.popup.contentItem : null }
    readonly property Item kanteBackground: KanteCard {
        color: KanteStyle.dialogColor
        barColor: skin.barColor
    }
    readonly property Binding backgroundBinding: Binding {
        target: skin.popup
        property: "background"
        value: skin.kanteBackground
        when: KanteStyle.themed && skin.popup !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
