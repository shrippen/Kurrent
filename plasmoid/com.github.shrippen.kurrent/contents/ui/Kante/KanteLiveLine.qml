import QtQuick
import "."

/**
 * The line of live data on the bottom edge of a tile or card. `fresh()` runs a
 * 2 px cyan line along it once (new data arrived); `stale` shows warning stripes
 * and the age (`staleText`, "since 12 min") instead. Place it with anchors on the
 * bottom of the surface; dim the tile's content with `stale` (0.55).
 */
Item {
    id: line

    property bool stale: false
    property string staleText: ""
    /** Distance of the age label above the line; a tile lifts it over its caption row. */
    property real ageLift: KanteStyle.unit(4)
    /** Opacity for the content of a stale tile. */
    readonly property real dim: stale ? 0.55 : 1

    function fresh() {
        if (!KanteStyle.animate || stale) {
            return
        }
        run.restart()
    }

    height: stale ? KanteStyle.unit(4) : KanteStyle.unit(2)
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    visible: KanteStyle.active

    // Fresh: a cyan line that draws from left to right and fades.
    Rectangle {
        id: bar
        height: KanteStyle.unit(2)
        anchors.bottom: parent.bottom
        width: 0
        color: KanteStyle.focusColor
        opacity: 0
        visible: !line.stale
    }
    SequentialAnimation {
        id: run
        ScriptAction { script: { bar.width = 0; bar.opacity = 1 } }
        NumberAnimation { target: bar; property: "width"; from: 0; to: line.width; duration: 630; easing.type: Easing.OutCubic }
        NumberAnimation { target: bar; property: "opacity"; to: 0; duration: 270 }
    }

    // Stale: still warning stripes with the age above them.
    KanteHazard {
        anchors.fill: parent
        visible: line.stale
        color: KanteStyle.warningColor
        stripe: KanteStyle.unit(6)
        running: false
    }
    Rectangle {
        visible: line.stale && line.staleText.length > 0
        anchors.right: parent.right
        anchors.rightMargin: KanteStyle.unit(10)
        anchors.bottom: parent.top
        anchors.bottomMargin: line.ageLift
        width: age.implicitWidth + KanteStyle.unit(8)
        height: age.implicitHeight
        color: KanteStyle.dialogColor
        Text {
            id: age
            anchors.centerIn: parent
            text: line.staleText
            color: KanteStyle.warningColor
            font: KanteStyle.labelFont()
        }
    }
}
