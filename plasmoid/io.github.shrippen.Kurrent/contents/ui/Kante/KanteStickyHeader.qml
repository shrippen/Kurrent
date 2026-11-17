import QtQuick
import "."

/**
 * A page header that stays at the top while the page scrolls under it: the page's title and a
 * bar of tabs, one per section (scrollspy). A translucent glass layer (KanteGlassPanel): the
 * content shimmers through blurred; without a GPU the tint is plain and denser.
 *
 *   at the top                                 scrolled a little
 *   ┌─────────────────────────────┐            ┌─────────────────────────────┐
 *   │ EINSTELLUNGEN               │            │ EINSTELLUNGEN               │
 *   │                             │            │ Audio  Instrument  Anzeige  │
 *   │ Audio  Instrument  Anzeige  │            │ ▔▔▔▔▔                       │
 *   │ ▔▔▔▔▔                       │            └─────────────────────────────┘
 *   └─────────────────────────────┘
 *
 * Place it as a sibling above the page's flickable (never inside it), anchored left, right and
 * top, and reserve `expandedHeight` at the top of the content, so nothing starts under the
 * header. Beyond `shrinkAt` of scrolling it shrinks to `compactHeight` (smaller title, less
 * padding), animated with `KanteStyle.animate`, otherwise at once. The sections are items in
 * the flickable's content (`targets`, one per entry of `model`, usually KanteSettingGroups).
 *   flickable     the scrolled view (a Flickable, a Kirigami page's `flickable`); also the blur's source
 *   title, model  the title and the tabs' labels
 *   targets       the section item of each tab (bind in something that notifies, such as a
 *                 Repeater's `count`: `itemAt()` alone does not)
 *   currentIndex  the tab of the section at the top; follows the scrolling, a tap scrolls there
 *   scrollTo(i)   scrolls section i just below the header, then moves the keyboard focus to its
 *                 first control (as a Tab from its top would, not out of the section)
 * The tab bar is a KanteTabBar with the Underline look, `activation` Manual: Left/Right only
 * move the selection (the bar keeps focus, nothing scrolls yet); Return, Enter, Space or a tap
 * scroll there and move the focus to the section (`scrollTo`). The scrollspy stands aside from
 * a Manual arrow move until it is acted on, the user scrolls by themselves or the bar loses the
 * focus, so it cannot pull the selection away from under the arrows. After `scrollTo` the
 * jumped-to tab stays current until the page moves (`jumped`), also when the jump ends at the
 * page's bottom, where the last tab would otherwise win.
 * Pair it with `KanteFocusFollow { topInset: header.height }` so Tab does not hide the focus
 * under the header.
 */
