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
    /** Dots per day, by ISO date: {"2026-10-29": {event: true, task: true, late: false}}.
     *  With markers the grid always uses the plain cells (the Kante grid has no dots). */
    property var markers: null
    /** Days from rangeStart to rangeEnd get a tint (the Agenda's shown days); null for none. */
    property var rangeStart: null
    property var rangeEnd: null

    property date _monthStart: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    readonly property date shownMonth: _monthStart
    readonly property bool _kanteGrid: KanteStyle.active && !markers

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
                    anchors.bottomMargin: 1
                    spacing: 2
                    visible: !!modelData.marks
                    Repeater {
                        model: {
                            var m = modelData.marks
                            if (!m) {
                                return []
                            }
                            var out = []
                            if (m.event) {
                                out.push(KanteStyle.mutedTextColor)
                            }
                            if (m.task) {
                                out.push(m.late ? KanteStyle.negativeTextColor : KanteStyle.accentColor)
                            }
                            return out
                        }
                        delegate: Rectangle {
                            required property color modelData
                            width: 4
                            height: 4
                            radius: 2
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
