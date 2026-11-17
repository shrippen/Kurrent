import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Hands the Kante colors to `target`'s Kirigami.Theme, so Plasma and
 * Kirigami controls below it (labels, check boxes, spin boxes, combo
 * boxes, icons) follow Kante too. Does nothing in the System style: when
 * Kante is switched off the colors are reset and the target inherits again.
 *
 * Place one inside the popup root and inside each popup/dialog (popups do
 * not inherit the theme of the item that opens them).
 *
 * Disabled items (1.51): Kirigami gives a disabled item a colour table of its own in the
 * platform's colours, whatever its parents set. In Kante on a light system a disabled drawer
 * entry stood at 1.7:1, a separator white on dark. In Kante the scope binds the roles on
 * each disabled item below `target` too (text in disabledTextColor) and hands them back to
 * the platform when Kante is switched off. An item with colours of its own keeps them. It
 * watches the subtree only once Kante is on.
 *
 * `popup` (1.51): a popup or drawer whose ground (`background`) lies beside `target`, its
 * content: the scope themes both. A Kirigami GlobalDrawer showed a white area below the
 * entries and "close sidebar" at 1.4:1.
 *   KanteScope { target: drawer.contentItem; popup: drawer }
 */
Item {
    id: scope

    required property Item target
    property QtObject popup: null
    /** KanteStyle role of the target's `backgroundColor` (the window role by default). */
    property string backgroundRole: "dialogColor"
    /**
     * Off: Kante off gives the platform's own colours back (undress), not the parent's. For a
     * target with a colour set of its own that does not inherit (Kirigami's toolbar, Header).
     */
    property bool restorePlatform: false
    /**
     * On: the items below the target are not watched while it is enabled (no sweep, one
     * connection). Only when the target is disabled they are swept: a disabled item has a colour
     * table of its own, so the whole subtree needs the roles then. For a target that is made
     * often and is disabled rarely (a Kirigami bar on each page).
     */
    property bool shallow: false
    readonly property var theme: target ? target.Kirigami.Theme : null
    readonly property Item ground: popup && popup.background ? popup.background : null
    readonly property var groundTheme: ground ? ground.Kirigami.Theme : null

    visible: false

    // Theme property -> KanteStyle role.
    readonly property var roles: ({
        textColor: "textColor",
        disabledTextColor: "disabledTextColor",
        backgroundColor: scope.backgroundRole,
        alternateBackgroundColor: "cardColor",
        highlightColor: "accentColor",
        highlightedTextColor: "accentForegroundColor",
        focusColor: "focusColor",
        hoverColor: "accentColor",
        linkColor: "infoColor",
        positiveTextColor: "positiveTextColor",
        neutralTextColor: "neutralTextColor",
        negativeTextColor: "negativeTextColor"
    })

    // Kante: detach the target and bind the roles (under the Plasma theme custom colors on an
    // inheriting theme do not reach the items below). Leaving Kante: stay detached and bind
    // each color live to the parent's theme, which behaves like inheriting and follows later
    // platform theme changes. Not a reset plus re-attach: under the Plasma theme undefined
    // stores an invalid color (#00000000), and re-attaching leaves the children on the old
    // colour table, so all text below turned invisible.
    function apply() {
        if (!theme || KanteStyle.materialStyle || KanteStyle.themed === applied) {
            return
        }
        bind(theme, target)
        if (groundTheme) {
            bind(groundTheme, ground)
        }
        applied = KanteStyle.themed
        if (applied) {
            if (!shallow) {
                sweep(target)
            } else {
                watchTarget()
            }
            return
        }
        undress()
    }

    // One detached theme: Kante's roles, or the live colours of its item's parent.
    function bind(t, item) {
        if (restorePlatform && !KanteStyle.themed) {
            unbind(t)
            return
        }
        for (const prop in roles) {
            t[prop] = Qt.binding(KanteStyle.themed ? roleBinding(roles[prop]) : parentBinding(item, prop))
        }
        t.inherit = false
    }

    // Kante off: the platform's colours again. Undefined drops the colour and leaves the
    // theme transparent until it syncs; a change of its colour group makes it sync now.
    function unbind(t) {
        for (const prop in roles) {
            t[prop] = undefined
        }
        const group = t.colorGroup
        t.colorGroup = group === Kirigami.Theme.Inactive ? Kirigami.Theme.Active : Kirigami.Theme.Inactive
        t.colorGroup = group
    }

    /** The colors are set by this scope (System never touches the target). */
    property bool applied: false

    function roleBinding(role) {
        return function() { return KanteStyle[role] }
    }

    /** The parent's live theme color (what `item` would inherit). */
    function parentBinding(item, prop) {
        return function() {
            const p = item ? item.parent : null
            return p ? p.Kirigami.Theme[prop] : Kirigami.Theme[prop]
        }
    }

    onThemeChanged: {
        applied = false
        apply()
    }
    onGroundThemeChanged: {
        applied = false
        apply()
    }
    Component.onCompleted: apply()

    Connections {
        target: KanteStyle
        function onThemedChanged() {
            if (scope) {
                scope.apply()
            }
        }
    }

    // ── Disabled items ──────────────────────────────────────────────────
    //
    //   target ── item ── item (enabled: false) ── item
    //                       theme: own table      theme: own table
    //                       ← dress: Kante roles   ← dress: Kante roles
    //
    // Each disabled item with a theme draws from a table of its own, so each one gets the
    // roles. Items are watched once (enabled, children); new children are looked at
    // together after the current event, not one by one.

    /**
     * Items the scope watches and items it dressed, by key (`String(item)` names its
     * address; the value tells an item from a later one at the same address). A JS Set of
     * items looks up linearly (0.5 s for the gallery), a WeakSet crashed the engine once
     * the items were gone. Gone items are cleared as the table doubles.
     */
    property var watched: ({})
    property int watchedCount: 0
    property int watchedKept: 0
    property var dressed: ({})
    /** Items with new children, looked at together. */
    property var pending: []

    // `item` and everything below it: watched, the disabled ones dressed.
    function sweep(item) {
        if (!item) {
            return
        }
        watch(item)
        check(item)
        const kids = item.children
        for (let i = 0; i < kids.length; i++) {
            sweep(kids[i])
        }
    }

    function known(item) {
        return watched[String(item)] === item
    }

    // One connection per signal: connected with the item as `this`, dropped first if there.
    function watch(item) {
        const key = String(item)
        if (watched[key] === item) {
            return
        }
        if (watchedCount > Math.max(2000, 2 * watchedKept)) {
            prune()
        }
        watched[key] = item
        watchedCount++
        item.enabledChanged.disconnect(item, itemEnabled)
        item.childrenChanged.disconnect(item, itemGrown)
        item.enabledChanged.connect(item, itemEnabled)
        item.childrenChanged.connect(item, itemGrown)
    }

    // Shallow: only the target's own `enabled` is watched; a disabled target is swept.
    function watchTarget() {
        target.enabledChanged.disconnect(scope, targetEnabled)
        target.enabledChanged.connect(scope, targetEnabled)
        targetEnabled()
    }

    function targetEnabled() {
        if (!applied || !target) {
            return
        }
        if (!target.enabled) {
            sweep(target)
            return
        }
        unwatchAll()
    }

    // Enabled again: the items are let go (the ones dressed keep their roles and keep their
    // `enabled` watch: their text colour follows it). The next time the target is disabled,
    // the sweep looks at them again.
    function unwatchAll() {
        const table = watched
        watched = {}
        watchedCount = 0
        watchedKept = 0
        pending = []
        for (const key in table) {
            const item = table[key]
            if (!alive(item)) {
                continue
            }
            if (dressed[key] !== item) {
                item.enabledChanged.disconnect(item, itemEnabled)
            }
            item.childrenChanged.disconnect(item, itemGrown)
        }
    }

    // Called with the item as `this`. The scope may go before the items (a popup torn down).
    function itemEnabled() {
        if (scope) {
            scope.check(this)
        }
    }
    function itemGrown() {
        if (scope) {
            scope.grown(this)
        }
    }

    // `item` is the target or still hangs below it (every sweep starts at the target).
    function below(item) {
        for (let p = item; p; p = p.parent) {
            if (p === target) {
                return true
            }
        }
        return false
    }

    // Reading a gone item throws.
    function alive(item) {
        try {
            return item !== null && item !== undefined && typeof item.enabled === "boolean"
        } catch (e) {
            return false
        }
    }

    function living(table) {
        const kept = {}
        for (const key in table) {
            if (alive(table[key])) {
                kept[key] = table[key]
            }
        }
        return kept
    }

    function prune() {
        watched = living(watched)
        watchedKept = Object.keys(watched).length
        watchedCount = watchedKept
        dressed = living(dressed)
    }

    function grown(item) {
        if (!applied) {
            return
        }
        // Once per item: a staff of hundreds of notes queued itself once per note, and the sweep
        // looked at its children that often (Kontra's notation view stood still for 2.7 s).
        if (pending.indexOf(item) < 0) {
            pending.push(item)
        }
        sweepLater.start()
    }
    // Deferred by a timer of the scope's own, not Qt.callLater: a delegate torn down right
    // after its content grew left the call behind in its gone context (1.53).
    Timer {
        id: sweepLater
        interval: 0
        // The garbage collector takes the scope's functions before the scope and this Timer.
        onTriggered: {
            if (typeof scope.sweepPending === "function") {
                scope.sweepPending()
            }
        }
    }

    // New children of the items in `pending`; the ones seen before are left alone.
    function sweepPending() {
        const list = pending
        pending = []
        for (let i = 0; i < list.length; i++) {
            const kids = alive(list[i]) ? list[i].children : []
            for (let k = 0; k < kids.length; k++) {
                if (!known(kids[k])) {
                    sweep(kids[k])
                }
            }
        }
    }

    // A disabled item in Kante gets the roles; an item another scope detached, or one with
    // colours of its own, keeps them.
    function check(item) {
        if (!applied || !windowRoot) {
            return
        }
        // Taken apart (~QQuickItem drops its children, which are enabled again, and the items
        // below them): its theme reads a parent that is gone.
        if (!below(item)) {
            return
        }
        const key = String(item)
        if (dressed[key] === item) {
            // Dressed before: only the text role follows enabled (no binding on item.enabled: it
            // flips as the window goes and would write to a theme in teardown).
            const dt = item.Kirigami.Theme
            dt.textColor = Qt.binding(roleBinding(item.enabled ? "textColor" : "disabledTextColor"))
            return
        }
        if (item.enabled) {
            return
        }
        const t = item.Kirigami.Theme
        // Without a window there is no probe to judge by: the item waits for one.
        if (!t.inherit || !windowRoot || ownColours(t)) {
            return
        }
        for (const prop in roles) {
            t[prop] = Qt.binding(roleBinding(roles[prop]))
        }
        t.textColor = Qt.binding(roleBinding("disabledTextColor"))
        dressed[key] = item
    }

    // A disabled item of the same colour set: the platform's colours, what a theme without
    // colours of its own shows.
    // It sits in the window, outside the scope and visible (size 0): the Plasma theme gives a
    // hidden item no colours.
    property Item probe: null
    readonly property Component probeComponent: Component {
        Item {
            enabled: false
        }
    }
    // A popup's content gets its window on opening: then its disabled items are looked at.
    // Looked up through the target (1.81): a scope held as a property (a skin's) has no window of its
    // own; the scope's is the fallback for a target without one.
    readonly property Item windowRoot: target && target.Window.contentItem ? target.Window.contentItem
                                                                           : scope.Window.contentItem
    // Only towards a window: resweep() does nothing without one, and a Timer started in a teardown
    // makes Qt tick every running animation at once (ColumnView then disabled pages being deleted).
    onWindowRootChanged: {
        if (windowRoot) {
            resweepLater.start()
        }
    }
    Timer {
        id: resweepLater
        interval: 0
        // The garbage collector takes the scope's functions before the scope and this Timer.
        onTriggered: {
            if (typeof scope.resweep === "function") {
                scope.resweep()
            }
        }
    }
    // After the event: the themes below take the window's colours first.
    function resweep() {
        if (applied && windowRoot && (!shallow || !target.enabled)) {
            sweep(target)
        }
    }
    Component.onDestruction: {
        if (probe) {
            probe.destroy()
        }
    }

    // Colours the app set on the theme (review of #88: a red text was lost after Kante): a
    // colour that is neither the platform's for a disabled item nor Kante's.
    function ownColours(t) {
        if (!probe || probe.parent !== windowRoot) {
            if (probe) {
                probe.destroy()
            }
            probe = probeComponent.createObject(windowRoot)
        }
        if (!probe) {
            return false
        }
        const p = probe.Kirigami.Theme
        p.colorSet = t.colorSet
        for (const prop in roles) {
            if (!Qt.colorEqual(t[prop], p[prop]) && !Qt.colorEqual(t[prop], KanteStyle[roles[prop]])) {
                return true
            }
        }
        return false
    }

    // Kante off: the platform's colours again. Undefined drops the colour and leaves the
    // theme transparent until it syncs; a change of its colour group makes it sync now.
    function undress() {
        const table = dressed
        dressed = {}
        for (const key in table) {
            const item = table[key]
            if (!alive(item)) {
                continue
            }
            unbind(item.Kirigami.Theme)
        }
    }
}
