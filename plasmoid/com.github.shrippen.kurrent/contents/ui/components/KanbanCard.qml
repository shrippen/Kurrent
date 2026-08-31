import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import com.github.shrippen.kurrent 1.0
import "../colors.js" as Colors
import "../datetime.js" as DateTime
import "../taskmeta.js" as TaskMeta
import ".."

Kirigami.AbstractCard {
    id: root

    required property TaskController controller
    required property var task
    property Item dragHost: null
    property Item kanbanView: null
    property int cardIndex: 0
    property string columnKey: ""
    // Full-editor overlay: suppress card hover under the dim.
    property bool interactionsSuspended: false

    signal requestFullEditor(var task)

    width: parent ? parent.width : implicitWidth
    opacity: (task && task.completed ? 0.65 : 1)
    hoverEnabled: !interactionsSuspended

    property Item dragHomeParent: null
    property real grabLocalX: 0
    property real grabLocalY: 0

    Drag.keys: ["application/x-kurrent-task"]
    Drag.mimeData: {
        "application/x-kurrent-task": task ? String(task.itemId) : ""
    }
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: Math.min(height / 2, 24)

    function syncDragPosition() {
        if (!dragHost) {
            return
        }
        var c = cardDrag.centroid.position
        var g = root.mapToGlobal(c.x, c.y)
        var local = dragHost.mapFromGlobal(g.x, g.y)
        root.x = local.x - root.Drag.hotSpot.x
        root.y = local.y - root.Drag.hotSpot.y
    }

    DragHandler {
        id: cardDrag
        enabled: !!(task && !task.completed && dragHost && kanbanView && !interactionsSuspended)
        target: null
        onActiveChanged: {
            if (!dragHost || !task || !kanbanView) {
                return
            }
            if (active) {
                kanbanView.beginKanbanCardDrag(columnKey, cardIndex)
            } else {
                if (kanbanView.kanbanDragCommitted) {
                    root.Drag.drop()
                    root.Drag.active = false
                    if (dragHomeParent) {
                        root.parent = dragHomeParent
                        root.x = 0
                        root.y = 0
                        root.z = 0
                    }
                    dragHost.endTaskDrag()
                }
                kanbanView.endKanbanCardDrag()
            }
        }
        onCentroidChanged: {
            if (!active || !dragHost || !kanbanView) {
                return
            }
            var t = translation
            var dist = Math.sqrt(t.x * t.x + t.y * t.y)
            if (!kanbanView.kanbanDragCommitted) {
                if (dist < kanbanView.dragThreshold) {
                    return
                }
                kanbanView.commitKanbanCardDrag(root.height)
                dragHomeParent = root.parent
                root.parent = dragHost
                root.z = 10000
                root.Drag.active = true
                dragHost.beginTaskDrag(task)
            }
            syncDragPosition()
        }
    }

    contentItem: ColumnLayout {
        spacing: Design.spaceTiny

        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: (Plasmoid.configuration.showLabelChips !== false && (task.categories || []).length > 0)
                     || (Plasmoid.configuration.showPriorityChip !== false && task.priority > 0)
                     || (Plasmoid.configuration.showRecurringIcon !== false && task.recurring)
                     || (Plasmoid.configuration.showProgressChip !== false && task.percentComplete > 0)
                     || (Plasmoid.configuration.showStatusChip !== false && (task.status || 0) !== 0)
                     || (Plasmoid.configuration.showSecrecyChip !== false && (task.secrecy || 0) > 0)
                     || (Plasmoid.configuration.showLocationChip !== false && !!(task.location && String(task.location).trim().length))
                     || (Plasmoid.configuration.showDateChip !== false && DateTime.isValidDate(task.dueDate))

            Repeater {
                model: Plasmoid.configuration.showLabelChips !== false ? (task.categories || []) : []
                delegate: Kirigami.Icon {
                    required property var modelData
                    source: "tag"
                    color: Design.colorForKey(modelData, "label")
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    QQC2.ToolTip.text: modelData
                    QQC2.ToolTip.visible: tagHover.hovered
                    HoverHandler { id: tagHover }
                }
            }

            Kirigami.Icon {
                visible: Plasmoid.configuration.showPriorityChip !== false && task.priority > 0
                source: "flag"
                color: Colors.colorForPriority(task.priority)
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            Kirigami.Icon {
                visible: Plasmoid.configuration.showRecurringIcon !== false && task.recurring
                source: "media-playlist-repeat"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                opacity: 0.85
            }

            Kirigami.Icon {
                visible: Plasmoid.configuration.showProgressChip !== false && task.percentComplete > 0
                source: TaskMeta.progressIconForPercent(task.percentComplete)
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                QQC2.ToolTip.text: i18n("Progress %1%", task.percentComplete)
                QQC2.ToolTip.visible: kbProgressHover.hovered
                HoverHandler { id: kbProgressHover }
            }

            Kirigami.Icon {
                visible: Plasmoid.configuration.showStatusChip !== false && (task.status || 0) !== 0
                source: TaskMeta.statusIconForValue(task.status)
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                QQC2.ToolTip.text: {
                    switch (Number(task.status)) {
                    case 4: return i18n("Needs action")
                    case 6: return i18n("In process")
                    case 3: return i18n("Completed")
                    case 5: return i18n("Canceled")
                    default: return i18n("Status")
                    }
                }
                QQC2.ToolTip.visible: kbStatusHover.hovered
                HoverHandler { id: kbStatusHover }
            }

            Kirigami.Icon {
                visible: Plasmoid.configuration.showSecrecyChip !== false && (task.secrecy || 0) > 0
                source: TaskMeta.secrecyIconForValue(task.secrecy)
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                QQC2.ToolTip.text: {
                    switch (Number(task.secrecy)) {
                    case 1: return i18n("Private")
                    case 2: return i18n("Confidential")
                    default: return i18n("Public")
                    }
                }
                QQC2.ToolTip.visible: kbSecrecyHover.hovered
                HoverHandler { id: kbSecrecyHover }
            }

            Kirigami.Icon {
                visible: Plasmoid.configuration.showLocationChip !== false
                         && !!(task.location && String(task.location).trim().length)
                source: "mark-location"
                color: Design.colorForKey(String(task.location), "location")
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                QQC2.ToolTip.text: task.location
                QQC2.ToolTip.visible: kbLocationHover.hovered
                HoverHandler { id: kbLocationHover }
            }

            Item { Layout.fillWidth: true }

            QQC2.Label {
                visible: Plasmoid.configuration.showDateChip !== false && DateTime.isValidDate(task.dueDate)
                text: DateTime.formatDate(task.dueDate)
                opacity: 0.85
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.highlightColor
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: task.summary || i18n("(Untitled)")
            wrapMode: Text.WordWrap
            font.strikeout: task.completed === true
            font.bold: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: (Plasmoid.configuration.descriptionPreviewLines || 0) > 0
                     && !!(task.description && String(task.description).trim().length)
            text: task.description || ""
            opacity: 0.75
            wrapMode: Text.WordWrap
            maximumLineCount: Plasmoid.configuration.descriptionPreviewLines || 2
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            QQC2.ToolButton {
                icon.name: "document-edit"
                display: QQC2.AbstractButton.IconOnly
                onClicked: root.requestFullEditor(task)
                QQC2.ToolTip.text: i18n("Edit task")
                QQC2.ToolTip.visible: hovered
            }

            QQC2.ToolButton {
                visible: Plasmoid.configuration.showJoinButton !== false
                         && !!(task.joinUrl && String(task.joinUrl).length)
                icon.name: "internet-services"
                display: QQC2.AbstractButton.IconOnly
                onClicked: Qt.openUrlExternally(task.joinUrl)
                QQC2.ToolTip.text: i18n("Open / Join")
                QQC2.ToolTip.visible: hovered
            }

            Item { Layout.fillWidth: true }

            QQC2.Label {
                visible: task.syncing === true
                text: i18n("Syncing…")
                opacity: 0.65
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }
}
