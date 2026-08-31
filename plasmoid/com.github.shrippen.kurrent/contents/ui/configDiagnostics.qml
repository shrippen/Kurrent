import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"

ConfigPageBase {
    id: root
    ConfigControllerLoader {
        id: settingsControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var settingsController: settingsControllerLoader.controller

    function copyDebugBundle() {
        var lines = []
        lines.push("Kurrent diagnostics")
        if (settingsController) {
            lines.push("plugin=" + settingsController.pluginVersion)
            lines.push("build=" + settingsController.buildNumber)
            lines.push("devBuild=" + settingsController.devBuild)
            lines.push("akonadi=" + (settingsController.akonadiAvailable ? "online" : "offline"))
            lines.push("syncingCount=" + settingsController.syncingCount)
            lines.push("pendingCount=" + settingsController.pendingCount)
            lines.push(settingsController.debugInfo || "")
        } else {
            lines.push("plugin=not loaded")
        }
        var text = lines.join("\n")
        if (typeof plasmoid !== "undefined" && plasmoid.copyToClipboard) {
            plasmoid.copyToClipboard(text)
        }
    }

    ConfigFormShell {
        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                Kirigami.FormData.label: i18n("Status")
                text: i18n("Akonadi and plugin diagnostics")
                level: 3
                Layout.fillWidth: true
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Akonadi")
                text: settingsController && settingsController.akonadiAvailable
                        ? i18n("Online")
                        : i18n("Offline")
                color: settingsController && settingsController.akonadiAvailable
                        ? Kirigami.Theme.positiveTextColor
                        : Kirigami.Theme.negativeTextColor
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Plugin version")
                text: settingsController ? settingsController.pluginVersion : i18n("Not loaded")
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Build")
                text: settingsController && settingsController.devBuild
                        ? String(settingsController.buildNumber)
                        : i18n("Release")
                visible: !settingsController || settingsController.devBuild
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Pending jobs")
                text: settingsController ? String(settingsController.syncingCount) : "0"
            }

            ScrollableTextArea {
                Kirigami.FormData.label: i18n("Debug info")
                Layout.fillWidth: true
                preferredLines: 8
                readOnly: true
                text: settingsController ? (settingsController.debugInfo || "") : ""
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("Copy")
                text: i18n("Copy debug bundle")
                enabled: !!settingsController
                onClicked: root.copyDebugBundle()
            }

            Kirigami.Heading {
                Kirigami.FormData.label: i18n("Logging")
                text: i18n("Journal diagnostics")
                level: 3
                Layout.fillWidth: true
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Info journal")
                text: i18n("Log Akonadi writes and sync state to the system journal")
                checked: root.cfg_infoJournalLogging
                onCheckedChanged: root.cfg_infoJournalLogging = checked
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Verbose journal")
                text: i18n("Log fetch, monitor, and collection details to the system journal")
                checked: root.cfg_verboseJournalLogging
                onCheckedChanged: root.cfg_verboseJournalLogging = checked
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Category")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.75
                text: i18n("Both use com.github.shrippen.kurrent.akonadi. Info covers writes and sync (Qt Info). Verbose adds fetch/monitor lines (Qt Debug).")
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Smoke test")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.75
                text: i18n("Set KURRENT_SMOKE=1 and check ~/.cache/kurrent-smoke/ for logs.")
            }
        }
    }
}
