import QtQuick
import QtQuick.Layouts
import "."

/**
 * Image tile: 3:2 stage, a 4 px tier bar (green / yellow / red, never colour
 * alone: name and figure sit below), selection as a cyan frame and tick, keyboard
 * focus as four cyan brackets that lock on. Put the image in the stage
 * (`content`); `figure` is the number on the right (98 %).
 * Live data: `fresh()` runs a cyan line along the bottom edge, `stale` dims the tile and
 * puts warning stripes there (`staleText`: the age). Edit mode: `editing` turns the
 * bar cyan and locks the brackets on, one tile after the other (`editIndex`).
 * Drag and drop: `picked` is the lifted tile (cyan frame, tint, square handle).
 */
FocusScope {
    id: tile

    enum Tier {
        Good,
        Check,
        Bad
    }

    property int tier: KanteTile.Tier.Good
    property string name: ""
    property string figure: ""
    property bool selected: false
    property bool stale: false
    property string staleText: ""
    property bool editing: false
    property int editIndex: 0
    property bool picked: false
    function fresh() { liveLine.fresh() }
    property bool _editShown: false
    default property alias content: stage.data
    signal clicked()

    onEditingChanged: {
        if (editing && KanteStyle.animate) {
            editTimer.restart()
        } else {
            editTimer.stop()
            _editShown = editing
        }
    }
    Timer { id: editTimer; interval: tile.editIndex * 70; onTriggered: tile._editShown = true }

    readonly property color tone: tier === KanteTile.Tier.Bad ? KanteStyle.negativeTextColor
        : (tier === KanteTile.Tier.Check ? KanteStyle.accentTextColor : KanteStyle.positiveTextColor)

    implicitWidth: KanteStyle.unit(180)
    implicitHeight: implicitWidth * 2 / 3 + KanteStyle.unit(34)
    activeFocusOnTab: true

    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    KanteCard {
        anchors.fill: parent
        color: KanteStyle.cardColor
        barColor: tile._editShown ? KanteStyle.focusColor : tile.tone
        chamfer: KanteStyle.chamferSmall
    }

    Item {
        id: stage
        x: 0
        y: KanteStyle.unit(4)
        width: parent.width
        height: width * 2 / 3
        clip: true
        opacity: tile.stale ? 0.55 : 1
    }

    RowLayout {
        opacity: tile.stale ? 0.55 : 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: KanteStyle.unit(8)
        spacing: KanteStyle.unit(8)
        Text {
            Layout.fillWidth: true
            text: tile.name
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
            elide: Text.ElideRight
        }
        Text {
            text: tile.figure
            color: tile.tone
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
        }
    }

    // Selected: cyan frame and a tick in a cyan square.
    Rectangle {
        anchors.fill: parent
        visible: tile.selected
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.focusColor
    }
    Rectangle {
        visible: tile.selected
        x: KanteStyle.unit(6)
        y: KanteStyle.unit(10)
        width: KanteStyle.unit(18)
        height: width
        color: KanteStyle.focusColor
        KanteTick {
            anchors.fill: parent
            anchors.margins: 3
            checked: tile.selected
            color: KanteStyle.onStateColor
        }
    }

    // Picked (dragged): cyan frame, tint and a square handle bottom-right.
    Rectangle {
        anchors.fill: parent
        visible: tile.picked
        color: KanteStyle.tint(KanteStyle.focusColor, 0.14)
        border.width: 2
        border.color: KanteStyle.focusColor
        Rectangle {
            width: KanteStyle.unit(10)
            height: width
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 2
            color: KanteStyle.focusColor
        }
    }

    KanteBrackets {
        anchors.fill: parent
        active: tile.activeFocus || tile._editShown
    }

    KanteLiveLine {
        id: liveLine
        stale: tile.stale
        staleText: tile.staleText
        ageLift: KanteStyle.unit(28)
    }

    HoverHandler { id: hover }
    Rectangle {
        anchors.fill: parent
        visible: hover.hovered && !tile.selected
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.frameColor
    }
    TapHandler { onTapped: { tile.forceActiveFocus(); tile.clicked() } }
}
