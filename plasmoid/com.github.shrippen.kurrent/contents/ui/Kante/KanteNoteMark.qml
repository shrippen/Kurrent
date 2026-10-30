import QtQuick
import QtQuick.Shapes
import "."

/**
 * The sign of a played note's state (`noteState`, Kante 1.23), so colour is never the only
 * sign: "hit" a check, "wrong" a cross, "missed" a hollow dashed square, "early" an
 * arrow to the left (before the beat, as on a time axis), "late" an arrow to the right,
 * "offpitch" (1.27: the right note, its pitch off by more than the app's cents limit) a
 * wave; "pending" (or anything else) draws nothing. Colour from KanteStyle.noteStateColor.
 * `badge` puts the sign on a small dialog-coloured square with a frame, so it reads on
 * top of a filled note. Used by KanteTabLane, KanteTabStaff and KanteBassStaff, and as
 * the key of a legend.
 *
 *   cents      offpitch only: the deviation in cents (NaN, the default: none). With
 *              `showCents` it shows beside the sign as "+32 ct" / "−18 ct"
 *              (KanteStyle.centsText) and is read out with the state's name
 *   showCents  show the cents label (default true); it sits right of the sign, outside
 *              the mark's own square, so a mark keeps its size with or without it
 */
Item {
    id: mark

    property string noteState: "pending"
    property color color: KanteStyle.noteStateColor(noteState)
    property bool badge: false
    property real cents: NaN
    property bool showCents: true
    readonly property bool drawn: noteState === "hit" || noteState === "wrong" || noteState === "missed"
                                  || noteState === "early" || noteState === "late" || noteState === "offpitch"
    /** "+32 ct" for an offpitch note with cents, else "". */
    readonly property string centsLabel: noteState === "offpitch" ? KanteStyle.centsText(cents) : ""

    implicitWidth: KanteStyle.unit(14)
    implicitHeight: implicitWidth

    Accessible.role: Accessible.Graphic
    Accessible.name: KanteStyle.noteStateName(noteState) + (centsLabel !== "" ? ", " + centsLabel : "")

    readonly property real s: Math.min(width, height)
    readonly property real stroke: Math.max(1.5, s * (badge ? 0.13 : 0.15))

    /** The path of a sign in a square of side `s` (SVG syntax). */
    function pathFor(st, s) {
        function p(x, y) { return (x * s).toFixed(2) + " " + (y * s).toFixed(2) }
        switch (st) {
        case "hit": return "M " + p(0.2, 0.52) + " L " + p(0.42, 0.74) + " L " + p(0.82, 0.28)
        case "wrong": return "M " + p(0.26, 0.26) + " L " + p(0.74, 0.74) + " M " + p(0.74, 0.26) + " L " + p(0.26, 0.74)
        case "early": return "M " + p(0.8, 0.5) + " L " + p(0.22, 0.5) + " M " + p(0.46, 0.26) + " L " + p(0.22, 0.5) + " L " + p(0.46, 0.74)
        case "late": return "M " + p(0.2, 0.5) + " L " + p(0.78, 0.5) + " M " + p(0.54, 0.26) + " L " + p(0.78, 0.5) + " L " + p(0.54, 0.74)
        case "missed": return "M " + p(0.22, 0.22) + " L " + p(0.78, 0.22) + " L " + p(0.78, 0.78) + " L " + p(0.22, 0.78) + " Z"
        // A full wave (a tilde): a pitch that wobbles around the right one. Round, where
        // check and cross are straight strokes, and level, where the arrows point.
        case "offpitch": return "M " + p(0.16, 0.56) + " C " + p(0.26, 0.24) + " " + p(0.4, 0.24) + " " + p(0.5, 0.5)
                                + " C " + p(0.6, 0.76) + " " + p(0.74, 0.76) + " " + p(0.84, 0.44)
        default: return ""
        }
    }

    Rectangle {
        visible: mark.badge && mark.drawn
        anchors.centerIn: parent
        width: mark.s
        height: mark.s
        color: KanteStyle.dialogColor
        border.width: 1
        border.color: mark.color
    }

    Shape {
        visible: mark.drawn
        width: mark.s
        height: mark.s
        anchors.centerIn: parent
        antialiasing: true
        ShapePath {
            strokeColor: mark.color
            strokeWidth: mark.stroke
            fillColor: "transparent"
            capStyle: mark.noteState === "offpitch" ? ShapePath.RoundCap : ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            strokeStyle: mark.noteState === "missed" ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [1.6, 1.4]
            PathSvg { path: mark.pathFor(mark.noteState, mark.s) }
        }
    }

    // Cents beside the sign; on a badge with the badge's ground, so it reads over a note.
    Rectangle {
        id: centsBox
        visible: mark.showCents && mark.centsLabel !== ""
        x: (mark.width + mark.s) / 2 + (mark.badge ? 0 : KanteStyle.unit(2))
        anchors.verticalCenter: parent.verticalCenter
        width: centsText.implicitWidth + (mark.badge ? KanteStyle.unit(6) : 0)
        height: Math.max(mark.s, centsText.implicitHeight)
        color: mark.badge ? KanteStyle.dialogColor : "transparent"
        border.width: mark.badge ? 1 : 0
        border.color: mark.color
        Text {
            id: centsText
            anchors.centerIn: parent
            text: mark.centsLabel
            color: mark.color
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
            Accessible.ignored: true
        }
    }
    /** Width of the cents label beside the sign (0 without one), for a legend's layout. */
    readonly property real centsWidth: centsBox.visible ? centsBox.width + (badge ? 0 : KanteStyle.unit(2)) : 0
}
