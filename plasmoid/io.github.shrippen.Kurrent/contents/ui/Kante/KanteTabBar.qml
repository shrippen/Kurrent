import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "."

/**
 * Tabs as notched tabs (top-right cut). The yellow tab slides to the selected
 * one. `model` is a list of labels (it may change at run time), `icons` an optional
 * list of icon names (empty label = icon only), `counts` an optional list of counters
 * and `countKinds` their kinds (KanteCounter.Kind: 0 normal, 1 info, 2 error, e.g. overdue).
 * With `badges` the counters are filled badges instead of mono text. When the tabs do not
 * fit they scroll sideways and the selected tab is kept in view; an arrow (‹ ›) over a fade
 * into `edgeColor` marks each side with hidden tabs, and a tap on it scrolls that way.
 * Left/Right move the selection while the bar has focus; by default (`activation` Automatic)
 * they activate it at once, like a tap. With `activation: KanteTabBar.Activation.Manual` the
 * arrows only move the selection (nothing opens, the bar keeps focus); Return, Enter, Space or
 * a tap activate it (KanteStickyHeader's tabs: the page should not jump on every arrow).
 * `look` (Underline): no notched tabs, only text and a 2 px accent line under the selected one,
 * for a bar in a page header (KanteStickyHeader); the line and the accent text colour carry
 * the selection, not colour alone.
 *
 *   Notched:    [ Alle ]  Prüfen   Fertig         Underline:  Alle   Prüfen   Fertig
 *   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━                      ▔▔▔▔▔
 */
