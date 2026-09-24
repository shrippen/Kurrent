import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import "../colors.js" as Colors
import "../matrixlabels.js" as Labels
import ".."

// Swimlanes: rows = lane axis (project / label / priority / parent task), columns = time bucket.
// Cells hold compact task cards; dragging a card onto another cell writes the lane field and the
// due date of the target period (one undo step). Clicking a header opens the list filtered to that
// lane / period.
Item {
    id: root

    required property TaskController controller
    property Item dragHost: null
    property var onOpenFullEditor: null
    // Full-editor overlay: suppress hover under the dim.
    property bool interactionsSuspended: false

    clip: true
    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0

    // ---- data ---------------------------------------------------------------------------
    readonly property int layoutRevision: controller ? controller.matrixRevision : 0
    readonly property string laneAxis: controller ? controller.swimlaneLaneAxis : "project"
    readonly property string timeBucket: controller ? controller.swimlaneTimeBucket : "week"
    readonly property int horizon: controller ? controller.swimlaneHorizon : 0

    readonly property var matrix: {
        var rev = layoutRevision
        var axis = laneAxis
        var bucket = timeBucket
        var hz = horizon
        return controller ? controller.swimlaneMatrixForVisibleTasks() : ({})
    }
    readonly property var lanes: matrix.lanes || []
    readonly property var times: matrix.times || []
    readonly property var cells: matrix.cells || ({})
    readonly property var tasks: matrix.tasks || ({})
    readonly property var laneLabels: matrix.laneLabels || ({})
    readonly property int taskCount: Object.keys(tasks).length

    // Precomputed once per matrix: a per-cell binding would parse a date for every cell
    // on every rebuild (hundreds of cells × JS call + Date allocation).
    readonly property var weekendColumns: {
        var out = ({})
        if (timeBucket === "day") {
            for (var i = 0; i < times.length; ++i) {
                if (Labels.isWeekend(matrix, times[i], timeBucket)) {
                    out[times[i]] = true
                }
            }
        }
        return out
    }

    readonly property var timeStrings: ({
        overdue: i18n("Overdue"),
        later: i18n("Later"),
        unscheduled: i18n("No date"),
        today: i18n("Today"),
        tomorrow: i18n("Tomorrow"),
        week: function(n) { return i18n("Week %1", n) }
    })

    function laneLabel(key) {
        if (laneAxis === "priority") {
            switch (String(key)) {
            case "1": return i18n("High")
            case "5": return i18n("Medium")
            case "9": return i18n("Low")
            default: return i18n("None")
            }
        }
        if (laneAxis === "label") {
            return key === "none" ? i18n("No label") : key
        }
        if (key === "none") {
            return i18n("No parent")
        }
        var l = laneLabels[key]
        return l !== undefined && l !== "" ? l : key
    }

    function laneIcon() {
        switch (laneAxis) {
        case "label": return "tag"
        case "priority": return "flag"
        case "parent": return "view-list-tree"
        default: return "folder"
        }
    }

    function laneColor(key) {
        switch (laneAxis) {
        case "label": return key === "none" ? Kirigami.Theme.disabledTextColor : Design.colorForKey(key, "label")
        case "priority": return Colors.colorForPriority(parseInt(key, 10))
        case "parent": return Kirigami.Theme.textColor
        default: return Design.colorForKey(key, "project")
        }
    }

    function timeTitle(key) {
        return Labels.title(matrix, key, timeBucket, timeStrings)
    }

    function drill(laneKey, timeKey) {
        if (!controller) {
            return
        }
        var parts = []
        if (laneKey) {
            parts.push(laneLabel(laneKey))
        }
        if (timeKey) {
            parts.push(Labels.fullLabel(matrix, timeKey, timeBucket, timeStrings))
        }
        controller.setMatrixDrilldown("swimlane", laneKey || "", timeKey || "", parts.join(" · "))
        controller.requestMainPaneMode("list")
    }

    // Pinned row header width follows the widest lane label (bounded).
    property real rowHeaderWidth: Design.matrixRowHeaderMinWidth
    function updateRowHeaderWidth() {
        var widest = 0
        for (var i = 0; i < lanes.length; ++i) {
            labelMetrics.text = laneLabel(lanes[i])
            widest = Math.max(widest, labelMetrics.advanceWidth)
        }
        var chrome = Kirigami.Units.iconSizes.small + Design.spaceSmall * 4 + Kirigami.Units.gridUnit * 2
        rowHeaderWidth = Math.max(Design.matrixRowHeaderMinWidth,
                                  Math.min(Design.matrixRowHeaderMaxWidth, widest + chrome))
    }
    onLanesChanged: updateRowHeaderWidth()
    onLaneLabelsChanged: updateRowHeaderWidth()

    TextMetrics {
        id: labelMetrics
        font.bold: true
    }

    // ---- drag & drop state (KanbanCard talks to these) ---------------------------------
    property bool kanbanDragCommitted: false
    property string dragSourceKey: ""
    property int dragSourceIndex: -1
    property real dragPlaceholderHeight: 0
    property string dropCellKey: ""
    readonly property real dragThreshold: Math.max(8, Kirigami.Units.smallSpacing * 2)

    function beginKanbanCardDrag(cellKey, cardIndex) {
        dragSourceKey = cellKey
        dragSourceIndex = cardIndex
        kanbanDragCommitted = false
        dragPlaceholderHeight = 0
        dropCellKey = ""
    }

    function commitKanbanCardDrag(cardHeight) {
        dragPlaceholderHeight = Math.max(0, cardHeight)
        kanbanDragCommitted = true
    }

    function endKanbanCardDrag() {
        clearDrop()
        kanbanDragCommitted = false
        dragSourceKey = ""
        dragSourceIndex = -1
        dragPlaceholderHeight = 0
    }

    function setDrop(cellKey) {
        if (dropCellKey === cellKey) {
            return
        }
        dropCellKey = cellKey
        if (dragHost) {
            dragHost.setDropHint(i18n("Drop here"))
        }
    }

    function clearDrop() {
        dropCellKey = ""
        if (dragHost) {
            dragHost.clearDropHint(i18n("Drop here"))
        }
    }

    function finishDrop(laneKey, timeKey) {
        if (!dragHost || !dragHost.draggingTask || !kanbanDragCommitted) {
            clearDrop()
            return
        }
        var id = dragHost.draggingTask.itemId
        clearDrop()
        controller.moveTaskToMatrixCell(id, laneKey, timeKey)
    }

    // ---- states -------------------------------------------------------------------------
    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Design.spaceMedium * 2
        visible: root.taskCount === 0 && root.lanes.length === 0
                 || (controller && controller.loading && root.taskCount === 0)
        icon.name: "view-split-left-right"
        text: controller && controller.loading ? i18n("Loading tasks…") : i18n("No tasks in this view.")
        explanation: controller && controller.loading ? "" : i18n("Tasks appear here by row and period once they match the current view.")
    }

    // ---- grid ---------------------------------------------------------------------------
    MatrixGrid {
        id: grid
        anchors.fill: parent
        visible: root.lanes.length > 0 && !(controller && controller.loading && root.taskCount === 0)
        rows: root.lanes
        columns: root.times
        columnWidth: Design.swimlaneColumnWidth
        rowHeaderWidth: root.rowHeaderWidth
        currentColumn: root.matrix.currentTime || ""

        cornerDelegate: Component {
            Rectangle {
                color: Kirigami.Theme.backgroundColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Kirigami.Theme.textColor
                    opacity: Design.matrixLineOpacity
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Kirigami.Theme.textColor
                    opacity: Design.matrixLineOpacity
                }
                QQC2.ToolButton {
                    anchors.centerIn: parent
                    icon.name: "go-jump-today"
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !root.interactionsSuspended
                    onClicked: grid.scrollToColumn(grid.currentColumn)
                    QQC2.ToolTip.text: i18n("Jump to current period")
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        columnHeaderDelegate: Component {
            Rectangle {
                id: head
                readonly property string timeKey: parent ? parent.columnKey : ""
                readonly property bool isCurrent: timeKey === grid.currentColumn
                readonly property bool isOverdue: timeKey === "overdue"
                readonly property int total: root.matrix.timeTotals ? (root.matrix.timeTotals[timeKey] || 0) : 0
                readonly property string sub: Labels.subtitle(root.matrix, timeKey, root.timeBucket)
                color: Kirigami.Theme.backgroundColor

                Rectangle {
                    anchors.fill: parent
                    color: head.isCurrent ? Kirigami.Theme.highlightColor
                         : root.weekendColumns[head.timeKey] === true ? Kirigami.Theme.textColor
                         : "transparent"
                    opacity: head.isCurrent ? Design.matrixTodayTintOpacity * 2 : Design.matrixWeekendTintOpacity
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: head.isCurrent ? 2 : 1
                    color: head.isCurrent ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    opacity: head.isCurrent ? 1 : Design.matrixLineOpacity
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Kirigami.Theme.textColor
                    opacity: Design.matrixLineOpacity
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Design.spaceSmall * 2
                    anchors.rightMargin: Design.spaceSmall * 2
                    spacing: Design.spaceSmall

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: root.timeTitle(head.timeKey)
                            font.bold: true
                            elide: Text.ElideRight
                            color: head.isOverdue ? Kirigami.Theme.negativeTextColor
                                 : head.isCurrent ? Kirigami.Theme.highlightColor
                                 : Kirigami.Theme.textColor
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: head.sub !== ""
                            text: head.sub
                            opacity: 0.7
                            elide: Text.ElideRight
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }
                    QQC2.Label {
                        Layout.alignment: Qt.AlignVCenter
                        visible: head.total > 0
                        text: String(head.total)
                        opacity: 0.7
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }

                HoverHandler {
                    id: headHover
                    enabled: !root.interactionsSuspended && head.total > 0
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: !root.interactionsSuspended && head.total > 0
                    onTapped: root.drill("", head.timeKey)
                }
                QQC2.ToolTip.text: i18np("Show %1 task in the list", "Show %1 tasks in the list", head.total)
                QQC2.ToolTip.visible: headHover.hovered && head.total > 0
            }
        }

        rowHeaderDelegate: Component {
            Rectangle {
                id: rowHead
                readonly property string laneKey: parent ? parent.rowKey : ""
                readonly property int total: root.matrix.rowTotals ? (root.matrix.rowTotals[laneKey] || 0) : 0
                implicitHeight: Design.swimlaneCellMinHeight
                color: Kirigami.Theme.backgroundColor

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Kirigami.Theme.textColor
                    opacity: Design.matrixLineOpacity
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Kirigami.Theme.textColor
                    opacity: Design.matrixLineOpacity
                }

                RowLayout {
                    id: rowContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Design.spaceSmall * 2
                    // Tall lanes: keep the label in view while scrolling down inside the lane.
                    y: Design.spaceSmall * 2 + Math.max(0, Math.min(
                           rowHead.height - implicitHeight - Design.spaceSmall * 4,
                           grid.flickable.contentY + grid.headerHeight - (rowHead.parent ? rowHead.parent.y : 0)))
                    spacing: Design.spaceSmall

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: root.laneIcon()
                        color: root.laneColor(rowHead.laneKey)
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.laneLabel(rowHead.laneKey)
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        visible: rowHead.total > 0
                        text: String(rowHead.total)
                        opacity: 0.7
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }

                HoverHandler {
                    id: rowHover
                    enabled: !root.interactionsSuspended && rowHead.total > 0
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    enabled: !root.interactionsSuspended && rowHead.total > 0
                    onTapped: root.drill(rowHead.laneKey, "")
                }
                QQC2.ToolTip.text: i18np("Show %1 task in the list", "Show %1 tasks in the list", rowHead.total)
                QQC2.ToolTip.visible: rowHover.hovered && rowHead.total > 0
            }
        }

        cellDelegate: Component {
            Item {
                id: cell
                readonly property string laneKey: parent ? parent.rowKey : ""
                readonly property string timeKey: parent ? parent.columnKey : ""
                readonly property string cellKey: laneKey + "|" + timeKey
                readonly property var ids: root.cells[cellKey] || []
                readonly property int shownCount: Math.min(ids.length, Design.swimlaneMaxCardsPerCell)
                readonly property int hiddenCount: ids.length - shownCount
                readonly property bool isCurrent: timeKey === grid.currentColumn
                readonly property bool droppable: timeKey !== "overdue" && timeKey !== "later"
                readonly property bool isDropTarget: root.dropCellKey === cellKey
                readonly property bool isWeekend: root.weekendColumns[timeKey] === true

                // Virtualization: a cell only builds its content (tint, grid lines, cards,
                // hit areas) once it is within a screen of the viewport, and keeps it afterwards.
                // Building every cell of a large matrix up front costs hundreds of milliseconds
                // on each axis / bucket switch; an unbuilt cell just reserves an estimated height
                // from its card count so the scroll extent stays plausible.
                readonly property real cardEstimate: Kirigami.Units.gridUnit * 4.5 + Design.kanbanCardGap
                property bool contentWanted: false
                readonly property bool nearViewport: {
                    var p = cell.parent
                    if (!p || p.width <= 0) {
                        return false   // not laid out yet
                    }
                    return p.x + p.width > grid.viewX - grid.width && p.x < grid.viewX + grid.width * 2
                        && p.y + cell.height > grid.viewY - grid.height && p.y < grid.viewY + grid.height * 2
                }
                onNearViewportChanged: if (nearViewport) contentWanted = true

                implicitHeight: content.item
                        ? content.item.implicitHeight
                        : Math.max(Design.swimlaneCellMinHeight,
                                   shownCount * cardEstimate + Design.spaceSmall * 2)

                Loader {
                    id: content
                    anchors.fill: parent
                    active: cell.contentWanted
                    sourceComponent: cellContent
                }

                Component {
                    id: cellContent

                    Item {
                        implicitHeight: Math.max(Design.swimlaneCellMinHeight,
                                                 cardsColumn.implicitHeight + Design.spaceSmall * 2)

                        Rectangle {
                            anchors.fill: parent
                            color: cell.isDropTarget || cell.isCurrent ? Kirigami.Theme.highlightColor
                                 : cell.isWeekend ? Kirigami.Theme.textColor
                                 : "transparent"
                            opacity: cell.isDropTarget ? 0.22
                                   : cell.isCurrent ? Design.matrixTodayTintOpacity * 0.6
                                   : Design.matrixWeekendTintOpacity
                            Behavior on opacity {
                                enabled: !Design.reducedMotion
                                NumberAnimation { duration: Kirigami.Units.shortDuration }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: cell.isDropTarget
                            color: "transparent"
                            border.width: 2
                            border.color: Kirigami.Theme.highlightColor
                            radius: Design.inputRadius
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Kirigami.Theme.textColor
                            opacity: Design.matrixLineOpacity
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: Kirigami.Theme.textColor
                            opacity: Design.matrixLineOpacity
                        }

                        // Empty area → open the cell in the list.
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.interactionsSuspended && cell.ids.length > 0
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.drill(cell.laneKey, cell.timeKey)
                            QQC2.ToolTip.text: i18np("Show %1 task in the list",
                                                     "Show %1 tasks in the list", cell.ids.length)
                            QQC2.ToolTip.visible: containsMouse && cell.ids.length > 0
                                                 && !root.kanbanDragCommitted
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }

                        Column {
                            id: cardsColumn
                            x: Design.spaceSmall
                            y: Design.spaceSmall
                            width: parent.width - Design.spaceSmall * 2
                            spacing: Design.kanbanCardGap

                            Repeater {
                                model: cell.shownCount

                                delegate: Item {
                                    id: slot
                                    required property int index
                                    readonly property var taskObj: root.tasks[String(cell.ids[index])]

                                    width: cardsColumn.width
                                    height: !cardLoader.item ? (slot.taskObj ? cell.cardEstimate : 0)
                                          : (root.kanbanDragCommitted && root.dragSourceKey === cell.cellKey
                                             && root.dragSourceIndex === slot.index)
                                            ? root.dragPlaceholderHeight : cardLoader.item.height

                                    // Cells and the task map arrive together, but bindings settle one
                                    // by one: only build a card while its task is actually known.
                                    Loader {
                                        id: cardLoader
                                        width: slot.width
                                        active: !!slot.taskObj
                                        // Build cards incrementally so a cell full of tasks does not
                                        // block the frame.
                                        asynchronous: !root.controller.smokeTest
                                        sourceComponent: KanbanCard {
                                            width: slot.width
                                            controller: root.controller
                                            task: slot.taskObj
                                            dragHost: root.dragHost
                                            kanbanView: root
                                            cardIndex: slot.index
                                            columnKey: cell.cellKey
                                            compact: true
                                            interactionsSuspended: root.interactionsSuspended
                                            onRequestFullEditor: function(taskObj) {
                                                if (root.onOpenFullEditor) {
                                                    root.onOpenFullEditor(taskObj)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Overflow marker: the cell itself drills into the list on click.
                            QQC2.Label {
                                width: cardsColumn.width
                                visible: cell.hiddenCount > 0
                                topPadding: Design.spaceTiny
                                text: i18np("+%1 more task", "+%1 more tasks", cell.hiddenCount)
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                color: Kirigami.Theme.highlightColor
                                elide: Text.ElideRight
                            }
                        }

                        // Columns that cannot take drops (Overdue / Later) fade while a card is in flight.
                        Rectangle {
                            anchors.fill: parent
                            visible: root.kanbanDragCommitted && !cell.droppable
                            color: Kirigami.Theme.backgroundColor
                            opacity: 0.55
                        }

                        DropArea {
                            anchors.fill: parent
                            keys: ["application/x-kurrent-task"]
                            enabled: cell.droppable && !!(root.dragHost && root.dragHost.draggingTask
                                                          && root.kanbanDragCommitted)
                            z: 10

                            onEntered: function(drag) {
                                drag.acceptProposedAction()
                                root.setDrop(cell.cellKey)
                            }
                            onExited: {
                                if (root.dropCellKey === cell.cellKey) {
                                    root.clearDrop()
                                }
                            }
                            onDropped: function(drop) {
                                root.finishDrop(cell.laneKey, cell.timeKey)
                                drop.acceptProposedAction()
                            }
                        }
                    }
                }
            }
        }
    }
}
