import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a horizontal slider: place inside the control. Hides the
 * style's groove and handle and draws a flat sunken track, the filled part in
 * the accent and a square handle. Nothing in the System style.
 */
Item {
    id: skin

    required property Item control

    visible: KanteStyle.themed
    anchors.fill: parent
    opacity: control && control.enabled ? 1 : 0.5

    readonly property real trackX: control ? control.leftPadding : 0
    readonly property real trackWidth: control ? control.availableWidth : 0
    readonly property int handleSize: Math.round(Kirigami.Units.gridUnit * 0.8)

    Binding {
        target: skin.control ? skin.control.background : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.control !== null && skin.control.background !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: skin.control ? skin.control.handle : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.control !== null && skin.control.handle !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Rectangle {
        x: skin.trackX
        width: skin.trackWidth
        height: 4
        anchors.verticalCenter: parent.verticalCenter
        color: KanteStyle.sunkenColor

        Rectangle {
            width: skin.control ? skin.control.visualPosition * parent.width : 0
            height: parent.height
            color: KanteStyle.accentColor
        }
    }

    Rectangle {
        width: skin.handleSize
        height: skin.handleSize
        anchors.verticalCenter: parent.verticalCenter
        x: skin.trackX + (skin.control ? skin.control.visualPosition : 0) * (skin.trackWidth - width)
        color: KanteStyle.accentColor
        border.width: skin.control && skin.control.visualFocus ? 2 : 0
        border.color: KanteStyle.strongTextColor
    }
}
