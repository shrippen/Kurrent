import QtQuick
import "."

/** Segmented control: one row, the chosen segment filled with the accent. `model` is a list of labels. */
FocusScope {
    id: seg

    property var model: []
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
        anchors.fill: parent
        color: KanteStyle.sunkenColor
        border.width: 1
        border.color: seg.activeFocus ? KanteStyle.focusColor : KanteStyle.frameColor
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 1

        Repeater {
            model: seg.model
            delegate: Rectangle {
                id: item
                required property int index
                required property var modelData
                readonly property bool current: seg.currentIndex === index
                width: label.implicitWidth + KanteStyle.unit(28)
                height: parent.height
                color: current ? KanteStyle.accentColor : (hover.hovered ? KanteStyle.cardColor : "transparent")
                Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: item.modelData
                    font: KanteStyle.labelFont()
                    color: item.current ? KanteStyle.accentForegroundColor : (hover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor)
                }
                HoverHandler { id: hover }
                TapHandler { onTapped: seg.select(item.index) }
                Accessible.role: Accessible.RadioButton
                Accessible.name: item.modelData
                Accessible.checked: item.current
            }
        }
    }
}
