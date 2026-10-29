import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."
import "../Kante"
import "../datetime.js" as DateTime

// An appointment on the Agenda's week and month boards: no box, a stripe in the calendar's
// colour, a fixed time column (start, the end below it) and the title in full text colour.
// Tasks stay cards with a check box, so the shape tells "to do" from "fixed". `compact` is the
// one-line form for month cells: stripe, start, title.
Item {
    id: row

    required property var event
    property bool compact: false
    /** Title lines before it elides; 0 wraps without limit. */
    property int maximumLineCount: 2

    readonly property color calendarColor: Design.colorForKey(String(event.calendarId))
    readonly property font timeFont: KanteStyle.active ? KanteStyle.monoFont(Kirigami.Theme.smallFont.pointSize)
                                                       : Kirigami.Theme.smallFont

    implicitHeight: compact ? line.implicitHeight : Math.max(times.implicitHeight, titleLabel.implicitHeight) + Design.spaceTiny * 2

    function hm(minute) {
        return DateTime.pad2(Math.floor(minute / 60)) + ":" + DateTime.pad2(minute % 60)
    }

    HoverHandler { id: hover }
    QQC2.ToolTip.text: event.summary + (event.calendarName ? " · " + event.calendarName : "")
    QQC2.ToolTip.visible: hover.hovered
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    // Same width for every row, so the titles line up.
    TextMetrics {
        id: clock
        font: row.timeFont
        text: "00:00"
    }

    Rectangle {
        width: 3
        height: row.compact ? Math.round(line.implicitHeight * 0.75) : parent.height
        anchors.verticalCenter: parent.verticalCenter
        radius: 1
        color: row.calendarColor
    }

    // Board form: the time column, then the title.
    RowLayout {
        visible: !row.compact
        anchors.fill: parent
        anchors.topMargin: Design.spaceTiny
        anchors.bottomMargin: Design.spaceTiny
        anchors.leftMargin: 3 + Design.spaceSmall
        spacing: Design.spaceSmall

        ColumnLayout {
            id: times
            visible: !row.event.allDay
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Math.ceil(clock.advanceWidth)
            spacing: 0
            QQC2.Label {
                text: row.event.allDay ? "" : row.hm(row.event.start)
                font: row.timeFont
                color: KanteStyle.textColor
            }
            QQC2.Label {
                text: row.event.allDay ? "" : row.hm(row.event.end)
                font: row.timeFont
                color: KanteStyle.mutedTextColor
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0
            QQC2.Label {
                visible: row.event.allDay
                text: i18n("All day")
                font: row.timeFont
                color: KanteStyle.mutedTextColor
            }
            QQC2.Label {
                id: titleLabel
                Layout.fillWidth: true
                text: row.event.summary
                wrapMode: Text.Wrap
                maximumLineCount: row.maximumLineCount > 0 ? row.maximumLineCount : 1000
                elide: row.maximumLineCount > 0 ? Text.ElideRight : Text.ElideNone
                color: KanteStyle.textColor
            }
        }
    }

    // Month cell form: one line.
    RowLayout {
        id: line
        visible: row.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 3 + Design.spaceTiny
        spacing: Design.spaceTiny
        QQC2.Label {
            visible: !row.event.allDay
            text: row.event.allDay ? "" : row.hm(row.event.start)
            font: row.timeFont
            color: KanteStyle.textColor
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: row.event.summary || i18n("(Untitled)")
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: KanteStyle.textColor
        }
    }
}
