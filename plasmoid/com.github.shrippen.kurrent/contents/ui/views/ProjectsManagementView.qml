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
            source: "folder"
            width: Kirigami.Units.iconSizes.smallMedium
            height: Kirigami.Units.iconSizes.smallMedium
        }

        Kirigami.Heading {
            level: 3
            Layout.fillWidth: true
            text: i18n("Projects")
        }

        QQC2.ToolButton {
            icon.name: "edit-clear"
            visible: controller.selectedCollectionId >= 0
            onClicked: controller.selectedCollectionId = -1
            QQC2.ToolTip.text: i18n("Clear project filter")
            QQC2.ToolTip.visible: hovered
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.75
        text: i18n("Select a project to filter tasks.")
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 1
        model: controller.collectionModel

        delegate: PlasmaComponents3.ItemDelegate {
            id: delegate
            width: parent.width
            hoverEnabled: true
            highlighted: controller.selectedCollectionId === model.collectionId

            onClicked: {
                // Toggle filter and return to task view.
                controller.selectedCollectionId = controller.selectedCollectionId === model.collectionId ? -1 : model.collectionId
                controller.managementView = ""
            }

            background: null

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "folder"
                    color: Colors.colorForKey(String(model.collectionId))
                    width: Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                    anchors.verticalCenter: parent.verticalCenter
                }

                KirigamiDelegates.TitleSubtitle {
                    title: model.name
                    selected: highlighted
                }
            }
        }
    }
}

