import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property alias cfg_notificationsEnabled: notifyCheck.checked
    property alias cfg_quietHoursEnabled: quietCheck.checked
    property int cfg_quietHoursStart
    property int cfg_quietHoursEnd

    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(quietStartCombo, String(cfg_quietHoursStart))
        selectCombo(quietEndCombo, String(cfg_quietHoursEnd))
    }

    ConfigFormShell {
        anchors.fill: parent

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                id: notifyCheck
                Kirigami.FormData.label: i18n("Desktop notifications")
                text: i18n("Notify when a task reminder is due")
                Component.onCompleted: checked = plasmoid.configuration.notificationsEnabled !== false
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: i18n("Snooze from the notification (15 minutes, 1 hour, tomorrow) rewrites the VALARM. Due date is unchanged; use Reschedule for that.")
            }

            QQC2.CheckBox {
                id: quietCheck
                Kirigami.FormData.label: i18n("Quiet hours")
                text: i18n("Suppress reminder notifications in this window")
                Component.onCompleted: checked = plasmoid.configuration.quietHoursEnabled === true
            }

            QQC2.ComboBox {
                id: quietStartCombo
                Kirigami.FormData.label: i18n("Starts")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                enabled: quietCheck.checked
                textRole: "text"
                model: root.hourModel
                onActivated: root.cfg_quietHoursStart = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(quietStartCombo, String(plasmoid.configuration.quietHoursStart !== undefined ? plasmoid.configuration.quietHoursStart : 22))
            }

            QQC2.ComboBox {
                id: quietEndCombo
                Kirigami.FormData.label: i18n("Ends")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                enabled: quietCheck.checked
                textRole: "text"
                model: root.hourModel
                onActivated: root.cfg_quietHoursEnd = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(quietEndCombo, String(plasmoid.configuration.quietHoursEnd !== undefined ? plasmoid.configuration.quietHoursEnd : 7))
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    notificationsEnabled: true,
                    quietHoursEnabled: false,
                    quietHoursStart: 22,
                    quietHoursEnd: 7
                })
            }
        }
    }

    readonly property var hourModel: (function() {
        var rows = []
        for (var h = 0; h < 24; ++h) {
            rows.push({ text: i18n("%1:00", h), value: String(h) })
        }
        return rows
    })()
}
