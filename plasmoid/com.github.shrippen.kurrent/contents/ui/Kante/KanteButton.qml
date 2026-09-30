import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "."

/**
 * Push button.
 *   System  a plain button of the active style (unchanged).
 *   Kante   uppercase Rajdhani on a cut shape (top-right; primary and
 *           destructive also bottom-left). Hover opens the cut, pressing sets
 *           the button 1 px in, focus is a ring inside. `emphasis` picks the
 *           variant, `size` the height (32 / 40 / 48 px), `busy` shows three
 *           hopping squares, `raised` sits the button on a hard shadow that it
 *           presses into.
 *
 * In Kante the style's frame and content stay (they size the button) but are
 * hidden; frame, icon and text are drawn here.
 */
QQC2.Button {
    id: control

    enum Emphasis {
        Normal,
        Primary,
        Destructive,
        Data,
        Quiet
    }

    enum Size {
        Medium,
        Small,
        Large
    }

    property int emphasis: KanteButton.Emphasis.Normal
    property int size: KanteButton.Size.Medium
    /** Waiting for a result: three squares before the text. */
    property bool busy: false
    /** Sits on a hard 4 px shadow and presses into it (a big, single action). */
    property bool raised: false

    readonly property bool filled: emphasis === KanteButton.Emphasis.Primary || emphasis === KanteButton.Emphasis.Destructive
    readonly property bool lit: enabled && (hovered || visualFocus) && !down
    readonly property real cut: size === KanteButton.Size.Small ? KanteStyle.cutSmall
        : (size === KanteButton.Size.Large ? KanteStyle.unit(12) : KanteStyle.chamferSmall)
    /** The cut opens by 6 px (4 small, 8 large) under the pointer. */
    property real grow: (enabled && hovered && !down && emphasis !== KanteButton.Emphasis.Quiet)
        ? KanteStyle.unit(size === KanteButton.Size.Small ? 4 : (size === KanteButton.Size.Large ? 8 : 6)) : 0
    Behavior on grow { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutCubic } }

    readonly property color kanteFill: {
        switch (emphasis) {
        case KanteButton.Emphasis.Primary:
            return busy || down ? KanteStyle.accentPressedColor : (hovered ? KanteStyle.accentHoverColor : KanteStyle.accentColor)
        case KanteButton.Emphasis.Destructive:
            return down ? Qt.darker(KanteStyle.negativeTextColor, 1.15) : (hovered ? Qt.lighter(KanteStyle.negativeTextColor, 1.12) : KanteStyle.negativeTextColor)
        case KanteButton.Emphasis.Data:
            return (hovered || down) ? KanteStyle.selectionColor : "transparent"
        default:
            return (down || hovered || checked) ? KanteStyle.sunkenColor : "transparent"
        }
    }
    readonly property color kanteInk: {
        switch (emphasis) {
        case KanteButton.Emphasis.Primary: return KanteStyle.accentForegroundColor
        case KanteButton.Emphasis.Destructive: return KanteStyle.onStateColor
        case KanteButton.Emphasis.Data: return KanteStyle.focusColor
        case KanteButton.Emphasis.Quiet: return hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
        default: return KanteStyle.textColor
        }
    }
    readonly property color kanteFrame: emphasis === KanteButton.Emphasis.Data
        ? (hovered ? KanteStyle.focusColor : KanteStyle.tint(KanteStyle.focusColor, 0.55))
        : (visualFocus ? KanteStyle.focusColor : KanteStyle.frameColor)

    transform: Translate {
        x: control.down && KanteStyle.themed ? (control.raised ? 4 : 1) : 0
        y: control.down && KanteStyle.themed ? (control.raised ? 4 : 1) : 0
    }

    // Hard shadow (raised): a second cut shape 4 px down and right.
    KantePolygon {
        z: -2
        x: 4
        y: 4
        width: control.width
        height: control.height
        visible: KanteStyle.themed && control.raised && !control.down
        fillColor: KanteStyle.tint(KanteStyle.strongTextColor, 0.2)
        cutTopRight: control.cut + control.grow
    }

    KantePolygon {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed && control.emphasis !== KanteButton.Emphasis.Quiet
        opacity: control.enabled ? 1 : 0.45
        fillColor: control.kanteFill
        strokeColor: control.filled ? "transparent" : control.kanteFrame
        strokeWidth: control.filled ? 0 : 1
        cutTopRight: control.cut + control.grow
        cutBottomLeft: control.filled ? control.cut + control.grow : 0
    }

    // Quiet: no frame, only a ground on hover.
    Rectangle {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed && control.emphasis === KanteButton.Emphasis.Quiet
        color: (control.hovered || control.down) ? KanteStyle.sunkenColor : "transparent"
    }

    // Focus ring inside the shape.
    KantePolygon {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed && control.visualFocus
        strokeColor: control.filled ? KanteStyle.accentForegroundColor : KanteStyle.focusColor
        strokeWidth: 2
        inset: 3
        cutTopRight: Math.max(0, control.cut + control.grow - 3)
        cutBottomLeft: control.filled ? Math.max(0, control.cut + control.grow - 3) : 0
    }

    RowLayout {
        id: kanteContent
        visible: KanteStyle.themed
        x: control.leftPadding + Math.max(0, (control.availableWidth - width) / 2)
        y: control.topPadding
        width: Math.min(implicitWidth, control.availableWidth)
        height: control.availableHeight
        spacing: Math.max(control.spacing, Kirigami.Units.smallSpacing)
        opacity: control.enabled ? 1 : 0.5

        KanteLoader {
            visible: control.busy
            Layout.alignment: Qt.AlignVCenter
            color: control.kanteInk
            size: KanteStyle.unit(5)
        }

        Kirigami.Icon {
            readonly property var iconSource: control.icon.name !== "" ? control.icon.name : control.icon.source
            visible: !control.busy && control.display !== T.AbstractButton.TextOnly && String(iconSource).length > 0
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignVCenter
            source: iconSource
            color: control.kanteInk
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

    // Kante's uppercase label is wider than the style's: size for it.
    Binding {
        target: control
        property: "implicitWidth"
        value: Math.max(control.implicitBackgroundWidth + control.leftInset + control.rightInset,
                        kanteContent.implicitWidth + control.leftPadding + control.rightPadding)
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
    // 32 / 40 / 48 px, like the web buttons.
    Binding {
        target: control
        property: "implicitHeight"
        value: control.size === KanteButton.Size.Small ? KanteStyle.heightSmall
            : (control.size === KanteButton.Size.Large ? KanteStyle.heightLarge : KanteStyle.heightMedium)
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
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
    Binding {
        target: control
        property: "font"
        value: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * (control.size === KanteButton.Size.Small ? 0.9 : 1))
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
