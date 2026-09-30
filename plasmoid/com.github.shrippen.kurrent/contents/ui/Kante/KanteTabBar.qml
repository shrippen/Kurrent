import QtQuick
import "."

/**
 * Tabs as notched tabs (top-right cut). The yellow tab slides to the selected
 * one. `model` is a list of labels, `counts` an optional list of counters.
 * Left/Right move the selection while the bar has focus.
 */
FocusScope {
    id: tabs

    property var model: []
    property var counts: []
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

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: KanteStyle.frameColor
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
                width: label.implicitWidth + counter.width + KanteStyle.unit(40)
                height: tabs.height

                KantePolygon {
                    anchors.fill: parent
                    fillColor: hover.hovered ? KanteStyle.sunkenColor : KanteStyle.cardColor
                    cutTopRight: KanteStyle.chamferSmall
                    visible: !tab.current
                }

                Text {
                    id: label
                    x: KanteStyle.unit(20)
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData
                    font: KanteStyle.labelFont()
                    color: tab.current ? KanteStyle.accentForegroundColor : (hover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor)
                    Behavior on color { ColorAnimation { duration: KanteStyle.duration } }
                }
                Text {
                    id: counter
                    readonly property string value: tabs.counts && tabs.counts.length > tab.index ? String(tabs.counts[tab.index]) : ""
                    anchors.left: label.right
                    anchors.leftMargin: value.length > 0 ? KanteStyle.unit(8) : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: value
                    width: value.length > 0 ? implicitWidth : 0
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
                    color: label.color
                    opacity: 0.7
                }

                HoverHandler { id: hover }
                TapHandler { onTapped: tabs.select(tab.index); }
                Accessible.role: Accessible.PageTab
                Accessible.name: tab.modelData
                Accessible.selected: tab.current
            }
        }
    }

    // The sliding yellow tab.
    KantePolygon {
        id: slider
        // rep.count makes the binding re-run once the tabs exist.
        readonly property Item target: rep.count > 0 ? rep.itemAt(tabs.currentIndex) : null
        x: target ? target.x : 0
        width: target ? target.width : 0
        height: tabs.height
        z: -1
        fillColor: KanteStyle.accentColor
        cutTopRight: KanteStyle.chamferSmall
        Behavior on x { NumberAnimation { duration: KanteStyle.animate ? 260 : 0; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: KanteStyle.animate ? 260 : 0; easing.type: Easing.OutCubic } }
    }

    // Focus: a 3 px cyan line under the selected tab.
    Rectangle {
        visible: tabs.activeFocus
        x: slider.x
        width: slider.width
        y: parent.height - 3
        height: 3
        color: KanteStyle.focusColor
    }
}
