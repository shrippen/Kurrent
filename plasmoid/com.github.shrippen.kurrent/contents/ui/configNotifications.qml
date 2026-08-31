import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "."

import "components"

ConfigPageBase {
    id: root
    ConfigControllerLoader {
        id: configControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var configController: configControllerLoader.controller

    readonly property int eventCalendarCount: {
        var model = configController ? configController.eventCalendarModel : null
        return model ? model.count : 0
    }

    function busyCalendarSet() {
        var raw = cfg_busyCalendarIds || ""
        if (!raw.trim()) return {}
        var parts = raw.split(",")
        var s = {}
        for (var i = 0; i < parts.length; ++i) {
            var v = parts[i].trim()
            if (v !== "") s[v] = true
        }
        return s
    }

    function eventCalendarIds() {
        var model = configController ? configController.eventCalendarModel : null
        var ids = []
        if (!model) {
            return ids
        }
        for (var i = 0; i < model.count; ++i) {
            ids.push(String(model.collectionIdAt(i)))
        }
        return ids
    }

    function toggleBusyCalendar(collectionId) {
        var current = busyCalendarSet()
        var key = String(collectionId)
        var allIds = eventCalendarIds()

        var isEmpty = Object.keys(current).length === 0
        if (isEmpty) {
            var result = []
            for (var j = 0; j < allIds.length; ++j) {
                if (allIds[j] !== key) result.push(allIds[j])
            }
            cfg_busyCalendarIds = result.join(",")
        } else if (current[key]) {
            delete current[key]
            var arr = Object.keys(current)
            cfg_busyCalendarIds = arr.length > 0 ? arr.join(",") : ""
        } else {
            current[key] = true
            var arr2 = Object.keys(current)
            if (arr2.length >= allIds.length) {
                cfg_busyCalendarIds = ""
            } else {
                cfg_busyCalendarIds = arr2.join(",")
            }
        }
    }

    function isBusyCalendarEnabled(collectionId) {
        var s = busyCalendarSet()
        if (Object.keys(s).length === 0) return true
        return !!s[String(collectionId)]
    }

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
        id: shell

        PluginMissingView {
            visible: configControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                id: notifyCheck
                Kirigami.FormData.label: i18n("Desktop notifications")
                text: i18n("Notify when a task reminder is due")
                checked: root.cfg_notificationsEnabled
                onCheckedChanged: root.cfg_notificationsEnabled = checked
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
                checked: root.cfg_quietHoursEnabled
                onCheckedChanged: root.cfg_quietHoursEnabled = checked
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

            QQC2.CheckBox {
                id: eventBusyCheck
                Kirigami.FormData.label: i18n("During events")
                text: i18n("Suppress reminders while a calendar event is in progress")
                checked: root.cfg_suppressRemindersDuringEvents
                onCheckedChanged: root.cfg_suppressRemindersDuringEvents = checked
            }

            QQC2.Label {
                Kirigami.FormData.label: ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                visible: eventBusyCheck.checked
                text: i18n("Only opaque (busy) events count. Transparent events are ignored.")
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    notificationsEnabled: true,
                    quietHoursEnabled: false,
                    quietHoursStart: 22,
                    quietHoursEnd: 7,
                    suppressRemindersDuringEvents: false,
                    busyCalendarIds: ""
                })
            }
        }

        Kirigami.Heading {
            visible: eventBusyCheck.checked
            text: i18n("Calendars for event suppression")
            level: 3
            Layout.fillWidth: true
        }

        QQC2.Label {
            visible: eventBusyCheck.checked
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: i18n("Choose which Akonadi event calendars block reminders. Disabled entries are ignored when checking for ongoing events.")
        }

        ColumnLayout {
            visible: eventBusyCheck.checked
            Layout.fillWidth: true
            spacing: Design.spaceSmall

            QQC2.Label {
                visible: root.eventCalendarCount === 0
                text: i18n("No event calendars found. Make sure Akonadi is running and CalDAV calendars are configured.")
                opacity: 0.6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                model: configController ? configController.eventCalendarModel : 0

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true

                    contentItem: RowLayout {
                        spacing: Design.spaceSmall

                        Kirigami.Icon {
                            source: "view-calendar"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: model.name
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }

                        QQC2.Switch {
                            checked: root.isBusyCalendarEnabled(model.collectionId)
                            onToggled: root.toggleBusyCalendar(model.collectionId)
                            QQC2.ToolTip.text: i18n("Include this calendar when checking for ongoing events")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: eventBusyCheck.checked && root.eventCalendarCount > 0
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("Include All")
                icon.name: "checkbox"
                onClicked: cfg_busyCalendarIds = ""
            }

            Item { Layout.fillWidth: true }

            QQC2.Button {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: if (configController) configController.refresh()
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
