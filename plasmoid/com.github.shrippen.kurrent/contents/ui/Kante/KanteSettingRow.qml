import QtQuick
import QtQuick.Layouts
import "."

/**
 * A setting: title, hint and the control (`control`). While `modified` a cyan
 * square marks the title and the reset button shows; `resetRequested` fires when
 * it is pressed.
 *   narrow      title and hint above, the control below (default: narrower than 360 units)
 *   titleWidth  a shared title column, like Kirigami.FormLayout: give every row of a group the
 *               largest `implicitTitleWidth`, and the controls start at one line. 0 = the title
 *               takes the room and the control sits right (as before)
 *   section     a section label with a rule above the row (the first row of a group)
 *
 *   ── ANZEIGE ───────────────────────────        section
 *   Schwelle ■        [ 62 ] ZURÜCKSETZEN        titleWidth: controls on one line
 *   Ab hier dreht …
 */
Item {
    id: row

    property string title: ""
    property string hint: ""
    property bool modified: false
    property string resetText: "Zurücksetzen"
    property bool narrow: width > 0 && width < KanteStyle.unit(360)
    property real titleWidth: 0
    property string section: ""
    default property alias control: controlSlot.data
    signal resetRequested()

    /** Width the title needs (the wider of title with its mark and hint, capped at 280 units). */
    readonly property real implicitTitleWidth: Math.min(KanteStyle.unit(280),
        Math.max(titleText.implicitWidth + KanteStyle.unit(14), hintMetrics.advanceWidth))
    readonly property real sectionHeight: section !== "" ? sectionHead.implicitHeight + KanteStyle.unit(14) : 0

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: sectionHeight + grid.implicitHeight + KanteStyle.unit(20)

    TextMetrics {
        id: hintMetrics
        font: KanteStyle.smallFont
        text: row.hint
    }

    // Section label: small uppercase mono and a thin rule, as KanteHeading's sections.
    RowLayout {
        id: sectionHead
        visible: row.section !== ""
        y: KanteStyle.unit(6)
        width: parent.width
        spacing: KanteStyle.unit(10)
        Text {
            text: row.section
            color: KanteStyle.mutedTextColor
            font: KanteStyle.labelFont()
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 1
            color: KanteStyle.ruleColor
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: KanteStyle.ruleColor
    }

    GridLayout {
        id: grid
        x: 0
        y: row.sectionHeight + KanteStyle.unit(10)
        width: parent.width
        columns: row.narrow ? 1 : 2
        columnSpacing: KanteStyle.unit(16)
        rowSpacing: KanteStyle.unit(8)

        ColumnLayout {
            id: texts
            Layout.fillWidth: row.narrow || row.titleWidth <= 0
            Layout.preferredWidth: !row.narrow && row.titleWidth > 0 ? row.titleWidth : -1
            Layout.alignment: Qt.AlignTop
            spacing: 2
            Row {
                spacing: KanteStyle.unit(8)
                Text {
                    id: titleText
                    text: row.title
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.defaultFont
                }
                Rectangle {
                    visible: row.modified
                    width: KanteStyle.unit(6)
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: KanteStyle.focusColor
                }
            }
            Text {
                visible: row.hint.length > 0
                Layout.fillWidth: true
                text: row.hint
                color: KanteStyle.mutedTextColor
                font: KanteStyle.smallFont
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            id: controlRow
            // In a shared column the control starts at the column line; otherwise it sits right.
            Layout.fillWidth: !row.narrow && row.titleWidth > 0
            Layout.alignment: Qt.AlignVCenter | (row.narrow || row.titleWidth > 0 ? Qt.AlignLeft : Qt.AlignRight)
            spacing: KanteStyle.unit(8)
            Item {
                id: controlSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
            KanteButton {
                visible: row.modified
                text: row.resetText
                emphasis: KanteButton.Emphasis.Quiet
                size: KanteButton.Size.Small
                onClicked: row.resetRequested()
            }
            Item { visible: !row.narrow && row.titleWidth > 0; Layout.fillWidth: true }
        }
    }
}
