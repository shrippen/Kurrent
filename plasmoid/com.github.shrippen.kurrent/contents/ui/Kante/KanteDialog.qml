import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Dialog.
 *   System  a plain dialog (unchanged).
 *   Kante   nearly opaque panel with cut top-right and bottom-left corners, an accent bar
 *           on top, an uppercase title, Kante colors inside and Kante
 *           buttons in the footer (the accept button filled).
 */
QQC2.Dialog {
    id: control

    /** Color of the bar on top in Kante (accent; negative for destructive questions). */
    property color kanteBarColor: KanteStyle.accentColor

    KanteScope { target: control.contentItem }

    // Not children: only handed to background/header/footer while Kante is on.
    readonly property Item kanteBackground: KanteCard {
        color: KanteStyle.dialogColor
        barColor: control.kanteBarColor
        chamferBottom: KanteStyle.chamfer
    }

    readonly property Item kanteHeader: QQC2.Label {
        visible: control.title.length > 0
        text: control.title
        font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.2)
        color: KanteStyle.strongTextColor
        elide: Text.ElideRight
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        topPadding: control.topPadding + 3
    }

    readonly property Item kanteFooter: QQC2.DialogButtonBox {
        visible: count > 0
        standardButtons: control.standardButtons
        alignment: Qt.AlignRight
        spacing: Kirigami.Units.smallSpacing
        padding: control.padding
        background: null
        delegate: KanteButton {
            emphasis: QQC2.DialogButtonBox.buttonRole === QQC2.DialogButtonBox.AcceptRole
                      ? KanteButton.Emphasis.Primary : KanteButton.Emphasis.Normal
        }
    }

    // The dim behind the dialog is Kante's scrim role (best effort: only when the style
    // provides the overlay attached object).
    Binding {
        target: control.QQC2.Overlay
        property: "modal"
        value: control.kanteScrim
        when: KanteStyle.themed && control.QQC2.Overlay !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    readonly property Component kanteScrim: Component { Rectangle { color: KanteStyle.scrimColor } }
    Binding {
        target: control
        property: "background"
        value: control.kanteBackground
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: control
        property: "header"
        value: control.kanteHeader
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: control
        property: "footer"
        value: control.kanteFooter
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
