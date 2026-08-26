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

    function reorder(from, to) {
        if (from === to || from < 0 || to < 0 || from >= keys.length || to >= keys.length) {
            return
        }
        var next = keys.slice()
        var item = next.splice(from, 1)[0]
        next.splice(to, 0, item)
        orderChanged(next.join(orderSeparator))
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        height: contentHeight
        interactive: false
        model: root.keys
        spacing: Design.spaceSmall

        delegate: Kirigami.AbstractCard {
            id: card
            width: list.width
            z: dragHandler.active ? 10 : 1

            DragHandler {
                id: dragHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.TouchPad
                cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property int hoverIndex: -1

                onActiveChanged: {
                    if (!active) {
                        if (hoverIndex >= 0 && hoverIndex !== index) {
                            root.reorder(index, hoverIndex)
                        }
                        hoverIndex = -1
                    }
                }

                onCentroidChanged: {
                    if (!active) {
                        return
                    }
                    var pos = card.mapToItem(list.contentItem, centroid.position.x, centroid.position.y)
                    hoverIndex = list.indexAt(pos.x, pos.y)
                }
            }

            contentItem: RowLayout {
                spacing: Design.spaceSmall

                Kirigami.Icon {
                    source: "list-reorder"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    opacity: 0.55
                    QQC2.ToolTip.text: i18n("Drag to reorder")
                    QQC2.ToolTip.visible: dragHandler.hovered
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.titleForKey(modelData)
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }

                QQC2.Switch {
                    checked: root.isVisible(modelData)
                    onToggled: root.visibilityToggled(modelData)
                    QQC2.ToolTip.text: i18n("Show in the sidebar")
                    QQC2.ToolTip.visible: hovered
                }
            }
        }
    }
}
