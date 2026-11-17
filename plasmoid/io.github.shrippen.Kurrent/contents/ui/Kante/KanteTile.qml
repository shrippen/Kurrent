import QtQuick
import QtQuick.Layouts
import "."

/**
 * Image tile: 3:2 stage (`stageAspect` sets another ratio), a 4 px tier bar (green / orange / red, never colour
 * alone: name and figure sit below), selection as a cyan frame and tick, keyboard
 * focus as four cyan brackets that lock on. Put the image in the stage
 * (`content`), or set `source` (an image url, scaled to fill the stage, cropped); `figure` is
 * the number on the right (98 %). Without an image (no `source` yet, still loading or failed) the
 * stage shows a neutral placeholder, a framed sunken field with a picture sign. Name and figure
 * are optional: with both empty the caption row is left out and the tile is as high as its stage.
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
    /** Image shown in the stage; "" for none. */
    property url source: ""
    /** Size `source` is decoded at (Image.sourceSize), e.g. Qt.size(360, 240) for a big photo; unset: full size. */
    property size sourceSize
    /** The stage shows the placeholder while `source` is not an image on screen. */
    property bool placeholder: true
    /** Width over height of the stage (Kante 1.81): 1.5 is 3:2 (default), 2.39 a wide film frame. */
    property real stageAspect: 1.5
    readonly property bool captioned: name !== "" || figure !== ""
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
        : (tier === KanteTile.Tier.Check ? KanteStyle.warningColor : KanteStyle.positiveTextColor)

    implicitWidth: KanteStyle.unit(180)
    implicitHeight: implicitWidth / stageAspect + (captioned ? KanteStyle.unit(34) : KanteStyle.unit(8))
    activeFocusOnTab: true

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
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
        height: width / tile.stageAspect
        clip: true
        opacity: tile.stale ? 0.55 : 1

        // Placeholder: sunken field, a frame and a picture sign (a hill under a sun), no text.
        Rectangle {
            objectName: "kantePlaceholder"
            anchors.fill: parent
            visible: tile.placeholder && !image.shown
            color: KanteStyle.sunkenColor
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.36
                height: width * 0.75
                color: "transparent"
                border.width: 2
                border.color: KanteStyle.frameColor
                Rectangle {
                    x: parent.width * 0.18
                    y: parent.height * 0.18
                    width: parent.width * 0.2
                    height: width
                    color: KanteStyle.frameColor
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 2
                    width: parent.width * 0.5
                    height: parent.height * 0.3
                    color: KanteStyle.frameColor
                }
            }
        }
        Image {
            id: image
            objectName: "kanteTileImage"
            readonly property bool shown: status === Image.Ready
            anchors.fill: parent
            source: tile.source
            sourceSize: tile.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: shown
        }
    }

    RowLayout {
        visible: tile.captioned
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
