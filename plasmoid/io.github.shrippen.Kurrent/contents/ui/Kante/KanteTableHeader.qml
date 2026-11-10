pragma ComponentBehavior: Bound
import QtQuick
import "."

/**
 * Table header (Kante 1.43, from lmix): the column titles over a list of `KanteListRow`s or
 * own rows, lined up with them. The header computes the columns; the rows take their x and
 * width from it (`columnX(i)`, `columnWidth(i)`), so title and value always sit on one line.
 *   columns   [{ title, width, align }]: width in px (> 0) or 0 for a column that shares
 *             the rest; align Text.AlignLeft (default) or Text.AlignRight (figures)
 *   spacing   gap between columns
 * Titles in label style (`KanteSectionLabel`), a 1 px rule under them. Screen readers get
 * each title as a column header.
 */
Item {
    id: header

    property var columns: []
    property real spacing: KanteStyle.unit(10)

    readonly property var widths: {
        let fixed = 0
        let fills = 0
        for (const c of columns) {
            if (c.width > 0) {
                fixed += c.width
            } else {
                fills++
            }
        }
        const gaps = Math.max(0, columns.length - 1) * spacing
        const rest = Math.max(0, width - fixed - gaps)
        return columns.map(c => c.width > 0 ? c.width : (fills > 0 ? rest / fills : 0))
    }

    function columnWidth(i) {
        return widths[i] || 0
    }
    function columnX(i) {
        let x = 0
        for (let k = 0; k < i && k < widths.length; k++) {
            x += widths[k] + spacing
        }
        return x
    }

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: KanteStyle.unit(24)

    Repeater {
        model: header.columns.length

        KanteSectionLabel {
            id: title
            required property int index
            x: header.columnX(title.index)
            width: header.columnWidth(title.index)
            anchors.verticalCenter: parent.verticalCenter
            text: header.columns[title.index].title || ""
            horizontalAlignment: header.columns[title.index].align === Text.AlignRight ? Text.AlignRight : Text.AlignLeft
            Accessible.role: Accessible.ColumnHeader
            Accessible.name: text
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: KanteStyle.ruleColor
    }
}
