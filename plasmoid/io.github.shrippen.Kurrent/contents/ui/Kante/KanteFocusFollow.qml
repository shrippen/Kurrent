import QtQuick
import "."

/**
 * Keeps the keyboard focus in view (1.49, WCAG 2.4.7 / 2.4.11): a long page in a Flickable
 * (a ScrollView's, a Kirigami.ScrollablePage's) did not move when Tab went below its edge,
 * so the focus ring sat off screen (Kontra: settings, lessons at 200 %).
 *
 *   KanteFocusFollow { flickable: page.flickable }
 *
 * Whenever the window's focus moves to an item inside `flickable.contentItem`, the view
 * scrolls the least it can so that item, plus `margin`, is visible; an item taller than the
 * view shows its top. Focus taken by the mouse never moves the view: a button takes the focus on
 * press, and a scroll then would move it away from the pointer and lose the click. Rows and tiles
 * focus themselves from a tap and have no focusReason, so a pointer press in the flickable counts
 * too, until its release has been handled.
 */
QtObject {
    id: follow

    property Flickable flickable: null
    /** Room kept between the focused item and the view's edge. */
    property real margin: KanteStyle.unit(16)
    property bool enabled: true

    readonly property Item focusItem: flickable && flickable.Window.window
                                      ? flickable.Window.activeFocusItem : null

    onFocusItemChanged: reveal(focusItem)

    /** True from a press in the flickable until the events of its release are handled. */
    property bool pointing: false

    // Watches without grabbing, so taps and drags still reach the content. Made per flickable:
    // a handler declared here has no item to belong to.
    property Component pointerComponent: Component {
        PointHandler {
            acceptedButtons: Qt.AllButtons
            onActiveChanged: {
                if (active) {
                    follow.pointing = true
                } else {
                    // A row focuses itself on release; that focus change comes before this call.
                    Qt.callLater(function () { follow.pointing = false })
                }
            }
        }
    }
    property PointHandler pointer: null

    onFlickableChanged: {
        if (pointer) {
            pointer.destroy()
        }
        pointer = flickable ? pointerComponent.createObject(flickable) : null
    }
    Component.onCompleted: {
        if (flickable && !pointer) {
            pointer = pointerComponent.createObject(flickable)
        }
    }

    /** True when `item` lies in the flickable's content. */
    function contains(item) {
        for (let p = item; p; p = p.parent) {
            if (p === flickable.contentItem) {
                return true
            }
        }
        return false
    }

    /** contentY that shows `top`..`bottom` (content coordinates) with the least move. */
    function targetY(top, bottom) {
        const view = flickable.height
        const y = flickable.contentY
        let next = y
        if (bottom - top + 2 * margin > view || top - margin < y) {
            next = top - margin
        } else if (bottom + margin > y + view) {
            next = bottom + margin - view
        }
        const low = flickable.originY - flickable.topMargin
        const high = Math.max(low, flickable.originY + flickable.contentHeight + flickable.bottomMargin - view)
        return Math.max(low, Math.min(high, next))
    }

    function reveal(item) {
        if (!enabled || !item || !flickable || !contains(item)) {
            return
        }
        if (pointing || item.focusReason === Qt.MouseFocusReason) {
            return
        }
        const p = item.mapToItem(flickable.contentItem, 0, 0)
        flickable.contentY = targetY(p.y, p.y + item.height)
    }
}
