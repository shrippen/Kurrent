import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"
import org.kde.plasma.plasmoid

ConfigPageBase {
    id: root
    ConfigControllerLoader {
        id: settingsControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var settingsController: settingsControllerLoader.controller
    readonly property string widgetVersion: (typeof Plasmoid !== "undefined" && Plasmoid.metaData) ? Plasmoid.metaData.version : ""
    readonly property bool versionMismatch: !!settingsController && widgetVersion.length > 0
            && String(settingsController.pluginVersion).split(".").slice(0, 2).join(".")
               !== widgetVersion.split(".").slice(0, 2).join(".")

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

            // Real section heads instead of form rows (m1).
            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Status")
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

            // Widget and plugin side by side; a mismatch is the usual cause after updates (m2).
            QQC2.Label {
                Kirigami.FormData.label: i18n("Version")
                text: i18n("Widget %1 · Plugin %2", root.widgetVersion,
                           settingsController ? settingsController.pluginVersion : i18n("Not loaded"))
            }
            QQC2.Label {
                visible: root.versionMismatch
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                text: i18n("Widget and plugin versions differ. Reinstall Kurrent so both match.")
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
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                preferredLines: 8
                readOnly: true
                text: settingsController ? (settingsController.debugInfo || "") : ""
            }

            QQC2.Button {
                id: copyButton
                // Confirms the copy for two seconds (m3).
                property bool copied: false
                text: copied ? i18n("Copied") : i18n("Copy debug bundle")
                icon.name: copied ? "checkmark" : "edit-copy"
                enabled: !!settingsController
                onClicked: {
                    root.copyDebugBundle()
                    copied = true
                    copiedTimer.restart()
                }
                Timer {
                    id: copiedTimer
                    interval: 2000
                    onTriggered: copyButton.copied = false
                }
            }

            ConfigSection {
                Kirigami.FormData.isSection: true
                text: i18n("Logging")
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Info journal")
                text: i18n("Writes and sync state")
                checked: root.cfg_infoJournalLogging
                onCheckedChanged: root.cfg_infoJournalLogging = checked
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Verbose journal")
                text: i18n("Fetch, monitor and collection details")
                checked: root.cfg_verboseJournalLogging
                onCheckedChanged: root.cfg_verboseJournalLogging = checked
            }

            ConfigHint {
                Kirigami.FormData.label: i18n("Category")
                text: i18n("Both use com.github.shrippen.kurrent.akonadi. Info covers writes and sync (Qt Info). Verbose adds fetch/monitor lines (Qt Debug).")
            }

            ConfigHint {
                Kirigami.FormData.label: i18n("Smoke test")
                text: i18n("Set KURRENT_SMOKE=1 and check ~/.cache/kurrent-smoke/ for logs.")
            }
        }
    }
}
