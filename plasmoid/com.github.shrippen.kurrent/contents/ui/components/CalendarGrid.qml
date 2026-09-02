import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

ColumnLayout {
    id: root

    property date selectedDate: new Date()
    signal dateSelected(date date)

    property date _monthStart: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)

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

        QQC2.ToolButton {
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
            text: Qt.formatDate(root._monthStart, "MMMM yyyy")
            font.bold: true
        }

        QQC2.ToolButton {
            icon.name: "go-next"
            onClicked: {
                var d = new Date(root._monthStart)
                d.setMonth(d.getMonth() + 1)
                root._monthStart = d
            }
        }
    }

    // Weekday headers
    Grid {
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
                        items.push({day: d, selected: isSel, today: isToday, _date: cellDate})
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
                         ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                   Kirigami.Theme.highlightColor.g,
                                   Kirigami.Theme.highlightColor.b, 0.15)
                         : "transparent"
                border.color: modelData.today ? Kirigami.Theme.highlightColor : "transparent"

                QQC2.Label {
                    anchors.centerIn: parent
                    text: modelData.day > 0 ? modelData.day : ""
                    color: modelData.selected ? Kirigami.Theme.highlightedTextColor
                                              : Kirigami.Theme.textColor
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
