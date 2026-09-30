import QtQuick
import QtQuick.Layouts
import "."

/**
 * A row of a list: a leading figure (`leadingText`, e.g. a time), a marker (`marker`, e.g. a
 * KanteSwatch), the text with an optional `subtitle` line, a count badge and a meta figure.
 * Selected = cyan tint with a bar, hover = tint step 1, pressed = tint step 2, keyboard
 * focus = a ring inside, `dropTarget` = cyan tint with a dashed cyan frame (something is
 * dragged over it). The badge (`count`) turns cyan with the selection.
 *   density         Compact / Normal / Comfortable: 32 / 40 / 48 units (two lines grow it)
 *   rule            the 1 px rule under the row (off in lists with their own separators)
 *   focusOnClick    a tap takes the keyboard focus (off where the list keeps it)
 *   disabledReason  when disabled, shown as the second line, so it is readable on touch too
 *                   (a disabled item gets no hover, so a tooltip would never show)
 */
FocusScope {
    id: row

    enum Density {
        Compact,
        Normal,
        Comfortable
    }

    property string text: ""
    property string subtitle: ""
    property string meta: ""
    property string leadingText: ""
    /** Width of the leading figure, so a column of times lines up; 0 = its own width. */
    property real leadingWidth: 0
    property string count: ""
    property bool selected: false
    property bool dropTarget: false
    property bool rule: true
    property bool focusOnClick: true
    property string disabledReason: ""
    property int density: KanteListRow.Density.Normal
    readonly property bool pressed: tap.pressed
    default property alias marker: markerSlot.data
    signal clicked()

    readonly property string secondLine: !enabled && disabledReason !== "" ? disabledReason : subtitle
    readonly property real densityHeight: density === KanteListRow.Density.Compact ? KanteStyle.heightSmall
                                          : (density === KanteListRow.Density.Comfortable ? KanteStyle.heightLarge : KanteStyle.heightMedium)

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: Math.max(densityHeight, texts.implicitHeight + KanteStyle.unit(12))
    activeFocusOnTab: true

    /** A tap: takes the focus (`focusOnClick`) and emits `clicked`. */
    function activate() {
        if (focusOnClick) {
            forceActiveFocus()
        }
        clicked()
    }

    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Rectangle {
        anchors.fill: parent
        color: row.dropTarget ? KanteStyle.tintHighlight2Color
             : row.selected ? KanteStyle.selectionColor
             : row.pressed ? KanteStyle.tint2Color
             : (hover.hovered ? KanteStyle.tint1Color : "transparent")
    }
    Rectangle { visible: row.selected; width: 3; height: parent.height; color: KanteStyle.focusColor }
    Rectangle { visible: row.rule; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: KanteStyle.ruleColor }
    KanteDropZone {
        anchors.fill: parent
        visible: row.dropTarget
        kind: KanteDropZone.Kind.Gap
    }
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
        opacity: row.enabled ? 1 : 0.5

        Text {
            visible: row.leadingText !== ""
            Layout.preferredWidth: row.leadingWidth > 0 ? row.leadingWidth : implicitWidth
            Layout.alignment: Qt.AlignVCenter
            text: row.leadingText
            color: row.selected ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 0.9, false)
        }
        Item {
            id: markerSlot
            visible: childrenRect.width > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: row.text
                color: KanteStyle.textColor
                font: KanteStyle.defaultFont
                elide: Text.ElideRight
            }
            Text {
                visible: row.secondLine !== ""
                Layout.fillWidth: true
                text: row.secondLine
                color: !row.enabled && row.disabledReason !== "" ? KanteStyle.neutralTextColor : KanteStyle.mutedTextColor
                font: KanteStyle.smallFont
                elide: Text.ElideRight
            }
        }
        // Count badge: quiet, cyan on the selected row.
        Rectangle {
            visible: row.count !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.max(KanteStyle.unit(20), badge.implicitWidth + KanteStyle.unit(10))
            implicitHeight: KanteStyle.unit(18)
            color: row.selected ? KanteStyle.focusColor : KanteStyle.tint2Color
            Text {
                id: badge
                anchors.centerIn: parent
                text: row.count
                color: row.selected ? KanteStyle.onStateColor : KanteStyle.textColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
            }
        }
        Text {
            visible: row.meta !== ""
            text: row.meta
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        onTapped: row.activate()
    }
    Accessible.role: Accessible.ListItem
    Accessible.name: row.text
    Accessible.description: row.secondLine
    Accessible.selected: row.selected
}
