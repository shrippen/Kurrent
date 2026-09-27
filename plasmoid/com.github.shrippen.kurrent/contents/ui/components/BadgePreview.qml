import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Settings preview: the panel icon with the badge as configured (number or dot, accent or
// negative colour). Uses an example count.
Item {
    id: preview

    property string mode: "open"          // off, open, today, overdue, tomorrow, high
    property string badgeStyle: "number"  // number, dot
    property bool negative: false
    property int count: 3

    implicitWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.smallSpacing * 2
    implicitHeight: Kirigami.Units.iconSizes.large + Kirigami.Units.smallSpacing * 2
    Accessible.name: i18n("Preview")

    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.large
        height: width
        source: Qt.resolvedUrl("../../icons/kurrent.svg")
        isMask: true
        color: Kirigami.Theme.textColor
    }

    Rectangle {
        visible: preview.mode !== "off"
        anchors.right: icon.right
        anchors.bottom: icon.bottom
        readonly property bool dot: preview.badgeStyle === "dot"
        width: dot ? Kirigami.Units.smallSpacing * 3 : Math.max(height, label.implicitWidth + Kirigami.Units.smallSpacing * 2)
        height: dot ? width : label.implicitHeight + 2
        radius: height / 2
        color: preview.negative ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

        Text {
            id: label
            anchors.centerIn: parent
            visible: !parent.dot
            text: String(preview.count)
            font: Kirigami.Theme.smallFont
            color: preview.negative ? "white" : Kirigami.Theme.highlightedTextColor
        }
    }
}
