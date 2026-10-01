import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
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

    // Title strip (a Kirigami.PromptDialog has none: it shows the title in its content): without it the platform's light strip stays on the dark card.
    readonly property Item kanteHeader: QQC2.Label {
        visible: !!skin.dialog && skin.dialog.title.length > 0
        text: skin.dialog ? skin.dialog.title : ""
        font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.2)
        color: KanteStyle.strongTextColor
        // No elide: the dialog takes its width from the title (implicitHeaderWidth), and an
        // elided title's size follows the dialog's again, a binding loop with Kirigami 6.24.
        // A title wider than the dialog's maximum is clipped.
        clip: true
        leftPadding: skin.dialog ? skin.dialog.leftPadding : 0
        rightPadding: skin.dialog ? skin.dialog.rightPadding : 0
        topPadding: skin.dialog ? skin.dialog.topPadding + 3 : 0
    }

    readonly property Binding headerBinding: Binding {
        target: skin.dialog
        property: "header"
        value: skin.kanteHeader
        when: KanteStyle.themed && skin.dialog !== null && !skin.dialog.hasOwnProperty("subtitle")
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Standard buttons and, for a Kirigami.Dialog, its customFooterActions as Kante buttons.
    readonly property Item kanteFooter: QQC2.Control {
        visible: box.count > 0 || actions.count > 0
        padding: skin.dialog ? skin.dialog.padding : 0
        leftPadding: Kirigami.Units.largeSpacing
        rightPadding: Kirigami.Units.largeSpacing
        bottomPadding: Kirigami.Units.largeSpacing

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Item { Layout.fillWidth: true }

            QQC2.DialogButtonBox {
                id: box
                visible: count > 0
                standardButtons: skin.dialog ? skin.dialog.standardButtons : 0
                alignment: Qt.AlignRight
                spacing: Kirigami.Units.smallSpacing
                padding: 0
                background: null
                delegate: KanteButton {
                    Layout.alignment: Qt.AlignVCenter
                    emphasis: QQC2.DialogButtonBox.buttonRole === QQC2.DialogButtonBox.AcceptRole
                              ? KanteButton.Emphasis.Primary : KanteButton.Emphasis.Normal
                }
            }

            Repeater {
                id: actions
                model: skin.dialog && skin.dialog.customFooterActions ? skin.dialog.customFooterActions : []
                delegate: KanteButton {
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    text: modelData.text
                    visible: modelData.visible
                    enabled: modelData.enabled
                    onClicked: modelData.trigger()
                }
            }
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
