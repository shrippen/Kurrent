import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

// Settings preview: one example task row that follows the row options live (chips, dates,
// description preview, density). Plasma look; the widget itself may use Kante.
Rectangle {
    id: preview

    property bool showDate: true
    property bool showLabels: true
    property bool showPriority: true
    property bool showRecurring: true
    property bool showProgress: true
    property bool showStatus: true
    property bool showSecrecy: true
    property bool showLocation: true
    property bool relativeDates: false
    property bool showTime: true
    property int descriptionLines: 0
    property bool comfortable: false

    readonly property int iconSize: Kirigami.Units.iconSizes.small

    Layout.fillWidth: true
    Layout.maximumWidth: Kirigami.Units.gridUnit * 26
    implicitHeight: row.implicitHeight + (comfortable ? Kirigami.Units.largeSpacing * 2 : Kirigami.Units.smallSpacing * 2)
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
    Accessible.name: i18n("Preview")

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.CheckBox {
            Layout.alignment: Qt.AlignTop
            enabled: false
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Call the plumber")
                elide: Text.ElideRight
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: preview.descriptionLines > 0
                text: i18n("Leaking tap in the kitchen, ask for Thursday morning.")
                maximumLineCount: preview.descriptionLines
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon { source: "folder"; color: "#3daee9"; implicitWidth: preview.iconSize; implicitHeight: preview.iconSize }
                QQC2.Label { text: i18n("Home"); font: Kirigami.Theme.smallFont; opacity: 0.7 }
                QQC2.Label { visible: preview.showLabels; text: "#" + i18n("Errands"); font: Kirigami.Theme.smallFont; color: "#1abc9c" }
                Kirigami.Icon { visible: preview.showRecurring; source: "media-playlist-repeat"; implicitWidth: preview.iconSize; implicitHeight: preview.iconSize }
                Kirigami.Icon { visible: preview.showProgress; source: "view-task"; implicitWidth: preview.iconSize; implicitHeight: preview.iconSize }
                Kirigami.Icon { visible: preview.showStatus; source: "media-playback-start"; implicitWidth: preview.iconSize; implicitHeight: preview.iconSize }
                Kirigami.Icon { visible: preview.showSecrecy; source: "object-locked"; implicitWidth: preview.iconSize; implicitHeight: preview.iconSize }
                Kirigami.Icon { visible: preview.showLocation; source: "mark-location"; color: "#e67e22"; implicitWidth: preview.iconSize; implicitHeight: preview.iconSize }
            }
        }

        Kirigami.Icon {
            visible: preview.showPriority
            source: "flag"
            color: Kirigami.Theme.negativeTextColor
            implicitWidth: preview.iconSize
            implicitHeight: preview.iconSize
        }
        QQC2.Label {
            visible: preview.showDate
            text: (preview.relativeDates ? i18n("Tomorrow") : Qt.locale().toString(new Date(Date.now() + 86400000), Locale.ShortFormat))
                  + (preview.showTime ? " " + Qt.locale().toString(new Date(2000, 0, 1, 9, 30), Qt.locale().timeFormat(Locale.ShortFormat)) : "")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.positiveTextColor
        }
    }
}
