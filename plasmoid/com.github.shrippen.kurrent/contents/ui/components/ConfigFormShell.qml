import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Centered, width-capped column. SimpleKCM already scrolls; do not nest a Flickable.
Item {
    id: root

    default property alias content: column.data

    readonly property bool wideLayout: width >= Kirigami.Units.gridUnit * 28
    readonly property int contentWidth: Math.min(
        Math.max(width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 12),
        Kirigami.Units.gridUnit * 32)

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight
    width: parent ? parent.width : contentWidth
    Layout.fillWidth: true

    ColumnLayout {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.contentWidth
        spacing: Kirigami.Units.smallSpacing
    }
}
