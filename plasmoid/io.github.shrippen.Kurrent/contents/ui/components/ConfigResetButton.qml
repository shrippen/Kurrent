import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2

import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// "Reset this page": always below the form at the left edge (x3).
QQC2.Button {
    required property var page
    required property var defaults

    Layout.alignment: Qt.AlignLeft
    Layout.topMargin: Kirigami.Units.largeSpacing
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
