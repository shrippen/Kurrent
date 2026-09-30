import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Time input: type the time or pick hour and minute.
 *   typed   "9:30", "09.30", "930", "9" (full hour), "9h30", "9:30 pm", "9p"; Enter or
 *           leaving the field takes it, an unreadable time marks the field `invalid`
 *   popup   24 hour cells (6 × 4), then the minutes in `minuteStep`; picking the hour keeps
 *           the popup open, picking the minute closes it
 *   12 h    `twelveHour` (default: the locale's short time format has AM/PM) shows
 *           "9:30 PM" and 12 hour cells with an AM / PM switch; typed 24 h times still work
 * `open()` / `close()` drive the popup; it stays inside the window (`popupAbove` forces a side).
 * `hour` and `minute` are -1 when empty. `timeEdited(hour, minute)` fires on every change by
 * the user, never when they are set from outside. Selected cells are cyan, as in the month grid.
 *   System  a plain text field and tool button of the platform; the cells draw in the roles.
 *   Kante   sunken Kante field, square button, the popup as a Kante card.
 */
FocusScope {
    id: root

    property int hour: -1
    property int minute: -1
    property int minuteStep: 5
    /** 12-hour clock with AM / PM; default from Qt.locale(). */
    property bool twelveHour: /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat))
    property string amText: Qt.locale().amText !== "" ? Qt.locale().amText : "AM"
    property string pmText: Qt.locale().pmText !== "" ? Qt.locale().pmText : "PM"
    property string placeholderText: twelveHour ? "HH:MM " + amText : "HH:MM"
    property string hourText: qsTr("Hour")
    property string minuteText: qsTr("Minute")
    readonly property bool hasTime: hour >= 0 && minute >= 0
    readonly property bool invalid: input.invalid
    readonly property alias popupOpen: popup.visible
    /** Side of the popup: undefined = below, above when there is no room (true / false force it). */
    property var popupAbove: undefined
    signal timeEdited(int hour, int minute)

    implicitWidth: KanteStyle.unit(twelveHour ? 150 : 120)
    implicitHeight: input.implicitHeight

    /** Opens the hour popup (e.g. from a shortcut); `close()` closes it. */
    function open() {
        popup.open()
    }
    function close() {
        popup.close()
    }

    /** Half of the day a typed suffix names. */
    enum Half {
        None,
        Am,
        Pm
    }
    /** "9:30 pm" -> {text: "9:30", half: Pm}: the AM / PM suffix, in any clock mode. */
    function splitHalf(t) {
        var forms = [
            [KanteTimeField.Half.Am, [amText.toLowerCase(), "a.m.", "am", "a"]],
            [KanteTimeField.Half.Pm, [pmText.toLowerCase(), "p.m.", "pm", "p"]]
        ]
        for (var i = 0; i < forms.length; i++) {
            var words = forms[i][1]
            for (var k = 0; k < words.length; k++) {
                if (words[k] !== "" && t.length > words[k].length && t.endsWith(words[k])) {
                    return { text: t.slice(0, -words[k].length).trim(), half: forms[i][0] }
                }
            }
        }
        return { text: t, half: KanteTimeField.Half.None }
    }

    /** Text -> {hour, minute}, or null if empty, or undefined if unreadable. */
    function parse(text) {
        var t = String(text).trim().toLowerCase()
        if (t === "") {
            return null
        }
        var split = splitHalf(t)
        var m = split.text.match(/^(\d{1,2})(?:[:.h ]?(\d{2}))?$/)
        if (!m) {
            return undefined
        }
        var h = +m[1]
        var min = m[2] === undefined ? 0 : +m[2]
        if (h > 23 || min > 59) {
            return undefined
        }
        if (split.half === KanteTimeField.Half.None) {
            return { hour: h, minute: min }
        }
        // 12 am = 0:00, 12 pm = 12:00.
        if (h < 1 || h > 12) {
            return undefined
        }
        return { hour: h % 12 + (split.half === KanteTimeField.Half.Pm ? 12 : 0), minute: min }
    }

    function textOf(h, m) {
        if (h < 0 || m < 0) {
            return ""
        }
        var mm = String(m).padStart(2, "0")
        if (twelveHour) {
            return (h % 12 === 0 ? 12 : h % 12) + ":" + mm + " " + (h < 12 ? amText : pmText)
        }
        return String(h).padStart(2, "0") + ":" + mm
    }

    function pick(h, m) {
        var changed = h !== hour || m !== minute
        hour = h
        minute = m
        input.invalid = false
        input.text = textOf(h, m)
        if (changed) {
            timeEdited(h, m)
        }
    }

    function commit() {
        var t = parse(input.text)
        if (t === undefined) {
            input.invalid = true
            return
        }
        if (t === null) {
            pick(-1, -1)
            return
        }
        pick(t.hour, t.minute)
    }

    function refresh() {
        if (!input.activeFocus) {
            input.text = textOf(hour, minute)
        }
    }
    onHourChanged: refresh()
    onMinuteChanged: refresh()
    onTwelveHourChanged: refresh()

    // The button sits inside the field's right end; the text keeps clear of it.
    Item {
        anchors.fill: parent

        KanteTextField {
            id: input
            anchors.fill: parent
            rightPadding: button.width + KanteStyle.unit(6)
            focus: true
            text: root.textOf(root.hour, root.minute)
            placeholderText: root.placeholderText
            inputMethodHints: Qt.ImhTime | Qt.ImhNoPredictiveText
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
            focusPolicy: Qt.NoFocus
            Accessible.name: root.placeholderText
            onClicked: popup.visible ? popup.close() : popup.open()

            // Clock glyph (an icon, so round): ring and two hands.
            Shape {
                id: glyph
                readonly property real r: KanteStyle.unit(6.5)
                anchors.centerIn: parent
                width: r * 2
                height: r * 2
                antialiasing: true
                ShapePath {
                    strokeColor: KanteStyle.textColor
                    strokeWidth: Math.max(1, KanteStyle.unit(1.5))
                    fillColor: "transparent"
                    PathAngleArc { centerX: glyph.r; centerY: glyph.r; radiusX: glyph.r - 1; radiusY: glyph.r - 1; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: KanteStyle.accentTextColor
                    strokeWidth: Math.max(1, KanteStyle.unit(1.5))
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: glyph.r; startY: glyph.r * 0.45
                    PathLine { x: glyph.r; y: glyph.r }
                    PathLine { x: glyph.r * 1.45; y: glyph.r }
                }
            }
        }
    }

    component Cell: Rectangle {
        id: cell
        property string label: ""
        property bool selected: false
        signal picked()
        implicitWidth: KanteStyle.unit(38)
        implicitHeight: KanteStyle.unit(30)
        color: selected ? KanteStyle.selectionColor : (cellHover.hovered ? KanteStyle.tint1Color : KanteStyle.cardColor)
        border.width: selected ? 2 : 0
        border.color: KanteStyle.focusColor
        Text {
            anchors.centerIn: parent
            text: cell.label
            color: cell.selected ? KanteStyle.strongTextColor : KanteStyle.textColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 0.95, cell.selected)
        }
        HoverHandler { id: cellHover }
        TapHandler { onTapped: cell.picked() }
        Accessible.role: Accessible.Button
        Accessible.name: cell.label
    }

    QQC2.Popup {
        id: popup
        objectName: "popup"
        // Inside the window: shifted left at the right edge, above the field at the bottom.
        readonly property var place: visible ? KanteStyle.popupPlace(root, width, implicitHeight, root.popupAbove)
                                             : ({ x: 0, y: root.height + KanteStyle.unit(2), above: false })
        x: place.x
        y: place.y
        padding: KanteStyle.unit(12)
        topPadding: KanteStyle.unit(14)
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

        /** The hour being picked (the typed one, or the current one). */
        property int draftHour: -1
        /** 12 h: the half shown by the hour cells. */
        property bool draftPm: false

        onAboutToShow: {
            var t = root.parse(input.text)
            draftHour = t ? t.hour : root.hour
            draftPm = draftHour >= 12
        }

        function setPm(pm) {
            draftPm = pm
            if (draftHour >= 0) {
                draftHour = draftHour % 12 + (pm ? 12 : 0)
            }
        }

        KantePopupSkin { popup: popup }

        contentItem: ColumnLayout {
            spacing: KanteStyle.unit(6)

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.hourText
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.labelFont()
                }
                // 12 h: AM / PM switch the hour cells.
                Cell {
                    visible: root.twelveHour
                    implicitWidth: KanteStyle.unit(48)
                    label: root.amText
                    selected: !popup.draftPm
                    onPicked: popup.setPm(false)
                }
                Cell {
                    visible: root.twelveHour
                    implicitWidth: KanteStyle.unit(48)
                    label: root.pmText
                    selected: popup.draftPm
                    onPicked: popup.setPm(true)
                }
            }
            GridLayout {
                columns: 6
                columnSpacing: 2
                rowSpacing: 2
                Repeater {
                    model: root.twelveHour ? 12 : 24
                    delegate: Cell {
                        required property int index
                        // 12 h: the cells read 12, 1 … 11 of the chosen half.
                        readonly property int hour: root.twelveHour ? index + (popup.draftPm ? 12 : 0) : index
                        label: root.twelveHour ? String(index === 0 ? 12 : index) : String(index).padStart(2, "0")
                        selected: popup.draftHour === hour
                        onPicked: popup.draftHour = hour
                    }
                }
            }
            QQC2.Label {
                Layout.topMargin: KanteStyle.unit(4)
                text: root.minuteText
                color: KanteStyle.mutedTextColor
                font: KanteStyle.labelFont()
            }
            GridLayout {
                columns: 6
                columnSpacing: 2
                rowSpacing: 2
                Repeater {
                    model: Math.ceil(60 / Math.max(1, root.minuteStep))
                    delegate: Cell {
                        required property int index
                        readonly property int value: index * Math.max(1, root.minuteStep)
                        label: ":" + String(value).padStart(2, "0")
                        selected: root.hasTime && popup.draftHour === root.hour && root.minute === value
                        onPicked: {
                            root.pick(popup.draftHour >= 0 ? popup.draftHour : (popup.draftPm ? 12 : 0), value)
                            popup.close()
                        }
                    }
                }
            }
        }
    }
}
