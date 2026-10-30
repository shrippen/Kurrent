import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Section heading in a menu (Kante 1.43, from lmix): "Show", "Exchange", "Settings" over a
 * group of `KanteMenuItem`s, instead of separators alone. Not an item: the keyboard and
 * the mouse pass over it. The first section of a menu needs no `rule`; the others get a
 * thin line above (`rule`, default true). Kante and Kante Light: `KanteSectionLabel`
 * (small mono capitals, muted); System: the platform's small bold label.
 */
Item {
    id: section

    property string text: ""
    property bool rule: true

    implicitWidth: label.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: label.implicitHeight + KanteStyle.unit(rule ? 14 : 8)

    Accessible.role: Accessible.Heading
    Accessible.name: text

    Rectangle {
        visible: section.rule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: KanteStyle.unit(3)
        height: 1
        color: KanteStyle.ruleColor
    }

    KanteSectionLabel {
        id: label
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.bottomMargin: KanteStyle.unit(2)
        text: section.text
        Accessible.ignored: true
    }
}
