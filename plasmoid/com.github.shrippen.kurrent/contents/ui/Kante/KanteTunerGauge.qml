import QtQuick
import QtQuick.Shapes
import "."

/**
 * Tuner (Kante 1.23, for Kontra): a needle on a scale of −50..+50 cents, the note name
 * with its octave, the deviation as text ("−12 ct") and a hint in words.
 *
 *   noteName, octave   the nearest note ("E", 1); octave < 0 hides it
 *   cents              deviation from it, −50..+50 (clamped on the scale)
 *   active             a tone is heard; inactive the needle hides and the name shows "–"
 *   inTuneCents        |cents| up to this is in tune (default 3)
 *   hint               words for the player, e.g. "tune up" (the app knows the string)
 *
 * In tune shows by shape and text, not colour alone: the in-tune band on the scale,
 * a check mark beside the name, the name framed, and `inTuneText` when `hint` is empty.
 * Out of tune fills the triangle on the side the tone is off (flat left, sharp right).
 * The needle follows `cents` with a short ease only when Kante motion is on.
 */
Item {
    id: tuner

    property string noteName: ""
    property int octave: -1
    property real cents: 0
    property bool active: false
    property real inTuneCents: 3
    property string hint: ""
    property string inTuneText: "Gestimmt"
    property string accessibleName: "Stimmgerät"

    readonly property real shown: Math.max(-50, Math.min(50, cents))
    readonly property bool inTune: active && Math.abs(cents) <= inTuneCents
    readonly property string centsText: !active ? "– ct"
        : (Math.round(cents) < 0 ? "−" : Math.round(cents) > 0 ? "+" : "") + Math.abs(Math.round(cents)) + " ct"
    readonly property string shownHint: hint !== "" ? hint : (inTune ? inTuneText : "")

    // Scale geometry: a 120° arc, 0 cents straight up.
    readonly property real radius: Math.max(KanteStyle.unit(40), Math.min(width / 2 - KanteStyle.unit(24), height * 0.62))
    readonly property real cx: width / 2
    readonly property real cy: radius + KanteStyle.unit(18)
    function angleOf(c) {
        return (270 + c / 50 * 60) * Math.PI / 180
    }
    function pointAt(c, r) {
        var a = angleOf(c)
        return Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a))
    }

    implicitWidth: KanteStyle.unit(340)
    implicitHeight: KanteStyle.unit(250)

    Accessible.role: Accessible.Indicator
    Accessible.name: accessibleName
    Accessible.description: active
        ? [noteName + (octave >= 0 ? octave : ""), centsText, shownHint].filter(function (s) { return s !== "" }).join(", ")
        : "–"

    Shape {
        anchors.fill: parent
        antialiasing: true
        // The scale
        ShapePath {
            strokeColor: KanteStyle.frameColor
            strokeWidth: Math.max(2, KanteStyle.unit(3))
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: tuner.cx; centerY: tuner.cy; radiusX: tuner.radius; radiusY: tuner.radius; startAngle: 210; sweepAngle: 120 }
        }
        // In-tune band
        ShapePath {
            strokeColor: tuner.inTune ? KanteStyle.positiveTextColor : KanteStyle.tint(KanteStyle.positiveTextColor, 0.5)
            strokeWidth: Math.max(6, KanteStyle.unit(10))
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: tuner.cx; centerY: tuner.cy; radiusX: tuner.radius; radiusY: tuner.radius
                startAngle: 270 - Math.max(0.5, tuner.inTuneCents) / 50 * 60
                sweepAngle: 2 * Math.max(0.5, tuner.inTuneCents) / 50 * 60
            }
        }
        // Ticks every 5 cents, longer every 10, longest at 0 and ±50.
        ShapePath {
            strokeColor: KanteStyle.mutedTextColor
            strokeWidth: Math.max(1, KanteStyle.unit(2))
            fillColor: "transparent"
            PathMultiline {
                paths: {
                    var out = []
                    for (var c = -50; c <= 50; c += 5) {
                        var len = (c % 50 === 0) ? 0.16 : (c % 10 === 0 ? 0.1 : 0.05)
                        out.push([tuner.pointAt(c, tuner.radius - KanteStyle.unit(8)), tuner.pointAt(c, tuner.radius * (1 - len) - KanteStyle.unit(8))])
                    }
                    return out
                }
            }
        }
    }

    // Scale labels
    Repeater {
        model: [-50, 0, 50]
        delegate: Text {
            required property var modelData
            readonly property point p: tuner.pointAt(modelData, tuner.radius + KanteStyle.unit(12))
            x: p.x - width / 2
            y: p.y - height / 2
            text: modelData < 0 ? "−50" : modelData > 0 ? "+50" : "0"
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }

    // Flat / sharp triangles: filled on the side the tone is off.
    Repeater {
        model: 2
        delegate: Shape {
            id: tri
            required property int index
            readonly property bool sharpSide: index === 1
            readonly property bool lit: tuner.active && !tuner.inTune && (sharpSide ? tuner.cents > 0 : tuner.cents < 0)
            readonly property real s: KanteStyle.unit(16)
            readonly property point p: tuner.pointAt(sharpSide ? 50 : -50, tuner.radius * 0.62)
            x: p.x - s / 2
            y: p.y - s / 2
            width: s
            height: s
            antialiasing: true
            ShapePath {
                strokeColor: tri.lit ? KanteStyle.warningColor : KanteStyle.mutedTextColor
                strokeWidth: Math.max(1.5, KanteStyle.unit(2))
                fillColor: tri.lit ? KanteStyle.warningColor : "transparent"
                joinStyle: ShapePath.MiterJoin
                // Points toward the centre: the way to turn the peg.
                startX: tri.sharpSide ? tri.s * 0.85 : tri.s * 0.15; startY: tri.s * 0.15
                PathLine { x: tri.sharpSide ? tri.s * 0.85 : tri.s * 0.15; y: tri.s * 0.85 }
                PathLine { x: tri.sharpSide ? tri.s * 0.15 : tri.s * 0.85; y: tri.s * 0.5 }
                PathLine { x: tri.sharpSide ? tri.s * 0.85 : tri.s * 0.15; y: tri.s * 0.15 }
            }
        }
    }

    // Needle
    Rectangle {
        visible: tuner.active
        width: Math.max(2, KanteStyle.unit(3))
        height: tuner.radius - KanteStyle.unit(4)
        x: tuner.cx - width / 2
        y: tuner.cy - height
        transformOrigin: Item.Bottom
        rotation: tuner.shown / 50 * 60
        color: tuner.inTune ? KanteStyle.positiveTextColor : KanteStyle.strongTextColor
        Behavior on rotation { NumberAnimation { duration: KanteStyle.durationFast; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        width: KanteStyle.unit(10)
        height: width
        x: tuner.cx - width / 2
        y: tuner.cy - height / 2
        rotation: 45
        color: tuner.active ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
    }

    // Name, deviation, hint
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: tuner.cy + KanteStyle.unit(10)
        spacing: KanteStyle.unit(2)

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: nameRow.width + KanteStyle.unit(16)
            height: nameRow.height + KanteStyle.unit(4)
            KanteBrackets {
                anchors.fill: parent
                active: tuner.inTune
                restInset: 0
                color: KanteStyle.positiveTextColor
            }
            Row {
                id: nameRow
                anchors.centerIn: parent
                spacing: KanteStyle.unit(4)
                Text {
                    text: tuner.active && tuner.noteName !== "" ? tuner.noteName : "–"
                    color: tuner.active ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
                    font: KanteStyle.titleFont(KanteStyle.defaultFont.pointSize * 2.6)
                }
                Text {
                    visible: tuner.active && tuner.octave >= 0
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: KanteStyle.unit(4)
                    text: tuner.octave
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 1.1, false)
                }
                KanteNoteMark {
                    visible: tuner.inTune
                    anchors.verticalCenter: parent.verticalCenter
                    width: KanteStyle.unit(20)
                    height: width
                    noteState: "hit"
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tuner.centsText
            color: tuner.active ? KanteStyle.textColor : KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 1.2, true)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: tuner.shownHint
            color: tuner.inTune ? KanteStyle.positiveTextColor : KanteStyle.textColor
            font: KanteStyle.labelFont()
        }
    }
}
