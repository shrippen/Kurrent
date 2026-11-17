import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2

import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// "Reset this page": always below the form at the left edge (x3).
QQC2.Button {
    required property var page
    // Names of the settings on the page; their defaults come from main.xml
    // through the cfg_<name>Default properties Plasma sets on the page.
    required property var keys

    Layout.alignment: Qt.AlignLeft
    Layout.topMargin: Kirigami.Units.largeSpacing
    text: i18n("Reset this page")
    icon.name: "edit-reset"
    onClicked: {
        for (var i = 0; i < keys.length; ++i) {
            page["cfg_" + keys[i]] = page["cfg_" + keys[i] + "Default"]
        }
        if (typeof page.syncControls === "function") {
            page.syncControls()
        }
    }
}