FocusScope {
    id: tabs

    enum Look {
        Notched,
        Underline
    }

    enum Activation {
        /** The arrows activate at once, like a tap (the default, every earlier app relies on it). */
        Automatic,
        /** The arrows only move the selection; Return, Enter, Space or a tap activate it. */
        Manual
    }

    property int look: KanteTabBar.Look.Notched
    property int activation: KanteTabBar.Activation.Automatic
    /** Screen readers hear this as the tab list's name. */
    property string accessibleName: ""
    property var model: []
    property var icons: []
    property var counts: []
    property var countKinds: []
    property bool badges: false
    property int currentIndex: 0
    /** The ground the side arrows fade into: the colour behind the bar. */
    property color edgeColor: KanteStyle.backgroundColor
    /** Tabs hidden to the left or right (the bar is too narrow for all of them). */
    readonly property bool moreBefore: flick.contentX > 1
    readonly property bool moreAfter: flick.contentX + flick.width < flick.contentWidth - 1
    signal activated(int index)
    /** Manual arrows only (`move`): the selection changed without activating it. */
    signal moved(int index)

    implicitHeight: KanteStyle.heightMedium
    implicitWidth: row.implicitWidth
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTabList
    Accessible.name: accessibleName

    // Automatic (default): the arrows select and activate at once, like a tap. Manual: they
    // only move the selection (the bar keeps focus, nothing opens or scrolls); Return, Enter
    // and Space activate the selected tab then, as a tap does.
    Keys.onLeftPressed: moveOrSelect(Math.max(0, currentIndex - 1))
    Keys.onRightPressed: moveOrSelect(Math.min(model.length - 1, currentIndex + 1))
    Keys.onReturnPressed: activate(currentIndex)
    Keys.onEnterPressed: activate(currentIndex)
    Keys.onSpacePressed: activate(currentIndex)

    function moveOrSelect(i) {
        if (activation === KanteTabBar.Activation.Manual) {
            move(i)
        } else {
            select(i)
        }
    }

    /** Moves the selection without activating it (Manual arrows): no `activated`, nothing opens. */
    function move(i) {
        currentIndex = i
        moved(i)
    }

    /** Selects and activates, as a tap does: fires `activated` only when `i` changes the
        selection (tapping the already-active tab twice does nothing the second time). */
    function select(i) {
        if (i !== currentIndex) {
            currentIndex = i
            activated(i)
        }
    }

    /** Activates `i` unconditionally (Return, Enter, Space): the key press itself is the
        request to act, even when the arrows already left the selection there. */
    function activate(i) {
        currentIndex = i
        activated(i)
    }

    /** The tab item at `i` (for tests and layouts that place things by a tab). */
    function tabAt(i) {
        return rep.count > i ? rep.itemAt(i) : null
    }

    // Room an arrow takes at a side that still hides tabs: the chosen tab stays clear of it.
    readonly property real arrowWidth: KanteStyle.unit(40)

    function ensureVisible() {
        var t = rep.count > 0 ? rep.itemAt(currentIndex) : null
        if (!t) {
            return
        }
        // Tabs left of this one stay hidden while it is not the first: keep the arrow's room.
        var before = t.x > 0 ? arrowWidth : 0
        var after = t.x + t.width < flick.contentWidth - 1 ? arrowWidth : 0
        var most = Math.max(0, flick.contentWidth - flick.width)
        if (t.x - before < scrollTarget()) {
            flick.contentX = Math.max(0, t.x - before)
        } else if (t.x + t.width + after > scrollTarget() + flick.width) {
            // A tab wider than the room between the arrows keeps its start in view.
            var end = Math.min(most, t.x + t.width + after - flick.width)
            flick.contentX = Math.min(end, Math.max(0, t.x - before))
        }
    }

    // Where the bar scrolls to: the end of a running slide, not its current point.
    function scrollTarget() {
        return slideMotion.running ? slide.targetValue : flick.contentX
    }
    onCurrentIndexChanged: ensureVisible()

    /** Scrolls most of a width towards `direction` (-1 left, 1 right): a side arrow's tap. */
    function page(direction) {
        var most = Math.max(0, flick.contentWidth - flick.width)
        flick.contentX = Math.max(0, Math.min(most, scrollTarget() + direction * flick.width * 0.8))
    }

    // A side with hidden tabs: an arrow over a fade, so a label cut at the edge never passes for
    // the last tab (Kontra QA 14.11.: "Taste…" at 200 %). Not a Tab stop: the arrows of the
    // keyboard keep the selection in view, clear of the arrows (`ensureVisible`).
    component Edge: Item {
        id: edge
        required property int direction
        width: tabs.arrowWidth
        height: tabs.height - 2
        Accessible.ignored: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: edge.direction < 0 ? tabs.edgeColor : "transparent" }
                GradientStop { position: 0.55; color: tabs.edgeColor }
                GradientStop { position: 1; color: edge.direction < 0 ? "transparent" : tabs.edgeColor }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: edge.direction < 0 ? parent.left : undefined
            anchors.right: edge.direction < 0 ? undefined : parent.right
            anchors.margins: KanteStyle.unit(6)
            text: edge.direction < 0 ? "‹" : "›"
            font: KanteStyle.titleFont(KanteStyle.labelFont().pointSize * 1.4)
            color: arrowArea.containsMouse ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
        }
        // A MouseArea, not a TapHandler: it takes the press, so the tab under the fade is not
        // chosen as well.
        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tabs.page(edge.direction)
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: KanteStyle.frameColor
    }

    Flickable {
        id: flick
        objectName: "tabsFlick"
        anchors.fill: parent
        contentWidth: row.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true
        Behavior on contentX {
            id: slide
            NumberAnimation { id: slideMotion; duration: KanteStyle.duration; easing.type: Easing.OutCubic }
        }

        // The sliding yellow tab.
        KantePolygon {
            id: slider
            // rep.count makes the binding re-run once the tabs exist.
            readonly property Item target: rep.count > 0 ? rep.itemAt(tabs.currentIndex) : null
            x: target ? target.x : 0
            width: target ? target.width : 0
            height: tabs.height
            fillColor: KanteStyle.accentColor
            visible: tabs.look === KanteTabBar.Look.Notched
            cutTopRight: KanteStyle.chamferSmall
            Behavior on x { NumberAnimation { duration: KanteStyle.animate ? 260 : 0; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: KanteStyle.animate ? 260 : 0; easing.type: Easing.OutCubic } }
        }

        Row {
            id: row
            spacing: 2

            Repeater {
                id: rep
                model: tabs.model
                delegate: Item {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool current: tabs.currentIndex === index
                    readonly property string iconName: tabs.icons && tabs.icons.length > index ? String(tabs.icons[index]) : ""
                    readonly property string countText: tabs.counts && tabs.counts.length > index ? String(tabs.counts[index]) : ""
                    readonly property color ink: current ? (tabs.look === KanteTabBar.Look.Underline ? KanteStyle.accentTextColor : KanteStyle.accentForegroundColor) : (hover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor)
                    width: content.implicitWidth + KanteStyle.unit(iconName.length > 0 && String(modelData).length === 0 ? 24 : tabs.look === KanteTabBar.Look.Underline ? 24 : 36)
                    height: tabs.height

                    KantePolygon {
                        anchors.fill: parent
                        fillColor: hover.hovered ? KanteStyle.sunkenColor : KanteStyle.cardColor
                        cutTopRight: KanteStyle.chamferSmall
                        // Shapes entirely outside the flickable are still painted by the software
                        // renderer (it ignores the clip for them): draw only tabs in view.
                        visible: tabs.look === KanteTabBar.Look.Notched && !tab.current && tab.x + tab.width > flick.contentX && tab.x < flick.contentX + flick.width
                    }

                    RowLayout {
                        id: content
                        anchors.centerIn: parent
                        spacing: KanteStyle.unit(8)
                        KanteIcon {
                            visible: tab.iconName.length > 0
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            iconSource: tab.iconName
                            color: tab.ink
                        }
                        Text {
                            visible: String(tab.modelData).length > 0
                            text: tab.modelData
                            font: KanteStyle.labelFont()
                            color: tab.ink
                            Behavior on color { ColorAnimation { duration: KanteStyle.duration } }
                        }
                        Text {
                            visible: tab.countText.length > 0 && !tabs.badges
                            text: tab.countText
                            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
                            color: tab.ink
                            opacity: 0.7
                        }
                        KanteCounter {
                            visible: tab.countText.length > 0 && tabs.badges
                            text: tab.countText
                            kind: tabs.countKinds && tabs.countKinds.length > tab.index ? tabs.countKinds[tab.index] : KanteCounter.Kind.Normal
                        }
                    }

                    HoverHandler { id: hover }
                    TapHandler { onTapped: tabs.select(tab.index) }
                    Accessible.role: Accessible.PageTab
                    Accessible.name: String(tab.modelData).length > 0 ? tab.modelData : tab.iconName
                    Accessible.selected: tab.current
                    // Screen readers pick a tab through this, not through a tap; Qt sends it to
                    // a disabled control too (review #174).
                    Accessible.onPressAction: if (tabs.enabled) { tabs.select(tab.index) }
                }
            }
        }

        // Underline look: the selected tab's accent line, over the bar's rule.
        Rectangle {
            visible: tabs.look === KanteTabBar.Look.Underline && slider.width > 0
            x: slider.x
            width: slider.width
            y: tabs.height - height
            height: KanteStyle.unit(2)
            color: KanteStyle.accentColor
        }

        // Focus: a 3 px cyan line under the selected tab.
        Rectangle {
            visible: tabs.activeFocus
            x: slider.x
            width: slider.width
            y: tabs.height - 3
            height: 3
            color: KanteStyle.focusColor
        }
    }

    Edge {
        objectName: "moreBefore"
        direction: -1
        anchors.left: parent.left
        visible: tabs.moreBefore
    }
    Edge {
        objectName: "moreAfter"
        direction: 1
        anchors.right: parent.right
        visible: tabs.moreAfter
    }
}
