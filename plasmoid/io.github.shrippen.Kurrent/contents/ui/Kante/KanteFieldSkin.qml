import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import "."

/**
 * Kante look for input controls that keep their own content (spin box,
 * combo box, text area): place inside the control. Hides the style's
 * background and draws a square sunken box with a 2 px bottom edge that
 * turns cyan on focus. Nothing in the System style.
 *
 * The open list of a combo box stays the style's here; KanteComboBox (1.27) is a combo
 * box with this skin whose list is Kante too.
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
        id: comboValue
        objectName: "kanteComboValue"
        visible: KanteStyle.themed && skin.comboBox && skin.control.contentItem !== null
        // At least 8 px in from the frame (some styles put the text flush to it), clear of the arrow.
        x: Math.max(KanteStyle.unit(8), skin.control && skin.control.contentItem ? skin.control.contentItem.x + (skin.control.contentItem.leftPadding || 0) : 0)
        width: Math.max(0, skin.width - x - skin.arrowRoom)
        anchors.verticalCenter: parent.verticalCenter
        text: skin.comboBox ? skin.control.displayText : ""
        font: skin.control ? skin.control.font : KanteStyle.defaultFont
        color: KanteStyle.textColor
        elide: Text.ElideRight
    }

    // Room left of the value as drawn, from the padding (not the content item's x, which
    // follows the width the binding below sets).
    readonly property real valueInset: Math.max(KanteStyle.unit(8), control && control.contentItem
        ? control.leftPadding + (control.contentItem.leftPadding || 0) : 0)
    // Room right of the value: the arrow and its margins.
    readonly property int arrowRoom: KanteStyle.unit(30)
    // The widest entry, so the box neither cuts the value short nor jumps when it changes.
    FontMetrics {
        id: comboMetrics
        font: skin.control ? skin.control.font : KanteStyle.defaultFont
    }
    readonly property real comboTextWidth: {
        if (!comboBox) {
            return 0
        }
        void control.model
        void comboMetrics.font
        let widest = comboMetrics.advanceWidth(control.displayText)
        for (let i = 0; i < control.count; ++i) {
            widest = Math.max(widest, comboMetrics.advanceWidth(control.textAt(i)))
        }
        return Math.ceil(widest)
    }
    // A style that sizes the box from its own background (org.kde.desktop) leaves less room
    // than the value drawn here takes; it read "Erledigu…" in Kurrent's heatmap (1.56).
    Binding {
        target: skin.comboBox ? skin.control : null
        property: "implicitWidth"
        // Not the style's background width: it is hidden here, and org.kde.desktop measures it
        // again from the width this sets (a binding loop).
        // At least comboMinimumWidth, so short entries keep a box that is easy to hit. To fix a
        // width, set width or Layout.preferredWidth; implicitWidth is the skin's in Kante.
        value: Math.max(KanteStyle.comboMinimumWidth,
                        skin.control ? skin.control.implicitContentWidth + skin.control.leftPadding + skin.control.rightPadding : 0,
                        skin.comboTextWidth + skin.valueInset + skin.arrowRoom)
        when: KanteStyle.themed && skin.comboBox && !skin.control.editable
        restoreMode: Binding.RestoreBindingOrValue
    }

    // The style's arrow lives in the indicator or, with desktop styles, in the
    // hidden background: hide the indicator and always draw one.
    // Drawn, not an icon: an app without an icon theme (offscreen, Android) showed none (1.27).
    Shape {
        id: arrow
        visible: KanteStyle.themed && skin.comboBox
        width: KanteStyle.unit(10)
        height: KanteStyle.unit(6)
        anchors.right: parent.right
        anchors.rightMargin: KanteStyle.unit(12)
        anchors.verticalCenter: parent.verticalCenter
        antialiasing: true
        ShapePath {
            strokeColor: skin.control && skin.control.popup && skin.control.popup.visible ? KanteStyle.focusColor : KanteStyle.mutedTextColor
            strokeWidth: Math.max(1.5, KanteStyle.unit(2))
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            startX: 0; startY: 0
            PathLine { x: arrow.width / 2; y: arrow.height }
            PathLine { x: arrow.width; y: 0 }
        }
    }

    Binding {
        target: skin.comboBox ? skin.control.indicator : null
        property: "opacity"
        value: 0
        when: KanteStyle.themed && skin.comboBox && skin.control.indicator !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Text areas: the placeholder stays inside the box (1.73, see KanteTextField).
    readonly property bool textArea: control !== null && control.placeholderText !== undefined && control.text !== undefined
    QQC2.Label {
        objectName: "kantePlaceholder"
        visible: KanteStyle.themed && skin.textArea && skin.control.placeholderText !== ""
                 && skin.control.text === "" && skin.control.preeditText === ""
        x: skin.control ? skin.control.leftPadding : 0
        // A text area starts at the top, a one-line field in its middle.
        y: !skin.control ? 0 : skin.control.textDocument !== undefined ? skin.control.topPadding : (skin.control.height - height) / 2
        width: skin.control ? skin.control.width - skin.control.leftPadding - skin.control.rightPadding : 0
        text: skin.textArea ? skin.control.placeholderText : ""
        horizontalAlignment: skin.control ? skin.control.horizontalAlignment : Text.AlignLeft
        elide: Text.ElideRight
        font: skin.control ? skin.control.font : Qt.application.font
        color: KanteStyle.disabledTextColor
    }
    Binding {
        target: skin.textArea ? skin.control : null
        property: "placeholderTextColor"
        value: "transparent"
        when: KanteStyle.themed && skin.textArea
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

    // A spin box at its upper (dir 1) or lower (dir -1) limit, or disabled: + or − does nothing (1.28).
    function atLimit(dir) {
        if (!spinBox) {
            return false
        }
        var c = control
        if (!c.enabled) {
            return true
        }
        if (c.wrap) {
            return false
        }
        var top = Math.max(c.from, c.to), bottom = Math.min(c.from, c.to)
        var up = c.from <= c.to ? dir > 0 : dir < 0
        return up ? c.value >= top : c.value <= bottom
    }

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
        opacity: skin.atLimit(1) ? 0.4 : 1
    }
    Text {
        visible: KanteStyle.themed && skin.spinBox && skin.control.down.indicator !== null
        x: skin.spinBox && skin.control.down.indicator ? skin.control.down.indicator.x + (skin.control.down.indicator.width - width) / 2 : 0
        y: skin.spinBox && skin.control.down.indicator ? skin.control.down.indicator.y + (skin.control.down.indicator.height - height) / 2 : 0
        text: "−"
        font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        color: skin.spinBox && skin.control.down.pressed ? KanteStyle.accentTextColor : KanteStyle.mutedTextColor
        opacity: skin.atLimit(-1) ? 0.4 : 1
    }
}
