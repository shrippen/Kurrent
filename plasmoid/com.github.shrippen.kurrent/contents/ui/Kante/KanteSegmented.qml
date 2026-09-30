import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "."

/**
 * Segmented control: one row, the chosen segment filled with the accent. `model` is a
 * list of labels (an empty label makes the segment icon only), `icons` an optional list of
 * icon names and `tooltips` an optional list of hints (needed for icon-only segments).
 */
FocusScope {
    id: seg

    property var model: []
    property var icons: []
    property var tooltips: []
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
                readonly property string iconName: seg.icons && seg.icons.length > index ? String(seg.icons[index]) : ""
                readonly property string tip: seg.tooltips && seg.tooltips.length > index ? String(seg.tooltips[index]) : ""
                readonly property color ink: current ? KanteStyle.accentForegroundColor : (hover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor)
                width: content.implicitWidth + KanteStyle.unit(String(modelData).length === 0 ? 20 : 28)
                height: parent.height
                color: current ? KanteStyle.accentColor : (hover.hovered ? KanteStyle.cardColor : "transparent")
                Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: KanteStyle.unit(6)
                    Kirigami.Icon {
                        visible: item.iconName.length > 0
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: item.iconName
                        isMask: true
                        color: item.ink
                    }
                    Text {
                        visible: String(item.modelData).length > 0
                        text: item.modelData
                        font: KanteStyle.labelFont()
                        color: item.ink
                    }
                }
                HoverHandler { id: hover }
                QQC2.ToolTip.text: item.tip
                QQC2.ToolTip.visible: hover.hovered && item.tip.length > 0
                QQC2.ToolTip.delay: 500
                TapHandler { onTapped: seg.select(item.index) }
                Accessible.role: Accessible.RadioButton
                Accessible.name: String(item.modelData).length > 0 ? item.modelData : item.tip
                Accessible.checked: item.current
            }
        }
    }
}
