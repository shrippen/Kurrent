import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "."

/**
 * Tool (icon) button.
 *   System  a plain tool button of the active style (unchanged).
 *   Kante   square; hover and pressed show the sunken tint, checked ones
 *           (segmented filters) the accent. Icon and text are drawn here.
 *
 *   fillChecked  (1.38) false: a checked button is not filled with the accent, for a
 *                toggle that shows its state itself (KanteTransportBar's lamps). It stays
 *                checkable and checked, so screen readers still get the state from Qt.
 */
QQC2.ToolButton {
    id: control

    // Return and Enter press a focused button like Space (1.49, WCAG 2.1.1): Qt Quick
    // Controls take only Space, so keyboard users pressed Return and nothing happened.
    Keys.onReturnPressed: function (event) { KanteStyle.pressByKey(control, event) }
    Keys.onEnterPressed: function (event) { KanteStyle.pressByKey(control, event) }

    property bool fillChecked: true
    readonly property bool filled: checked && fillChecked
    readonly property color kanteInk: filled ? KanteStyle.accentForegroundColor : KanteStyle.textColor

    Rectangle {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed && (control.hovered || control.down || control.filled || control.visualFocus)
        color: control.filled ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: control.visualFocus && !control.filled ? 2 : 0
        border.color: KanteStyle.focusColor
    }

    RowLayout {
        visible: KanteStyle.themed
        x: control.leftPadding + Math.max(0, (control.availableWidth - width) / 2)
        y: control.topPadding
        width: Math.min(implicitWidth, control.availableWidth)
        height: control.availableHeight
        spacing: Math.max(control.spacing, Kirigami.Units.smallSpacing)
        opacity: control.enabled ? 1 : 0.4

        Kirigami.Icon {
            readonly property var iconSource: control.icon.name !== "" ? control.icon.name : control.icon.source
            visible: control.display !== T.AbstractButton.TextOnly && String(iconSource).length > 0
            Layout.preferredWidth: control.icon.width > 0 ? control.icon.width : Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: control.icon.height > 0 ? control.icon.height : Kirigami.Units.iconSizes.smallMedium
            Layout.alignment: Qt.AlignVCenter
            source: iconSource
            color: control.icon.color.a > 0 ? control.icon.color : control.kanteInk
            isMask: true
        }

        QQC2.Label {
            visible: control.display !== T.AbstractButton.IconOnly && control.text.length > 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: control.text
            font: control.font
            color: control.kanteInk
            elide: Text.ElideRight
        }
    }

    Binding {
        target: control.background
        property: "opacity"
        value: 0
        when: KanteStyle.themed && control.background !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: control.contentItem
        property: "opacity"
        value: 0
        when: KanteStyle.themed && control.contentItem !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
