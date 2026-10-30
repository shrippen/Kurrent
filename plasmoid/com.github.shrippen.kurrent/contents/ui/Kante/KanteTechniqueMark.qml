import QtQuick
import QtQuick.Shapes
import "."

/**
 * The sign of a playing technique (Kante 1.31, for Kontra), as written in bass tab: slide
 * "sl", hammer-on "h", pull-off "p", slap "S", pop "P", ghost note "( )", dead note "x"
 * (1.32: muted, no pitch; the tab writes x for its fret). With a `result`
 * it also says how the technique was played, by shape and not by colour alone:
 *
 *   ""         the sign alone (what the score asks for), muted
 *   "played"   a solid frame around the sign
 *   "other"    a solid frame, the sign struck through by a diagonal (another technique)
 *   "unheard"  a dashed frame, the sign struck through (nothing heard for the note)
 *
 *   technique  key: "slide", "hammer", "pull", "slap", "pop", "ghost", "dead"; anything else
 *              draws nothing (`drawn` false)
 *   result     "", "played", "other", "unheard"
 *   color      `resultColor` by default: played as a hit, other as a wrong note, unheard
 *              as a missed one, none muted (KanteStyle.noteStateColor)
 *
 * Set the height; `implicitWidth` follows it (wider for "sl" and "( )").
 *
 *   signVisible  (1.37) false: no sign, only the result's frame and stroke, drawn only with
 *                a result. For a sign the note already carries, a ghost note's fret in
 *                parentheses in tab: the mark then frames that fret. Without a result it
 *                paints nothing but stays visible, so screen readers still name the technique.
 *
 * Names for screen readers: KanteStyle.techniqueName and techniqueResultName (an app sets
 * their translations once). Used by KanteTabLane, KanteTabStaff and KanteBassStaff.
 */
Item {
    id: mark

    property string technique: ""
    property string result: ""
    /** The colour of the result (the default `color`); a quiet view sets `color` muted. */
    readonly property color resultColor: result === "played" ? KanteStyle.noteStateColor("hit")
                                       : result === "other" ? KanteStyle.noteStateColor("wrong")
                                       : result === "unheard" ? KanteStyle.noteStateColor("missed")
                                       : KanteStyle.mutedTextColor
    property color color: resultColor
    /** The tab sign of a technique key, "" for an unknown one. */
    function signOf(key) {
        switch (key) {
        case "slide": return "sl"
        case "hammer": return "h"
        case "pull": return "p"
        case "slap": return "S"
        case "pop": return "P"
        case "ghost": return "( )"
        case "dead": return "x"
        default: return ""
        }
    }
    readonly property string sign: signOf(technique)
    property bool signVisible: true
    readonly property bool framed: result === "played" || result === "other" || result === "unheard"
    readonly property bool drawn: sign !== "" && (signVisible || framed)
    readonly property bool struck: result === "other" || result === "unheard"

    // Stays in the accessibility tree while it draws nothing (a ghost note without a result,
    // signVisible false): screen readers still hear the technique (1.37).
    visible: sign !== ""
    implicitHeight: KanteStyle.unit(14)
    // As wide as the sign needs at the height it is given.
    implicitWidth: Math.max(height, label.implicitWidth + height * 0.5)

    Accessible.role: Accessible.Graphic
    Accessible.name: KanteStyle.techniqueName(technique)
                     + (framed ? ", " + KanteStyle.techniqueResultName(result) : "")

    readonly property real stroke: Math.max(1, Math.round(height * 0.09))

    Text {
        id: label
        anchors.centerIn: parent
        text: mark.sign
        visible: mark.signVisible
        color: mark.color
        font.family: KanteStyle.monoFont(10, true).family
        font.weight: Font.Bold
        font.pixelSize: Math.max(7, Math.round(mark.height * 0.68))
        Accessible.ignored: true
    }

    Shape {
        visible: mark.drawn && mark.framed
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: mark.color
            strokeWidth: mark.stroke
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            strokeStyle: mark.result === "unheard" ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [2, 1.5]
            PathSvg {
                path: {
                    var a = mark.stroke / 2, w = mark.width - a, h = mark.height - a
                    return "M " + a + " " + a + " H " + w + " V " + h + " H " + a + " Z"
                }
            }
        }
    }

    // Struck through: a diagonal from bottom left to top right over the sign.
    Shape {
        visible: mark.drawn && mark.struck
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: mark.color
            strokeWidth: mark.stroke
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            PathSvg {
                path: "M " + (mark.width * 0.18) + " " + (mark.height * 0.82)
                      + " L " + (mark.width * 0.82) + " " + (mark.height * 0.18)
            }
        }
    }
}
