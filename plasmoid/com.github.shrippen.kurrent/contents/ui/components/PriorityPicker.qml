import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "../colors.js" as Colors
import ".."
import "../Kante"

RowLayout {
    id: root

    property int priority: 0
    /** When false, the parent FormLayout supplies the left-side label. */
    property bool showLabel: false

    // Kante draws the priority flag after each option (see below): leave room for it.
    spacing: KanteStyle.themed ? Design.spaceMedium + Kirigami.Units.iconSizes.small + 2 : Design.spaceMedium

    QQC2.Label {
        visible: root.showLabel
        text: i18n("Priority")
        opacity: 0.85
        Layout.alignment: Qt.AlignVCenter
    }

    QQC2.ButtonGroup {
        id: priorityGroup
    }

    Repeater {
        model: [
            { label: i18n("None"), value: 0 },
            { label: i18n("High"), value: 1 },
            { label: i18n("Medium"), value: 5 },
            { label: i18n("Low"), value: 9 }
        ]

        delegate: QQC2.RadioButton {
            id: priorityRadio
            KanteCheckSkin { control: parent }
            // The desktop style paints the flag together with the indicator, which the Kante
            // skin hides: draw it right after the option instead (the row spacing makes room).
            Kirigami.Icon {
                visible: KanteStyle.themed && priorityRadio.modelData.value > 0
                width: Kirigami.Units.iconSizes.small
                height: width
                x: priorityRadio.width + 2
                anchors.verticalCenter: parent.verticalCenter
                source: "flag"
                color: Design.priorityColor(priorityRadio.modelData.value)
                isMask: true
            }
            required property var modelData
            text: modelData.label
            icon.name: modelData.value > 0 ? "flag" : ""
            icon.color: modelData.value > 0 ? Design.priorityColor(modelData.value) : Kirigami.Theme.textColor
            checked: Colors.normalizePriority(root.priority) === modelData.value
            QQC2.ButtonGroup.group: priorityGroup
            onClicked: root.priority = modelData.value
        }
    }

    Item { Layout.fillWidth: true }
}
