import QtQuick
import QtQuick.Layouts
import "."

/**
 * Agenda: entries grouped by day, one list. `days` is a list of
 * {label, today, entries: [{time, title, kind}]} in order; kind as in KanteWeekView.
 * Day head in mono caps with a rule, today's head in yellow; each entry has a 4 px
 * bar in its state colour. `entryClicked(dayIndex, entryIndex)` on a tap.
 */
ColumnLayout {
    id: agenda

    property var days: []
    property string emptyText: "–"
    signal entryClicked(int dayIndex, int entryIndex)

    spacing: KanteStyle.unit(14)

    Repeater {
        model: agenda.days.length
        delegate: ColumnLayout {
            id: day
            required property int index
            readonly property var d: agenda.days[index]
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: KanteStyle.unit(10)
                Text {
                    text: day.d.label
                    color: day.d.today ? KanteStyle.accentColor : KanteStyle.mutedTextColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, day.d.today)
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: day.d.today ? KanteStyle.accentColor : KanteStyle.ruleColor
                }
            }
            Text {
                visible: day.d.entries.length === 0
                Layout.topMargin: KanteStyle.unit(6)
                text: agenda.emptyText
                color: KanteStyle.disabledTextColor
                font: KanteStyle.labelFont()
            }
            Repeater {
                model: day.d.entries.length
                delegate: Item {
                    id: entry
                    required property int index
                    readonly property var e: day.d.entries[index]
                    Layout.fillWidth: true
                    Layout.preferredHeight: KanteStyle.unit(32)

                    Rectangle {
                        width: 4
                        height: parent.height - KanteStyle.unit(8)
                        y: KanteStyle.unit(4)
                        color: {
                            switch (entry.e.kind) {
                            case "warn": return KanteStyle.warningColor
                            case "info": return KanteStyle.focusColor
                            case "ok": return KanteStyle.positiveTextColor
                            default: return KanteStyle.accentColor
                            }
                        }
                    }
                    Text {
                        x: KanteStyle.unit(14)
                        width: KanteStyle.unit(70)
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.e.time
                        color: KanteStyle.mutedTextColor
                        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
                    }
                    Text {
                        x: KanteStyle.unit(90)
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: entry.e.title
                        color: KanteStyle.textColor
                        font: KanteStyle.labelFont()
                    }
                    TapHandler { onTapped: agenda.entryClicked(day.index, entry.index) }
                    Accessible.role: Accessible.ListItem
                    Accessible.name: entry.e.time + " " + entry.e.title
                }
            }
        }
    }
}
