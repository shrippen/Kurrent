import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."

Flickable {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property var onOpenFullEditor: null
    // Full-editor overlay: suppress card hover under the dim.
    property bool interactionsSuspended: false

    // Gap index = insert-before position in the column list (including the dragged card's old slot).
    property string dropGapColumnKey: ""
    property int dropGapIndex: -1
    property string dragSourceColumnKey: ""
    property int dragSourceIndex: -1
    property bool kanbanDragCommitted: false
    property int dragPlaceholderHeight: 0

    clip: true
    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    contentWidth: columnRow.width
    contentHeight: height
    boundsBehavior: Flickable.OvershootBounds
    flickableDirection: Flickable.HorizontalFlick

    readonly property real dragThreshold: Math.max(8, Kirigami.Units.smallSpacing * 2)

    function settleScrollBounds() {
        var maxX = Math.max(0, contentWidth - width)
        if (Math.abs(horizontalOvershoot) > 0.5
                || contentX < -0.5
                || contentX > maxX + 0.5) {
            returnToBounds()
        }
    }

    // Forward horizontal thumb-wheel / shift-wheel to this Flickable using the same
    // notch scale as Kirigami.WheelHandler (angleDelta/120), so we do not double-scroll
    // the outer handler or invent a steeper step.
    function applyHorizontalWheel(wheel) {
        var px = wheel.pixelDelta ? wheel.pixelDelta.x : 0
        var py = wheel.pixelDelta ? wheel.pixelDelta.y : 0
        var ax = wheel.angleDelta ? wheel.angleDelta.x : 0
        var ay = wheel.angleDelta ? wheel.angleDelta.y : 0
        var dx = 0
        if (Math.abs(px) > Math.abs(py) && px !== 0) {
            dx = px
        } else if (Math.abs(ax) > Math.abs(ay) && ax !== 0) {
            dx = (ax / 120.0) * (columnWheelHandler.horizontalStepSize
                                 || columnWheelHandler.verticalStepSize || 30)
        } else {
            return false
        }
        var maxX = Math.max(0, root.contentWidth - root.width)
        root.contentX = Math.max(0, Math.min(maxX, root.contentX - dx))
        if (wheel.accepted !== undefined) {
            wheel.accepted = true
        }
        return true
    }

    function beginKanbanCardDrag(columnKey, cardIndex) {
        dragSourceColumnKey = columnKey
        dragSourceIndex = cardIndex
        kanbanDragCommitted = false
        dragPlaceholderHeight = 0
        dropGapColumnKey = ""
        dropGapIndex = -1
    }

    function commitKanbanCardDrag(cardHeight) {
        dragPlaceholderHeight = Math.max(0, cardHeight)
        kanbanDragCommitted = true
    }

    function setDropGap(columnKey, gapIndex) {
        if (dropGapColumnKey === columnKey && dropGapIndex === gapIndex) {
            return
        }
        dropGapColumnKey = columnKey
        dropGapIndex = gapIndex
        if (dragHost) {
            dragHost.setDropHint(i18n("Drop here"))
        }
    }

    function clearDropGap() {
        dropGapColumnKey = ""
        dropGapIndex = -1
        if (dragHost) {
            dragHost.clearDropHint(i18n("Drop here"))
        }
    }

    function finishKanbanDrop(columnKey, gapIndex) {
        if (!dragHost || !dragHost.draggingTask || !kanbanDragCommitted) {
            clearDropGap()
            return
        }
        var draggedId = dragHost.draggingTask.itemId
        var targetGap = gapIndex
        if (targetGap < 0) {
            targetGap = dropGapColumnKey === columnKey ? dropGapIndex : -1
        }
        if (targetGap < 0) {
            // Empty column / trailing drop: append.
            var tasks = controller.kanbanTasksForColumn(columnKey) || []
            targetGap = tasks.length
        }
        var sameSlot = columnKey === dragSourceColumnKey
                && (targetGap === dragSourceIndex || targetGap === dragSourceIndex + 1)
        // targetGap === sourceIndex + 1 with item still in list means "after self" → no move
        if (columnKey === dragSourceColumnKey && targetGap === dragSourceIndex + 1) {
            sameSlot = true
        }
        if (columnKey === dragSourceColumnKey && targetGap === dragSourceIndex) {
            sameSlot = true
        }
        clearDropGap()
        if (sameSlot) {
            return
        }
        controller.finishKanbanDrop(draggedId, columnKey, targetGap,
                                    dragSourceColumnKey, dragSourceIndex)
    }

    function endKanbanCardDrag() {
        clearDropGap()
        kanbanDragCommitted = false
        dragSourceColumnKey = ""
        dragSourceIndex = -1
        dragPlaceholderHeight = 0
    }

    onFlickEnded: settleScrollBounds()
    onMovementEnded: settleScrollBounds()
    onContentWidthChanged: Qt.callLater(settleScrollBounds)

    Kirigami.WheelHandler {
        id: columnWheelHandler
        target: root
        filterMouseEvents: true
        // Default Kirigami scrolling for this horizontal Flickable (incl. vertical
        // wheel → horizontal pan). Do not also apply a custom delta here — that
        // double-steps and feels jumpy. Thumb-wheel over cards is forwarded below.
        onWheel: function(wheel) {
            columnWheelIdle.restart()
        }
    }

    Timer {
        id: columnWheelIdle
        interval: 400
        repeat: false
        onTriggered: root.settleScrollBounds()
    }

    readonly property var columnKeys: controller ? controller.kanbanColumnKeys : []
    readonly property int layoutRevision: controller ? controller.kanbanRevision : 0

    QQC2.Label {
        anchors.centerIn: parent
        width: parent.width - Design.spaceMedium * 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: columnKeys.length === 0
        opacity: 0.7
        text: controller && controller.loading
                ? i18n("Loading tasks…")
                : i18n("No tasks in this view.")
    }

    Row {
        id: columnRow
        height: root.height
        spacing: 0
        visible: columnKeys.length > 0

        Repeater {
            model: root.columnKeys
            delegate: Row {
                required property string modelData
                required property int index
                readonly property string columnKey: modelData
                readonly property int layoutRev: root.layoutRevision
                height: columnRow.height
                spacing: 0

                // Light column separator — especially helps empty columns read as lanes.
                Rectangle {
                    visible: index > 0
                    width: 1
                    height: parent.height
                    color: Kirigami.Theme.textColor
                    opacity: 0.12
                }

                Item {
                    width: Design.spaceSmall
                    height: 1
                    visible: index > 0
                }

                ColumnLayout {
                    width: Design.kanbanColumnMinWidth
                    height: parent.height
                    spacing: Design.spaceSmall

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 5
                    text: controller.kanbanColumnLabelForKey(columnKey)
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: cardList
                        anchors.fill: parent
                        clip: true
                        spacing: Design.kanbanCardGap
                        boundsBehavior: Flickable.OvershootBounds
                        flickableDirection: Flickable.VerticalFlick
                        property var cardModel: {
                            var _ = layoutRev
                            return controller.kanbanTasksForColumn(columnKey)
                        }
                        model: cardModel

                        function settleScrollBounds() {
                            var maxY = Math.max(0, contentHeight - height)
                            if (Math.abs(verticalOvershoot) > 0.5
                                    || contentY < -0.5
                                    || contentY > maxY + 0.5) {
                                returnToBounds()
                            }
                        }

                        // Gap index from *card* midpoints only (ignore drop-gap chrome),
                        // so "bottom of card N" and "top of card N+1" are one slot.
                        function gapIndexAt(yInContent) {
                            var count = cardModel ? cardModel.length : 0
                            if (count === 0) {
                                return 0
                            }
                            for (var i = 0; i < count; ++i) {
                                var item = itemAtIndex(i)
                                if (!item || item.cardMidY === undefined) {
                                    continue
                                }
                                if (yInContent < item.cardMidY) {
                                    return i
                                }
                            }
                            return count
                        }

                        onFlickEnded: settleScrollBounds()
                        onMovementEnded: settleScrollBounds()
                        onContentHeightChanged: Qt.callLater(settleScrollBounds)

                        Kirigami.WheelHandler {
                            id: cardWheelHandler
                            target: cardList
                            filterMouseEvents: true
                            onWheel: function(wheel) {
                                if (root.applyHorizontalWheel(wheel)) {
                                    columnWheelIdle.restart()
                                    return
                                }
                                cardWheelIdle.restart()
                            }
                        }

                        Timer {
                            id: cardWheelIdle
                            interval: 400
                            repeat: false
                            onTriggered: cardList.settleScrollBounds()
                        }

                        delegate: Item {
                            id: cardSlot
                            required property var modelData
                            required property int index
                            width: cardList.width
                            height: gapLead.height + placeholder.height + card.height

                            // Content Y of the card centre — stable vs. animated gap chrome.
                            readonly property real cardMidY: y + gapLead.height + placeholder.height + card.height / 2

                            Item {
                                id: gapLead
                                width: parent.width
                                height: (root.dropGapColumnKey === columnKey
                                         && root.dropGapIndex === cardSlot.index)
                                        ? Design.spaceLarge : 0
                                Behavior on height {
                                    enabled: !Design.reducedMotion
                                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 2
                                    radius: 1
                                    color: Kirigami.Theme.highlightColor
                                    visible: parent.height > 0
                                    opacity: 0.85
                                }
                            }

                            Item {
                                id: placeholder
                                anchors.top: gapLead.bottom
                                width: parent.width
                                height: (root.kanbanDragCommitted
                                         && root.dragSourceColumnKey === columnKey
                                         && root.dragSourceIndex === cardSlot.index)
                                        ? root.dragPlaceholderHeight : 0
                            }

                            KanbanCard {
                                id: card
                                anchors.top: placeholder.bottom
                                width: cardList.width
                                controller: root.controller
                                task: modelData
                                dragHost: root.dragHost
                                kanbanView: root
                                cardIndex: cardSlot.index
                                columnKey: columnKey
                                interactionsSuspended: root.interactionsSuspended
                                onRequestFullEditor: function(taskObj) {
                                    if (root.onOpenFullEditor) {
                                        root.onOpenFullEditor(taskObj)
                                    }
                                }
                            }
                        }

                        footer: Item {
                            width: cardList.width
                            height: (root.dropGapColumnKey === columnKey
                                     && root.dropGapIndex === (cardList.cardModel
                                                              ? cardList.cardModel.length : 0))
                                    ? Design.spaceLarge : 0
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 2
                                radius: 1
                                color: Kirigami.Theme.highlightColor
                                visible: parent.height > 0
                                opacity: 0.85
                            }
                        }

                        QQC2.ScrollBar.vertical: ThinScrollBar {
                            view: cardList
                            stepSize: cardList.contentHeight > 0
                                    ? cardWheelHandler.verticalStepSize / cardList.contentHeight
                                    : 0.1
                        }
                        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
                            policy: QQC2.ScrollBar.AlwaysOff
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["application/x-kurrent-task"]
                        enabled: !!(root.dragHost && root.dragHost.draggingTask
                                    && root.kanbanDragCommitted)
                        z: 10

                        function updateGap(drag) {
                            var y = cardList.contentY + drag.y
                            root.setDropGap(columnKey, cardList.gapIndexAt(y))
                        }

                        onEntered: function(drag) {
                            drag.acceptProposedAction()
                            updateGap(drag)
                        }
                        onPositionChanged: function(drag) {
                            updateGap(drag)
                        }
                        onExited: {
                            if (root.dropGapColumnKey === columnKey) {
                                root.clearDropGap()
                            }
                        }
                        onDropped: function(drop) {
                            var gap = root.dropGapColumnKey === columnKey ? root.dropGapIndex : -1
                            root.finishKanbanDrop(columnKey, gap)
                            drop.acceptProposedAction()
                        }
                    }
                }
                }

                Item {
                    width: Design.spaceSmall
                    height: 1
                }
            }
        }
    }

    QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
        policy: root.contentWidth > root.width ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
    }

    MouseArea {
        id: panArea
        x: root.contentX
        y: 0
        width: root.width
        height: root.height
        z: 50
        acceptedButtons: Qt.MiddleButton
        property real panLastX: 0
        onPressed: function(mouse) {
            panLastX = mouse.x
            root.cancelFlick()
        }
        onPositionChanged: function(mouse) {
            if (!(mouse.buttons & Qt.MiddleButton)) {
                return
            }
            var maxX = Math.max(0, root.contentWidth - root.width)
            root.contentX = Math.max(0, Math.min(maxX, root.contentX - (mouse.x - panLastX)))
            panLastX = mouse.x
        }
    }
}
