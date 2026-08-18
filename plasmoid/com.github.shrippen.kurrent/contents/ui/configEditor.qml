import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property string cfg_clickAction
    property int cfg_defaultReminderMinutes

    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(clickCombo, cfg_clickAction || "inline")
        selectCombo(reminderCombo, String(cfg_defaultReminderMinutes))
    }

    ConfigFormShell {
        anchors.fill: parent

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                id: clickCombo
                Kirigami.FormData.label: i18n("Click a task")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 28
                textRole: "text"
                model: [
                    { text: i18n("Open the inline editor"), value: "inline" },
                    { text: i18n("Open the full editor"), value: "full" },
                    { text: i18n("Select only (double-click opens the full editor)"), value: "select" }
                ]
                onActivated: cfg_clickAction = model[currentIndex].value
                Component.onCompleted: selectCombo(clickCombo, plasmoid.configuration.clickAction || "inline")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: i18n("The full editor stays an overlay inside the widget. Day section (LIST) is in the full editor.")
            }

            QQC2.ComboBox {
                id: reminderCombo
                Kirigami.FormData.label: i18n("Default reminder")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Off"), value: "-1" },
                    { text: i18n("At due time"), value: "0" },
                    { text: i18n("15 minutes before"), value: "15" },
                    { text: i18n("1 hour before"), value: "60" },
                    { text: i18n("1 day before"), value: "1440" }
                ]
                onActivated: cfg_defaultReminderMinutes = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(reminderCombo, String(plasmoid.configuration.defaultReminderMinutes !== undefined ? plasmoid.configuration.defaultReminderMinutes : -1))
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    clickAction: "inline",
                    defaultReminderMinutes: -1
                })
            }
        }
    }
}
