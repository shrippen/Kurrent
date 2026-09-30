import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Kante look for a Kirigami or QQC2 dialog: place one inside the dialog with
 * `dialog: <id>`. Replaces the background with a cut-corner card (top-right and
 * bottom-left), the title strip with an uppercase title and the standard buttons with
 * Kante buttons, and hands the Kante colors to the dialog's content; does nothing in
 * the System style.
 *
 * A QtObject, not an Item: as a visual child of a Kirigami.Dialog an Item would
 * count as dialog content and size its ScrollView to 0.
 */
QtObject {
    id: skin

    required property var dialog

    readonly property KanteScope scope: KanteScope { target: skin.dialog ? skin.dialog.contentItem : null }

    // Not a child: only handed to `background` while Kante is on.
    readonly property Item kanteBackground: KanteCard {
        color: KanteStyle.dialogColor
        barColor: KanteStyle.accentColor
        chamferBottom: KanteStyle.chamfer
    }

    readonly property Binding backgroundBinding: Binding {
        target: skin.dialog
        property: "background"
        value: skin.kanteBackground
        when: KanteStyle.themed && skin.dialog !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Qt hides a replaced background and does not show it again when it comes back
    // (Kirigami's ShadowedRectangle stayed invisible and at the old size after Kante -> System).
    readonly property Connections restoreBackground: Connections {
        target: KanteStyle
        function onThemedChanged() {
            if (KanteStyle.themed) {
                return
            }
            Qt.callLater(function() {
                var bg = skin.dialog ? skin.dialog.background : null
                if (!bg) {
                    return
                }

                bg.visible = true
                bg.width = Qt.binding(() => skin.dialog.width)
                bg.height = Qt.binding(() => skin.dialog.height)
            })
        }
    }

    // Title strip: without it the platform's light strip stays on the dark card.
    readonly property Item kanteHeader: QQC2.Label {
        visible: !!skin.dialog && skin.dialog.title.length > 0
        text: skin.dialog ? skin.dialog.title : ""
        font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.2)
        color: KanteStyle.strongTextColor
        elide: Text.ElideRight
        leftPadding: skin.dialog ? skin.dialog.leftPadding : 0
        rightPadding: skin.dialog ? skin.dialog.rightPadding : 0
        topPadding: skin.dialog ? skin.dialog.topPadding + 3 : 0
    }

    readonly property Binding headerBinding: Binding {
        target: skin.dialog
        property: "header"
        value: skin.kanteHeader
        when: KanteStyle.themed && skin.dialog !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    readonly property Item kanteFooter: QQC2.DialogButtonBox {
        visible: count > 0
        standardButtons: skin.dialog ? skin.dialog.standardButtons : 0
        alignment: Qt.AlignRight
        spacing: Kirigami.Units.smallSpacing
        padding: skin.dialog ? skin.dialog.padding : 0
        background: null
        delegate: KanteButton {
            emphasis: QQC2.DialogButtonBox.buttonRole === QQC2.DialogButtonBox.AcceptRole
                      ? KanteButton.Emphasis.Primary : KanteButton.Emphasis.Normal
        }
    }

    readonly property Binding footerBinding: Binding {
        target: skin.dialog
        property: "footer"
        value: skin.kanteFooter
        when: KanteStyle.themed && skin.dialog !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
