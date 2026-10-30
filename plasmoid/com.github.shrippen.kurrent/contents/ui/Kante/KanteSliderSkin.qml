import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a slider: place inside the control. Hides the style's groove
 * and handle and draws a flat sunken track, the filled part in the accent and
 * a square handle. Nothing in the System style.
 *
 * Horizontal (the default): the track runs along availableWidth, filled from
 * the left up to the handle and the handle moves in x.
 * Vertical (control.orientation: Qt.Vertical, e.g. a fader): the track runs
 * along availableHeight, filled from the bottom up to the value and the
 * handle moves in y. Nothing to set on the skin; give the slider a height.
 */
Item {
    id: skin

    required property Item control

    visible: KanteStyle.themed
    anchors.fill: parent
    opacity: control && control.enabled ? 1 : 0.5

    readonly property bool vertical: control !== null && control.orientation === Qt.Vertical
    readonly property real trackX: control ? control.leftPadding : 0
    readonly property real trackWidth: control ? control.availableWidth : 0
    readonly property real trackY: control ? control.topPadding : 0
    readonly property real trackHeight: control ? control.availableHeight : 0
    readonly property int handleSize: Math.round(Kirigami.Units.gridUnit * 0.8)
    // Qt Quick Controls count visualPosition from the top for a vertical
    // slider (1 - position), so the handle's y follows it directly.
    readonly property real visualPosition: control ? control.visualPosition : 0

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

    // Horizontal
    Rectangle {
        objectName: "kanteSliderTrack"
        visible: !skin.vertical
        x: skin.trackX
        width: skin.trackWidth
        height: 4
        anchors.verticalCenter: parent.verticalCenter
        color: KanteStyle.sunkenColor

        Rectangle {
            objectName: "kanteSliderFill"
            width: skin.visualPosition * parent.width
            height: parent.height
            color: KanteStyle.accentColor
        }
    }

    Rectangle {
        objectName: "kanteSliderHandle"
        visible: !skin.vertical
        width: skin.handleSize
        height: skin.handleSize
        anchors.verticalCenter: parent.verticalCenter
        x: skin.trackX + skin.visualPosition * (skin.trackWidth - width)
        color: KanteStyle.accentColor
        border.width: skin.control && skin.control.visualFocus ? 2 : 0
        border.color: KanteStyle.focusColor
    }

    // Vertical
    Rectangle {
        objectName: "kanteSliderTrackVertical"
        visible: skin.vertical
        y: skin.trackY
        width: 4
        height: skin.trackHeight
        anchors.horizontalCenter: parent.horizontalCenter
        color: KanteStyle.sunkenColor

        Rectangle {
            objectName: "kanteSliderFillVertical"
            anchors.bottom: parent.bottom
            width: parent.width
            height: (1 - skin.visualPosition) * parent.height
            color: KanteStyle.accentColor
        }
    }

    Rectangle {
        objectName: "kanteSliderHandleVertical"
        visible: skin.vertical
        width: skin.handleSize
        height: skin.handleSize
        anchors.horizontalCenter: parent.horizontalCenter
        y: skin.trackY + skin.visualPosition * (skin.trackHeight - height)
        color: KanteStyle.accentColor
        border.width: skin.control && skin.control.visualFocus ? 2 : 0
        border.color: KanteStyle.focusColor
    }
}
