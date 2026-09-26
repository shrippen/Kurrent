import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../Kante"

// Counter next to sidebar rows, tabs and Kanban columns.
// System: rounded pill like Plasma badges. Kante Light: same pill, digits in JetBrains Mono.
// Kante: square, mono digits. `negative` (e.g. overdue) fills with the negative colour.
Rectangle {
    id: badge

    property alias text: label.text
    property bool selected: false
    property bool negative: false
    // Zero reads as "nothing here": dimmed so real counts stand out (g6).
    readonly property bool zero: label.text === "0"

    opacity: zero && !selected ? 0.45 : 1
    implicitHeight: Math.round(label.implicitHeight + 2)
    implicitWidth: Math.max(implicitHeight, Math.round(label.implicitWidth + Kirigami.Units.smallSpacing * 2))
    radius: KanteStyle.themed ? 0 : height / 2
    color: {
        if (negative) {
            return KanteStyle.negativeTextColor
        }
        if (selected) {
            return KanteStyle.tint(Kirigami.Theme.highlightedTextColor, 0.22)
        }
        return KanteStyle.themed ? KanteStyle.sunkenColor : KanteStyle.tint(Kirigami.Theme.textColor, 0.1)
    }

    QQC2.Label {
        id: label
        anchors.centerIn: parent
        font: KanteStyle.active ? KanteStyle.monoFont(Kirigami.Theme.smallFont.pointSize) : Kirigami.Theme.smallFont
        color: {
            if (badge.negative) {
                return KanteStyle.themed ? KanteStyle.backgroundColor : "white"
            }
            return badge.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
        opacity: badge.negative || badge.selected ? 1 : 0.75
    }
}
