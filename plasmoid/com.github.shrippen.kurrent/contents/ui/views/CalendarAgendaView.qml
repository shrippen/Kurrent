import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import ".."
import "../datetime.js" as DateTime

ColumnLayout {
    id: root

    required property TaskController controller
    property Item dragHost: null

    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    spacing: Design.spaceMedium

    property var selectedDay: new Date()

    readonly property var dayEvents: controller
            ? controller.agendaEventsForDay(selectedDay)
            : []

    Kirigami.Heading {
        level: 4
        text: i18n("Day agenda")
    }

    Flow {
        Layout.fillWidth: true
        spacing: Design.spaceSmall
        visible: dayEvents.length > 0

        Repeater {
            model: root.dayEvents
            delegate: Rectangle {
                required property var modelData
                radius: Design.inputRadius
                color: Kirigami.Theme.alternateBackgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                implicitWidth: chipRow.implicitWidth + Design.padInner * 2
                implicitHeight: chipRow.implicitHeight + Design.padInner

                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Design.spaceTiny
                    Kirigami.Icon {
                        source: "view-calendar"
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                    QQC2.Label {
                        text: modelData.start ? String(modelData.start).slice(11, 16) : ""
                    }
                }
            }
        }
    }

    QQC2.Label {
        visible: dayEvents.length === 0
        text: i18n("No busy events for this day.")
        opacity: 0.7
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        level: 4
        text: i18n("Tasks due this day")
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Design.spaceTiny
        model: controller.taskModel
        delegate: QQC2.Label {
            required property int index
            required property var model
            readonly property var due: model.dueDate
            visible: DateTime.isValidDate(due)
                    && DateTime.isoDateKey(due) === DateTime.isoDateKey(root.selectedDay)
            width: parent.width
            text: "• " + model.summary
            elide: Text.ElideRight
        }
    }
}
