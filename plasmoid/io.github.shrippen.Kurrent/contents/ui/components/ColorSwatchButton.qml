import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami 2.20 as Kirigami
import "../Kante"

// Colour override for a project, label or location: a swatch that opens a colour picker.
// Kante: KanteSwatch, ring = origin (own = set here, generated = automatic).
// Empty `value` = automatic colour (`autoColor`, shown dimmed). Emits the new "#rrggbb" or "".
QQC2.ToolButton {
    id: swatch

    property string value: ""
    property color autoColor: Kirigami.Theme.textColor

    signal picked(string hex)

    display: QQC2.AbstractButton.IconOnly
    text: value.length > 0 ? i18n("Colour %1", value) : i18n("Automatic colour")
    QQC2.ToolTip.text: text
    QQC2.ToolTip.visible: hovered
    onClicked: menu.popup(swatch, 0, swatch.height)

    contentItem: Item {
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: Kirigami.Units.iconSizes.small
        Rectangle {
            visible: !KanteStyle.active
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            radius: width / 2
            color: swatch.value.length > 0 ? swatch.value : swatch.autoColor
            border.width: swatch.value.length > 0 ? 0 : 1
            border.color: Kirigami.Theme.textColor
            opacity: swatch.value.length > 0 ? 1 : 0.55
        }
        KanteSwatch {
            visible: KanteStyle.active
            anchors.centerIn: parent
            implicitWidth: Kirigami.Units.iconSizes.small
            swatchColor: swatch.value.length > 0 ? swatch.value : swatch.autoColor
            source: swatch.value.length > 0 ? KanteSwatch.Source.Own : KanteSwatch.Source.Generated
        }
    }

    QQC2.Menu {
        id: menu
        QQC2.MenuItem {
            text: i18n("Choose colour…")
            icon.name: "color-picker"
            onTriggered: {
                dialog.selectedColor = swatch.value.length > 0 ? swatch.value : swatch.autoColor
                dialog.open()
            }
        }
        QQC2.MenuItem {
            text: i18n("Automatic")
            icon.name: "edit-reset"
            enabled: swatch.value.length > 0
            onTriggered: swatch.picked("")
        }
    }

    Dialogs.ColorDialog {
        id: dialog
        onAccepted: {
            var c = selectedColor
            swatch.picked("#" + [c.r, c.g, c.b].map(function(v) {
                return ("0" + Math.round(v * 255).toString(16)).slice(-2)
            }).join(""))
        }
    }
}
