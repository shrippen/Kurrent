import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Section label (web: `.h-label`): the small heading over a group of fields, a tile's
 * caption, "Findings from checks". Kante and Kante Light: small mono capitals in the
 * muted text colour; System: the platform's small font, bold, in the text colour.
 * `rule` adds the thin line under it, as on the web.
 */
QQC2.Label {
    id: label

    property bool rule: false

    font: KanteStyle.active ? KanteStyle.labelFont() : Qt.font({ family: KanteStyle.smallFont.family, pointSize: KanteStyle.smallFont.pointSize, bold: true })
    color: KanteStyle.active ? KanteStyle.mutedTextColor : Kirigami.Theme.textColor
    opacity: KanteStyle.active ? 1 : 0.85
    elide: Text.ElideRight
    bottomPadding: rule ? KanteStyle.unit(6) : 0

    Rectangle {
        visible: label.rule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: KanteStyle.ruleColor
    }
}
