import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami 2.20 as Kirigami
import ".."

QQC2.ScrollBar {
    id: bar

    property Flickable view: null
    property bool alwaysReserve: false
    // Override bar thickness (e.g. fit into a fixed list margin).
    property int extent: Design.scrollBarExtent

    implicitWidth: Math.max(2, extent)
    width: Math.max(2, extent)
    padding: Math.min(Design.scrollBarPadding, Math.max(0, Math.floor((extent - 2) / 2)))
    z: 10

    // Keep AlwaysOn so `size` stays updated; hide when content fits (with slack).
    policy: QQC2.ScrollBar.AlwaysOn
    readonly property bool overflowing: {
        if (alwaysReserve) {
            return true
        }
        if (view && Design.listNeedsScroll(view)) {
            return true
        }
        // Fallback: Qt's own handle ratio when the view binding lags a frame.
        return size > 0 && size < 0.999
    }
    visible: overflowing
    opacity: overflowing ? 1 : 0
    Behavior on opacity { enabled: false }

    contentItem: Rectangle {
        implicitWidth: Math.max(2, bar.extent - bar.padding * 2)
        radius: width / 2
        color: Kirigami.Theme.textColor
        opacity: Math.max(0.45, Design.scrollBarOpacity(bar.pressed, bar.hovered))
    }
    background: Item {}
}
