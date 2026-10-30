import QtQuick
import "."

/**
 * Piano keyboard (Kante 1.30, for Kontra's bass over MIDI): the keys of a range with
 * markers for notes, as KanteFretboard does for strings. Presentational: the app sets the
 * markers; nothing moves on its own (no animation, so reduced motion has nothing to stop).
 *
 *   low, high      MIDI numbers of the lowest and highest key (60 = middle C), e.g. an
 *                  instrument profile's key range 28..67 (E1..G4)
 *   noteNames, middleCOctave   key names, as KanteKeyLayout (the app sets its language)
 *   keyNames       which keys carry their name at the bottom: CKeys (default, "C2"),
 *                  WhiteKeys, None
 *   markers        [{midi, role, label, cents}]; role, each with its own shape, so colour
 *                  is never the only sign:
 *                    "current"  filled square (the note now)
 *                    "next"     hollow square with a thick edge (the note to come)
 *                    "root"     filled diamond (root of a scale or chord)
 *                    "scale"    small round dot (a note of the scale)
 *                    "hit", "wrong", "missed", "early", "late", "offpitch"  the note state's
 *                               sign (KanteNoteMark on a badge, offpitch with its cents)
 *                  label (finger, note name) is written inside the shapes; the key of
 *                  "current" is tinted too
 *   interactive    false (default): a display, as the other instrument components. true:
 *                  takes focus (Tab), Left / Right move a focus ring key by key, Home / End
 *                  jump to the ends, Enter / Space or a click fire activated(midi), e.g. to
 *                  pick the lowest key of a range
 *
 * Screen readers hear the markers ("Aktuell: E1; Nächste: G1"), in the words of
 * `roleNames` (note states in KanteStyle.noteStateName) and `markerText`.
 * Key colours follow the theme's lightness: the lighter of ground and text colour for the
 * white keys, the darker for the black ones, so it reads as a piano in dark and light.
 */
