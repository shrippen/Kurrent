import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for input controls that keep their own content (spin box,
 * combo box, text area): place inside the control. Hides the style's
 * background and draws a square sunken box whose frame turns accent on
 * focus. Nothing in the System style.
 */
Item {
    id: skin

    required property Item control

    // Stays visible, only its content hides: org.kde.desktop does not draw the
    // text of a text area over a hidden item with z < 0.
    z: -1
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        visible: KanteStyle.themed
        color: KanteStyle.sunkenColor
        opacity: skin.control && skin.control.enabled ? 1 : 0.5
        border.width: 1
        border.color: skin.control && (skin.control.activeFocus || skin.control.visualFocus) ? KanteStyle.accentColor : KanteStyle.frameColor
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
}
