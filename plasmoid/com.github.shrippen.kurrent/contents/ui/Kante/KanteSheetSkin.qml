import QtQuick
import "."

/**
 * Kante look for a sheet or drawer (a QQC2.Drawer or Popup that comes from an edge):
 * a cut-corner card with the yellow bar and the Kante colours for its content.
 * `drawer: true` for one over a dialog's content: raised, cut on the side facing it.
 * Give it `popup: <id>`; a QtObject, so it is no content of the popup.
 */
QtObject {
    id: skin

    required property var popup
    /** Bar colour; negative for a destructive question. */
    property color barColor: KanteStyle.accentColor
    /** A drawer over a dialog's content: one surface step raised, cut top left (`.sheet.is-drawer`). */
    property bool drawer: false

    readonly property KanteScope scope: KanteScope { target: skin.popup ? skin.popup.contentItem : null }
    // Not a replacement of `background` (Kante 1.43): Qt hides a background it replaces and
    // leaves it hidden and unsized when it comes back, so after Kante the sheet was
    // see-through. The platform background stays (hidden by opacity while Kante is on) and
    // the card is drawn behind the content.
    readonly property Item kanteBackground: KanteCard {
        parent: !KanteStyle.themed || !skin.popup ? null
              : skin.popup.background ? skin.popup.background.parent
              : skin.popup.contentItem ? skin.popup.contentItem.parent : null
        visible: parent !== null
        anchors.fill: parent
        z: -0.5
        color: skin.drawer ? Qt.tint(KanteStyle.dialogColor, KanteStyle.cardColor) : KanteStyle.dialogColor
        barColor: skin.barColor
        mirrored: skin.drawer
    }
    readonly property Binding backgroundBinding: Binding {
        target: skin.popup ? skin.popup.background : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
