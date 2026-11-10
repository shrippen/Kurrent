import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Muted help text under a control. Wraps within a narrow preferred width so a long sentence
// never pushes the FormLayout into its narrow (labels-above) mode.
QQC2.Label {
    Layout.fillWidth: true
    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    Layout.maximumWidth: Kirigami.Units.gridUnit * 26
    wrapMode: Text.WordWrap
    opacity: 0.7
    font: Kirigami.Theme.smallFont
}
