import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for input controls that keep their own content (spin box,
 * combo box, text area): place inside the control. Hides the style's
 * background and draws a square sunken box with a 2 px bottom edge that
 * turns cyan on focus. Nothing in the System style.
 */
Item {
    id: skin

    required property Item control
    /** Mark the field as invalid (red bottom edge). */
    property bool invalid: false

    // Stays visible, only its content hides: org.kde.desktop does not draw the
    // text of a text area over a hidden item with z < 0.
    z: -1
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        visible: KanteStyle.themed
        readonly property bool focused: !!skin.control && !!(skin.control.activeFocus || skin.control.visualFocus)
        color: focused ? KanteStyle.selectionColor : KanteStyle.sunkenColor
        opacity: skin.control && skin.control.enabled ? 1 : 0.5
        border.width: 1
        border.color: focused ? KanteStyle.tint(KanteStyle.focusColor, 0.55) : KanteStyle.frameColor
        Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

        // 2 px bottom edge: cyan on focus, red when invalid.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: skin.invalid ? KanteStyle.negativeTextColor : (parent.focused ? KanteStyle.focusColor : KanteStyle.frameColor)
            Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }
        }
    }

    Binding {
        target: skin.control ? skin.control.background : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.control !== null && skin.control.background !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    // Combo boxes: draw the shown value over the hidden content item instead of
    // recoloring it, so switching back to System leaves the style's text untouched.
    // (SpinBox has displayText too; only a combo box has a popup.)
    readonly property bool comboBox: control !== null && control.displayText !== undefined && control.popup !== undefined

    Text {
        visible: KanteStyle.themed && skin.comboBox && skin.control.contentItem !== null
        x: skin.control && skin.control.contentItem ? skin.control.contentItem.x + (skin.control.contentItem.leftPadding || 0) : 0
        width: skin.control && skin.control.contentItem ? skin.control.contentItem.width - (skin.control.contentItem.leftPadding || 0) : 0
        anchors.verticalCenter: parent.verticalCenter
        text: skin.comboBox ? skin.control.displayText : ""
        font: skin.control ? skin.control.font : KanteStyle.defaultFont
        color: KanteStyle.textColor
        elide: Text.ElideRight
    }

    // The style's arrow lives in the indicator or, with desktop styles, in the
    // hidden background: hide the indicator and always draw one.
    Kirigami.Icon {
        visible: KanteStyle.themed && skin.comboBox
        width: Kirigami.Units.iconSizes.small
        height: width
        anchors.right: parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        source: "arrow-down"
        isMask: true
        color: KanteStyle.mutedTextColor
    }

    Binding {
        target: skin.comboBox ? skin.control.indicator : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.comboBox && skin.control.indicator !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Text areas: Material floats the placeholder above filled text, over the frame.
    readonly property bool textArea: control !== null && control.placeholderText !== undefined && control.text !== undefined
    Binding {
        target: skin.textArea ? skin.control : null
        property: "placeholderText"
        value: ""
        when: KanteStyle.themed && skin.textArea && skin.control.text.length > 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: skin.comboBox ? skin.control.contentItem : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.comboBox && skin.control.contentItem !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    // A combo box that is not editable must not offer a text cursor: Android shows a
    // "pasted from clipboard" toast on every release of an editable-looking field.
    readonly property bool plainCombo: comboBox && !skin.control.editable && skin.control.contentItem !== null
        && skin.control.contentItem.readOnly !== undefined
    Binding {
        target: skin.plainCombo ? skin.control.contentItem : null
        property: "readOnly"
        value: true
        when: KanteStyle.themed && skin.plainCombo
        restoreMode: Binding.RestoreBindingOrValue
    }
    // Spin boxes: hide the style's arrows and draw + and − in mono.
    readonly property bool spinBox: control !== null && control.up !== undefined && control.down !== undefined
        && control.up.indicator !== undefined && control.down.indicator !== undefined

    // The desktop style gives a spin box the View colour set, so its text takes the
    // platform's text colour (dark on Kante dark under Breeze Light): bind Kante's.
    Binding {
        target: skin.spinBox ? skin.control.contentItem : null
        property: "color"
        value: skin.control && skin.control.enabled ? KanteStyle.textColor : KanteStyle.disabledTextColor
        // No check of contentItem.color here: reading it made `when` depend on the value it sets
        // (binding loop). A spin box's contentItem is a text input in every Qt style.
        when: KanteStyle.themed && skin.spinBox && skin.control.contentItem !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: skin.spinBox ? skin.control.up.indicator : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.spinBox && skin.control.up.indicator !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: skin.spinBox ? skin.control.down.indicator : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.spinBox && skin.control.down.indicator !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    Text {
        visible: KanteStyle.themed && skin.spinBox && skin.control.up.indicator !== null
        x: skin.spinBox && skin.control.up.indicator ? skin.control.up.indicator.x + (skin.control.up.indicator.width - width) / 2 : 0
        y: skin.spinBox && skin.control.up.indicator ? skin.control.up.indicator.y + (skin.control.up.indicator.height - height) / 2 : 0
        text: "+"
        font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        color: skin.spinBox && skin.control.up.pressed ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
    }
    Text {
        visible: KanteStyle.themed && skin.spinBox && skin.control.down.indicator !== null
        x: skin.spinBox && skin.control.down.indicator ? skin.control.down.indicator.x + (skin.control.down.indicator.width - width) / 2 : 0
        y: skin.spinBox && skin.control.down.indicator ? skin.control.down.indicator.y + (skin.control.down.indicator.height - height) / 2 : 0
        text: "−"
        font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        color: skin.spinBox && skin.control.down.pressed ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
    }
}
