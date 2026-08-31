import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import ".."

ColumnLayout {
    id: root

    required property TaskController controller
    // Full-editor overlay: no cell hover/tooltips under the dim.
    property bool interactionsSuspended: false

    clip: true
    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    spacing: Design.spaceSmall

    readonly property var matrix: controller ? controller.swimlaneMatrixForVisibleTasks() : ({})
    readonly property var lanes: matrix.lanes || []
    readonly property var times: matrix.times || []
    readonly property var cells: matrix.cells || ({})

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceTiny

        QQC2.Label {
            text: i18n("Busy days:")
            opacity: 0.8
        }

        Flow {
            Layout.fillWidth: true
            spacing: Design.spaceTiny

            Repeater {
                model: controller ? controller.busyDayStripForVisibleTasks() : []
                delegate: QQC2.ToolButton {
                    required property string modelData
                    text: modelData.slice(5)
                    display: QQC2.AbstractButton.TextOnly
                    onClicked: {
                        controller.currentView = "today"
                        controller.searchQuery = ""
                    }
                    QQC2.ToolTip.text: modelData
                    QQC2.ToolTip.visible: hovered
                }
            }
        }
    }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ColumnLayout {
            width: Math.max(root.width, headerRow.implicitWidth)
            spacing: 1

            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: 1

                Item {
                    Layout.preferredWidth: Design.kanbanColumnMinWidth
                    Layout.minimumWidth: Design.kanbanColumnMinWidth
                }

                Repeater {
                    model: root.times
                    delegate: QQC2.Label {
                        required property string modelData
                        Layout.preferredWidth: Design.kanbanColumnMinWidth
                        Layout.minimumWidth: Design.kanbanColumnMinWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: controller.swimlaneTimeLabelForKey(modelData)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }

            Repeater {
                model: root.lanes
                delegate: RowLayout {
                    required property string modelData
                    readonly property string laneKey: modelData
                    Layout.fillWidth: true
                    spacing: 1

                    QQC2.Label {
                        Layout.preferredWidth: Design.kanbanColumnMinWidth
                        Layout.minimumWidth: Design.kanbanColumnMinWidth
                        text: controller.swimlaneLaneLabelForKey(laneKey)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.times
                        delegate: Rectangle {
                            required property string modelData
                            readonly property string timeKey: modelData
                            readonly property string cellKey: laneKey + "|" + timeKey
                            readonly property var taskIds: root.cells[cellKey] || []

                            Layout.preferredWidth: Design.kanbanColumnMinWidth
                            Layout.minimumWidth: Design.kanbanColumnMinWidth
                            Layout.preferredHeight: Math.max(Design.heatmapCellSize * 2, cellCol.implicitHeight + Design.padInner * 2)
                            radius: Design.inputRadius
                            color: taskIds.length > 0 ? Kirigami.Theme.highlightColor : Kirigami.Theme.backgroundColor
                            opacity: taskIds.length > 0 ? Math.min(0.85, 0.2 + taskIds.length * 0.12) : 0.35
                            border.color: Kirigami.Theme.disabledTextColor

                            ColumnLayout {
                                id: cellCol
                                anchors.fill: parent
                                anchors.margins: Design.padInner
                                spacing: 2

                                QQC2.Label {
                                    visible: taskIds.length > 0
                                    Layout.alignment: Qt.AlignHCenter
                                    text: String(taskIds.length)
                                    font.bold: true
                                }
                            }

                            QQC2.ToolTip.text: taskIds.length + " " + i18n("tasks")
                            QQC2.ToolTip.visible: ma.containsMouse
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: !root.interactionsSuspended
                            }
                        }
                    }
                }
            }
        }
    }
}
