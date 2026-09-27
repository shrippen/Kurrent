import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"

// Panel badge and tooltip, plus reminder notifications (one page, g3).
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
        selectCombo(badgeCombo, cfg_panelBadge || "open")
        selectCombo(badgeStyleCombo, cfg_panelBadgeStyle || "number")
        selectCombo(overdueColorCombo, cfg_panelBadgeOverdueColor || "highlight")
        selectCombo(tooltipCombo, cfg_panelTooltip || "open")
        selectCombo(quietStartCombo, String(cfg_quietHoursStart))
        selectCombo(quietEndCombo, String(cfg_quietHoursEnd))
    }

    readonly property var hourModel: (function() {
        var rows = []
        for (var h = 0; h < 24; ++h) {
            rows.push({ text: i18n("%1:00", h), value: String(h) })
        }
        return rows
    })()

    ConfigFormShell {
        id: shell

        PluginMissingView {
            visible: configControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Panel")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Preview")
                BadgePreview {
                    mode: root.cfg_panelBadge || "open"
                    badgeStyle: root.cfg_panelBadgeStyle || "number"
                    negative: overdueColorCombo.enabled && root.cfg_panelBadgeOverdueColor === "negative"
                }
            }

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
                    { text: i18n("Overdue"), value: "overdue" },
                    { text: i18n("Tomorrow"), value: "tomorrow" },
                    { text: i18n("High priority"), value: "high" }
                ]
                onActivated: cfg_panelBadge = model[currentIndex].value
                Component.onCompleted: selectCombo(badgeCombo, plasmoid.configuration.panelBadge || "open")
            }

            QQC2.ComboBox {
                id: badgeStyleCombo
                Kirigami.FormData.label: i18n("Badge display")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Number"), value: "number" },
                    { text: i18n("Dot"), value: "dot" }
                ]
                onActivated: cfg_panelBadgeStyle = model[currentIndex].value
                Component.onCompleted: selectCombo(badgeStyleCombo, plasmoid.configuration.panelBadgeStyle || "number")
            }

            QQC2.ComboBox {
                id: overdueColorCombo
                Kirigami.FormData.label: i18n("Overdue badge color")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                enabled: badgeCombo.currentIndex >= 0
                        && (badgeCombo.model[badgeCombo.currentIndex].value === "overdue"
                            || badgeCombo.model[badgeCombo.currentIndex].value === "today")
                model: [
                    { text: i18n("Accent (highlight)"), value: "highlight" },
                    { text: i18n("Overdue (negative)"), value: "negative" }
                ]
                onActivated: cfg_panelBadgeOverdueColor = model[currentIndex].value
                Component.onCompleted: selectCombo(overdueColorCombo, plasmoid.configuration.panelBadgeOverdueColor || "highlight")
            }

            // Shown also while the option is greyed out, so it says why (g1).
            ConfigHint {
                text: badgeCombo.currentIndex >= 0 && badgeCombo.model[badgeCombo.currentIndex].value === "overdue"
                        ? i18n("Applies when the badge shows the overdue count.")
                        : i18n("Applies when the badge shows today and there are overdue tasks.")
            }

            QQC2.ComboBox {
                id: tooltipCombo
                Kirigami.FormData.label: i18n("Panel tooltip")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                textRole: "text"
                model: [
                    { text: i18n("Open tasks"), value: "open" },
                    { text: i18n("Today"), value: "today" },
                    { text: i18n("Today and overdue"), value: "today-overdue" },
                    { text: i18n("Overdue only"), value: "overdue" },
                    { text: i18n("High priority"), value: "high" },
                    { text: i18n("All views"), value: "views" },
                    { text: i18n("Off"), value: "off" }
                ]
                onActivated: cfg_panelTooltip = model[currentIndex].value
                Component.onCompleted: selectCombo(tooltipCombo, plasmoid.configuration.panelTooltip || "open")
            }

            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Notifications")
            }

            QQC2.CheckBox {
                id: notifyCheck
                Kirigami.FormData.label: i18n("Desktop notifications")
                text: i18n("Notify when a task reminder is due")
                checked: root.cfg_notificationsEnabled
                onCheckedChanged: root.cfg_notificationsEnabled = checked
            }

            ConfigHint {
                text: i18n("Snoozing only moves the reminder, not the due date.")
            }

            // Check that notifications arrive without waiting for a reminder (h3).
            QQC2.Button {
                icon.name: "notifications"
                text: i18n("Send test notification")
                enabled: !!configController
                onClicked: {
                    var ok = configController.sendTestNotification(i18n("Kurrent"), i18n("Notifications work."))
                    testResult.text = ok ? i18n("Sent.") : i18n("This build has no notification support.")
                }
            }
            QQC2.Label {
                id: testResult
                visible: text.length > 0
                opacity: 0.7
            }

            QQC2.CheckBox {
                id: quietCheck
                Kirigami.FormData.label: i18n("Quiet hours")
                text: i18n("No reminders during these hours")
                checked: root.cfg_quietHoursEnabled
                onCheckedChanged: root.cfg_quietHoursEnabled = checked
            }

            // Quiet hours in one line right under the switch (h1).
            RowLayout {
                enabled: quietCheck.checked
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label { text: i18n("From") }
                QQC2.ComboBox {
                    id: quietStartCombo
                    textRole: "text"
                    model: root.hourModel
                    onActivated: root.cfg_quietHoursStart = Number(model[currentIndex].value)
                    Component.onCompleted: selectCombo(quietStartCombo, String(plasmoid.configuration.quietHoursStart !== undefined ? plasmoid.configuration.quietHoursStart : 22))
                }
                QQC2.Label { text: i18n("to") }
                QQC2.ComboBox {
                    id: quietEndCombo
                    textRole: "text"
                    model: root.hourModel
                    onActivated: root.cfg_quietHoursEnd = Number(model[currentIndex].value)
                    Component.onCompleted: selectCombo(quietEndCombo, String(plasmoid.configuration.quietHoursEnd !== undefined ? plasmoid.configuration.quietHoursEnd : 7))
                }
            }

            QQC2.CheckBox {
                id: eventBusyCheck
                Kirigami.FormData.label: i18n("During events")
                text: i18n("No reminders during busy events")
                checked: root.cfg_suppressRemindersDuringEvents
                onCheckedChanged: root.cfg_suppressRemindersDuringEvents = checked
            }

            ConfigHint {
                visible: eventBusyCheck.checked
                text: i18n("Only opaque (busy) events count. Transparent events are ignored.")
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

        ConfigResetButton {
            page: root
            defaults: ({
                panelBadge: "open",
                panelBadgeStyle: "number",
                panelBadgeOverdueColor: "highlight",
                panelTooltip: "open",
                notificationsEnabled: true,
                quietHoursEnabled: false,
                quietHoursStart: 22,
                quietHoursEnd: 7,
                suppressRemindersDuringEvents: false,
                busyCalendarIds: ""
            })
        }
    }
}
