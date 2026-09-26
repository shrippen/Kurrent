import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "."

/**
 * Push button.
 *   System  a plain button of the active style (unchanged).
 *   Kante   square, uppercase Rajdhani, thin frame; `emphasis` fills it with
 *           the accent (primary action) or the negative color (stop, delete).
 *
 * In Kante the style's frame and content stay (they size the button) but are
 * hidden; frame, icon and text are drawn here.
 */
QQC2.Button {
    id: control

    enum Emphasis {
        Normal,
        Primary,
        Destructive
    }

    property int emphasis: KanteButton.Emphasis.Normal

    readonly property bool filled: emphasis !== KanteButton.Emphasis.Normal
    readonly property color kanteFill: emphasis === KanteButton.Emphasis.Primary ? KanteStyle.accentColor
        : (emphasis === KanteButton.Emphasis.Destructive ? KanteStyle.negativeTextColor : "transparent")
    readonly property color kanteInk: filled ? KanteStyle.accentForegroundColor : KanteStyle.textColor

    Rectangle {
        z: -1
        anchors.fill: parent
        visible: KanteStyle.themed
        opacity: control.enabled ? 1 : 0.45
        color: {
            if (control.filled) {
                return control.down ? Qt.darker(control.kanteFill, 1.15) : control.kanteFill
            }
            return (control.down || control.hovered || control.checked) ? KanteStyle.sunkenColor : "transparent"
        }
        border.width: control.filled ? 0 : 1
        border.color: control.visualFocus ? KanteStyle.accentColor : KanteStyle.frameColor
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

        Kirigami.Icon {
            readonly property var iconSource: control.icon.name !== "" ? control.icon.name : control.icon.source
            visible: control.display !== T.AbstractButton.TextOnly && String(iconSource).length > 0
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
        value: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize)
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
