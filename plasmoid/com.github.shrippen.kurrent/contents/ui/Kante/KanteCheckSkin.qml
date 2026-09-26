import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a check box or switch: place inside the control.
 * Hides the style's indicator and draws a square box (check box) or a square
 * track with a square knob (switch); checked uses the accent. Nothing in the
 * System style.
 */
Item {
    id: skin

    enum Shape {
        Box,
        Switch
    }

    required property Item control
    property int shape: KanteCheckSkin.Shape.Box

    readonly property Item indicator: control ? control.indicator : null

    visible: KanteStyle.themed && indicator !== null
    x: indicator ? indicator.x : 0
    y: indicator ? indicator.y : 0
    width: shape === KanteCheckSkin.Shape.Box ? Math.round(Kirigami.Units.gridUnit * 0.9) : Math.round(Kirigami.Units.gridUnit * 1.8)
    height: Math.round(Kirigami.Units.gridUnit * 0.9)
    anchors.verticalCenter: control ? control.verticalCenter : undefined
    opacity: control && control.enabled ? 1 : 0.5

    Binding {
        target: skin.indicator
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.indicator !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Check box
    Rectangle {
        anchors.fill: parent
        visible: skin.shape === KanteCheckSkin.Shape.Box
        color: skin.control && skin.control.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: 1
        border.color: skin.control && (skin.control.checked || skin.control.visualFocus) ? KanteStyle.accentColor : KanteStyle.frameColor

        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width - 4
            height: width
            visible: skin.control && skin.control.checked
            source: "checkmark"
            isMask: true
            color: KanteStyle.accentForegroundColor
        }
    }

    // Switch
    Rectangle {
        anchors.fill: parent
        visible: skin.shape === KanteCheckSkin.Shape.Switch
        color: skin.control && skin.control.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: 1
        border.color: skin.control && skin.control.checked ? KanteStyle.accentColor : KanteStyle.frameColor

        Rectangle {
            width: parent.height - 6
            height: width
            y: 3
            x: skin.control && skin.control.checked ? parent.width - width - 3 : 3
            color: skin.control && skin.control.checked ? KanteStyle.accentForegroundColor : KanteStyle.textColor
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
}
