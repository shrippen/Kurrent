import QtQuick 2.15

// Off-tree controller for KCM pages (SimpleKCM scroll content must stay visual-only).
Loader {
    id: loader
    active: true
    asynchronous: true
    visible: false
    width: 0
    height: 0
    source: Qt.resolvedUrl("../PluginController.qml")

    readonly property var controller: item

    function refresh() {
        if (item && item.refresh) {
            item.refresh()
        }
    }
}
