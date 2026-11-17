import QtQuick
import ".."
import "../Kante"

// Kante / Kante Light: a KanteListRow over the row draws it (selection, hover, drop target,
// count); the ItemDelegate below keeps click, drop and tooltip. System's content, hover
// and ListView highlight are hidden then.
KanteListRow {
    // The SidebarView, for the row density.
    required property Item sidebar
    required property Item control

    anchors.fill: parent
    z: 1
    visible: KanteStyle.active
    selected: control.highlighted
    rule: false
    focusOnClick: false
    activeFocusOnTab: false
    density: sidebar.comfortableRows ? KanteListRow.Density.Comfortable
           : (sidebar.denseRows ? KanteListRow.Density.Dense : KanteListRow.Density.Compact)
}
