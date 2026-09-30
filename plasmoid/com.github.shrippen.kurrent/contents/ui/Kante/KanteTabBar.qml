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
 * fit they scroll sideways and the selected tab is kept in view.
 * Left/Right move the selection while the bar has focus.
 */
FocusScope {
    id: tabs

    property var model: []
    property var icons: []
    property var counts: []
    property var countKinds: []
    property bool badges: false
    property int currentIndex: 0
    signal activated(int index)

    implicitHeight: KanteStyle.heightMedium
    implicitWidth: row.implicitWidth
    activeFocusOnTab: true

    Keys.onLeftPressed: select(Math.max(0, currentIndex - 1))
    Keys.onRightPressed: select(Math.min(model.length - 1, currentIndex + 1))

    function select(i) {
        if (i !== currentIndex) {
            currentIndex = i
            activated(i)
        }
    }

    function ensureVisible() {
        var t = rep.count > 0 ? rep.itemAt(currentIndex) : null
        if (!t) {
            return
        }
        if (t.x < flick.contentX) {
            flick.contentX = t.x
        } else if (t.x + t.width > flick.contentX + flick.width) {
            flick.contentX = t.x + t.width - flick.width
        }
    }
    onCurrentIndexChanged: ensureVisible()

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: KanteStyle.frameColor
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: row.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true
        Behavior on contentX { NumberAnimation { duration: KanteStyle.duration; easing.type: Easing.OutCubic } }

        // The sliding yellow tab.
        KantePolygon {
            id: slider
            // rep.count makes the binding re-run once the tabs exist.
            readonly property Item target: rep.count > 0 ? rep.itemAt(tabs.currentIndex) : null
            x: target ? target.x : 0
            width: target ? target.width : 0
            height: tabs.height
            fillColor: KanteStyle.accentColor
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
                    readonly property color ink: current ? KanteStyle.accentForegroundColor : (hover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor)
                    width: content.implicitWidth + KanteStyle.unit(iconName.length > 0 && String(modelData).length === 0 ? 24 : 36)
                    height: tabs.height

                    KantePolygon {
                        anchors.fill: parent
                        fillColor: hover.hovered ? KanteStyle.sunkenColor : KanteStyle.cardColor
                        cutTopRight: KanteStyle.chamferSmall
                        visible: !tab.current
                    }

                    RowLayout {
                        id: content
                        anchors.centerIn: parent
                        spacing: KanteStyle.unit(8)
                        Kirigami.Icon {
                            visible: tab.iconName.length > 0
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: tab.iconName
                            isMask: true
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
                }
            }
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
}
