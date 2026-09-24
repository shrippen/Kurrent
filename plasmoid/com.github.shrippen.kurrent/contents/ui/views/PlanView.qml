import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import "../matrixlabels.js" as Labels
import ".."

// Project plan: rows = projects, columns = time periods, cells = task counts.
// Clicking a cell / row / column opens the list filtered to it (the matrix itself stays intact).
Item {
    id: root

    required property TaskController controller
    // Full-editor overlay: suppress hover under the dim.
    property bool interactionsSuspended: false

    clip: true
    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0

    readonly property int layoutRevision: controller ? controller.matrixRevision : 0
    readonly property string timeBucket: controller ? controller.planTimeBucket : "week"

    readonly property var grid: {
        var rev = layoutRevision
        var bucket = controller ? controller.planTimeBucket : ""
        var hz = controller ? controller.planHorizon : 0
        var undated = controller ? controller.planShowUndated : true
        var done = controller ? controller.planShowCompleted : false
        return controller ? controller.planMatrixGridForVisibleTasks() : ({})
    }
    readonly property var projects: grid.projects || []
    readonly property var weeks: grid.weeks || []
    readonly property var counts: grid.counts || ({})
    readonly property var stats: grid.stats || ({})
    readonly property var laneLabels: grid.laneLabels || ({})

    // Relative heat scale: the busiest cell of this matrix is the darkest.
    readonly property int maxCount: {
        var m = 1
        for (var k in counts) {
            if (counts[k] > m) {
                m = counts[k]
            }
        }
        return m
    }

    readonly property var timeStrings: ({
        overdue: i18n("Overdue"),
        later: i18n("Later"),
        unscheduled: i18n("No date"),
        today: i18n("Today"),
        tomorrow: i18n("Tomorrow"),
        week: function(n) { return i18n("Week %1", n) }
    })

    function projectLabel(key) {
        if (key === "inbox") {
            return i18n("Inbox")
        }
        var l = laneLabels[key]
        return l !== undefined && l !== "" ? l : key
    }

    function drill(projectKey, timeKey) {
        if (!controller) {
            return
        }
        var parts = []
        if (projectKey) {
            parts.push(projectLabel(projectKey))
        }
        if (timeKey) {
            parts.push(Labels.fullLabel(grid, timeKey, timeBucket, timeStrings))
        }
        controller.setMatrixDrilldown("plan", projectKey || "", timeKey || "", parts.join(" · "))
        controller.requestMainPaneMode("list")
    }

    property real rowHeaderWidth: Design.matrixRowHeaderMinWidth
    function updateRowHeaderWidth() {
        var widest = 0
        for (var i = 0; i < projects.length; ++i) {
            labelMetrics.text = projectLabel(projects[i])
            widest = Math.max(widest, labelMetrics.advanceWidth)
        }
        var chrome = Kirigami.Units.iconSizes.small + Design.spaceSmall * 4 + Kirigami.Units.gridUnit * 2
        rowHeaderWidth = Math.max(Design.matrixRowHeaderMinWidth,
                                  Math.min(Design.matrixRowHeaderMaxWidth, widest + chrome))
    }
    onProjectsChanged: updateRowHeaderWidth()
    onLaneLabelsChanged: updateRowHeaderWidth()

    TextMetrics {
        id: labelMetrics
        font.bold: true
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Design.spaceMedium * 2
        visible: root.projects.length === 0 || root.weeks.length === 0
        icon.name: "view-pim-tasks"
        text: controller && controller.loading ? i18n("Loading tasks…") : i18n("No dated open tasks in this view.")
        explanation: controller && controller.loading ? ""
                     : i18n("Give tasks a due or start date to see them planned by project and period.")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: root.projects.length > 0 && root.weeks.length > 0

        MatrixGrid {
            id: matrixGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            rows: root.projects
            columns: root.weeks
            columnWidth: Design.planColumnWidth(root.timeBucket)
            rowHeaderWidth: root.rowHeaderWidth
            currentColumn: root.grid.currentTime || ""

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
                        onClicked: matrixGrid.scrollToColumn(matrixGrid.currentColumn)
                        QQC2.ToolTip.text: i18n("Jump to current period")
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }

            columnHeaderDelegate: Component {
                Rectangle {
                    id: head
                    readonly property string timeKey: parent ? parent.columnKey : ""
                    readonly property bool isCurrent: timeKey === matrixGrid.currentColumn
                    readonly property bool isOverdue: timeKey === "overdue"
                    readonly property int total: root.grid.timeTotals ? (root.grid.timeTotals[timeKey] || 0) : 0
                    readonly property string sub: Labels.subtitle(root.grid, timeKey, root.timeBucket)
                    color: Kirigami.Theme.backgroundColor

                    Rectangle {
                        anchors.fill: parent
                        color: head.isCurrent ? Kirigami.Theme.highlightColor
                             : head.isOverdue ? Kirigami.Theme.negativeTextColor : "transparent"
                        opacity: head.isCurrent ? Design.matrixTodayTintOpacity * 2 : Design.matrixTodayTintOpacity
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

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Design.spaceSmall
                        spacing: 0
                        Item { Layout.fillHeight: true }
                        QQC2.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Labels.title(root.grid, head.timeKey, root.timeBucket, root.timeStrings)
                            font.bold: true
                            elide: Text.ElideRight
                            color: head.isOverdue ? Kirigami.Theme.negativeTextColor
                                 : head.isCurrent ? Kirigami.Theme.highlightColor
                                 : Kirigami.Theme.textColor
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            visible: head.sub !== ""
                            text: head.sub
                            opacity: 0.7
                            elide: Text.ElideRight
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                        Item { Layout.fillHeight: true }
                    }

                    HoverHandler {
                        id: headHover
                        enabled: !root.interactionsSuspended
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: !root.interactionsSuspended
                        onTapped: root.drill("", head.timeKey)
                    }
                    QQC2.ToolTip.text: i18np("Show %1 task in the list", "Show %1 tasks in the list", head.total)
                    QQC2.ToolTip.visible: headHover.hovered
                }
            }

            rowHeaderDelegate: Component {
                Rectangle {
                    id: rowHead
                    readonly property string projectKey: parent ? parent.rowKey : ""
                    readonly property int total: root.grid.rowTotals ? (root.grid.rowTotals[projectKey] || 0) : 0
                    implicitHeight: Design.planCellHeight
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
                        anchors.fill: parent
                        anchors.leftMargin: Design.spaceSmall * 2
                        anchors.rightMargin: Design.spaceSmall * 2
                        spacing: Design.spaceSmall

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: rowHead.projectKey === "inbox" ? "mail-folder-inbox" : "folder"
                            color: Design.colorForKey(rowHead.projectKey, "project")
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: root.projectLabel(rowHead.projectKey)
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            text: String(rowHead.total)
                            opacity: 0.7
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        enabled: !root.interactionsSuspended
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: !root.interactionsSuspended
                        onTapped: root.drill(rowHead.projectKey, "")
                    }
                    QQC2.ToolTip.text: i18np("Show %1 task in the list", "Show %1 tasks in the list", rowHead.total)
                    QQC2.ToolTip.visible: rowHover.hovered
                }
            }

            cellDelegate: Component {
                Item {
                    id: cell
                    readonly property string projectKey: parent ? parent.rowKey : ""
                    readonly property string timeKey: parent ? parent.columnKey : ""
                    readonly property string cellKey: projectKey + "|" + timeKey
                    readonly property int count: root.counts[cellKey] || 0
                    readonly property var st: root.stats[cellKey] || ({})
                    readonly property bool isOverdueCol: timeKey === "overdue"
                    readonly property bool isCurrent: timeKey === matrixGrid.currentColumn
                    readonly property real heat: count > 0 ? Math.min(1, count / root.maxCount) : 0
                    readonly property color heatColor: isOverdueCol ? Kirigami.Theme.negativeTextColor
                                                                    : Kirigami.Theme.highlightColor

                    implicitHeight: Design.planCellHeight

                    Rectangle {
                        anchors.fill: parent
                        color: cell.isCurrent ? Kirigami.Theme.highlightColor : "transparent"
                        opacity: Design.matrixTodayTintOpacity * 0.6
                    }
                    // Heat chip: intensity follows the count relative to the busiest cell.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Design.spaceTiny
                        radius: Design.inputRadius
                        visible: cell.count > 0
                        color: cell.heatColor
                        opacity: 0.14 + 0.5 * cell.heat
                        border.width: cellMouse.containsMouse ? 2 : 0
                        border.color: cell.heatColor
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Design.spaceTiny
                        radius: Design.inputRadius
                        visible: cell.count === 0 && cellMouse.containsMouse
                        color: "transparent"
                        border.width: 1
                        border.color: Kirigami.Theme.textColor
                        opacity: 0.2
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

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        visible: cell.count > 0

                        QQC2.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: String(cell.count)
                            font.bold: true
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.15
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Design.spaceTiny
                            visible: !cell.isOverdueCol && ((cell.st.overdue || 0) > 0 || (cell.st.high || 0) > 0)
                            Rectangle {
                                visible: (cell.st.overdue || 0) > 0
                                width: Kirigami.Units.smallSpacing * 2
                                height: width
                                radius: width / 2
                                color: Kirigami.Theme.negativeTextColor
                            }
                            Kirigami.Icon {
                                visible: (cell.st.high || 0) > 0
                                source: "flag"
                                color: Kirigami.Theme.neutralTextColor
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.75
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.75
                            }
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        enabled: !root.interactionsSuspended && cell.count > 0
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.drill(cell.projectKey, cell.timeKey)
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.text: {
                            var lines = [i18np("%1 task", "%1 tasks", cell.count)]
                            if ((cell.st.overdue || 0) > 0 && !cell.isOverdueCol) {
                                lines.push(i18n("%1 overdue", cell.st.overdue))
                            }
                            if ((cell.st.high || 0) > 0) {
                                lines.push(i18n("%1 high priority", cell.st.high))
                            }
                            if ((cell.st.done || 0) > 0) {
                                lines.push(i18n("%1 completed", cell.st.done))
                            }
                            return lines.join(" · ")
                        }
                    }
                }
            }
        }

        // Legend: counts are task numbers, not workload.
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Design.spaceSmall
            spacing: Design.spaceMedium

            QQC2.Label {
                text: i18n("Number of tasks per period")
                opacity: 0.6
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: Kirigami.Units.smallSpacing * 2
                height: width
                radius: width / 2
                color: Kirigami.Theme.negativeTextColor
            }
            QQC2.Label {
                text: i18n("overdue")
                opacity: 0.6
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
            Kirigami.Icon {
                source: "flag"
                color: Kirigami.Theme.neutralTextColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.75
                Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.75
            }
            QQC2.Label {
                text: i18n("high priority")
                opacity: 0.6
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }
}
