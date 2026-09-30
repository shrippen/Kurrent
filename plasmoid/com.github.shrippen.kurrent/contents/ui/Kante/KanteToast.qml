import QtQuick
import QtQuick.Layouts
import "."

/**
 * Toast: slides in from the right with the cut corner first, a 2 px line at the
 * bottom shows how long it stays. Call `show()`; it hides itself after `life`
 * ms (0: stays) and emits `closed`.
 */
Item {
    id: toast

    enum Kind {
        Info,
        Ok,
        Warn,
        Danger
    }

    property int kind: KanteToast.Kind.Info
    property string title: ""
    property string text: ""
    property int life: 4000
    property bool shown: false
    signal closed()

    readonly property color tone: {
        switch (kind) {
        case KanteToast.Kind.Ok: return KanteStyle.positiveTextColor
        case KanteToast.Kind.Warn: return KanteStyle.warningColor
        case KanteToast.Kind.Danger: return KanteStyle.negativeTextColor
        default: return KanteStyle.infoColor
        }
    }

    function show() {
        shown = true
        lifeLine.restart()
        if (life > 0) {
            timer.restart()
        }
    }
    function hide() {
        timer.stop()
        shown = false
        closed()
    }

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: content.implicitHeight + KanteStyle.unit(24)
    visible: shown || slide.running
    clip: true

    transform: Translate {
        id: shift
        x: toast.shown ? 0 : toast.width * 1.1
        Behavior on x { NumberAnimation { id: slide; duration: KanteStyle.animate ? 360 : 0; easing.type: Easing.OutCubic } }
    }

    Timer { id: timer; interval: toast.life; onTriggered: toast.hide() }

    KanteCard {
        anchors.fill: parent
        color: KanteStyle.dialogColor
        barColor: toast.tone
        chamfer: KanteStyle.unit(12)
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: KanteStyle.unit(12)
        anchors.topMargin: KanteStyle.unit(14)
        spacing: KanteStyle.unit(10)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                visible: toast.title.length > 0
                Layout.fillWidth: true
                text: toast.title
                color: KanteStyle.strongTextColor
                font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize)
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: toast.text
                color: KanteStyle.textColor
                font: KanteStyle.defaultFont
                wrapMode: Text.WordWrap
            }
        }
    }

    // Remaining time.
    Rectangle {
        anchors.bottom: parent.bottom
        height: 2
        color: toast.tone
        width: parent.width
        visible: toast.life > 0 && KanteStyle.animate
        transformOrigin: Item.Left
        NumberAnimation on scale {
            id: lifeLine
            from: 1
            to: 0
            duration: toast.life
            running: false
        }
    }
}
