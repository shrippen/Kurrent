import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Section head for config pages: left-aligned title over a rule, the same on every page.
// In a FormLayout set Kirigami.FormData.isSection: true so it spans both columns.
ColumnLayout {
    property alias text: heading.text

    Layout.fillWidth: true
    Layout.topMargin: Kirigami.Units.largeSpacing
    spacing: Kirigami.Units.smallSpacing

    Kirigami.Heading {
        id: heading
        Layout.fillWidth: true
        level: 3
        wrapMode: Text.WordWrap
    }
    Kirigami.Separator {
        Layout.fillWidth: true
    }
}
