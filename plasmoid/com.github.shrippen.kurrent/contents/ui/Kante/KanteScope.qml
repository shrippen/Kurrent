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
    readonly property var theme: target ? target.Kirigami.Theme : null
    readonly property Item ground: popup && popup.background ? popup.background : null
    readonly property var groundTheme: ground ? ground.Kirigami.Theme : null

    visible: false

    // Theme property -> KanteStyle role.
    readonly property var roles: ({
        textColor: "textColor",
        disabledTextColor: "disabledTextColor",
        backgroundColor: "dialogColor",
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
            sweep(target)
            return
        }
        undress()
    }

    // One detached theme: Kante's roles, or the live colours of its item's parent.
    function bind(t, item) {
        for (const prop in roles) {
            t[prop] = Qt.binding(KanteStyle.themed ? roleBinding(roles[prop]) : parentBinding(item, prop))
        }
        t.inherit = false
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
        function onThemedChanged() { scope.apply() }
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
        pending.push(item)
        sweepLater.start()
    }
    // Deferred by a timer of the scope's own, not Qt.callLater: a delegate torn down right
    // after its content grew left the call behind in its gone context (1.53).
    Timer {
        id: sweepLater
        interval: 0
        onTriggered: scope.sweepPending()
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
        if (!applied || item.enabled) {
            return
        }
        const key = String(item)
        if (dressed[key] === item) {
            return
        }
        const t = item.Kirigami.Theme
        // Without a window there is no probe to judge by: the item waits for one.
        if (!t.inherit || !scope.Window.contentItem || ownColours(t)) {
            return
        }
        for (const prop in roles) {
            t[prop] = Qt.binding(prop === "textColor" ? enabledText(item) : roleBinding(roles[prop]))
        }
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
    readonly property Item windowRoot: scope.Window.contentItem
    onWindowRootChanged: resweepLater.start()
    Timer {
        id: resweepLater
        interval: 0
        onTriggered: scope.resweep()
    }
    // After the event: the themes below take the window's colours first.
    function resweep() {
        if (applied && windowRoot) {
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
        if (!probe || probe.parent !== scope.Window.contentItem) {
            if (probe) {
                probe.destroy()
            }
            probe = probeComponent.createObject(scope.Window.contentItem)
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

    // An item that is enabled again keeps the binding: then the enabled text colour.
    function enabledText(item) {
        return function() { return item.enabled ? KanteStyle.textColor : KanteStyle.disabledTextColor }
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
            const t = item.Kirigami.Theme
            for (const prop in roles) {
                t[prop] = undefined
            }
            const group = t.colorGroup
            t.colorGroup = group === Kirigami.Theme.Inactive ? Kirigami.Theme.Active : Kirigami.Theme.Inactive
            t.colorGroup = group
        }
    }
}
