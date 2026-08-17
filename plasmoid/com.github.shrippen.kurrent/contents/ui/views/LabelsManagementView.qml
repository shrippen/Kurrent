import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kirigami.delegates as KirigamiDelegates
import org.kde.plasma.components as PlasmaComponents3
import com.github.shrippen.kurrent 1.0
import "../colors.js" as Colors

ColumnLayout {
    id: root

    required property TaskController controller

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    Layout.maximumHeight: Infinity
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Icon {
            source: "tag"
            width: Kirigami.Units.iconSizes.smallMedium
            height: Kirigami.Units.iconSizes.smallMedium
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            text: i18n("Labels")
        }

        QQC2.ToolButton {
            icon.name: "edit-clear"
            visible: controller.selectedLabel !== ""
            onClicked: controller.selectedLabel = ""
            QQC2.ToolTip.text: i18n("Clear label filter")
            QQC2.ToolTip.visible: hovered
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.75
        text: i18n("Select a label to filter tasks.")
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 1
        model: controller.availableLabels

        delegate: PlasmaComponents3.ItemDelegate {
            id: delegate
            width: parent.width
            hoverEnabled: true
            highlighted: controller.selectedLabel === modelData

            onClicked: {
                controller.selectedLabel = controller.selectedLabel === modelData ? "" : modelData
                controller.managementView = ""
            }

            background: null

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "tag"
                    color: Colors.colorForKey(String(modelData))
                    width: Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                    anchors.verticalCenter: parent.verticalCenter
                }

                KirigamiDelegates.TitleSubtitle {
                    title: modelData
                    selected: highlighted
                }
            }
        }
    }
}

