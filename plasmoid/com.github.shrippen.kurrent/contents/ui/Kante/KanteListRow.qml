import QtQuick
import QtQuick.Layouts
import "."

/**
 * A row of a list: a marker (`marker`, e.g. a KanteSwatch), the text and a meta
 * figure. Selected = cyan tint with a bar, hover = tint step 1, keyboard focus = a ring inside.
 */
FocusScope {
    id: row

    property string text: ""
    property string meta: ""
    property bool selected: false
    default property alias marker: markerSlot.data
    signal clicked()

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: KanteStyle.heightMedium
    activeFocusOnTab: true

    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Rectangle {
        anchors.fill: parent
        color: row.selected ? KanteStyle.selectionColor : (hover.hovered ? KanteStyle.tint1Color : "transparent")
    }
    Rectangle { visible: row.selected; width: 3; height: parent.height; color: KanteStyle.focusColor }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: KanteStyle.ruleColor }
    Rectangle {
        anchors.fill: parent
        visible: row.activeFocus
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.focusColor
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: KanteStyle.unit(12)
        anchors.rightMargin: KanteStyle.unit(12)
        spacing: KanteStyle.unit(10)
        Item {
            id: markerSlot
            visible: childrenRect.width > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.fillWidth: true
            text: row.text
            color: KanteStyle.textColor
            font: KanteStyle.defaultFont
            elide: Text.ElideRight
        }
        Text {
            text: row.meta
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: { row.forceActiveFocus(); row.clicked() } }
    Accessible.role: Accessible.ListItem
    Accessible.name: row.text
    Accessible.selected: row.selected
}
