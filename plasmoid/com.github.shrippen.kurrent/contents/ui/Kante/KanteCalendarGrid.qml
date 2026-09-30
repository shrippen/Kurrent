import QtQuick
import "."

/**
 * A month as a grid, Monday first. Today = yellow frame, holiday = orange bar,
 * absence = cyan bar, both = split, weekend = sunken, selected = cyan tint and frame.
 * `holidays` and `absences` are lists of day numbers; `dayClicked(day)` on a tap.
 */
Item {
    id: cal

    property int year: new Date().getFullYear()
    property int month: new Date().getMonth() + 1
    /** Day number of today in this month, or 0. */
    property int today: (new Date().getFullYear() === year && new Date().getMonth() + 1 === month) ? new Date().getDate() : 0
    property var holidays: []
    property var absences: []
    property int selectedDay: 0
    property var dayNames: ["MO", "DI", "MI", "DO", "FR", "SA", "SO"]
    signal dayClicked(int day)

    readonly property int offset: (new Date(year, month - 1, 1).getDay() + 6) % 7
    readonly property int days: new Date(year, month, 0).getDate()

    implicitWidth: KanteStyle.unit(300)
    implicitHeight: header.height + grid.implicitHeight

    Row {
        id: header
        width: parent.width
        Repeater {
            model: cal.dayNames
            delegate: Text {
                required property string modelData
                width: cal.width / 7
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: KanteStyle.unit(4)
                text: modelData
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
            }
        }
    }

    Grid {
        id: grid
        y: header.height
        columns: 7
        spacing: 2
        Repeater {
            model: cal.offset + cal.days
            delegate: Item {
                id: cell
                required property int index
                readonly property int day: index - cal.offset + 1
                readonly property bool real: day >= 1
                readonly property bool weekend: (index % 7) >= 5
                readonly property bool holiday: real && cal.holidays.indexOf(day) >= 0
                readonly property bool absent: real && cal.absences.indexOf(day) >= 0
                width: (cal.width - 12) / 7
                height: width * 0.85

                Rectangle {
                    anchors.fill: parent
                    visible: cell.real
                    color: cal.selectedDay === cell.day ? KanteStyle.selectionColor
                        : (cell.weekend ? KanteStyle.sunkenColor : KanteStyle.cardColor)
                }
                Rectangle {
                    anchors.fill: parent
                    visible: cell.real && (cal.today === cell.day || cal.selectedDay === cell.day)
                    color: "transparent"
                    border.width: 2
                    border.color: cal.today === cell.day ? KanteStyle.accentColor : KanteStyle.focusColor
                }
                Text {
                    visible: cell.real
                    x: KanteStyle.unit(5)
                    y: KanteStyle.unit(3)
                    text: cell.day
                    color: cal.today === cell.day ? KanteStyle.strongTextColor : (cell.weekend ? KanteStyle.disabledTextColor : KanteStyle.mutedTextColor)
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
                }
                Row {
                    visible: cell.holiday || cell.absent
                    x: KanteStyle.unit(5)
                    width: parent.width - KanteStyle.unit(10)
                    y: parent.height - KanteStyle.unit(9)
                    height: KanteStyle.unit(4)
                    Rectangle {
                        visible: cell.holiday
                        width: cell.holiday && cell.absent ? parent.width / 2 : parent.width
                        height: parent.height
                        color: KanteStyle.warningColor
                    }
                    Rectangle {
                        visible: cell.absent
                        width: cell.holiday && cell.absent ? parent.width / 2 : parent.width
                        height: parent.height
                        color: KanteStyle.focusColor
                    }
                }
                TapHandler { enabled: cell.real; onTapped: cal.dayClicked(cell.day) }
            }
        }
    }
}
