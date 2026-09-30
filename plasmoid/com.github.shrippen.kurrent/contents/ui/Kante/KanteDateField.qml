import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Date input: type the date or pick it in a month grid (`KanteCalendarGrid`).
 *   typed   "1.10.2026", "1.10.26", "1.10." (this year), "2026-10-01"; Enter or leaving
 *           the field takes it, an unreadable date marks the field `invalid`
 *   popup   the button opens the month; ‹ › change it, a tap picks the day and closes
 * `open()` / `close()` drive the popup; it stays inside the window (`popupAbove` forces a side).
 * `date` is a JS Date or null (empty). `dateEdited(date)` fires on every change by the user
 * (typed or picked), never when `date` is set from outside.
 *   System  a plain text field and tool button of the platform; the grid draws in the roles.
 *   Kante   sunken Kante field, square button, the popup as a Kante card.
 */
FocusScope {
    id: root

    property var date: null
    /** Shown and parsed first (Qt.formatDate), e.g. "dd.MM.yyyy" or "yyyy-MM-dd". */
    property string format: "dd.MM.yyyy"
    property string placeholderText: format.toUpperCase()
    property var dayNames: ["MO", "DI", "MI", "DO", "FR", "SA", "SO"]
    property string todayText: qsTr("Today")
    readonly property bool invalid: input.invalid
    readonly property alias popupOpen: popup.visible
    /** Side of the popup: undefined = below, above when there is no room (true / false force it). */
    property var popupAbove: undefined
    signal dateEdited(var date)

    implicitWidth: KanteStyle.unit(170)
    implicitHeight: input.implicitHeight

    /** Text -> Date, or null if empty, or undefined if unreadable. */
    function parse(text) {
        var t = String(text).trim()
        if (t === "") {
            return null
        }
        var fixed = Date.fromLocaleString(Qt.locale(), t, format)
        if (fixed instanceof Date && !isNaN(fixed.getTime())) {
            return fixed
        }
        var y, m, d
        var iso = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)
        var dmy = t.match(/^(\d{1,2})[.\/](\d{1,2})[.\/]?(\d{2}|\d{4})?$/)
        if (iso) {
            y = +iso[1]; m = +iso[2]; d = +iso[3]
        } else if (dmy) {
            d = +dmy[1]; m = +dmy[2]
            y = dmy[3] === undefined ? new Date().getFullYear() : +dmy[3]
            if (y < 100) {
                y += 2000
            }
        } else {
            return undefined
        }
        var out = new Date(y, m - 1, d)
        // 31.02. rolls over to March: not a date.
        if (out.getFullYear() !== y || out.getMonth() !== m - 1 || out.getDate() !== d) {
            return undefined
        }
        return out
    }

    /** Opens the month popup (e.g. from a shortcut); `close()` closes it. */
    function open() {
        popup.open()
    }
    function close() {
        popup.close()
    }

    function textOf(date) {
        return date ? Qt.formatDate(date, format) : ""
    }

    /** Takes a date from the user: sets it, shows it, tells the app. */
    function pick(d) {
        date = d
        input.invalid = false
        input.text = textOf(d)
        dateEdited(d)
    }

    function commit() {
        var d = parse(input.text)
        if (d === undefined) {
            input.invalid = true
            return
        }
        var same = (d === null && root.date === null)
            || (d !== null && root.date !== null && d.getTime() === new Date(root.date).getTime())
        input.invalid = false
        input.text = textOf(d)
        if (!same) {
            pick(d)
        }
    }

    onDateChanged: {
        if (!input.activeFocus) {
            input.text = textOf(date)
            input.invalid = false
        }
    }

    // The button sits inside the field's right end; the text keeps clear of it.
    Item {
        anchors.fill: parent

        KanteTextField {
            id: input
            anchors.fill: parent
            rightPadding: button.width + KanteStyle.unit(6)
            focus: true
            text: root.textOf(root.date)
            placeholderText: root.placeholderText
            inputMethodHints: Qt.ImhDate | Qt.ImhNoPredictiveText
            font.family: KanteStyle.monoFamily
            onAccepted: root.commit()
            onActiveFocusChanged: {
                if (!activeFocus) {
                    root.commit()
                }
            }
            Keys.onDownPressed: popup.open()
            // The field keeps the focus, so the popup never sees Escape itself.
            Keys.onEscapePressed: function (event) {
                event.accepted = popup.visible
                popup.close()
            }
        }
        KanteToolButton {
            id: button
            anchors.right: parent.right
            anchors.rightMargin: KanteStyle.unit(2)
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(KanteStyle.unit(20), input.height - KanteStyle.unit(4))
            width: height
            padding: 0
            display: QQC2.AbstractButton.IconOnly
            checkable: false
            focusPolicy: Qt.NoFocus
            Accessible.name: root.placeholderText
            onClicked: popup.visible ? popup.close() : popup.open()

            // Calendar glyph: a square with a heavy top edge, drawn in every kind.
            Rectangle {
                anchors.centerIn: parent
                width: KanteStyle.unit(13)
                height: KanteStyle.unit(12)
                color: "transparent"
                border.width: Math.max(1, KanteStyle.unit(1.5))
                border.color: KanteStyle.textColor
                Rectangle { width: parent.width; height: KanteStyle.unit(4); color: KanteStyle.textColor }
                Rectangle {
                    x: KanteStyle.unit(3); y: KanteStyle.unit(6)
                    width: KanteStyle.unit(3); height: KanteStyle.unit(3)
                    color: KanteStyle.accentTextColor
                }
            }
        }
    }

    QQC2.Popup {
        id: popup
        objectName: "popup"
        // Inside the window: shifted left at the right edge, above the field at the bottom.
        readonly property var place: visible ? KanteStyle.popupPlace(root, width, implicitHeight, root.popupAbove)
                                             : ({ x: 0, y: root.height + KanteStyle.unit(2), above: false })
        x: place.x
        y: place.y
        width: KanteStyle.unit(292)
        padding: KanteStyle.unit(12)
        topPadding: KanteStyle.unit(14)
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

        property int year: new Date().getFullYear()
        property int month: new Date().getMonth() + 1

        onAboutToShow: {
            var d = root.parse(input.text) || root.date || new Date()
            d = new Date(d)
            year = d.getFullYear()
            month = d.getMonth() + 1
        }

        function step(delta) {
            var m = month - 1 + delta
            year += Math.floor(m / 12)
            month = ((m % 12) + 12) % 12 + 1
        }

        KantePopupSkin { popup: popup }

        contentItem: ColumnLayout {
            spacing: KanteStyle.unit(8)

            RowLayout {
                Layout.fillWidth: true
                KanteToolButton { text: "‹"; focusPolicy: Qt.NoFocus; onClicked: popup.step(-1); Accessible.name: "previous month" }
                QQC2.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneMonthName(popup.month - 1) + " " + popup.year
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.headingFont(Math.round(KanteStyle.defaultFont.pointSize * 1.1))
                }
                KanteToolButton { text: "›"; focusPolicy: Qt.NoFocus; onClicked: popup.step(1); Accessible.name: "next month" }
            }
            KanteCalendarGrid {
                id: grid
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                year: popup.year
                month: popup.month
                dayNames: root.dayNames
                selectedDay: root.date && new Date(root.date).getFullYear() === popup.year
                             && new Date(root.date).getMonth() + 1 === popup.month ? new Date(root.date).getDate() : 0
                onDayClicked: function (day) {
                    root.pick(new Date(popup.year, popup.month - 1, day))
                    popup.close()
                }
            }
            KanteButton {
                Layout.alignment: Qt.AlignRight
                text: root.todayText
                size: KanteButton.Size.Small
                emphasis: KanteButton.Emphasis.Quiet
                focusPolicy: Qt.NoFocus
                onClicked: {
                    var t = new Date()
                    root.pick(new Date(t.getFullYear(), t.getMonth(), t.getDate()))
                    popup.close()
                }
            }
        }
    }
}
