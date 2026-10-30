import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."
import "../Kante"
import "../datetime.js" as DateTime

ColumnLayout {
    id: root

    property date selectedDate: new Date()
    signal dateSelected(date date)
    /** Dots per day, by ISO date: {"2026-10-29": {event: true, task: true, late: false}}. */
    property var markers: null
    /** Days from rangeStart to rangeEnd get a tint (the Agenda's shown days); null for none. */
    property var rangeStart: null
    property var rangeEnd: null

    property date _monthStart: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    readonly property date shownMonth: _monthStart
    readonly property bool _kanteGrid: KanteStyle.active

    // The shown month's markers and range for the Kante grid, by day number.
    function _dotTones(marks) {
        var out = []
        if (marks && marks.event) {
            out.push("muted")
        }
        if (marks && marks.task) {
            out.push(marks.late ? "negative" : "accent")
        }
        return out
    }
    readonly property var _kanteDots: {
        var out = {}
        if (!markers) {
            return out
        }
        var year = _monthStart.getFullYear()
        var month = _monthStart.getMonth()
        for (var d = 1; d <= daysInMonth(year, month); ++d) {
            var tones = _dotTones(markers[DateTime.isoDateKey(new Date(year, month, d))])
            if (tones.length > 0) {
                out[d] = tones
            }
        }
        return out
    }
    function _rangeDay(last) {
        if (!rangeStart || !rangeEnd) {
            return 0
        }
        var first = new Date(_monthStart.getFullYear(), _monthStart.getMonth(), 1)
        var end = new Date(_monthStart.getFullYear(), _monthStart.getMonth() + 1, 0)
        var from = DateTime.isoDateKey(rangeStart), to = DateTime.isoDateKey(rangeEnd)
        if (to < DateTime.isoDateKey(first) || from > DateTime.isoDateKey(end)) {
            return 0
        }
        if (last) {
            return to > DateTime.isoDateKey(end) ? end.getDate() : rangeEnd.getDate()
        }
        return from < DateTime.isoDateKey(first) ? 1 : rangeStart.getDate()
    }

    /** Re-anchor the visible month to the selected date (call when opening the picker). */
    function resetToSelected() {
        root._monthStart = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function firstDayOfWeek(year, month) {
        return new Date(year, month, 1).getDay()  // 0=Sun
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceSmall

        KanteToolButton {
            icon.name: "go-previous"
            onClicked: {
                var d = new Date(root._monthStart)
                d.setMonth(d.getMonth() - 1)
                root._monthStart = d
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.locale().toString(root._monthStart, "MMMM yyyy")
            font.bold: true
        }

        KanteToolButton {
            icon.name: "go-next"
            onClicked: {
                var d = new Date(root._monthStart)
                d.setMonth(d.getMonth() + 1)
                root._monthStart = d
            }
        }
    }

    // Kante: month grid from the design system, same navigation above.
    KanteCalendarGrid {
        visible: root._kanteGrid
        Layout.fillWidth: true
        year: root._monthStart.getFullYear()
        month: root._monthStart.getMonth() + 1
        selectedDay: root.selectedDate.getFullYear() === year && root.selectedDate.getMonth() + 1 === month
                     ? root.selectedDate.getDate() : 0
        dayNames: [i18n("Mo"), i18n("Tu"), i18n("We"), i18n("Th"), i18n("Fr"), i18n("Sa"), i18n("Su")]
                  .map(function(n) { return n.toUpperCase() })
        dots: root._kanteDots
        rangeFrom: root._rangeDay(false)
        rangeTo: root._rangeDay(true)
        onDayClicked: function(day) { root.dateSelected(new Date(year, month - 1, day)) }
    }

    // Weekday headers
    Grid {
        visible: !root._kanteGrid
        columns: 7
        Layout.alignment: Qt.AlignHCenter
        spacing: 1

        Repeater {
            model: [i18n("Mo"), i18n("Tu"), i18n("We"), i18n("Th"), i18n("Fr"), i18n("Sa"), i18n("Su")]
            delegate: QQC2.Label {
                width: Design.heatmapCellSize
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                opacity: 0.6
            }
        }
    }

    // Day grid
    Grid {
        visible: !root._kanteGrid
        columns: 7
        Layout.alignment: Qt.AlignHCenter
        spacing: 1

        Repeater {
            model: {
                var year = root._monthStart.getFullYear()
                var month = root._monthStart.getMonth()
                var days = root.daysInMonth(year, month)
                var startDow = root.firstDayOfWeek(year, month)
                // Shift so Monday=0
                var start = (startDow + 6) % 7
                var total = start + days
                var items = []
                for (var i = 0; i < total; ++i) {
                    if (i < start) {
                        items.push({day: 0, selected: false, today: false})
                    } else {
                        var d = i - start + 1
                        var cellDate = new Date(year, month, d)
                        var isToday = cellDate.toDateString() === new Date().toDateString()
                        var isSel = cellDate.toDateString() === root.selectedDate.toDateString()
                        var key = DateTime.isoDateKey(cellDate)
                        var inRange = !!(root.rangeStart && root.rangeEnd)
                                && key >= DateTime.isoDateKey(root.rangeStart) && key <= DateTime.isoDateKey(root.rangeEnd)
                        items.push({day: d, selected: isSel, today: isToday, _date: cellDate, inRange: inRange,
                                    marks: root.markers ? (root.markers[key] || null) : null})
                    }
                }
                return items
            }

            delegate: Rectangle {
                width: Design.heatmapCellSize
                height: Design.heatmapCellSize
                radius: Design.inputRadius
                visible: modelData.day > 0
                color: modelData.selected
                       ? Kirigami.Theme.highlightColor
                       : modelData.today
                         ? (KanteStyle.themed ? KanteStyle.selectionColor
                                              : Qt.rgba(Kirigami.Theme.highlightColor.r,
                                                        Kirigami.Theme.highlightColor.g,
                                                        Kirigami.Theme.highlightColor.b, 0.15))
                         : modelData.inRange ? KanteStyle.tint1Color : "transparent"
                border.color: modelData.today ? Kirigami.Theme.highlightColor : "transparent"

                QQC2.Label {
                    anchors.centerIn: parent
                    text: modelData.day > 0 ? modelData.day : ""
                    color: modelData.selected ? Kirigami.Theme.highlightedTextColor
                                              : Kirigami.Theme.textColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: KanteStyle.borderWidth
                    spacing: Design.spaceTiny
                    visible: !!modelData.marks
                    Repeater {
                        model: {
                            var roles = { muted: KanteStyle.mutedTextColor, accent: KanteStyle.accentColor,
                                          negative: KanteStyle.negativeTextColor }
                            return root._dotTones(modelData.marks).map(function(t) { return roles[t] })
                        }
                        delegate: Rectangle {
                            required property color modelData
                            width: KanteStyle.markerSize
                            height: KanteStyle.markerSize
                            radius: KanteStyle.markerRadius
                            color: modelData
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData._date) {
                            root.dateSelected(modelData._date)
                        }
                    }
                }
            }
        }
    }
}
