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
 * For video (1.59, from Mitori):
 *   metronomeVisible, countInVisible   false hides the toggle (and its key)
 *   speedSteps  fixed tempi, e.g. [0.25, 0.5, 0.75, 1]: a segmented row in place of the
 *               spin box; + and − move to the next step (speedLabel(step) gives the words)
 *   frameStep   true adds single-frame buttons back and on (keys , and .);
 *               frameStepRequested(-1 | 1) asks for one frame
 *
 * Keyboard: Tab moves between the controls, Space or Enter presses the focused one.
 * Anywhere in the bar: K play/pause, L loop, M metronome, C count-in, Home rewind,
 * + / − speed by 5 % (or to the next of `speedSteps`), , and . a single frame (with `frameStep`).
 * Right to left the bar keeps its order (1.59): it runs along time, like the timeline. Every control has an accessible name; toggles are check boxes for
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
    property bool metronomeVisible: true
    property bool countInVisible: true
    property var speedSteps: []
    property bool frameStep: false
    property string frameBackText: "Bild zurück"
    property string frameOnText: "Bild vor"
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
    signal frameStepRequested(int direction)

    readonly property int speedPercent: Math.round(speed * 100)

    function time(s) {
        var t = Math.max(0, Math.floor(s))
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0")
    }
    /** The words of a fixed tempo: "25 %" for 0.25. */
    function speedLabel(step) {
        return Math.round(step * 100) + " %"
    }
    function stepSpeed(dir) {
        if (speedSteps.length > 0) {
            // The next step above (+) or below (−) the tempo, also from a tempo between steps.
            var next = speedSteps.filter(function (s) { return dir > 0 ? s > speed : s < speed })
            if (next.length > 0) {
                speedChangeRequested(dir > 0 ? Math.min.apply(null, next) : Math.max.apply(null, next))
            }
            return
        }
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
        case Qt.Key_M: if (!metronomeVisible) return; metronomeToggled(); break
        case Qt.Key_C: if (!countInVisible) return; countInToggled(); break
        case Qt.Key_Comma: if (!frameStep) return; frameStepRequested(-1); break
        case Qt.Key_Period: if (!frameStep) return; frameStepRequested(1); break
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

    // A single-frame button, drawn (no icon theme needed): ▷| on, mirrored |◁ back.
    component FrameButton: KanteToolButton {
        id: frameButton
        property int direction: 1
        property string label: ""
        readonly property real glyphSize: KanteStyle.unit(14)
        visible: bar.frameStep
        height: KanteStyle.heightMedium
        implicitWidth: KanteStyle.heightMedium
        text: ""
        display: QQC2.AbstractButton.TextOnly
        focusPolicy: Qt.StrongFocus
        Accessible.name: label
        QQC2.ToolTip.text: label
        QQC2.ToolTip.visible: hovered
        onClicked: bar.frameStepRequested(direction)
        Shape {
            anchors.centerIn: parent
            width: frameButton.glyphSize
            height: width
            antialiasing: true
            transform: Scale { origin.x: frameButton.glyphSize / 2; xScale: frameButton.direction }
            // A hollow triangle and a bar: unlike the solid |◀ of rewind.
            ShapePath {
                strokeColor: KanteStyle.themed ? frameButton.kanteInk : KanteStyle.textColor
                strokeWidth: KanteStyle.unit(1.5)
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                PathSvg {
                    readonly property real s: frameButton.glyphSize
                    path: "M 1 1 L " + (s * 0.6) + " " + s / 2 + " L 1 " + (s - 1) + " Z"
                }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: KanteStyle.themed ? frameButton.kanteInk : KanteStyle.textColor
                PathSvg {
                    readonly property real s: frameButton.glyphSize
                    path: "M " + s * 0.78 + " 0 H " + s + " V " + s + " H " + s * 0.78 + " Z"
                }
            }
        }
    }

    Flow {
        id: flow
        // Transport controls follow time, not the reading direction (rewind left, frame on right).
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true
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
        FrameButton {
            direction: -1
            label: bar.frameBackText
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
        FrameButton {
            direction: 1
            label: bar.frameOnText
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
            KanteSegmented {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.speedSteps.length > 0
                model: bar.speedSteps.map(function (s) { return bar.speedLabel(s) })
                currentIndex: bar.speedSteps.indexOf(bar.speed)
                // A click sets currentIndex and breaks the binding: bind again, so the row keeps
                // showing the app's tempo (it may refuse the request or change it later).
                onActivated: function (index) {
                    currentIndex = Qt.binding(function () { return bar.speedSteps.indexOf(bar.speed) })
                    bar.speedChangeRequested(bar.speedSteps[index])
                }
                Accessible.name: bar.speedText
            }
            QQC2.SpinBox {
                id: speedBox
                visible: bar.speedSteps.length === 0
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
            visible: bar.metronomeVisible
            height: KanteStyle.heightMedium
            text: bar.metronomeText
            on: bar.metronome
            onRequested: bar.metronomeToggled()
        }
        Toggle {
            id: countInButton
            visible: bar.countInVisible
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
