import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

Item {
    id: root

    property var keys: []
    property string hiddenRaw: ""
    property string hiddenSeparator: "||"
    property string orderSeparator: ","
    property var titleForKey: function(key) { return key }
    property string visibilityTip: i18n("Show in the sidebar")

    signal orderChanged(string joined)
    signal visibilityToggled(string key)

    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: list.contentHeight

    function isVisible(key) {
        if (!hiddenRaw) {
            return true
        }
        return hiddenRaw.split(hiddenSeparator).indexOf(key) < 0
    }

    function keysMatchModel(nextKeys) {
        var list = nextKeys || []
        if (orderModel.count !== list.length) {
            return false
        }
        for (var i = 0; i < list.length; ++i) {
            if (orderModel.get(i).key !== String(list[i])) {
                return false
            }
        }
        return true
    }

    function rebuildModel() {
        // Skip reset when the binding echoes our own drag result — clearing the
        // ListModel mid-gesture would abort a multi-step reorder.
        if (keysMatchModel(keys)) {
            return
        }
        orderModel.clear()
        var list = keys || []
        for (var i = 0; i < list.length; ++i) {
            orderModel.append({ key: String(list[i]) })
        }
    }

    function emitOrder() {
        var next = []
        for (var i = 0; i < orderModel.count; ++i) {
            next.push(orderModel.get(i).key)
        }
        orderChanged(next.join(orderSeparator))
    }

    onKeysChanged: rebuildModel()
    Component.onCompleted: rebuildModel()

    ListModel {
        id: orderModel
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        height: contentHeight
        interactive: false
        clip: true
        model: orderModel
        spacing: 0

        moveDisplaced: Transition {
            YAnimator {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        delegate: Item {
            id: wrapper
            width: list.width
            height: listItem.implicitHeight

            required property int index
            required property string key

            QQC2.ItemDelegate {
                id: listItem
                width: parent.width
                // Reorder via drag handle only — avoid press feedback fighting the handle.
                down: false
                highlighted: false

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.ListItemDragHandle {
                        listItem: listItem
                        listView: list
                        // Move the model during the gesture so multiple steps work;
                        // persist order only when the item is dropped.
                        onMoveRequested: function(oldIndex, newIndex) {
                            orderModel.move(oldIndex, newIndex, 1)
                        }
                        onDropped: function(oldIndex, newIndex) {
                            root.emitOrder()
                        }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.titleForKey(wrapper.key)
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                    }

                    QQC2.Switch {
                        checked: root.isVisible(wrapper.key)
                        onToggled: root.visibilityToggled(wrapper.key)
                        QQC2.ToolTip.text: root.visibilityTip
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
        }
    }
}
