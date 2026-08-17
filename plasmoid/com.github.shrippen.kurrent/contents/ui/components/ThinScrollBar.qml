import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami 2.20 as Kirigami
import ".."

QQC2.ScrollBar {
    id: bar

    property Flickable view: null
    property bool alwaysReserve: false

    implicitWidth: Design.scrollBarExtent
    width: Design.scrollBarExtent
    padding: Design.scrollBarPadding
    policy: {
        if (alwaysReserve) {
            return QQC2.ScrollBar.AsNeeded
        }
        if (view && view.contentHeight > view.height + 1) {
            return QQC2.ScrollBar.AsNeeded
        }
        return QQC2.ScrollBar.AlwaysOff
    }

    contentItem: Rectangle {
        implicitWidth: Math.max(2, Design.scrollBarExtent - Design.scrollBarPadding * 2)
        radius: width / 2
        color: Kirigami.Theme.textColor
        opacity: Design.scrollBarOpacity(bar.pressed, bar.hovered)
    }
    background: Item {}
}
