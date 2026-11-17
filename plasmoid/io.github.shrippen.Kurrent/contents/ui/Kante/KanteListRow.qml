import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "."

/**
 * A row of a list: a leading figure (`leadingText`, e.g. a time), a marker (`marker`, e.g. a
 * KanteSwatch), the text with an optional `subtitle` line, a count badge and a meta figure.
 * Selected = cyan tint with a bar, hover = tint step 1, pressed = tint step 2, keyboard
 * focus = a ring inside, `dropTarget` = cyan tint with a dashed cyan frame (something is
 * dragged over it). The badge (`count`) turns cyan with the selection; `countKind` Error makes
 * it red (e.g. failed jobs). `trailing` holds items after the meta figure (an arrow, an icon).
 * A tap never swallows the press: a row inside an ItemDelegate (or a ListView that flicks)
 * leaves the press to it, so the delegate's `clicked` fires too.
 *   density         Compact / Normal / Comfortable: 32 / 40 / 48 units (two lines grow it)
 *   rule            the 1 px rule under the row (off in lists with their own separators)
 *   focusOnClick    a tap takes the keyboard focus (off where the list keeps it)
 *   disabledReason  when disabled, shown as the second line, so it is readable on touch too
 *                   (a disabled item gets no hover, so a tooltip would never show)
 * A focusable `trailing` control (1.51, e.g. a KanteInfoTip "?"): Tab reaches the row, then the
 * control; Shift+Tab from the row's first control goes to its row (from a later one to the
 * control before it). Leaving the row, the control gives up
 * the row's focus, so Tab into the row stops at the row again.
 */
