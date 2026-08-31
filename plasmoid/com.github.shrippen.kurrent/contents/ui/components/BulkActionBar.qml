import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import com.github.shrippen.kurrent 1.0
import ".."

RowLayout {
    id: root

    required property TaskController controller
    property var itemIds: []

    visible: controller && controller.selectedTaskIds.length > 0
    spacing: Design.spaceSmall

    function bulkIds() {
        var ids = []
        for (var i = 0; i < controller.selectedTaskIds.length; ++i) {
            ids.push(parseInt(controller.selectedTaskIds[i], 10))
        }
        return ids
    }

    QQC2.Label {
        text: i18np("%1 task selected", "%1 tasks selected", controller.selectedTaskIds.length)
    }

    QQC2.ToolButton {
        icon.name: "checkmark"
        display: QQC2.AbstractButton.IconOnly
        onClicked: controller.bulkCompleteTasks(root.bulkIds(), true)
        QQC2.ToolTip.text: i18n("Complete")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.ToolButton {
        icon.name: "edit-delete"
        display: QQC2.AbstractButton.IconOnly
        onClicked: controller.bulkDeleteTasks(root.bulkIds())
        QQC2.ToolTip.text: i18n("Delete")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.ToolButton {
        icon.name: "go-next"
        display: QQC2.AbstractButton.IconOnly
        onClicked: controller.bulkRescheduleTasks(root.bulkIds(), "tomorrow")
        QQC2.ToolTip.text: i18n("Tomorrow")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.ToolButton {
        icon.name: "go-next"
        display: QQC2.AbstractButton.IconOnly
        onClicked: controller.bulkRescheduleTasks(root.bulkIds(), "1d")
        QQC2.ToolTip.text: i18n("+1 day")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.ToolButton {
        icon.name: "folder"
        display: QQC2.AbstractButton.IconOnly
        onClicked: moveMenu.open()
        QQC2.ToolTip.text: i18n("Move to project")
        QQC2.ToolTip.visible: hovered

        QQC2.Menu {
            id: moveMenu
            title: i18n("Move to project")

            Instantiator {
                model: controller.collectionModel ? controller.collectionModel.count : 0
                delegate: QQC2.MenuItem {
                    required property int index
                    text: controller.collectionModel.nameAt(index)
                    onTriggered: controller.bulkMoveTasks(root.bulkIds(), controller.collectionModel.collectionIdAt(index))
                }
                onObjectAdded: function(index, object) { moveMenu.insertItem(index, object) }
                onObjectRemoved: function(index, object) { moveMenu.removeItem(object) }
            }
        }
    }

    QQC2.ToolButton {
        icon.name: "tag"
        display: QQC2.AbstractButton.IconOnly
        onClicked: labelMenu.open()
        QQC2.ToolTip.text: i18n("Add label")
        QQC2.ToolTip.visible: hovered

        QQC2.Menu {
            id: labelMenu
            title: i18n("Add label")

            Instantiator {
                model: controller.availableLabels
                delegate: QQC2.MenuItem {
                    required property int index
                    required property var modelData
                    text: modelData
                    onTriggered: controller.bulkAddLabel(root.bulkIds(), modelData)
                }
                onObjectAdded: function(index, object) { labelMenu.insertItem(index, object) }
                onObjectRemoved: function(index, object) { labelMenu.removeItem(object) }
            }
        }
    }

    QQC2.ToolButton {
        icon.name: "flag"
        display: QQC2.AbstractButton.IconOnly
        onClicked: priorityMenu.open()
        QQC2.ToolTip.text: i18n("Set priority")
        QQC2.ToolTip.visible: hovered

        QQC2.Menu {
            id: priorityMenu
            title: i18n("Set priority")
            QQC2.MenuItem {
                text: i18n("High")
                onTriggered: controller.bulkSetPriority(root.bulkIds(), 1)
            }
            QQC2.MenuItem {
                text: i18n("Medium")
                onTriggered: controller.bulkSetPriority(root.bulkIds(), 5)
            }
            QQC2.MenuItem {
                text: i18n("Low")
                onTriggered: controller.bulkSetPriority(root.bulkIds(), 9)
            }
            QQC2.MenuItem {
                text: i18n("None")
                onTriggered: controller.bulkSetPriority(root.bulkIds(), 0)
            }
        }
    }

    QQC2.ToolButton {
        icon.name: "edit-copy"
        display: QQC2.AbstractButton.IconOnly
        onClicked: {
            var text = controller.bulkExportUids(root.bulkIds())
            if (text.length > 0) {
                Plasmoid.copyToClipboard(text)
            }
        }
        QQC2.ToolTip.text: i18n("Copy UIDs")
        QQC2.ToolTip.visible: hovered
    }

    QQC2.ToolButton {
        icon.name: "dialog-cancel"
        display: QQC2.AbstractButton.IconOnly
        onClicked: controller.clearTaskSelection()
        QQC2.ToolTip.text: i18n("Clear selection")
        QQC2.ToolTip.visible: hovered
    }

    Item { Layout.fillWidth: true }
}
