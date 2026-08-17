import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import com.github.shrippen.kurrent 1.0
import "colors.js" as Colors

KCM.SimpleKCM {
    id: root

    property string cfg_hiddenLabels

    TaskController {
        id: configController
        showCompleted: true
    }

    function hiddenSet() {
        var raw = cfg_hiddenLabels || ""
        if (!raw.trim()) return {}
        var parts = raw.split("||")
        var s = {}
        for (var i = 0; i < parts.length; ++i) {
            var v = parts[i].trim()
            if (v !== "") s[v] = true
        }
        return s
    }

    function toggleHidden(label) {
        var current = hiddenSet()
        if (current[label]) {
            delete current[label]
        } else {
            current[label] = true
        }
        cfg_hiddenLabels = Object.keys(current).join("||")
    }

    function isHidden(label) {
        return !!hiddenSet()[label]
    }

    function labelCount(name) {
        var n = configController.labelTaskCounts[name]
        return n === undefined || n === null ? 0 : Number(n)
    }

    function addCurrentLabel() {
        var name = newLabelField.text.trim()
        if (!name) {
            return
        }
        configController.createLabel(name)
        newLabelField.text = ""
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(Math.max(parent.width - Kirigami.Units.largeSpacing * 2,
                                 Kirigami.Units.gridUnit * 12),
                        Kirigami.Units.gridUnit * 28)
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            text: i18n("Labels (Categories)")
            level: 3
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("Labels are extracted from Akonadi task categories. Hidden labels will not appear in the sidebar filter list but remain on tasks.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            QQC2.Label {
                visible: labelRepeater.count === 0
                text: i18n("No labels found. Labels are automatically discovered from task categories in Akonadi.")
                opacity: 0.6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                id: labelRepeater
                model: configController.availableLabels

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "tag"
                            color: Colors.colorForKey(modelData)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: Kirigami.Units.iconSizes.smallMedium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: i18np("%1 task", "%1 tasks", root.labelCount(modelData))
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                opacity: 0.6
                            }
                        }

                        QQC2.Switch {
                            text: i18n("Visible")
                            checked: !root.isHidden(modelData)
                            onToggled: root.toggleHidden(modelData)
                            QQC2.ToolTip.text: i18n("Show this label in the sidebar filter")
                            QQC2.ToolTip.visible: hovered
                        }

                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            display: QQC2.AbstractButton.IconOnly
                            onClicked: configController.deleteLabel(modelData)
                            QQC2.ToolTip.text: i18n("Delete label")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: newLabelField
                Layout.fillWidth: true
                placeholderText: i18n("New label")
                Keys.onReturnPressed: root.addCurrentLabel()
                Keys.onEnterPressed: root.addCurrentLabel()
            }

            QQC2.Button {
                text: i18n("Add label")
                icon.name: "list-add"
                enabled: newLabelField.text.trim().length > 0
                onClicked: root.addCurrentLabel()
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("Show All")
                icon.name: "view-visible"
                onClicked: cfg_hiddenLabels = ""
            }

            Item { Layout.fillWidth: true }

            QQC2.Button {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: configController.refresh()
            }
        }
    }
}
