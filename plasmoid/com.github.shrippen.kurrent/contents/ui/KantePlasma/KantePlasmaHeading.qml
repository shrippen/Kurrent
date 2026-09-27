import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import "../Kante"

/**
 * Heading of a Plasma widget (PlasmaExtras.Heading).
 *   System  PlasmaExtras.Heading (unchanged).
 *   Kante   level 4 and below (sections): small uppercase monospace label
 *           followed by a thin rule; above: uppercase Rajdhani title.
 *   Kante Light  the same section labels in theme colors, and the Rajdhani
 *           title for `pageTitle`; other headings stay the platform's.
 */
PlasmaExtras.Heading {
    id: control

    readonly property bool sectionLabel: level >= 4
    /** The view's own title (app or popup name): uppercase Rajdhani in Kante Light too. */
    property bool pageTitle: false
    /** Kante draws every level; Kante Light only section labels and the page title. */
    readonly property bool kanteDrawn: KanteStyle.active && (KanteStyle.themed || sectionLabel || pageTitle)

    // Kante draws its own text over the hidden original; the heading's own font
    // and color stay untouched, so switching back to System restores them exactly.
    PlasmaComponents3.Label {
        id: kanteText
        visible: control.kanteDrawn
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // centered on the text, not on the padded box
        anchors.verticalCenterOffset: (control.topPadding - control.bottomPadding) / 2
        width: Math.min(implicitWidth, control.width)
        text: control.text
        font: control.sectionLabel ? KanteStyle.labelFont()
                                   : KanteStyle.titleFont(KanteStyle.defaultFont.pointSize * (control.level <= 2 ? 1.6 : 1.3))
        color: control.sectionLabel ? KanteStyle.mutedTextColor : KanteStyle.strongTextColor
        elide: Text.ElideRight
    }

    Rectangle {
        visible: control.kanteDrawn && control.sectionLabel
        x: kanteText.width + Math.round(kanteText.font.pixelSize * 0.8)
        width: Math.max(0, control.width - x)
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        // centered on the text, not on the padded box
        anchors.verticalCenterOffset: (control.topPadding - control.bottomPadding) / 2
        color: KanteStyle.ruleColor
    }

    Binding {
        target: control
        property: "color"
        value: "transparent"
        when: control.kanteDrawn
        restoreMode: Binding.RestoreBindingOrValue
    }
}
