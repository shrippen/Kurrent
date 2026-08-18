import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property string cfg_panelBadge
    property int cfg_flyoutWidthUnits
    property int cfg_flyoutHeightUnits

    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(badgeCombo, cfg_panelBadge || "open")
        widthBox.value = cfg_flyoutWidthUnits
        heightBox.value = cfg_flyoutHeightUnits
    }

    ConfigFormShell {
        anchors.fill: parent

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                id: badgeCombo
                Kirigami.FormData.label: i18n("Panel badge")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Off"), value: "off" },
                    { text: i18n("Open root tasks"), value: "open" },
                    { text: i18n("Today"), value: "today" },
                    { text: i18n("Overdue"), value: "overdue" }
                ]
                onActivated: cfg_panelBadge = model[currentIndex].value
                Component.onCompleted: selectCombo(badgeCombo, plasmoid.configuration.panelBadge || "open")
            }

            QQC2.SpinBox {
                id: widthBox
                Kirigami.FormData.label: i18n("Flyout width")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                from: 20
                to: 64
                value: plasmoid.configuration.flyoutWidthUnits || 32
                textFromValue: function(value) { return i18n("%1 grid units", value) }
                valueFromText: function(text) { return widthBox.value }
                onValueChanged: root.cfg_flyoutWidthUnits = value
                Component.onCompleted: root.cfg_flyoutWidthUnits = value
            }

            QQC2.SpinBox {
                id: heightBox
                Kirigami.FormData.label: i18n("Flyout height")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                from: 16
                to: 48
                value: plasmoid.configuration.flyoutHeightUnits || 24
                textFromValue: function(value) { return i18n("%1 grid units", value) }
                valueFromText: function(text) { return heightBox.value }
                onValueChanged: root.cfg_flyoutHeightUnits = value
                Component.onCompleted: root.cfg_flyoutHeightUnits = value
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    panelBadge: "open",
                    flyoutWidthUnits: 32,
                    flyoutHeightUnits: 24
                })
            }
        }
    }
}
