import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import "."

/**
 * Transport for a player (Kante 1.23, for Kontra): back to the start, play/pause, loop,
 * speed (25..150 % in steps of 5), metronome, count-in and the position. Presentational:
 * the state comes in through the properties, every action goes out as a signal and the
 * buttons show the state again only when the app has changed it.
 *
 *   playing, looping, metronome, countIn   state of the player
 *   speed       1.0 = 100 %; speedChangeRequested(real) asks for a new one (0.25..1.5)
 *   position, duration   seconds, shown as m:ss / m:ss (or `positionText`)
 *
 * Keyboard: Tab moves between the controls, Space or Enter presses the focused one.
 * Anywhere in the bar: K play/pause, L loop, M metronome, C count-in, Home rewind,
 * + / − speed by 5 %. Every control has an accessible name; toggles are check boxes for
 * screen readers and show their state by the lamp before the word alone (1.38). The controls wrap onto a second line when
 * the bar is narrow (large fonts, 200 %).
 */
FocusScope {
    id: bar

    property bool playing: false
    property bool looping: false
    property bool metronome: false
    property bool countIn: false
    property real speed: 1.0
    property real minSpeed: 0.25
    property real maxSpeed: 1.5
    property real position: 0
    property real duration: 0
    property string positionText: time(position) + " / " + time(duration)

    property string rewindText: "Zum Anfang"
    property string playText: "Abspielen"
    property string pauseText: "Pause"
    property string loopText: "Schleife"
    property string speedText: "Tempo"
    property string metronomeText: "Metronom"
    property string countInText: "Einzähler"
    property string positionName: "Position"
    property string accessibleName: "Wiedergabe"

    signal playToggled()
    signal loopToggled()
    signal speedChangeRequested(real speed)
    signal metronomeToggled()
    signal countInToggled()
    signal rewind()

    readonly property int speedPercent: Math.round(speed * 100)

    function time(s) {
        var t = Math.max(0, Math.floor(s))
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0")
    }
    function stepSpeed(dir) {
        var p = Math.max(Math.round(minSpeed * 100), Math.min(Math.round(maxSpeed * 100), Math.round(speedPercent / 5) * 5 + dir * 5))
        if (p !== speedPercent) {
            speedChangeRequested(p / 100)
        }
    }

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight
    activeFocusOnTab: false

    Accessible.role: Accessible.ToolBar
    Accessible.name: accessibleName

    Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_K: playToggled(); break
        case Qt.Key_L: loopToggled(); break
        case Qt.Key_M: metronomeToggled(); break
        case Qt.Key_C: countInToggled(); break
        case Qt.Key_Home: rewind(); break
        case Qt.Key_Plus:
        case Qt.Key_Equal: stepSpeed(1); break
        case Qt.Key_Minus: stepSpeed(-1); break
        default: return
        }
        event.accepted = true
    }

    // A toggle: a square lamp before the word, filled when on (the state is not colour
    // alone, and needs no icon theme). Only the lamp shows the state (1.38): a filled accent
    // button for metronome and count-in competed with the play button.
    component Toggle: KanteToolButton {
        id: toggle
        property bool on: false
        signal requested()
        readonly property real lamp: KanteStyle.unit(10)
        display: QQC2.AbstractButton.TextOnly
        focusPolicy: Qt.StrongFocus
        leftPadding: KanteStyle.unit(10) + lamp + KanteStyle.unit(6)
        rightPadding: KanteStyle.unit(10)
        implicitWidth: Math.ceil(leftPadding + words.advanceWidth + rightPadding + KanteStyle.unit(2))
        TextMetrics { id: words; font: toggle.font; text: toggle.text }
        // Checkable and checked as the app says, so Qt reports the state to screen readers
        // (it sets Accessible.checked from `checked` when a screen reader starts); not filled,
        // the lamp shows it.
        checkable: true
        checked: on
        fillChecked: false
        // The app owns the state: give the click to the app and show its answer.
        onToggled: {
            checked = Qt.binding(function () { return toggle.on })
            requested()
        }
        Accessible.role: Accessible.CheckBox
        Accessible.checkable: true
        Accessible.checked: on
        Accessible.name: text
        Rectangle {
            x: KanteStyle.unit(10)
            anchors.verticalCenter: parent.verticalCenter
            width: toggle.lamp
            height: width
            readonly property color ink: KanteStyle.themed ? toggle.kanteInk : KanteStyle.textColor
            color: toggle.on ? ink : "transparent"
            border.width: Math.max(1.5, KanteStyle.unit(2))
            border.color: ink
        }
    }

    Flow {
        id: flow
        width: bar.width > 0 ? bar.width : implicitWidth
        spacing: KanteStyle.unit(8)

        KanteToolButton {
            id: rewindButton
            height: KanteStyle.heightMedium
            implicitWidth: KanteStyle.heightMedium
            text: ""
            display: QQC2.AbstractButton.TextOnly
            focusPolicy: Qt.StrongFocus
            Accessible.name: bar.rewindText
            QQC2.ToolTip.text: bar.rewindText
            QQC2.ToolTip.visible: hovered
            onClicked: bar.rewind()
            // |◀ drawn, so it needs no icon theme.
            Shape {
                anchors.centerIn: parent
                width: KanteStyle.unit(14)
                height: width
                antialiasing: true
                ShapePath {
                    readonly property color ink: KanteStyle.themed ? rewindButton.kanteInk : KanteStyle.textColor
                    strokeColor: "transparent"
                    fillColor: ink
                    PathSvg {
                        readonly property real s: KanteStyle.unit(14)
                        path: "M 0 0 H " + s * 0.18 + " V " + s + " H 0 Z M " + s + " 0 V " + s + " L " + s * 0.25 + " " + s / 2 + " Z"
                    }
                }
            }
        }
        KanteButton {
            id: playButton
            focus: true
            height: KanteStyle.heightMedium
            emphasis: KanteButton.Emphasis.Primary
            icon.name: bar.playing ? "media-playback-pause" : "media-playback-start"
            text: bar.playing ? bar.pauseText : bar.playText
            focusPolicy: Qt.StrongFocus
            Accessible.name: text
            onClicked: bar.playToggled()
        }
        Toggle {
            id: loopButton
            height: KanteStyle.heightMedium
            text: bar.loopText
            on: bar.looping
            onRequested: bar.loopToggled()
        }
        Row {
            spacing: KanteStyle.unit(6)
            height: KanteStyle.heightMedium
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.speedText
                color: KanteStyle.mutedTextColor
                font: KanteStyle.labelFont()
            }
            QQC2.SpinBox {
                id: speedBox
                anchors.verticalCenter: parent.verticalCenter
                from: Math.round(bar.minSpeed * 100)
                to: Math.round(bar.maxSpeed * 100)
                stepSize: 5
                value: bar.speedPercent
                editable: false
                focusPolicy: Qt.StrongFocus
                textFromValue: function (v) { return v + " %" }
                valueFromText: function (t) { return parseInt(t) }
                font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, false)
                onValueModified: {
                    var v = value
                    value = Qt.binding(function () { return bar.speedPercent })
                    bar.speedChangeRequested(v / 100)
                }
                Accessible.name: bar.speedText
                KanteFieldSkin { control: parent }
            }
        }
        Toggle {
            id: metronomeButton
            height: KanteStyle.heightMedium
            text: bar.metronomeText
            on: bar.metronome
            onRequested: bar.metronomeToggled()
        }
        Toggle {
            id: countInButton
            height: KanteStyle.heightMedium
            text: bar.countInText
            on: bar.countIn
            onRequested: bar.countInToggled()
        }
        Text {
            height: KanteStyle.heightMedium
            verticalAlignment: Text.AlignVCenter
            text: bar.positionText
            color: KanteStyle.textColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 1.1, true)
            Accessible.role: Accessible.StaticText
            Accessible.name: bar.positionName + " " + text
        }
    }
}
