import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "."

/**
 * Segmented control: one row, the chosen segment filled with the accent. `model` is a
 * list of labels (an empty label makes the segment icon only), `icons` an optional list of
 * icon names and `tooltips` an optional list of hints (needed for icon-only segments).
 * `disabledIndexes` (Kante 1.28) lists segments that cannot be chosen, e.g. [2]: muted and
 * struck through (not colour alone), no click, arrow keys skip them, screen readers hear
 * them as unavailable. Their tooltip still shows, so it can say why.
 */
FocusScope {
    id: seg

    property var model: []
    property var icons: []
    property var tooltips: []
    property var disabledIndexes: []
    property int currentIndex: 0
    signal activated(int index)

    implicitHeight: KanteStyle.heightMedium
    implicitWidth: row.implicitWidth
    activeFocusOnTab: true

    Keys.onLeftPressed: select(nextEnabled(-1))
    Keys.onRightPressed: select(nextEnabled(1))

    /** Whether segment i is in `disabledIndexes`. */
    function isDisabled(i) {
        return !!disabledIndexes && disabledIndexes.indexOf(i) >= 0
    }
    // The next segment in direction dir (-1 left, 1 right) that is not disabled; else the current.
    function nextEnabled(dir) {
        for (var i = currentIndex + dir; i >= 0 && i < model.length; i += dir) {
            if (!isDisabled(i)) {
                return i
            }
        }
        return currentIndex
    }

    function select(i) {
        if (isDisabled(i)) {
            return
        }
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
                readonly property bool off: seg.isDisabled(index)
                readonly property string iconName: seg.icons && seg.icons.length > index ? String(seg.icons[index]) : ""
                readonly property string tip: seg.tooltips && seg.tooltips.length > index ? String(seg.tooltips[index]) : ""
                readonly property color ink: current ? KanteStyle.accentForegroundColor
                    : (off ? KanteStyle.disabledTextColor : (hover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor))
                width: content.implicitWidth + KanteStyle.unit(String(modelData).length === 0 ? 20 : 28)
                height: parent.height
                color: current ? KanteStyle.accentColor : (hover.hovered && !off ? KanteStyle.cardColor : "transparent")
                Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    opacity: item.off ? 0.6 : 1
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
                // Disabled: a line through label and icon, so it does not rely on colour.
                Rectangle {
                    visible: item.off
                    anchors.centerIn: content
                    width: content.width + KanteStyle.unit(6)
                    height: Math.max(1, KanteStyle.unit(1.5))
                    color: item.ink
                    opacity: content.opacity
                }
                HoverHandler { id: hover }
                QQC2.ToolTip.text: item.tip
                QQC2.ToolTip.visible: hover.hovered && item.tip.length > 0
                QQC2.ToolTip.delay: 500
                // Click and accessibility on a child: a disabled item reports the disabled
                // state and takes no taps, while the hover (tooltip) above stays alive.
                Item {
                    anchors.fill: parent
                    enabled: !item.off
                    TapHandler { onTapped: seg.select(item.index) }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: String(item.modelData).length > 0 ? item.modelData : item.tip
                    Accessible.checked: item.current
                }
            }
        }
    }
}
