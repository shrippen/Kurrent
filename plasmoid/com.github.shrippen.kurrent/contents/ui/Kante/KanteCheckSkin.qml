import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a check box, radio button or switch: place inside the control.
 * Hides the style's indicator and draws a square box with a tick that is drawn
 * as a stroke (check box), a diamond with a core that snaps in (radio button, so
 * single choice never reads as a check box) or a square track with a square knob
 * that snaps to its end with a small overshoot (switch); checked uses the accent.
 * Focus is a cyan ring with a gap. The label takes the Kante text colour, so Kante dark stays
 * readable on a light platform scheme (and Leinen on a dark one) even outside a KanteScope.
 * Nothing in the System style.
 */
Item {
    id: skin

    enum Shape {
        Box,
        Switch,
        Radio
    }

    required property Item control
    property int shape: KanteCheckSkin.Shape.Box

    readonly property Item indicator: control ? control.indicator : null
    readonly property bool checked: control ? control.checked : false
    readonly property bool focused: control ? control.visualFocus : false
    readonly property bool hovered: control ? control.hovered : false

    visible: KanteStyle.themed && indicator !== null
    x: indicator ? indicator.x : 0
    y: indicator ? indicator.y : 0
    width: shape === KanteCheckSkin.Shape.Switch ? Math.round(Kirigami.Units.gridUnit * 1.8) : Math.round(Kirigami.Units.gridUnit * 0.9)
    height: Math.round(Kirigami.Units.gridUnit * 0.9)
    anchors.verticalCenter: control ? control.verticalCenter : undefined
    opacity: control && control.enabled ? 1 : 0.5

    // The platform label draws in the platform's text colour (Breeze Light: near black on
    // Kante dark); Kante's own colour instead.
    readonly property Item label: control && control.contentItem instanceof Text ? control.contentItem : null
    Binding {
        target: skin.label
        property: "color"
        value: KanteStyle.textColor
        when: KanteStyle.themed && skin.label !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: skin.indicator
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.indicator !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Focus ring, 3 px outside the shape.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        visible: skin.focused
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.focusColor
        rotation: 0
    }

    // Check box
    Rectangle {
        anchors.fill: parent
        visible: skin.shape === KanteCheckSkin.Shape.Box
        color: skin.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: 1
        border.color: skin.checked ? KanteStyle.accentColor : (skin.hovered ? KanteStyle.mutedTextColor : KanteStyle.frameColor)
        Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

        KanteTick {
            anchors.centerIn: parent
            width: parent.width - 4
            height: width
            checked: skin.checked
        }
    }

    // Radio button: diamond outline, accent core that snaps in when checked.
    Rectangle {
        anchors.centerIn: parent
        visible: skin.shape === KanteCheckSkin.Shape.Radio
        width: Math.round(parent.width * 0.74)
        height: width
        rotation: 45
        color: skin.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: 1
        border.color: skin.checked ? KanteStyle.accentColor : (skin.hovered ? KanteStyle.mutedTextColor : KanteStyle.frameColor)
        Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.5)
            height: width
            color: KanteStyle.accentForegroundColor
            scale: skin.checked ? 1 : 0
            Behavior on scale { NumberAnimation { duration: KanteStyle.animate ? 160 : 0; easing.type: Easing.OutBack; easing.overshoot: KanteStyle.snapOvershoot } }
        }
    }

    // Switch: the knob snaps to its end with a small overshoot.
    Rectangle {
        anchors.fill: parent
        visible: skin.shape === KanteCheckSkin.Shape.Switch
        color: skin.checked ? KanteStyle.accentColor : KanteStyle.sunkenColor
        border.width: 1
        border.color: skin.checked ? KanteStyle.accentColor : KanteStyle.frameColor
        Behavior on color { ColorAnimation { duration: KanteStyle.duration } }

        Rectangle {
            width: parent.height - 6
            height: width
            y: 3
            x: skin.checked ? parent.width - width - 3 : 3
            color: skin.checked ? KanteStyle.accentForegroundColor : KanteStyle.textColor
            Behavior on x { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutBack; easing.overshoot: KanteStyle.snapOvershoot } }
        }
    }
}
