import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2

QQC2.Button {
    required property var page
    required property var defaults

    text: i18n("Reset this page")
    icon.name: "edit-reset"
    onClicked: {
        for (var key in defaults) {
            page["cfg_" + key] = defaults[key]
        }
        if (typeof page.syncControls === "function") {
            page.syncControls()
        }
    }
}
