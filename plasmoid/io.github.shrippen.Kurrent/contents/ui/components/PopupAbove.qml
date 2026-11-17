import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami 2.20 as Kirigami
import ".."

// Places a picker's list above its input field, as high as the space up to the top of
// `boundsItem` allows, and opens it. The pickers sit at the bottom of the editor, so a list
// below the field would run off the window.
//
//   +-------------+
//   |  list       |  <- popup, at most as high as the room above the field
//   +-------------+
//   | [ field   ] |
//   +-------------+
QtObject {
    id: placer

    property Item owner: null          // the picker; the popup is positioned relative to it
    property Item field: null          // the input field the list sits above
    property Item boundsItem: null     // the top edge of the room; null = the topmost sized ancestor
    property QQC2.Popup popup: null
    property ListView list: null

    function availableAbove() {
        var host = boundsItem
        if (!host) {
            var p = owner.parent
            while (p) {
                if (p.width > 0 && p.height > 0 && p !== owner) {
                    host = p
                }
                p = p.parent
            }
        }
        if (!host) {
            return Kirigami.Units.gridUnit * 12
        }
        var top = field.mapToItem(host, 0, 0).y
        return Math.max(Kirigami.Units.gridUnit * 3, top - Design.spaceSmall)
    }

    function place() {
        var maxH = availableAbove()
        var contentH = Math.max(Kirigami.Units.gridUnit * 3,
                                list.contentHeight + Design.spaceMedium)
        popup.height = Math.min(maxH, contentH)
        popup.width = owner.width
        popup.x = 0
        popup.y = -popup.height - Design.spaceSmall
    }

    function open() {
        place()
        if (!popup.visible) {
            popup.open()
        } else {
            place()
        }
    }
}
