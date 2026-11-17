import QtQuick
import QtQuick.Layouts
import "."

/**
 * A group of settings as a tile: a panel with the group's title (Kante heading) on the left,
 * the number of its settings (small mono label, `countText`) on the right, and the rows below
 * (KanteSettingRow, or any item the app lists). The rows go in as children; give them
 * `Layout.fillWidth: true`.
 *   title      the group's name; screen readers hear a group with this name
 *   countText  the words for the count, e.g. "5 Einstellungen"; the app writes it (plural forms
 *              are the app's), "" shows nothing
 *   count      read only: the visible KanteSettingRows inside, also nested in layouts and
 *              repeaters; an item with `isSetting: true` counts as one and is not searched
 *
 *   ┌──────────────────────────────────────┐
 *   │ ANZEIGE                 5 EINSTELLUNGEN │
 *   ├──────────────────────────────────────┤
 *   │ Schwelle                  [ 62 ]     │
 *   │ Intervall                 [ 5 s ]    │
 *   └──────────────────────────────────────┘
 *
 * Kante and Kante Light: the card with the small cut corner and a 1 px frame; System: platform
 * colours. Put the group in the page's column; KanteStickyHeader scrolls to it.
 */
Item {
    id: group

    property string title: ""
    property string countText: ""
    default property alias content: rows.data
    /** Marks the item for KanteSettingRow, which tells its group when it comes or goes. */
    readonly property bool settingGroup: true
    readonly property int count: counter.value

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: column.implicitHeight

    Accessible.role: Accessible.Grouping
    Accessible.name: title
    Accessible.description: countText

    /** Counts the settings again, once the layout has settled. */
    function recount() {
        Qt.callLater(counter.update)
    }

    QtObject {
        id: counter
        property int value: 0

        function walk(item) {
            let n = 0
            for (const child of item.children) {
                if (!child.visible) {
                    continue
                }
                n += child.isSetting === true ? 1 : walk(child)
            }
            return n
        }

        function update() {
            value = walk(rows)
        }
    }

    Component.onCompleted: recount()

    KanteCard {
        anchors.fill: parent
        color: KanteStyle.cardColor
        borderColor: KanteStyle.frameColor
        chamfer: KanteStyle.chamferSmall
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: KanteStyle.unit(16)
            Layout.bottomMargin: KanteStyle.unit(8)
            spacing: KanteStyle.unit(12)

            KanteHeading {
                objectName: "groupTitle"
                level: 3
                text: group.title
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            KanteSectionLabel {
                objectName: "groupCount"
                visible: group.countText.length > 0
                text: group.countText
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: KanteStyle.ruleColor
        }

        ColumnLayout {
            id: rows
            Layout.fillWidth: true
            Layout.leftMargin: KanteStyle.unit(16)
            Layout.rightMargin: KanteStyle.unit(16)
            Layout.bottomMargin: KanteStyle.unit(4)
            spacing: 0
        }
    }
}