Item {
    id: board

    enum KeyNames {
        CKeys,
        WhiteKeys,
        None
    }

    property int low: 28
    property int high: 67
    property alias noteNames: layout.noteNames
    property alias middleCOctave: layout.middleCOctave
    property int keyNames: KanteKeyboard.KeyNames.CKeys
    property var markers: []
    property bool interactive: false
    /** The key with the focus ring (interactive). */
    property int focusKey: low
    property string accessibleName: "Klaviatur"
    property var roleNames: ({ current: "Aktuell", next: "Nächste", root: "Grundton", scale: "Tonleiter" })
    /** Words of a marker for screen readers: %1 role, %2 key name. */
    property string markerText: "%1: %2"

    /** A key was clicked or chosen with Enter / Space (interactive). */
    signal activated(int midi)

    /** The key geometry (KanteKeyLayout), e.g. to align own items with the keys. */
    readonly property KanteKeyLayout keyLayout: KanteKeyLayout {
        id: layout
        low: board.low
        high: board.high
        width: board.width
    }
    readonly property bool darkGround: KanteStyle.relLum(KanteStyle.backgroundColor) < KanteStyle.relLum(KanteStyle.textColor)
    readonly property color whiteColor: darkGround ? KanteStyle.textColor : KanteStyle.backgroundColor
    readonly property color blackColor: darkGround ? KanteStyle.backgroundColor : KanteStyle.strongTextColor
    readonly property real blackHeight: Math.round(height * layout.blackLength)
    readonly property real markerSize: Math.max(KanteStyle.unit(10), Math.min(layout.whiteWidth * layout.blackWidth * 0.86, KanteStyle.unit(30)))

    implicitWidth: KanteStyle.unit(680)
    implicitHeight: KanteStyle.unit(110)
    activeFocusOnTab: interactive

    Accessible.role: interactive ? Accessible.List : Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: {
        var parts = []
        if (interactive && activeFocus) {
            parts.push(nameOf(focusKey))
        }
        var order = ["current", "next", "hit", "offpitch", "wrong", "missed", "early", "late", "root", "scale"]
        for (var o = 0; o < order.length; o++) {
            for (var i = 0; markers && i < markers.length; i++) {
                var m = markers[i]
                if (roleOf(m) === order[o] && Number(m.midi) >= layout.first && Number(m.midi) <= layout.last) {
                    parts.push(markerText.arg(roleName(order[o])).arg(nameOf(Number(m.midi))))
                }
            }
        }
        return parts.join("; ")
    }

    /** Key name with octave, e.g. "E1"; as KanteKeyLayout.nameOf. */
    function nameOf(m) {
        return layout.nameOf(m)
    }
    function roleOf(m) {
        return m && m.role ? String(m.role) : "scale"
    }
    function roleName(r) {
        return roleNames && roleNames[r] !== undefined ? String(roleNames[r]) : KanteStyle.noteStateName(r)
    }
    function isState(r) {
        return r === "hit" || r === "wrong" || r === "missed" || r === "early" || r === "late" || r === "offpitch"
    }
    function moveFocus(step) {
        focusKey = Math.max(layout.first, Math.min(layout.last, focusKey + step))
    }
    function showsName(m) {
        return keyNames === KanteKeyboard.KeyNames.WhiteKeys ? !layout.isBlack(m)
             : keyNames === KanteKeyboard.KeyNames.CKeys && layout.pc(m) === 0
    }
    // The marked "current" keys, for the key tint.
    readonly property var currentKeys: {
        var out = {}
        for (var i = 0; markers && i < markers.length; i++) {
            if (roleOf(markers[i]) === "current") {
                out[Number(markers[i].midi)] = true
            }
        }
        return out
    }

    Keys.enabled: interactive
    Keys.onLeftPressed: moveFocus(-1)
    Keys.onRightPressed: moveFocus(1)
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Home) {
            focusKey = layout.first
        } else if (event.key === Qt.Key_End) {
            focusKey = layout.last
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activated(focusKey)
        } else {
            return
        }
        event.accepted = true
    }

    TextMetrics {
        id: nameMetrics
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        text: "C♯8"
    }

    // The keys: black ones over the white ones (z).
    Repeater {
        model: layout.count
        delegate: Rectangle {
            id: key
            required property int index
            readonly property int midi: layout.first + index
            readonly property bool blackKey: layout.isBlack(midi)
            readonly property bool current: !!board.currentKeys[midi]
            x: Math.round(layout.x(midi))
            width: Math.round(layout.x(midi) + layout.keyWidth(midi)) - x
            z: blackKey ? 1 : 0
            height: blackKey ? board.blackHeight : board.height
            color: current ? Qt.tint(blackKey ? board.blackColor : board.whiteColor, KanteStyle.tint(KanteStyle.accentColor, 0.45))
                           : (blackKey ? board.blackColor : board.whiteColor)
            border.width: 1
            border.color: blackKey ? KanteStyle.frameColor : KanteStyle.tint(board.blackColor, 0.35)

            Text {
                visible: board.showsName(key.midi) && width <= key.width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: KanteStyle.unit(3)
                text: board.nameOf(key.midi)
                color: KanteStyle.inkOn(key.color)
                font: nameMetrics.font
            }
            // Focus ring (interactive).
            Rectangle {
                visible: board.interactive && board.activeFocus && board.focusKey === key.midi
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: KanteStyle.focusColor
            }
        }
    }

    // Markers: quiet roles below, the current note on top.
    Repeater {
        model: {
            var order = { scale: 0, root: 1, next: 3, current: 4 }
            var list = (board.markers || []).filter(function (m) {
                var k = Number(m.midi)
                return k >= layout.first && k <= layout.last
            })
            list.sort(function (a, b) {
                var ra = board.roleOf(a), rb = board.roleOf(b)
                return (order[ra] !== undefined ? order[ra] : 2) - (order[rb] !== undefined ? order[rb] : 2)
            })
            return list
        }
        delegate: Item {
            id: mk
            required property var modelData
            readonly property string role: board.roleOf(modelData)
            readonly property int midi: Number(modelData.midi)
            readonly property bool blackKey: layout.isBlack(midi)
            readonly property bool stateSign: board.isState(role)
            readonly property real size: role === "scale" ? board.markerSize * 0.62 : board.markerSize
            readonly property color tone: role === "current" ? KanteStyle.accentColor
                                        : role === "next" ? KanteStyle.focusColor
                                        : role === "root" ? KanteStyle.tagColor
                                        : stateSign ? KanteStyle.noteStateColor(role) : KanteStyle.mutedTextColor
            // On a white key below the black keys, on a black key near its tip.
            readonly property real centerY: blackKey ? board.blackHeight - board.markerSize * 0.75
                                                     : board.blackHeight + (board.height - board.blackHeight - nameMetrics.height) / 2
            z: 2
            x: layout.x(midi) + layout.keyWidth(midi) / 2 - width / 2
            y: centerY - height / 2
            width: size
            height: size
            Accessible.ignored: true

            Rectangle {
                visible: !mk.stateSign
                anchors.centerIn: parent
                width: mk.role === "root" ? mk.size * 0.78 : mk.size
                height: width
                rotation: mk.role === "root" ? 45 : 0
                radius: mk.role === "scale" ? width / 2 : 0
                color: mk.role === "next" ? board.whiteColor : mk.tone
                border.width: mk.role === "next" ? Math.max(2, Math.round(mk.size * 0.14)) : (mk.role === "scale" ? 1 : 0)
                border.color: mk.role === "scale" ? KanteStyle.inkOn(mk.tone) : mk.tone
            }
            KanteNoteMark {
                visible: mk.stateSign
                anchors.fill: parent
                noteState: mk.role
                badge: true
                cents: mk.modelData.cents !== undefined && mk.modelData.cents !== null ? Number(mk.modelData.cents) : NaN
                color: mk.tone
            }
            Text {
                visible: !mk.stateSign
                anchors.centerIn: parent
                text: mk.modelData.label !== undefined ? mk.modelData.label : ""
                color: mk.role === "next" ? KanteStyle.inkOn(board.whiteColor) : KanteStyle.inkOn(mk.tone)
                font.family: nameMetrics.font.family
                font.weight: Font.Medium
                font.pixelSize: Math.max(7, Math.round(mk.size * (mk.role === "scale" ? 0.6 : 0.5)))
            }
        }
    }

    // Clicks (interactive): the black key above wins where it covers a white one.
    TapHandler {
        enabled: board.interactive
        onTapped: function (point) {
            var p = point.position
            var k = layout.keyAt(p.x, p.y < board.blackHeight)
            if (k < 0) {
                return
            }
            board.focusKey = k
            board.forceActiveFocus()
            board.activated(k)
        }
    }
}