Item {
    id: header

    /** The scrolled view. */
    property Flickable flickable: null
    property string title: ""
    property var model: []
    property var targets: []
    property int currentIndex: 0
    /** Screen readers hear this as the tab list's name. */
    property string tabsName: ""
    /** Space left and right of the title and the tabs. */
    property real sideMargin: KanteStyle.unit(16)
    /** Scrolled by this much (px) the header shrinks. */
    property real shrinkAt: KanteStyle.unit(40)
    /** Room between the header and the section a tab scrolls to. */
    property real gap: KanteStyle.unit(12)
    /** Off: never blur (a low-power setting). */
    property bool blurAllowed: true
    /** True on the software renderer. Writable for tests only. */
    property alias software: glass.software

    /** Height at the top of the page; reserve it at the top of the content. */
    readonly property real expandedHeight: topExpanded + bigText.height + gapExpanded + bar.implicitHeight
    /** Height once scrolled. */
    readonly property real compactHeight: topCompact + smallText.height + gapCompact + bar.implicitHeight
    readonly property bool compact: flickable !== null && flickable.contentY - flickable.originY > shrinkAt
    /** 0 at the top, 1 shrunk; the whole header follows it. */
    property real shrink: compact ? 1 : 0

    readonly property real topExpanded: KanteStyle.unit(16)
    readonly property real topCompact: KanteStyle.unit(6)
    readonly property real gapExpanded: KanteStyle.unit(10)
    readonly property real gapCompact: KanteStyle.unit(2)
    readonly property real pointExpanded: KanteStyle.defaultFont.pointSize * 1.6
    readonly property real pointCompact: KanteStyle.defaultFont.pointSize * 1.15

    function mix(a, b) {
        return a + (b - a) * shrink
    }

    height: mix(expandedHeight, compactHeight)
    z: 10
    Accessible.role: Accessible.Pane
    Accessible.name: title

    Behavior on shrink {
        NumberAnimation { duration: KanteStyle.animate ? KanteStyle.duration : 0; easing.type: Easing.OutCubic }
    }

    TextMetrics { id: bigText; font: KanteStyle.titleFont(header.pointExpanded); text: header.title }
    TextMetrics { id: smallText; font: KanteStyle.titleFont(header.pointCompact); text: header.title }

    // ── Scrollspy ────────────────────────────────────────────────────────
    // The tab of the last section whose top has passed the line under the header; at the very
    // end of the page the last one (the short sections at the end never reach the top).
    function sectionTop(item) {
        return item.mapToItem(flickable.contentItem, 0, 0).y
    }

    // True from a Manual arrow move until it is acted on (Return, Enter, Space, a tap) or the
    // user scrolls by themselves: while it holds, a stray contentY/contentHeight change (layout
    // settling, KanteFocusFollow) must not pull the arrow-picked tab away before they act on it.
    // Also cleared when the bar loses active focus (Tab out without Return): otherwise a later
    // programmatic scroll (KanteFocusFollow, no mouse involved) never clears it and the
    // underline stays stuck on the arrow-picked tab for the rest of the session.
    property bool browsing: false
    // True from `scrollTo` until the page actually scrolls away from where the jump landed: a
    // jump near the end of the page lands at the same clamped contentY the "last tab at the
    // end" rule below reacts to, which would otherwise override the jumped-to tab right away.
    property bool jumped: false
    property real jumpedAtY: 0

    function spy() {
        if (!flickable || scrollAnim.running || targets.length === 0 || browsing) {
            return
        }
        if (jumped) {
            if (flickable.contentY === jumpedAtY) {
                return
            }
            jumped = false
        }
        const line = flickable.contentY + height + gap
        const end = flickable.contentHeight - flickable.height
        let found = 0
        for (let i = 0; i < targets.length; i++) {
            const item = targets[i]
            if (item && item.visible && sectionTop(item) <= line) {
                found = i
            }
        }
        if (end > 0 && flickable.contentY >= end - 1) {
            found = targets.length - 1
        }
        currentIndex = found
    }

    Connections {
        target: header.flickable
        function onContentYChanged() { header.spy() }
        function onContentHeightChanged() { header.spy() }
        // A real flick or drag (wheel included): the user is scrolling by themselves now, not
        // browsing the bar with the arrows any more, and any earlier jump no longer pins the tab.
        function onMovementStarted() { header.browsing = false; header.jumped = false }
    }
    onTargetsChanged: spy()
    onHeightChanged: spy()

    // ── Scrolling to a section ───────────────────────────────────────────
    property Item jumpTarget: null

    NumberAnimation {
        id: scrollAnim
        target: header.flickable
        property: "contentY"
        duration: KanteStyle.duration
        easing.type: Easing.OutCubic
        onFinished: header.arrived()
    }

    // Moves the focus to the section's first control, if it lies in the section and in view.
    function arrived() {
        const item = jumpTarget
        jumpTarget = null
        jumpedAtY = flickable ? flickable.contentY : 0
        spy()
        if (!item) {
            return
        }
        const first = item.nextItemInFocusChain(true)
        let inside = false
        for (let p = first; p; p = p.parent) {
            inside = inside || p === item
        }
        if (!first || !inside) {
            return
        }
        const y = first.mapToItem(flickable.contentItem, 0, 0).y
        if (y >= sectionTop(item) - 1 && y < flickable.contentY + flickable.height) {
            first.forceActiveFocus(Qt.TabFocusReason)
        }
    }

    function scrollTo(index) {
        const item = targets[index]
        if (!flickable || !item) {
            return
        }
        const top = sectionTop(item)
        // Below the shrunk header, unless the page then stays within `shrinkAt` and keeps the big one.
        const shrunk = top - compactHeight - gap
        const target = shrunk > shrinkAt ? shrunk : Math.max(0, top - expandedHeight - gap)
        jumpTarget = item
        jumped = true
        currentIndex = index
        scrollAnim.to = Math.max(0, Math.min(target, flickable.contentHeight - flickable.height))
        scrollAnim.restart()
    }

    // ── Look ─────────────────────────────────────────────────────────────
    KanteGlassPanel {
        id: glass
        anchors.fill: parent
        open: true
        padding: 0
        panelSize: header.height
        blurSource: header.flickable
        blurAllowed: header.blurAllowed

        Text {
            id: titleText
            objectName: "headerTitle"
            x: header.sideMargin
            y: header.mix(header.topExpanded, header.topCompact)
            width: parent.width - 2 * header.sideMargin
            text: header.title
            font: KanteStyle.titleFont(header.mix(header.pointExpanded, header.pointCompact))
            color: KanteStyle.strongTextColor
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
            Accessible.name: header.title
        }

        KanteTabBar {
            id: bar
            objectName: "headerTabs"
            look: KanteTabBar.Look.Underline
            // The page must not jump on every arrow press: only Return, Enter, Space or a tap
            // scroll there (other KanteTabBar uses keep the default, Automatic).
            activation: KanteTabBar.Activation.Manual
            accessibleName: header.tabsName
            // The side arrows fade into the glass, not the page ground.
            edgeColor: glass.blurred ? KanteStyle.glassColor : KanteStyle.glassDenseColor
            model: header.model
            x: header.sideMargin
            y: parent.height - height
            width: parent.width - 2 * header.sideMargin
            onActivated: function(index) { header.browsing = false; header.scrollTo(index) }
            onMoved: header.browsing = true
            // Tab out without Return: nothing acted on the arrow move, but the pause ends and the
            // underline goes back to the section at the top (review #167).
            onActiveFocusChanged: {
                if (!activeFocus) {
                    header.browsing = false
                    header.spy()
                }
            }
            // The arrows move the bar's own selection without scrolling (no `activated`):
            // follow it here, so the underline and `currentIndex` agree while the bar has focus.
            onCurrentIndexChanged: header.currentIndex = currentIndex
        }
    }

    // The tab bar assigns currentIndex when a tab is chosen; the page's binding would break.
    Binding { target: bar; property: "currentIndex"; value: header.currentIndex; restoreMode: Binding.RestoreNone }
}
