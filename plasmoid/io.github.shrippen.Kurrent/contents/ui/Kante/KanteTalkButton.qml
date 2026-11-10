import QtQuick
import QtQuick.Shapes
import "."

/**
 * The talk button of a spoken conversation (Kante 1.25, for Kaiwa; web: `.talk`). One big
 * control with five states, each with its own word and a mark of its own shape, so it
 * never hangs on colour (decision D-3: height `heightLarge`, wider than a button):
 *
 *   Ready      square        press (Hold) or click (Toggle) to talk       → talkStarted()
 *   Listening  accent fill, live level as six segments                    → talkEnded()
 *   Thinking   diamond, running light along the outline (no action)
 *   Speaking   breathing lamp; a click interrupts                         → interruptRequested()
 *   Error      triangle, a 4 px negative bar, the remedy as second line   → errorActionRequested()
 *
 * The app owns the state: the button only says what the person did. Space works like the
 * mouse (held in Hold mode). It draws itself (no platform control), so it works the same
 * in apps and Plasma widgets.
 *
 *   KanteTalkButton { talkState: session.state; level: mic.level; onTalkStarted: mic.start() }
 */
Item {
    id: talk

    enum State {
        Ready,
        Listening,
        Thinking,
        Speaking,
        Error
    }
    enum Mode {
        Hold,
        Toggle
    }

    property int talkState: KanteTalkButton.State.Ready
    property int mode: KanteTalkButton.Mode.Hold
    /** Input level 0..1 while listening. */
    property real level: 0
    property int segments: 6
    /** Words per state (an app sets its translations). */
    property var titles: ["Sprechen", "Hört zu", "Denkt nach", "Spricht", "Kein Mikrofon"]
    property var hints: ["Leertaste halten", "Loslassen zum Senden", "", "Tippen zum Unterbrechen", "Einstellungen öffnen"]
    /** Overrides the second line of the current state (e.g. "1,2 s" while thinking). */
    property string hint: ""

    signal talkStarted()
    signal talkEnded()
    signal interruptRequested()
    signal errorActionRequested()

    readonly property bool listening: talkState === KanteTalkButton.State.Listening
    readonly property string title: titles[talkState] || ""
    readonly property string hintText: hint.length > 0 ? hint : (talkState === KanteTalkButton.State.Ready && mode === KanteTalkButton.Mode.Toggle ? "Leertaste" : (hints[talkState] || ""))
    readonly property real cut: KanteStyle.active ? KanteStyle.unit(10) : 0
    readonly property color fill: listening ? KanteStyle.accentColor : KanteStyle.cardColor
    readonly property color ink: listening ? KanteStyle.accentForegroundColor : KanteStyle.strongTextColor
    readonly property color markColor: {
        switch (talkState) {
        case KanteTalkButton.State.Listening: return KanteStyle.accentForegroundColor
        case KanteTalkButton.State.Thinking: return KanteStyle.infoColor
        case KanteTalkButton.State.Speaking: return KanteStyle.positiveTextColor
        case KanteTalkButton.State.Error: return KanteStyle.negativeTextColor
        default: return KanteStyle.mutedTextColor
        }
    }

    implicitWidth: Math.max(KanteStyle.unit(240), row.implicitWidth + KanteStyle.unit(40))
    implicitHeight: Math.max(KanteStyle.heightLarge, row.implicitHeight + KanteStyle.unit(12))

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: hintText
    Accessible.onPressAction: talk.click()

    function press() {
        if (talkState === KanteTalkButton.State.Ready) {
            talkStarted()
        } else if (talkState === KanteTalkButton.State.Listening && mode === KanteTalkButton.Mode.Toggle) {
            talkEnded()
        } else if (talkState === KanteTalkButton.State.Speaking) {
            interruptRequested()
        } else if (talkState === KanteTalkButton.State.Error) {
            errorActionRequested()
        }
    }
    function release() {
        if (talkState === KanteTalkButton.State.Listening && mode === KanteTalkButton.Mode.Hold) talkEnded()
    }
    /** One activation without holding (Enter, a screen reader's press): toggles in both modes. */
    function click() {
        if (talkState === KanteTalkButton.State.Listening) talkEnded()
        else press()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) { talk.press(); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { talk.click(); event.accepted = true }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) { talk.release(); event.accepted = true }
    }

    KantePolygon {
        anchors.fill: parent
        fillColor: talk.fill
        strokeColor: talk.listening ? "transparent" : KanteStyle.frameColor
        strokeWidth: talk.listening ? 0 : 1
        cutTopRight: talk.cut
        cutBottomLeft: talk.cut
        visible: KanteStyle.active
    }
    Rectangle {
        // System: a plain rounded surface in platform colours.
        anchors.fill: parent
        visible: !KanteStyle.active
        radius: KanteStyle.unit(4)
        color: talk.fill
        border.color: talk.listening ? "transparent" : KanteStyle.frameColor
    }
    Rectangle {
        visible: talk.talkState === KanteTalkButton.State.Error
        anchors.bottom: parent.bottom
        x: talk.cut
        width: parent.width - talk.cut
        height: KanteStyle.unit(4)
        color: KanteStyle.negativeTextColor
    }
    KanteRunner {
        anchors.fill: parent
        visible: talk.talkState === KanteTalkButton.State.Thinking
        running: visible
        color: KanteStyle.infoColor
        cut: talk.cut
    }
    KantePolygon {
        // Focus: cyan, 2 px, inside and along the cut shape.
        visible: talk.activeFocus
        anchors.fill: parent
        anchors.margins: KanteStyle.unit(3)
        strokeColor: KanteStyle.focusColor
        strokeWidth: 2
        cutTopRight: Math.max(0, talk.cut - KanteStyle.unit(1))
        cutBottomLeft: cutTopRight
    }

    Row {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: KanteStyle.unit(18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: KanteStyle.unit(12)

        Item {
            id: markBox
            width: KanteStyle.unit(14)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            // Ready / Listening: square. Speaking: a breathing lamp (square).
            KanteLamp {
                anchors.fill: parent
                visible: talk.talkState <= KanteTalkButton.State.Listening || talk.talkState === KanteTalkButton.State.Speaking
                color: talk.markColor
                rhythm: talk.talkState === KanteTalkButton.State.Speaking ? KanteLamp.Rhythm.Breathe : KanteLamp.Rhythm.Steady
            }
            Shape {
                anchors.fill: parent
                visible: talk.talkState === KanteTalkButton.State.Thinking || talk.talkState === KanteTalkButton.State.Error
                antialiasing: true
                ShapePath {
                    strokeWidth: -1
                    fillColor: talk.markColor
                    PathSvg {
                        path: {
                            var s = markBox.width
                            return talk.talkState === KanteTalkButton.State.Thinking
                                ? "M " + s / 2 + " 0 L " + s + " " + s / 2 + " L " + s / 2 + " " + s + " L 0 " + s / 2 + " Z"
                                : "M " + s / 2 + " 0 L " + s + " " + s + " L 0 " + s + " Z"
                        }
                    }
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: talk.title
                color: talk.ink
                font: KanteStyle.titleFont(KanteStyle.defaultFont.pointSize * 1.1)
            }
            Text {
                visible: text.length > 0
                text: talk.hintText
                color: talk.ink
                opacity: 0.8
                font: KanteStyle.labelFont()
            }
        }
        Row {
            id: meter
            visible: talk.listening
            anchors.verticalCenter: parent.verticalCenter
            spacing: KanteStyle.unit(3)
            Repeater {
                model: talk.segments
                delegate: Rectangle {
                    required property int index
                    width: KanteStyle.unit(10)
                    height: KanteStyle.unit(14)
                    color: talk.level * talk.segments > index ? talk.ink : KanteStyle.tint(talk.ink, 0.22)
                }
            }
        }
    }

    TapHandler {
        onPressedChanged: {
            if (pressed) {
                talk.forceActiveFocus(Qt.MouseFocusReason)
                talk.press()
            } else {
                talk.release()
            }
        }
    }
    HoverHandler { cursorShape: talk.talkState === KanteTalkButton.State.Thinking ? Qt.ArrowCursor : Qt.PointingHandCursor }
}
