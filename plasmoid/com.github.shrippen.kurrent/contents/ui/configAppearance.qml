import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM
import "components"

KCM.SimpleKCM {
    id: root

    property alias cfg_blurBackground: blurBackgroundCheck.checked
    property alias cfg_reducedMotion: reducedMotionCheck.checked
    property int cfg_descriptionPreviewLines
    property string cfg_density
    property int cfg_overlayDimStep

    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(densityCombo, cfg_density || "auto")
        selectCombo(overlayDimCombo, String(cfg_overlayDimStep))
        selectCombo(previewLinesCombo, String(cfg_descriptionPreviewLines))
    }

    ConfigFormShell {

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                id: blurBackgroundCheck
                Kirigami.FormData.label: i18n("Background")
                text: i18n("Blurred wallpaper behind the widget")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: i18n("Use Plasma’s translucent background so KWin blurs the wallpaper. Also applies to the panel flyout.")
            }

            QQC2.ComboBox {
                id: densityCombo
                Kirigami.FormData.label: i18n("Density")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                textRole: "text"
                model: [
                    { text: i18n("Auto (compact, larger with touch)"), value: "auto" },
                    { text: i18n("Compact"), value: "compact" },
                    { text: i18n("Comfortable"), value: "comfortable" }
                ]
                onActivated: cfg_density = model[currentIndex].value
                Component.onCompleted: selectCombo(densityCombo, plasmoid.configuration.density || "auto")
            }

            QQC2.ComboBox {
                id: overlayDimCombo
                Kirigami.FormData.label: i18n("Editor dim")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                textRole: "text"
                model: [
                    { text: i18n("Light"), value: "0" },
                    { text: i18n("Medium"), value: "1" },
                    { text: i18n("Strong"), value: "2" }
                ]
                onActivated: root.cfg_overlayDimStep = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(overlayDimCombo, String(plasmoid.configuration.overlayDimStep !== undefined ? plasmoid.configuration.overlayDimStep : 1))
            }

            QQC2.CheckBox {
                id: reducedMotionCheck
                Kirigami.FormData.label: i18n("Motion")
                text: i18n("Reduced motion (no spinner, quieter hover)")
                Component.onCompleted: checked = plasmoid.configuration.reducedMotion === true
            }

            QQC2.ComboBox {
                id: previewLinesCombo
                Kirigami.FormData.label: i18n("Description preview")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                textRole: "text"
                model: [
                    { text: i18n("Hidden"), value: "0" },
                    { text: i18n("1 line"), value: "1" },
                    { text: i18n("2 lines"), value: "2" }
                ]
                onActivated: root.cfg_descriptionPreviewLines = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(previewLinesCombo, String(plasmoid.configuration.descriptionPreviewLines || 0))
            }

            ConfigResetButton {
                Kirigami.FormData.label: ""
                page: root
                defaults: ({
                    blurBackground: true,
                    density: "auto",
                    overlayDimStep: 1,
                    reducedMotion: false,
                    descriptionPreviewLines: 0
                })
            }
        }
    }
}
