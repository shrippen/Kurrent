import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Popover (Kante 1.43, from lmix): a card that opens at a button and holds a few settings
 * (segments, switches), such as a "View" button over a list. Lighter than a dialog: no
 * title bar and no buttons, every change applies at once; Esc or a click outside closes it.
 * Call `openAt(item)`: it opens below the item, or above when there is no room below, and
 * stays inside the window.
 *   title    an optional heading (KanteSectionLabel) over the content
 * The content goes inside as children (a ColumnLayout is the usual one). Kante: the dialog
 * colour with the focus bar on top and the cut corner (`KantePopupSkin`); Kante Light and
 * System: the platform's popup background.
 */
QQC2.Popup {
    id: popover

    property string title: ""
    property Item anchorItem: null
    default property alias content: column.data

    /** When it last closed: a press on its own button closes it, the click then must not reopen it. */
    property real closedAt: 0
    onAboutToHide: closedAt = Date.now()

    function openAt(item) {
        if (item === anchorItem && Date.now() - closedAt < Qt.styleHints.mouseDoubleClickInterval) {
            return
        }
        anchorItem = item
        // Content changed just before (another item's settings, rows shown or hidden): the
        // column lays it out only on the next frame, measured now it has the size before.
        column.forceLayout()
        // In scene coordinates, against the window: below the item, above when there is no
        // room below and more above, shifted to stay inside.
        const win = item.Window.window
        const sceneW = win ? win.width : item.width
        const sceneH = win ? win.height : item.height
        const gap = KanteStyle.unit(2)
        const margin = KanteStyle.unit(4)
        const p = item.mapToItem(null, 0, 0)
        const w = implicitWidth
        const h = implicitHeight
        const below = sceneH - p.y - item.height - gap - margin
        const above = p.y - gap - margin
        const up = h > below && above > below
        const sx = Math.max(margin, Math.min(p.x, sceneW - margin - w))
        const sy = up ? Math.max(margin, p.y - gap - h) : p.y + item.height + gap
        // Positioned relative to the item: the overlay need not sit at the scene's origin yet.
        parent = item
        const local = item.mapFromItem(null, sx, sy)
        x = local.x
        y = local.y
        open()
    }

    padding: KanteStyle.unit(14)
    topPadding: KanteStyle.unit(14) + (KanteStyle.themed ? KanteStyle.unit(3) : 0)
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    // Qt keeps the popover this far inside the window.
    margins: KanteStyle.unit(4)

    // A property, not a child: children go into the content column.
    readonly property Item skin: KantePopupSkin {
        popup: popover
    }

    // As wide as the title too: the Column counts its width, which follows the Column.
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            Math.max(column.implicitWidth, titleLabel.visible ? titleLabel.implicitWidth : 0)
                            + leftPadding + rightPadding)
    contentItem: Column {
        id: column
        spacing: KanteStyle.unit(10)

        KanteSectionLabel {
            id: titleLabel
            visible: popover.title.length > 0
            text: popover.title
            width: parent.width
        }
    }
}
