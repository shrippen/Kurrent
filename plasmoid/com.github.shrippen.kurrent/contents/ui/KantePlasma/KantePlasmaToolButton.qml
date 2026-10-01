import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../Kante"

/**
 * Tool (icon) button of a Plasma widget (PlasmaComponents3).
 *   System  a plain Plasma tool button (unchanged).
 *   Kante   square; hover and pressed show the sunken tint instead of the
 *           rounded Breeze highlight.
 */
PlasmaComponents3.ToolButton {
    id: control

    Rectangle {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed && (control.hovered || control.down || control.checked || control.visualFocus)
        // Checked (segmented filters): sunken tint plus an accent bar under the label. A fill
        // would need dark text, and Plasma's runtime does not pass a theme colour to the label.
        color: KanteStyle.sunkenColor
        border.width: control.visualFocus ? 1 : 0
        border.color: KanteStyle.accentColor

        Rectangle {
            visible: control.checked
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: KanteStyle.unit(3)
            color: KanteStyle.accentColor
        }
    }

    Binding {
        target: control.background
        property: "opacity"
        value: 0
        when: KanteStyle.themed && control.background !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
