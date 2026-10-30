import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "."

/**
 * Menu item (Kante 1.43, from lmix): a QQC2.MenuItem with an icon, the text, a value on the
 * right and the shortcut as a keycap. Put it in a menu with `KantePopupSkin`; group items
 * under a `KanteMenuSection`.
 *   icon.name / icon.source  the icon (Kirigami.Icon, drawn in the text colour)
 *   iconRoom      an item without icon keeps the icon's room (texts of a menu line up)
 *   valueText     the current value of a setting the item opens, e.g. "Hold last frame"
 *   shortcutText  the shortcut as shown; empty: the action's shortcut (native text)
 *   destructive   the negative text colour (Remove, Factory settings)
 * Kante and Kante Light: the shortcut as `KanteKeycap`, the value in mono, small and muted.
 * System: the shortcut as plain text as the platform draws it. Indicator (check), arrow
 * (sub menu), highlight and background stay the platform's.
 */
QQC2.MenuItem {
    id: item

    property string valueText: ""
    property string shortcutText: ""
    property bool destructive: false
    /** Keep the icon's room without an icon, so the texts of a menu with icons line up. */
    property bool iconRoom: false

    readonly property string shownShortcut: shortcutText.length > 0 ? shortcutText : (actionShortcut.nativeText || "")
    readonly property bool hasIcon: icon.name !== "" || icon.source.toString() !== ""
    // On the platform's highlight (hover, keyboard, press) its ink, also for destructive items:
    // dark text or red on Breeze's blue reads too faintly.
    readonly property color ink: !enabled ? Kirigami.Theme.disabledTextColor
                                 : (highlighted || pressed) ? Kirigami.Theme.highlightedTextColor
                                 : destructive ? KanteStyle.negativeTextColor
                                 : Kirigami.Theme.textColor

    /** The value's label, for tests. */
    readonly property alias valueLabel: valueLabel

    Accessible.name: text
    Accessible.description: valueText

    Shortcut {
        id: actionShortcut
        enabled: false
        sequence: item.action && item.action.shortcut !== undefined ? item.action.shortcut : ""
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing * 2

        // Room of the check indicator, as the platform keeps it.
        Item {
            Layout.preferredWidth: item.checkable && item.indicator ? item.indicator.width : 0
            visible: item.checkable
        }
        Kirigami.Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            visible: item.hasIcon || item.iconRoom
            source: item.icon.name !== "" ? item.icon.name : item.icon.source
            color: item.ink
            isMask: true
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: item.text
            font: item.font
            color: item.ink
            elide: Text.ElideRight
        }
        QQC2.Label {
            id: valueLabel
            Layout.alignment: Qt.AlignVCenter
            visible: item.valueText.length > 0
            text: item.valueText
            font: KanteStyle.active ? KanteStyle.monoFont(KanteStyle.smallFont.pointSize) : KanteStyle.smallFont
            // Muted on the menu, the highlight's ink on the highlight (muted reads faintly there).
            color: (item.highlighted || item.pressed) ? item.ink : KanteStyle.mutedTextColor
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 9
        }
        KanteKeycap {
            Layout.alignment: Qt.AlignVCenter
            visible: KanteStyle.active && item.shownShortcut.length > 0
            text: item.shownShortcut
        }
        QQC2.Label {
            Layout.alignment: Qt.AlignVCenter
            visible: !KanteStyle.active && item.shownShortcut.length > 0
            text: item.shownShortcut
            font: item.font
            color: item.ink
        }
        // Room of the sub menu arrow.
        Item {
            Layout.preferredWidth: item.subMenu && item.arrow ? item.arrow.width : 0
            visible: item.subMenu !== null
        }
    }
}
