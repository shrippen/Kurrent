import QtQuick
import "."

/**
 * Focus trap (1.51, WCAG 2.1.2 / 2.4.3) for a sheet or overlay that lives in the page, not
 * in a window dialog (so it is part of screenshots). Kontra's run summary: Tab went on into the
 * sidebar behind it, and the screen reader read the page under it.
 *
 *   KanteFocusTrap { area: sheet; returnTo: playButton; behind: [pageContent] }
 *
 * While `active` (default: while `area` is visible):
 *   - the focus moves to `first` (default: the area's first stop in the focus chain);
 *   - Tab past the area's last stop goes to its first stop, Shift+Tab before the first stop
 *     to the last one (`first` only says where the focus lands, a stop before it stays
 *     reachable). The ends are tied with KeyNavigation, so the focus never touches what lies
 *     outside; the last stop is looked up again as the focus moves (rows shown, hidden);
 *   - the items in `behind` are disabled (`behindMode` Behind.Disable: no focus, no click)
 *     or hidden (Behind.Hide: screen readers do not read them either; for a sheet that
 *     covers them). Their own value or binding comes back afterwards.
 * Then the focus goes to `returnTo` (when it was in the area or got lost), and Tab leaves
 * the area as before. Earlier KeyNavigation of the two ends comes back too.
 */
QtObject {
    id: trap

    enum Behind {
        Disable,
        Hide
    }

    property Item area: null
    property Item first: null
    property Item returnTo: null
    property var behind: []
    property int behindMode: KanteFocusTrap.Behind.Disable
    property bool active: area ? area.visible : false
    readonly property bool trapped: active && area !== null

    readonly property Item focusItem: area && area.Window.window ? area.Window.activeFocusItem : null

    // The tied ends and what their KeyNavigation held before.
    property Item head: null
    property Item tail: null
    property Item headBacktab: null
    property Item tailTab: null

    // The items behind: disabled or hidden while trapped, restored after (RestoreBindingOrValue).
    readonly property Instantiator cover: Instantiator {
        model: trap.behind
        delegate: Binding {
            required property var modelData
            target: modelData
            property: trap.behindMode === KanteFocusTrap.Behind.Hide ? "visible" : "enabled"
            value: false
            when: trap.trapped
            restoreMode: Binding.RestoreBindingOrValue
        }
    }

    onTrappedChanged: {
        if (trapped) {
            Qt.callLater(enter)
            return
        }
        untie()
        Qt.callLater(leave)
    }
    Component.onCompleted: {
        if (trapped) {
            Qt.callLater(enter)
        }
    }

    // Each time the focus moves in the area: its stops may have changed.
    onFocusItemChanged: {
        if (trapped && focusItem && inside(focusItem)) {
            tie()
        }
    }

    function inside(item) {
        for (let p = item; p; p = p.parent) {
            if (p === area) {
                return true
            }
        }
        return false
    }

    // Where the focus lands on opening: `first`, or the area's first stop.
    function firstStop() {
        return first ? first : areaStart()
    }

    // The area's first stop: the focus chain from the area runs through its children first.
    function areaStart() {
        const next = area ? area.nextItemInFocusChain(true) : null
        return next && inside(next) ? next : null
    }

    // The area's last stop in the focus chain, starting from `start`.
    function lastStop(start) {
        let item = start
        for (let next = item.nextItemInFocusChain(true), n = 0; next && next !== start && inside(next) && n < 1000;
             next = next.nextItemInFocusChain(true), n++) {
            item = next
        }
        return item
    }

    function enter() {
        if (!trapped) {
            return
        }
        const start = firstStop()
        if (!start) {
            return
        }
        start.forceActiveFocus(Qt.TabFocusReason)
        tie()
    }

    // Ties the area's last stop to its first and back; keeps what the ends held before.
    function tie() {
        const start = areaStart()
        if (!start) {
            return
        }
        const last = lastStop(start)
        if (head === start && tail === last) {
            return
        }
        untie()
        head = start
        tail = last
        headBacktab = start.KeyNavigation.backtab
        tailTab = last.KeyNavigation.tab
        last.KeyNavigation.tab = start
        start.KeyNavigation.backtab = last
    }

    function untie() {
        if (tail) {
            tail.KeyNavigation.tab = tailTab
        }
        if (head) {
            head.KeyNavigation.backtab = headBacktab
        }
        head = null
        tail = null
        headBacktab = null
        tailTab = null
    }

    // Closed: the focus goes to `returnTo` when it sat in the area, on a hidden item or nowhere.
    function leave() {
        if (trapped || !returnTo) {
            return
        }
        const f = focusItem
        if (f && !inside(f) && f.visible && f.enabled) {
            return
        }
        returnTo.forceActiveFocus(Qt.TabFocusReason)
    }
}
