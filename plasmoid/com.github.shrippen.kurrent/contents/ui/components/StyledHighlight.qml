import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import "../Kante"

// Selection background for sidebar rows and tabs.
// System and Kante Light: the Plasma list highlight. Kante: accent fill with the small cut corner.
Item {
    id: highlight

    property bool hovered: true
    property bool pressed: false

    PlasmaExtras.Highlight {
        anchors.fill: parent
        visible: !KanteStyle.themed
        hovered: highlight.hovered
        pressed: highlight.pressed
    }

    KanteCard {
        anchors.fill: parent
        visible: KanteStyle.themed
        chamfer: Math.min(KanteStyle.chamferSmall, Math.round(parent.height / 3))
        color: highlight.pressed ? Qt.darker(KanteStyle.accentColor, 1.1) : KanteStyle.accentColor
    }
}
