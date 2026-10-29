import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import ".."
import "../Kante"
import "../taps.js" as Taps
import "../datetime.js" as DateTime

// A task as a dense card for narrow week columns: project as colour edge, the title up to
// three lines (with its time when it has a block), then labels and priority. With `showDate`
// it names the due day (the overdue tray). Drag it onto a day; a click shows it in the
// inspector (when on), otherwise opens the editor.
Rectangle {
    id: card

    required property TaskController controller
    required property var task
    property Item dragHost: null
    property bool interactionsSuspended: false
    property bool showDate: false

    readonly property bool inspected: !!(dragHost && dragHost.inspectorActive && dragHost.inspectedItemId === task.itemId)
    readonly property color projectColor: Design.colorForKey(String(task.collectionId))

    implicitHeight: body.implicitHeight + Design.spaceSmall * 2
    radius: Design.inputRadius
    color: inspected ? KanteStyle.selectionColor : (hover.hovered ? KanteStyle.sunkenColor : KanteStyle.cardColor)
    border.width: inspected ? 1 : 0
    border.color: KanteStyle.accentColor
    opacity: task.completed ? 0.55 : 1

    QQC2.ToolTip.text: (task.summary || i18n("(Untitled)")) + (task.collectionName ? " · " + task.collectionName : "")
    QQC2.ToolTip.visible: hover.hovered && titleLabel.truncated
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    function hm(minute) {
        return DateTime.pad2(Math.floor(minute / 60)) + ":" + DateTime.pad2(minute % 60)
    }

    Rectangle {
        width: Design.agendaEdge
        height: parent.height
        radius: Design.agendaEdgeRadius
        color: card.projectColor
    }

    RowLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Design.spaceSmall
        anchors.leftMargin: Design.spaceSmall + Design.agendaEdge
        spacing: Design.spaceTiny

        QQC2.CheckBox {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: implicitIndicatorWidth
            padding: 0
            checked: card.task.completed
            enabled: !card.interactionsSuspended
            onToggled: card.controller.setTaskCompleted(card.task.itemId, checked)
            QQC2.ToolTip.text: card.task.completed ? i18n("Mark as not done") : i18n("Mark as done")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            QQC2.Label {
                id: titleLabel
                Layout.fillWidth: true
                text: (card.task.start !== undefined ? card.hm(card.task.start) + "  " : "") + (card.task.summary || i18n("(Untitled)"))
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.strikeout: card.task.completed
            }

            Flow {
                Layout.fillWidth: true
                spacing: Design.spaceTiny
                visible: card.showDate || (card.task.categories && card.task.categories.length > 0) || card.task.priority > 0
                QQC2.Label {
                    visible: card.showDate && !!card.task.dueDate
                    text: card.task.dueDate ? Qt.locale().toString(new Date(card.task.dueDate), "ddd d.M.") : ""
                    color: KanteStyle.negativeTextColor
                    font: Kirigami.Theme.smallFont
                }
                Repeater {
                    model: KanteStyle.active ? [] : (card.task.categories || [])
                    delegate: Kirigami.Icon {
                        required property string modelData
                        source: "tag"
                        color: Design.colorForKey(modelData, "label")
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        QQC2.ToolTip.text: modelData
                        QQC2.ToolTip.visible: tagHover.hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        HoverHandler { id: tagHover }
                    }
                }
                Repeater {
                    model: KanteStyle.active ? (card.task.categories || []) : []
                    delegate: KanteChip {
                        required property string modelData
                        compact: true
                        activeFocusOnTab: false
                        text: modelData
                        chipColor: Design.colorForKey(modelData, "label")
                    }
                }
                Kirigami.Icon {
                    visible: card.task.priority > 0
                    source: "flag"
                    color: Design.priorityColor(card.task.priority)
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: !card.interactionsSuspended
    }

    TapHandler {
        enabled: !card.interactionsSuspended
        onTapped: {
            if (!card.dragHost) {
                return
            }
            var action = Taps.tapAction(tapCount, !!card.dragHost.inspectorActive)
            if (action === "inspect") {
                card.dragHost.inspectTask(card.task.itemId)
            } else if (action === "edit" && card.dragHost.openFullEditor) {
                card.dragHost.openFullEditor(card.controller.taskSnapshotById(card.task.itemId))
            }
        }
    }

    AgendaTaskDrag {
        task: card.task
        dragHost: card.dragHost
        suspended: card.interactionsSuspended
    }
}
