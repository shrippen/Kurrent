import QtQuick
import QtQuick.Controls as QQC2
import "../Kante"

// A task row's "Reschedule" menu. Created when opened and gone when closed (TaskDelegate).
QQC2.Menu {
    id: menu

    required property var controller
    required property var itemId

    popupType: QQC2.Popup.Item
    onClosed: destroy()

    KantePopupSkin { popup: menu }

    QQC2.MenuItem {
        text: i18n("In 15 minutes")
        onTriggered: menu.controller.rescheduleTask(menu.itemId, "15m")
    }
    QQC2.MenuItem {
        text: i18n("In 1 hour")
        onTriggered: menu.controller.rescheduleTask(menu.itemId, "1h")
    }
    QQC2.MenuItem {
        text: i18n("In 4 hours")
        onTriggered: menu.controller.rescheduleTask(menu.itemId, "4h")
    }
    QQC2.MenuSeparator {}
    QQC2.MenuItem {
        text: i18n("Tomorrow")
        onTriggered: menu.controller.rescheduleTask(menu.itemId, "tomorrow")
    }
    QQC2.MenuItem {
        text: i18n("Next week")
        onTriggered: menu.controller.rescheduleTask(menu.itemId, "next-week")
    }
}
