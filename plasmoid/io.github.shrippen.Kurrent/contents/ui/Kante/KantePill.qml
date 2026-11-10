import QtQuick
import QtQuick.Shapes
import "."

/**
 * Status pill: mono uppercase label with a square marker in the state's color;
 * the state is form + color + word, never color alone.
 *   Running  breathing square (info color)   Review  hollow square (accent)
 *   Locked   triangle (warning)              Done    tick (positive)
 *   Failed   cross (negative)                Off     hollow square (muted)
 */
Item {
    id: pill

    enum State {
        Running,
        Review,
        Locked,
        Done,
        Failed,
        Off
    }

    property int status: KantePill.State.Off
    property string text: ""

    readonly property color tone: {
        switch (status) {
        case KantePill.State.Running: return KanteStyle.infoColor
        case KantePill.State.Review: return KanteStyle.accentTextColor
        case KantePill.State.Locked: return KanteStyle.warningColor
        case KantePill.State.Done: return KanteStyle.positiveTextColor
        case KantePill.State.Failed: return KanteStyle.negativeTextColor
        default: return KanteStyle.mutedTextColor
        }
    }

    implicitHeight: KanteStyle.unit(24)
    implicitWidth: row.implicitWidth + KanteStyle.unit(20)

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: pill.tone
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: KanteStyle.unit(7)

        Item {
            width: KanteStyle.unit(8)
            height: width
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                visible: pill.status === KantePill.State.Running || pill.status === KantePill.State.Review || pill.status === KantePill.State.Off
                color: pill.status === KantePill.State.Running ? pill.tone : "transparent"
                border.width: pill.status === KantePill.State.Running ? 0 : 2
                border.color: pill.tone
                SequentialAnimation on opacity {
                    running: pill.status === KantePill.State.Running && KanteStyle.animate && pill.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.3; to: 1; duration: 800; easing.type: Easing.InOutSine }
                }
            }
            Shape {
                id: triangle
                anchors.fill: parent
                visible: pill.status === KantePill.State.Locked
                ShapePath {
                    fillColor: pill.tone
                    strokeWidth: -1
                    startX: triangle.width / 2; startY: 0
                    PathLine { x: triangle.width; y: triangle.height }
                    PathLine { x: 0; y: triangle.height }
                    PathLine { x: triangle.width / 2; y: 0 }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: pill.status === KantePill.State.Done || pill.status === KantePill.State.Failed
                text: pill.status === KantePill.State.Done ? "✓" : "✕"
                color: pill.tone
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.text
            color: pill.tone
            font: KanteStyle.labelFont()
        }
    }
}
