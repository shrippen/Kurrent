import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "."

/**
 * Hint card (Kante 1.25, the QML twin of `.hint-card`): a card with a tier bar, a head line
 * with the tier as sign and word on the left and `meta` on the right, the title, a text and
 * actions. The tier is a sign, a word and a colour, never colour alone: Red a triangle,
 * Yellow (warning) a diamond, Blue a square, Green a check, Primary a square in the accent.
 * `compact` is the one-line row (`.hint-card.is-row`): the bar on the left edge, sign,
 * title and meta in a line, actions on the right (Kaiwa's plasmoid feedback).
 *
 * Kaiwa's severities (decision D-4): blocks understanding Red, wrong Yellow, unnatural
 * Blue, style None.
 *
 *   KanteHintCard { tier: KanteHintCard.Tier.Yellow; tierText: "Falsch"; meta: "Partikel"
 *       title: KanteDiffText { parts: […] }; text: "好き verlangt が."
 *       KanteButton { text: "Anhören"; size: KanteButton.Size.Small } }
 */
Item {
    id: card

    enum Tier {
        None,
        Red,
        Yellow,
        Blue,
        Green,
        Primary
    }

    property int tier: KanteHintCard.Tier.Blue
    property string tierText: ""
    property string meta: ""
    /** Title as text; or put an item into `titleItem` (a KanteDiffText). */
    property string titleText: ""
    property Item titleItem: null
    property string text: ""
    property bool compact: false
    /** Actions (buttons) under the text, or on the right in the compact row. */
    default property alias actions: actionRow.data

    readonly property color tone: {
        switch (tier) {
        case KanteHintCard.Tier.Red: return KanteStyle.negativeTextColor
        case KanteHintCard.Tier.Yellow: return KanteStyle.warningColor
        case KanteHintCard.Tier.Blue: return KanteStyle.infoColor
        case KanteHintCard.Tier.Green: return KanteStyle.positiveTextColor
        case KanteHintCard.Tier.Primary: return KanteStyle.accentColor
        default: return KanteStyle.frameColor
        }
    }
    readonly property color toneText: tier === KanteHintCard.Tier.Primary ? KanteStyle.accentTextColor
        : tier === KanteHintCard.Tier.None ? KanteStyle.mutedTextColor : tone
    readonly property int pad: KanteStyle.unit(compact ? 8 : 12)

    implicitWidth: KanteStyle.unit(compact ? 420 : 320)
    implicitHeight: (compact ? rowLayout.implicitHeight : column.implicitHeight) + 2 * pad + (compact ? 0 : KanteStyle.unit(4))

    Accessible.role: Accessible.Grouping
    Accessible.name: (tierText ? tierText + ": " : "") + (titleItem && titleItem.Accessible.name ? titleItem.Accessible.name : titleText)
    Accessible.description: (meta ? meta + ". " : "") + text

    KanteCard {
        anchors.fill: parent
        chamfer: KanteStyle.active ? KanteStyle.unit(10) : 0
        barColor: card.compact ? "transparent" : card.tone
    }
    Rectangle {
        visible: card.compact
        width: KanteStyle.unit(3)
        height: parent.height
        color: card.tone
    }

    component Sign: Shape {
        id: sign
        width: KanteStyle.unit(10)
        height: width
        visible: card.tier !== KanteHintCard.Tier.None
        antialiasing: true
        readonly property real s: width
        ShapePath {
            strokeWidth: card.tier === KanteHintCard.Tier.Green ? 2 : -1
            strokeColor: card.tier === KanteHintCard.Tier.Green ? card.toneText : "transparent"
            fillColor: card.tier === KanteHintCard.Tier.Green ? "transparent" : card.toneText
            capStyle: ShapePath.FlatCap
            PathSvg {
                path: {
                    var s = sign.s
                    switch (card.tier) {
                    case KanteHintCard.Tier.Red: return "M " + s / 2 + " 0 L " + s + " " + s + " L 0 " + s + " Z"
                    case KanteHintCard.Tier.Yellow: return "M " + s / 2 + " 0 L " + s + " " + s / 2 + " L " + s / 2 + " " + s + " L 0 " + s / 2 + " Z"
                    case KanteHintCard.Tier.Green: return "M " + 0.1 * s + " " + 0.55 * s + " L " + 0.4 * s + " " + 0.85 * s + " L " + 0.95 * s + " " + 0.15 * s
                    default: return "M 0 0 L " + s + " 0 L " + s + " " + s + " L 0 " + s + " Z"
                    }
                }
            }
        }
    }

    // ── Card ──
    ColumnLayout {
        id: column
        visible: !card.compact
        x: card.pad + KanteStyle.unit(2)
        y: card.pad + KanteStyle.unit(4)
        width: card.width - 2 * card.pad - KanteStyle.unit(4)
        spacing: KanteStyle.unit(6)

        RowLayout {
            Layout.fillWidth: true
            spacing: KanteStyle.unit(6)
            Sign {}
            Text {
                visible: card.tierText.length > 0
                text: card.tierText
                color: card.toneText
                font: KanteStyle.labelFont()
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: card.meta.length > 0
                text: card.meta
                color: KanteStyle.mutedTextColor
                font: KanteStyle.labelFont()
            }
        }
        Item {
            id: titleSlot
            Layout.fillWidth: true
            implicitHeight: card.titleItem ? card.titleItem.implicitHeight : titleLabel.implicitHeight
            Text {
                id: titleLabel
                visible: !card.titleItem && card.titleText.length > 0
                width: parent.width
                text: card.titleText
                color: KanteStyle.strongTextColor
                font.family: KanteStyle.defaultFont.family
                font.pointSize: KanteStyle.defaultFont.pointSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
        }
        Text {
            visible: card.text.length > 0
            Layout.fillWidth: true
            text: card.text
            color: KanteStyle.textColor
            font: KanteStyle.defaultFont
            wrapMode: Text.Wrap
        }
        Flow {
            id: actionRow
            Layout.fillWidth: true
            visible: children.length > 0
            spacing: KanteStyle.unit(8)
        }
    }

    // ── Compact row ──
    RowLayout {
        id: rowLayout
        visible: card.compact
        x: card.pad + KanteStyle.unit(3)
        y: card.pad
        width: card.width - 2 * card.pad - KanteStyle.unit(3)
        spacing: KanteStyle.unit(8)
        Sign { Layout.alignment: Qt.AlignVCenter }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: KanteStyle.unit(2)
            Item {
                id: rowTitleSlot
                Layout.fillWidth: true
                implicitHeight: card.titleItem ? card.titleItem.implicitHeight : rowTitle.implicitHeight
                Text {
                    id: rowTitle
                    visible: !card.titleItem
                    width: parent.width
                    text: card.titleText
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.defaultFont
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: card.meta.length > 0 || card.tierText.length > 0
                text: [card.meta, card.tierText].filter(s => s.length > 0).join(" · ")
                color: KanteStyle.mutedTextColor
                font: KanteStyle.labelFont()
            }
        }
        Item {
            id: rowActions
            implicitWidth: actionRow.implicitWidth
            implicitHeight: actionRow.implicitHeight
        }
    }

    // The title item and the actions move to the slot of the current layout.
    Binding { target: card.titleItem; property: "parent"; value: card.compact ? rowTitleSlot : titleSlot; when: card.titleItem !== null }
    Binding { target: card.titleItem; property: "width"; value: card.compact ? rowTitleSlot.width : titleSlot.width; when: card.titleItem !== null }
    Binding { target: actionRow; property: "parent"; value: card.compact ? rowActions : column; when: card.compact }
}
