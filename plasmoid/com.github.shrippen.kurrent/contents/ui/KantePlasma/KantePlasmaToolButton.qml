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
        // Checked (segmented filters): accent fill like a primary button.
        color: control.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: control.visualFocus && !control.checked ? 1 : 0
        border.color: KanteStyle.accentColor
    }

    Binding {
        target: control.Kirigami.Theme
        property: "textColor"
        value: KanteStyle.accentForegroundColor
        when: KanteStyle.themed && control.checked
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: control.Kirigami.Theme
        property: "highlightedTextColor"
        value: KanteStyle.accentForegroundColor
        when: KanteStyle.themed && control.checked
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: control.background
        property: "opacity"
        value: 0
        when: KanteStyle.themed && control.background !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
