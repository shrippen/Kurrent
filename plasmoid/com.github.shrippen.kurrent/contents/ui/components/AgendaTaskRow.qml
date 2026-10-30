import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import ".."
import "../Kante"
import "../taps.js" as Taps

// One task in the Agenda's day view (loose tasks, suggestions): project as colour edge, a
// check box, the title and one meta line. Drag it onto a day's hour grid to give it a time.
// A click shows it in the inspector (when on), otherwise opens the editor.
Rectangle {
    id: row

    required property TaskController controller
    required property var task
    property Item dragHost: null
    property bool interactionsSuspended: false
    /** Text under the title (time, due day). */
    property string meta: ""
    /** Reason markers: [{text, tone}] with tone "late", "high", "fit" or "". */
    property var reasons: []
    /** A button on the right ("→ Today"); empty hides it. */
    property string actionText: ""
    signal actionClicked()

    readonly property bool inspected: !!(dragHost && dragHost.inspectorActive && dragHost.inspectedItemId === task.itemId)

    implicitHeight: body.implicitHeight + Design.padInner * 2
    radius: Design.radius
    color: inspected ? KanteStyle.selectionColor : (hover.hovered ? KanteStyle.sunkenColor : KanteStyle.cardColor)
    border.width: inspected ? KanteStyle.borderWidth : 0
    border.color: KanteStyle.accentColor
    opacity: task.completed ? KanteStyle.doneOpacity : 1

    function toneColor(tone) {
        if (tone === "late") {
            return KanteStyle.negativeTextColor
        }
        if (tone === "high") {
            return KanteStyle.warningColor
        }
        if (tone === "fit") {
            return KanteStyle.positiveTextColor
        }
        return KanteStyle.mutedTextColor
    }

    function open(tapCount) {
        if (!dragHost) {
            return
        }
        var action = Taps.tapAction(tapCount, !!dragHost.inspectorActive)
        if (action === "inspect") {
            dragHost.inspectTask(task.itemId)
        } else if (action === "edit" && dragHost.openFullEditor) {
            dragHost.openFullEditor(controller.taskSnapshotById(task.itemId))
        }
    }

    Rectangle {
        width: KanteStyle.edgeWidth
        height: parent.height
        radius: KanteStyle.edgeRadius
        color: Design.colorForKey(String(row.task.collectionId))
    }

    RowLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Design.padInner + KanteStyle.edgeWidth
        anchors.rightMargin: Design.padInner
        spacing: Design.spaceSmall

        QQC2.CheckBox {
            Layout.alignment: Qt.AlignTop
            checked: row.task.completed
            enabled: !row.interactionsSuspended
            onToggled: row.controller.setTaskCompleted(row.task.itemId, checked)
            QQC2.ToolTip.text: row.task.completed ? i18n("Mark as not done") : i18n("Mark as done")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Design.spaceTiny

            QQC2.Label {
                Layout.fillWidth: true
                text: row.task.summary || i18n("(Untitled)")
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.strikeout: row.task.completed
            }
            Flow {
                Layout.fillWidth: true
                spacing: Design.spaceSmall
                visible: row.meta !== "" || row.reasons.length > 0
                QQC2.Label {
                    visible: row.meta !== ""
                    text: row.meta
                    color: KanteStyle.mutedTextColor
                    font: Kirigami.Theme.smallFont
                }
                Repeater {
                    model: row.reasons
                    delegate: QQC2.Label {
                        required property var modelData
                        text: modelData.text
                        color: row.toneColor(modelData.tone)
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        KanteButton {
            visible: row.actionText !== ""
            Layout.alignment: Qt.AlignVCenter
            text: row.actionText
            onClicked: row.actionClicked()
        }
    }

    HoverHandler {
        id: hover
        enabled: !row.interactionsSuspended
    }

    TapHandler {
        enabled: !row.interactionsSuspended
        onTapped: row.open(tapCount)
    }

    AgendaTaskDrag {
        task: row.task
        dragHost: row.dragHost
        suspended: row.interactionsSuspended
    }
}
