import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root

    default property alias content: column.data

    readonly property bool wideLayout: width >= Kirigami.Units.gridUnit * 28
    readonly property int contentWidth: Math.min(
        Math.max(width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 12),
        Kirigami.Units.gridUnit * 32)

    implicitHeight: flick.contentHeight
    implicitWidth: contentWidth

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: column.height + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.contentWidth
            spacing: Kirigami.Units.smallSpacing
        }
    }
}
