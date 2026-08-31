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

    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    spacing: Design.spaceSmall

    property string heatmapMode: "due"
    property var monthStart: {
        var d = new Date()
        return new Date(d.getFullYear(), d.getMonth(), 1)
    }

    readonly property var counts: controller
            ? controller.heatmapCountsForMonth(monthStart, heatmapMode)
            : ({})

    RowLayout {
        Layout.fillWidth: true
        QQC2.Label { text: i18n("Mode:") }
        QQC2.ComboBox {
            model: [
                { text: i18n("Due dates"), value: "due" },
                { text: i18n("Completions"), value: "completed" }
            ]
            textRole: "text"
            onActivated: root.heatmapMode = model[currentIndex].value
        }
    }

    Flow {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 2

        Repeater {
            model: Object.keys(root.counts)
            delegate: Rectangle {
                required property string modelData
                readonly property int count: root.counts[modelData]
                width: Design.heatmapCellSize
                height: Design.heatmapCellSize
                radius: 2
                color: Kirigami.Theme.highlightColor
                opacity: Math.min(0.85, 0.15 + count * 0.15)

                QQC2.ToolTip.text: modelData + ": " + count
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
