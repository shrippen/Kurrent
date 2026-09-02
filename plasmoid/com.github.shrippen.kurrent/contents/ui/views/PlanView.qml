import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import ".."

ColumnLayout {
    id: root

    required property TaskController controller

    clip: true
    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    spacing: Design.spaceSmall

    readonly property var grid: controller ? controller.planMatrixGridForVisibleTasks() : ({})
    readonly property var projects: grid.projects || []
    readonly property var weeks: grid.weeks || []
    readonly property var counts: grid.counts || ({})

    // Labels for time columns: "Overdue", "Undated", or format by bucket
    function timeLabel(key) {
        if (key === "overdue") return i18n("Overdue")
        if (key === "undated") return i18n("Undated")
        return key
    }

    // Column width varies by bucket
    readonly property real colWidth: {
        if (!controller) return Kirigami.Units.gridUnit * 7
        var bucket = controller.planTimeBucket || "week"
        if (bucket === "day") return Kirigami.Units.gridUnit * 5
        if (bucket === "month") return Kirigami.Units.gridUnit * 9
        return Kirigami.Units.gridUnit * 7
    }

    readonly property bool hasOverdue: weeks.indexOf("overdue") >= 0
    readonly property bool hasUndated: weeks.indexOf("undated") >= 0

    Kirigami.Heading {
        Layout.fillWidth: true
        level: 4
        text: i18n("Open tasks by project and time")
    }

    QQC2.Label {
        visible: projects.length === 0 || weeks.length === 0
        text: i18n("No dated open tasks in this view.")
        opacity: 0.7
    }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: projects.length > 0 && weeks.length > 0

        ColumnLayout {
            width: Math.max(root.width, headerRow.implicitWidth)
            spacing: 1

            RowLayout {
                id: headerRow
                spacing: 1

                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                }

                Repeater {
                    model: root.weeks
                    delegate: QQC2.Label {
                        required property string modelData
                        Layout.preferredWidth: root.colWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: root.timeLabel(modelData)
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: modelData === "overdue" ? Kirigami.Theme.negativeTextColor
                               : modelData === "undated" ? Kirigami.Theme.disabledTextColor
                               : Kirigami.Theme.textColor
                    }
                }
            }

            Repeater {
                model: root.projects
                delegate: RowLayout {
                    required property string modelData
                    readonly property string projectKey: modelData
                    readonly property int projectId: projectKey === "inbox" ? -1 : parseInt(projectKey, 10)

                    QQC2.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                        text: projectKey === "inbox"
                              ? i18n("Inbox")
                              : controller.collectionNameForId(projectId)
                        elide: Text.ElideRight
                        font.bold: true
                    }

                    Repeater {
                        model: root.weeks
                        delegate: Rectangle {
                            required property string modelData
                            readonly property string weekKey: modelData
                            readonly property string cellKey: projectKey + "|" + weekKey
                            readonly property int count: root.counts[cellKey] || 0
                            readonly property bool isOverdue: weekKey === "overdue"
                            readonly property bool isUndated: weekKey === "undated"

                            Layout.preferredWidth: root.colWidth
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                            radius: 2
                            color: count > 0
                                   ? isOverdue ? Kirigami.Theme.negativeTextColor
                                   : Kirigami.Theme.highlightColor
                                   : Kirigami.Theme.backgroundColor
                            opacity: count > 0 ? Math.min(0.9, 0.25 + count * 0.1) : 0.3
                            border.color: isOverdue && count > 0
                                          ? Kirigami.Theme.negativeTextColor
                                          : Kirigami.Theme.disabledTextColor

                            QQC2.Label {
                                anchors.centerIn: parent
                                text: count > 0 ? String(count) : ""
                                font.bold: count > 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: count > 0
                                onClicked: controller.setPlanPreviewFilter(projectId, weekKey)
                                QQC2.ToolTip.text: i18n("Show %1 tasks", count)
                                QQC2.ToolTip.visible: containsMouse
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: projects.length > 0

        QQC2.Button {
            text: i18n("Clear cell filter")
            onClicked: controller.clearPlanPreviewFilter()
        }
    }
}
