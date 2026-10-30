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
 * Accept button (Kante 1.43, from lmix): `acceptText` names it after what it does ("Add
 * input" instead of OK), `acceptEnabled` locks it while the form is incomplete (left unset,
 * the button's own `enabled` stays as the app bound it). Both hold
 * for the footer of every style, also after a switch at run time (Kante has its own footer;
 * a text or lock set on the button itself was lost there).
 * Size (Kante 1.55, from lmix): `size` Small, Medium or Large is 24, 36 or 48 grid units
 * wide and at most 90 % of the window, also in height (taller content scrolls in the app's
 * own ScrollView; the dialog does not clip it); Fit (default) sizes to the content as
 * before.
 * Destructive (Kante 1.55, from lmix): a question whose yes removes or resets something:
 * the bar on top and the accept button in the negative colour, Cancel before it; the
 * button says what goes (`acceptText: "Remove bus"`). In the Kante style only: System and
 * Kante Light keep the platform's dialog and button order.
 * Since 1.55 `acceptText` also holds when the button box sets its standard texts again
 * (a language change, also the one at start with the app's translations): it read "OK"
 * in German before.
 */
QQC2.Dialog {
    id: control

    enum Size { Fit, Small, Medium, Large }
    /** Width by step (see above); Fit: the content's. */
    property int size: KanteDialog.Size.Fit
    /** The yes removes or resets something (see above). */
    property bool destructive: false
    /** Color of the bar on top in Kante (accent; negative for destructive questions). */
    property color kanteBarColor: destructive ? KanteStyle.negativeTextColor : KanteStyle.accentColor

    /** Width of `size` in pixels, 0 for Fit. */
    readonly property real sizeWidth: size === KanteDialog.Size.Small ? Kirigami.Units.gridUnit * 24
        : size === KanteDialog.Size.Medium ? Kirigami.Units.gridUnit * 36
        : size === KanteDialog.Size.Large ? Kirigami.Units.gridUnit * 48 : 0
    // The window, not the parent item (a dialog may hang on a small one); no limit
    // before it has one.
    readonly property real kanteRoomWidth: control.parent && control.parent.Window.width > 0 ? control.parent.Window.width : Infinity
    readonly property real kanteRoomHeight: control.parent && control.parent.Window.height > 0 ? control.parent.Window.height : Infinity
    // Only for a size step: a width or height set here counts as the app's, and Qt no longer
    // fits a Fit dialog taller than the window into it. Back to Fit they are reset, not
    // restored: a restored value would count as the app's too.
    Binding on width {
        when: control.sizeWidth > 0
        value: Math.min(control.sizeWidth, control.kanteRoomWidth * 0.9)
        restoreMode: Binding.RestoreNone
    }
    Binding on height {
        when: control.sizeWidth > 0
        value: Math.min(control.implicitHeight, control.kanteRoomHeight * 0.9)
        restoreMode: Binding.RestoreNone
    }
    onSizeWidthChanged: {
        if (sizeWidth === 0) {
            width = undefined
            height = undefined
        }
    }
    /** Text of the accept button (Ok, Save, Apply, Yes); "": the standard one. */
    property string acceptText: ""
    /** The accept button can be pressed; undefined (default): Kante leaves `enabled` alone,
     *  so a dialog that binds it itself keeps its binding. */
    property var acceptEnabled: undefined
    // The standard texts of the buttons renamed so far, to give them back: [[button, text]].
    property var standardTexts: []
    // The buttons acceptEnabled has set (each footer has its own), to free them all when
    // acceptEnabled is unset again.
    property var lockedButtons: []

    /** The accept button of the footer shown now, or null. */
    function acceptButton() {
        for (const b of [QQC2.Dialog.Ok, QQC2.Dialog.Save, QQC2.Dialog.Apply, QQC2.Dialog.Yes]) {
            const button = standardButton(b)
            if (button) {
                return button
            }
        }
        return null
    }
    function applyAccept() {
        const button = acceptButton()
        if (!button) {
            return
        }
        let kept = standardTexts.find(pair => pair[0] === button)
        if (acceptText.length > 0) {
            if (!kept) {
                // The button, its standard text, the name set last.
                kept = [button, button.text, ""]
                standardTexts.push(kept)
                // The button box sets the standard texts again when the language changes
                // (at start, once the app's translations are in): the name comes back on
                // top, and the new standard text is the one to give back.
                button.textChanged.connect(() => {
                    if (control.acceptText.length > 0 && button.text !== control.acceptText) {
                        kept[1] = button.text
                        button.text = control.acceptText
                    }
                })
            } else if (button.text !== acceptText && button.text !== kept[2]) {
                // Its standard text may have changed while unset (a language change); the
                // name set last is no standard text.
                kept[1] = button.text
            }
            kept[2] = acceptText
            button.text = acceptText
        } else if (kept) {
            button.text = kept[1]
        }
        if (acceptEnabled !== undefined) {
            button.enabled = !!acceptEnabled
            if (lockedButtons.indexOf(button) < 0) {
                lockedButtons.push(button)
            }
        } else if (lockedButtons.length > 0) {
            // Unset again: every button it set is free as before Kante touched it, also
            // the footer of a style not shown now.
            for (const b of lockedButtons) {
                b.enabled = true
            }
            lockedButtons = []
        }
    }
    onAcceptTextChanged: applyAccept()
    onAcceptEnabledChanged: applyAccept()
    onStandardButtonsChanged: Qt.callLater(applyAccept)
    Component.onCompleted: applyAccept()

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
        // Cancel before the red button (lmix rule 1): whoever reads from the left meets
        // the way out first.
        Binding on buttonLayout {
            when: control.destructive
            value: QQC2.DialogButtonBox.GnomeLayout
            restoreMode: Binding.RestoreBindingOrValue
        }
        // Yes accepts a yes/no question: red there too, as Ok.
        delegate: KanteButton {
            readonly property int role: QQC2.DialogButtonBox.buttonRole
            emphasis: role === QQC2.DialogButtonBox.AcceptRole
                      ? (control.destructive ? KanteButton.Emphasis.Destructive : KanteButton.Emphasis.Primary)
                      : role === QQC2.DialogButtonBox.YesRole && control.destructive
                      ? KanteButton.Emphasis.Destructive
                      : KanteButton.Emphasis.Normal
        }
    }

    // Qt hides a replaced background, header or footer and does not show it again when
    // the platform's comes back (Kante -> Kante Light or System at run time, also when the
    // saved style is applied after start): the dialog stood without a ground. Shown again,
    // and the background takes the dialog's size again.
    function kanteRestored(item, own) {
        if (KanteStyle.themed || !item || item === own) {
            return false
        }
        item.visible = true
        return true
    }
    onBackgroundChanged: {
        if (kanteRestored(background, kanteBackground)) {
            background.width = Qt.binding(() => control.width)
            background.height = Qt.binding(() => control.height)
        }
    }
    onHeaderChanged: kanteRestored(header, kanteHeader)
    onFooterChanged: {
        kanteRestored(footer, kanteFooter)
        // The other footer has its own buttons: name and lock them too.
        Qt.callLater(applyAccept)
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
