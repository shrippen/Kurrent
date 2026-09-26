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
 */
QQC2.ToolButton {
    id: control

    readonly property color kanteInk: checked ? KanteStyle.accentForegroundColor : KanteStyle.textColor

    Rectangle {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed && (control.hovered || control.down || control.checked || control.visualFocus)
        color: control.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: control.visualFocus && !control.checked ? 1 : 0
        border.color: KanteStyle.accentColor
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