FocusScope {
    id: row

    enum CountKind {
        Quiet,
        Error
    }

    enum Overflow {
        Elide,     // one line each, cut with "…"
        Wrap       // as many lines as the texts need
    }

    enum Density {
        Compact,
        Normal,
        Comfortable,
        Dense      // 24 px, below the control heights: opt-in for long navigation lists only
    }

    property string text: ""
    property string subtitle: ""
    property string meta: ""
    property string leadingText: ""
    /** Width of the leading figure, so a column of times lines up; 0 = its own width. */
    property real leadingWidth: 0
    property string count: ""
    property int countKind: KanteListRow.CountKind.Quiet
    property bool selected: false
    property bool dropTarget: false
    property bool rule: true
    property bool focusOnClick: true
    property string disabledReason: ""
    property int density: KanteListRow.Density.Normal
    /** Opt-in (1.78): the meta figure and `trailing` go under the texts when these would get less than this width. 0 = never. */
    property real minTextWidth: 0
    /** Text and subtitle longer than their room (1.81): Elide (default) or Wrap; the row grows. */
    property int overflow: KanteListRow.Overflow.Elide
    /** The meta figure and `trailing` sit under the texts, because the row is too narrow. */
    readonly property bool stacked: minTextWidth > 0 && tail.visible && width < inlineNeed()
    readonly property bool pressed: tap.active
    default property alias marker: markerSlot.data
    /** Items at the right end, after the meta figure (e.g. a chevron or an icon). */
    property alias trailing: trailingSlot.data
    signal clicked()

    readonly property string secondLine: !enabled && disabledReason !== "" ? disabledReason : subtitle
    readonly property real densityHeight: density === KanteListRow.Density.Dense ? Math.round(KanteStyle.heightSmall * 0.75)
                                          : density === KanteListRow.Density.Compact ? KanteStyle.heightSmall
                                          : (density === KanteListRow.Density.Comfortable ? KanteStyle.heightLarge : KanteStyle.heightMedium)

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: Math.max(densityHeight, texts.implicitHeight + (stacked ? body.spacing + tail.implicitHeight : 0)
                             + KanteStyle.unit(density === KanteListRow.Density.Dense ? 4 : 12))
    activeFocusOnTab: true

    QtObject {
        id: metrics
        readonly property real margin: KanteStyle.unit(12)
        readonly property real gap: KanteStyle.unit(10)
        readonly property real stackGap: KanteStyle.unit(4)
        readonly property bool wraps: row.stacked || row.overflow === KanteListRow.Overflow.Wrap
    }

    // Width the row needs to keep everything on one line: the fixed items, the tail and the
    // least width of the texts, with the margins and the gaps between them.
    // [leading] [marker] [texts >= minTextWidth] [badge] [meta, trailing]
    function inlineNeed() {
        const items = [leadingFigure, markerSlot, badgeBox, tail]
        let need = row.minTextWidth + 2 * metrics.margin
        for (let i = 0; i < items.length; i++) {
            if (!items[i].visible) {
                continue
            }
            need += (items[i] === leadingFigure ? leadingFigure.Layout.preferredWidth : items[i].implicitWidth) + metrics.gap
        }
        return need
    }

    // Whether a popup stacked above the row (a sheet, a dialog, a drawer) lies at scene point
    // `at` (1.61.1). The passive tap below also sees presses that a TapHandler in the popup took.
    // Only popups count: Kirigami and apps keep other items in the overlay (passive
    // notifications, toasts). A row inside a popup only yields to popups drawn above its own
    // (higher z, or the same z and opened later).
    function underPopup(at) {
        const overlay = QQC2.Overlay.overlay
        if (!overlay || !overlay.visible) {
            return false
        }
        let own = -1
        for (let p = row; p && p.parent; p = p.parent) {
            if (p.parent === overlay) {
                own = overlay.children.indexOf(p)
                break
            }
        }
        const ownZ = own >= 0 ? overlay.children[own].z : -Infinity
        for (let i = 0; i < overlay.children.length; i++) {
            const c = overlay.children[i]
            // Above the row's own popup: a higher z, or the same z and opened later (drawn later).
            const above = c.z > ownZ || (c.z === ownZ && i > own)
            if (i !== own && above && c.visible && c.opacity > 0 && String(c).startsWith("QQuickPopupItem")
                    && c.contains(c.mapFromItem(null, at.x, at.y))) {
                return true
            }
        }
        return false
    }

    /** A tap: takes the focus (`focusOnClick`) and emits `clicked`. */
    function activate() {
        if (focusOnClick) {
            forceActiveFocus()
        }
        clicked()
    }

    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    // A focus scope hands its focus on to the child that had it last: once a trailing "?" had
    // the focus, Tab into the row went straight to the "?" (Kontra QA 28.10., P7). Leaving the
    // row, the children give the focus up.
    onActiveFocusChanged: {
        if (activeFocus) {
            const start = row.nextItemInFocusChain(true)
            guard(trailingSlot, start)
            guard(markerSlot, start)
            return
        }
        dropFocus(trailingSlot)
        dropFocus(markerSlot)
    }
    function dropFocus(item) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i]
            c.focus = false
            dropFocus(c)
        }
    }

    // Shift+Tab from the row's first control goes to the row; Qt passed over the row to the
    // control before it. Qt moves the focus in the control's own key handling, before the event
    // reaches the row, so that stop (`start`, the row's next in the focus chain) gets the
    // handler, once; a later control goes back to the one before it as usual.
    function guard(item, start) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i]
            if (c.activeFocusOnTab) {
                c.Keys.backtabPressed.disconnect(backFromChild)
                if (c === start) {
                    c.Keys.backtabPressed.connect(backFromChild)
                }
            }
            guard(c, start)
        }
    }
    function backFromChild(event) {
        event.accepted = true
        dropFocus(trailingSlot)
        dropFocus(markerSlot)
        row.forceActiveFocus(Qt.BacktabFocusReason)
    }

    Rectangle {
        anchors.fill: parent
        color: row.dropTarget ? KanteStyle.tintHighlight2Color
             : row.selected ? KanteStyle.selectionColor
             : row.pressed ? KanteStyle.tint2Color
             : (hover.hovered ? KanteStyle.tint1Color : "transparent")
    }
    Rectangle { visible: row.selected; width: 3; height: parent.height; color: KanteStyle.focusColor }
    Rectangle { visible: row.rule; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: KanteStyle.ruleColor }
    KanteDropZone {
        anchors.fill: parent
        visible: row.dropTarget
        kind: KanteDropZone.Kind.Gap
    }
    Rectangle {
        anchors.fill: parent
        visible: row.activeFocus
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.focusColor
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.leftMargin: metrics.margin
        anchors.rightMargin: metrics.margin
        spacing: metrics.stackGap
        opacity: row.enabled ? 1 : 0.5

        RowLayout {
            id: line
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: metrics.gap

            Text {
                id: leadingFigure
                visible: row.leadingText !== ""
                Layout.preferredWidth: row.leadingWidth > 0 ? row.leadingWidth : implicitWidth
                Layout.alignment: Qt.AlignVCenter
                text: row.leadingText
                color: row.selected ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 0.9, false)
            }
            Item {
                id: markerSlot
                visible: childrenRect.width > 0
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignVCenter
            }
            ColumnLayout {
                id: texts
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Text {
                    objectName: "listRowText"
                    Layout.fillWidth: true
                    text: row.text
                    color: KanteStyle.textColor
                    font: KanteStyle.defaultFont
                    wrapMode: metrics.wraps ? Text.Wrap : Text.NoWrap
                    elide: metrics.wraps ? Text.ElideNone : Text.ElideRight
                }
                Text {
                    objectName: "listRowSubtitle"
                    visible: row.secondLine !== ""
                    Layout.fillWidth: true
                    text: row.secondLine
                    color: !row.enabled && row.disabledReason !== "" ? KanteStyle.neutralTextColor : KanteStyle.mutedTextColor
                    font: KanteStyle.smallFont
                    wrapMode: metrics.wraps ? Text.Wrap : Text.NoWrap
                    elide: metrics.wraps ? Text.ElideNone : Text.ElideRight
                }
            }
            // Count badge: quiet, cyan on the selected row.
            Rectangle {
                id: badgeBox
                visible: row.count !== ""
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Math.max(KanteStyle.unit(20), badge.implicitWidth + KanteStyle.unit(10))
                implicitHeight: KanteStyle.unit(18)
                readonly property bool error: row.countKind === KanteListRow.CountKind.Error
                color: error ? KanteStyle.negativeTextColor : (row.selected ? KanteStyle.focusColor : KanteStyle.tint2Color)
                Text {
                    id: badge
                    anchors.centerIn: parent
                    text: row.count
                    color: parent.error || row.selected ? KanteStyle.onStateColor : KanteStyle.textColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
                }
            }
        }

        // Meta figure and trailing items: at the right end of the line, or, when the row is
        // `stacked`, under the texts. Moved by its parent, so the items keep their focus.
        RowLayout {
            id: tail
            parent: row.stacked ? body : line
            visible: row.meta !== "" || trailingSlot.childrenRect.width > 0
            spacing: metrics.gap
            Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignVCenter
            Layout.leftMargin: row.stacked ? texts.x : 0

            Text {
                visible: row.meta !== ""
                text: row.meta
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
            }
            Item {
                id: trailingSlot
                visible: childrenRect.width > 0
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    HoverHandler { id: hover }
    // A tap, seen passively: a TapHandler would keep the press from an ItemDelegate or
    // MouseArea underneath. Released inside, not dragged (a flick is no tap). In scene
    // coordinates: once a ListView grabbed the press, `position` came in another item's
    // (Qt 6.11), and every row but the first lost its taps (lmix, 29.10.2026).
    PointHandler {
        id: tap
        onGrabChanged: function (transition, point) {
            if (transition !== PointerDevice.UngrabPassive || point.state !== EventPoint.Released) {
                return
            }
            const at = point.scenePosition
            const from = point.scenePressPosition
            const moved = Math.hypot(at.x - from.x, at.y - from.y)
            if (moved > Qt.styleHints.startDragDistance || !row.contains(row.mapFromItem(null, at.x, at.y))
                    || row.underPopup(from)) {
                return
            }
            row.activate()
        }
    }
    Accessible.role: Accessible.ListItem
    Accessible.name: row.text
    Accessible.description: row.secondLine
    Accessible.selected: row.selected
}
