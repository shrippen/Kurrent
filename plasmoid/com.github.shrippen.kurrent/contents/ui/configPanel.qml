import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"

ConfigPageBase {
    id: root


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
    }

    ConfigFormShell {

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

            QQC2.Label {
                Kirigami.FormData.label: ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                visible: overdueColorCombo.enabled
                text: badgeCombo.model[badgeCombo.currentIndex].value === "overdue"
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

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    panelBadge: "open",
                    panelBadgeStyle: "number",
                    panelBadgeOverdueColor: "highlight",
                    panelTooltip: "open"
                })
            }
        }
    }
}
