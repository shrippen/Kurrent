import QtQuick
import org.kde.kirigami as Kirigami
import ".."
import "../Kante"

// Main-pane hint when overdue tasks exist and the current view does not show them.
// Closing hides it until the overdue count grows again.
Kirigami.InlineMessage {
    id: banner

    required property var controller
    property int dismissedCount: 0

    readonly property int overdueCount: controller && controller.viewTaskCounts
            ? (controller.viewTaskCounts["overdue"] || 0) : 0
    readonly property bool relevantView: !!controller
            && controller.currentView !== "overdue"
            && controller.currentView !== "completed"
    readonly property bool shouldShow: Design.showOverdueBanner && relevantView
            && overdueCount > 0 && overdueCount > dismissedCount

    signal showOverdue()

    // Kante: square callout tinted with the warning colour.
    KanteMessageSkin { message: banner }

    type: Kirigami.MessageType.Warning
    showCloseButton: true
    text: i18np("%1 task is overdue.", "%1 tasks are overdue.", overdueCount)

    // The close button sets visible = false directly, so drive visibility through a Binding
    // (re-applied when shouldShow changes) instead of a plain property binding.
    visible: false
    Binding {
        target: banner
        property: "visible"
        value: banner.shouldShow
    }

    onVisibleChanged: {
        if (!visible && shouldShow) {
            dismissedCount = overdueCount
        }
    }
    onOverdueCountChanged: {
        if (overdueCount === 0) {
            dismissedCount = 0
        }
    }

    actions: [
        Kirigami.Action {
            icon.name: "go-jump-today"
            text: i18n("Move all to today")
            onTriggered: banner.controller.rescheduleOverdueToToday()
        },
        Kirigami.Action {
            icon.name: "view-filter"
            text: i18n("Show overdue")
            onTriggered: banner.showOverdue()
        }
    ]
}
