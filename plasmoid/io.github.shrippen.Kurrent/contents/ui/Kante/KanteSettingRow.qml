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
    property string resetText: qsTr("Reset")
    property bool narrow: width > 0 && width < KanteStyle.unit(360)
    property real titleWidth: 0
    property string section: ""
    default property alias control: controlSlot.data
    signal resetRequested()

    /** Width the title needs (the wider of title with its mark and hint, capped at 280 units). */
    readonly property real implicitTitleWidth: Math.min(KanteStyle.unit(280),
        Math.max(titleText.implicitWidth + KanteStyle.unit(14), hintMetrics.advanceWidth))
    readonly property real sectionHeight: section !== "" ? sectionHead.implicitHeight + KanteStyle.unit(14) : 0

    /** A KanteSettingGroup counts the rows (and any item with this property true) it holds. */
    readonly property bool isSetting: true

    // Tells the group around it that a row came, went or was hidden.
    function tellGroup() {
        for (let p = row.parent; p; p = p.parent) {
            if (p.settingGroup === true) {
                p.recount()
                return
            }
        }
    }
    onVisibleChanged: tellGroup()
    Component.onCompleted: tellGroup()
    Component.onDestruction: tellGroup()

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
            Layout.preferredHeight: 1
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
            // A long title wraps inside the column instead of pushing the control out of the row.
            RowLayout {
                id: titleLine
                Layout.fillWidth: true
                spacing: KanteStyle.unit(8)
                Text {
                    id: titleText
                    objectName: "settingTitle"
                    // As wide as its text, narrower where the column is (it wraps there): the mark
                    // follows the text. Not bound to the column's width, which the layout itself
                    // sets: that loop left the title at width 0 (Kante 1.80). Rounded up: the
                    // layout floors a fractional implicitWidth to whole device pixels, which cut
                    // a short title (round 22, a real font under X11, not the test font) a
                    // fraction of a pixel short of its own natural width and wrapped it.
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.ceil(implicitWidth)
                    text: row.title
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.defaultFont
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    objectName: "settingMark"
                    visible: row.modified
                    Layout.preferredWidth: KanteStyle.unit(6)
                    Layout.preferredHeight: KanteStyle.unit(6)
                    Layout.alignment: Qt.AlignVCenter
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
