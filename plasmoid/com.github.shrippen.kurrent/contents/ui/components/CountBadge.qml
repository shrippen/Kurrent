import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../Kante"

// Counter next to sidebar rows, tabs and Kanban columns.
// System: rounded pill like Plasma badges. Kante and Kante Light: KanteCounter.
// `negative` (e.g. overdue) is its Error kind, `selected` (on an accent fill) its Info kind.
Rectangle {
    id: badge

    property alias text: label.text
    property bool selected: false
    property bool negative: false
    // Zero reads as "nothing here": dimmed so real counts stand out (g6).
    readonly property bool zero: label.text === "0"

    opacity: zero && !selected ? 0.45 : 1
    implicitHeight: KanteStyle.active ? kante.implicitHeight : Math.round(label.implicitHeight + 2)
    implicitWidth: KanteStyle.active ? kante.implicitWidth
                                     : Math.max(implicitHeight, Math.round(label.implicitWidth + Kirigami.Units.smallSpacing * 2))
    radius: height / 2
    color: {
        if (KanteStyle.active) {
            return "transparent"
        }
        if (negative) {
            return KanteStyle.negativeTextColor
        }
        if (selected) {
            return KanteStyle.tint(Kirigami.Theme.highlightedTextColor, 0.22)
        }
        return KanteStyle.tint(Kirigami.Theme.textColor, 0.1)
    }

    KanteCounter {
        id: kante
        visible: KanteStyle.active
        anchors.fill: parent
        text: label.text
        kind: badge.negative ? KanteCounter.Kind.Error
              : (badge.selected ? KanteCounter.Kind.Info : KanteCounter.Kind.Normal)
    }

    QQC2.Label {
        id: label
        visible: !KanteStyle.active
        anchors.centerIn: parent
        font: Kirigami.Theme.smallFont
        color: {
            if (badge.negative) {
                return "white"
            }
            return badge.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
        opacity: badge.negative || badge.selected ? 1 : 0.75
    }
}
