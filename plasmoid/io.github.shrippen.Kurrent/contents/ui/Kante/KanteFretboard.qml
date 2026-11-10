import QtQuick
import "."

/**
 * Fretboard (Kante 1.23, for Kontra): strings, frets, nut, inlays and markers for
 * notes and positions. Presentational: the app sets the markers.
 *
 *   strings, stringNames, lowStringOnTop  as KanteTabLane (string 0 = lowest)
 *   stringColors         as KanteTabLane (1.28): colours the string lines; where missing
 *                        KanteStyle.stringColor (the app's `stringPalette`). Markers keep
 *                        their role colours and shapes
 *   frets, firstFret     frets shown: firstFret + 1 .. firstFret + frets; with
 *                        firstFret 0 the nut and a column for open strings (fret 0)
 *   markers              [{string, fret, role, label}]; role:
 *                          "current"  filled square (the note now)
 *                          "next"     hollow square with a thick edge (the note to come)
 *                          "root"     filled diamond (root of a scale or chord)
 *                          "scale"    small round dot (a note of the scale)
 *                        so roles differ by shape, not colour alone; label (finger,
 *                        note name) is written inside
 *   leftHanded           mirrored: the nut on the right
 *   evenFrets            all frets equally wide (default: the real 2^(−n/12) spacing)
 *   inlays               frets with an inlay (12 and 24 doubled), numbered below
 */
Item {
    id: board

    property int strings: 4
    property var stringNames: ["E", "A", "D", "G"]
    property int frets: 12
    property int firstFret: 0
    property var markers: []
    property bool lowStringOnTop: false
    /** Colour per string, 0 = lowest (1.28); where missing KanteStyle.stringColor. */
    property var stringColors: []
    property bool leftHanded: false
    property bool evenFrets: false
    property var inlays: [3, 5, 7, 9, 12, 15, 17, 19, 21, 24]
    property bool fretNumbers: true
    property string accessibleName: "Griffbrett"
    property var roleNames: ({ current: "Aktuell", next: "Nächste", root: "Grundton", scale: "Tonleiter" })
    /** Words of a marker for screen readers: %1 role, %2 string, %3 fret. */
    property string markerText: "%1: Saite %2, Bund %3"

    readonly property real gutter: Math.round(nameMetrics.width + KanteStyle.unit(14))
    readonly property real openWidth: firstFret === 0 ? KanteStyle.unit(30) : KanteStyle.unit(6)
    readonly property real numbersHeight: fretNumbers ? Math.round(numberMetrics.height + KanteStyle.unit(6)) : 0
    readonly property real boardWidth: Math.max(1, width - gutter - openWidth)
    readonly property real boardHeight: Math.max(1, height - numbersHeight)
    readonly property real rowHeight: boardHeight / Math.max(1, strings)
    readonly property real markerSize: Math.max(KanteStyle.unit(12), Math.min(rowHeight * 0.78, KanteStyle.unit(36)))

    implicitWidth: KanteStyle.unit(680)
    implicitHeight: Math.max(1, strings) * KanteStyle.unit(32) + numbersHeight

    Accessible.role: Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: {
        var parts = []
        var order = ["current", "next", "root", "scale"]
        for (var o = 0; o < order.length; o++) {
            for (var i = 0; markers && i < markers.length; i++) {
                var m = markers[i]
                if (m.role === order[o]) {
                    parts.push(markerText.arg(roleNames[m.role] || m.role).arg(nameOf(Number(m.string) || 0)).arg(m.fret))
                }
            }
        }
        return parts.join("; ")
    }

    TextMetrics {
        id: nameMetrics
        font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        text: {
            var w = "M"
            for (var s = 0; s < board.strings; s++) {
                if (board.nameOf(s).length > w.length) {
                    w = board.nameOf(s)
                }
            }
            return w
        }
    }
    TextMetrics {
        id: numberMetrics
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        text: "24"
    }

    function stringColor(s) {
        if (stringColors && s < stringColors.length && stringColors[s] !== undefined) {
            return stringColors[s]
        }
        return KanteStyle.stringColor(s)
    }
    function nameOf(s) {
        return stringNames && s < stringNames.length ? String(stringNames[s]) : String(s + 1)
    }
    function rowOf(s) {
        return lowStringOnTop ? s : strings - 1 - s
    }
    function rowCenter(s) {
        return (rowOf(s) + 0.5) * rowHeight
    }
    function along(n) {
        return 1 - Math.pow(2, -n / 12)
    }
    /** x of fret wire n (n = firstFret is the nut or the left edge), mirrored when left-handed. */
    function fretX(n) {
        var f = evenFrets ? (n - firstFret) / Math.max(1, frets)
                          : (along(n) - along(firstFret)) / (along(firstFret + frets) - along(firstFret))
        var x = gutter + openWidth + f * boardWidth
        return leftHanded ? width - x : x
    }
    /** Centre of the place where fret n is pressed (n = 0: the open column). */
    function placeX(n) {
        if (n <= 0) {
            var x0 = gutter + openWidth / 2
            return leftHanded ? width - x0 : x0
        }
        return (fretX(n - 1 < firstFret ? firstFret : n - 1) + fretX(n)) / 2
    }
    function inView(n) {
        return n === 0 ? firstFret === 0 : n > firstFret && n <= firstFret + frets
    }

    // Board ground
    Rectangle {
        x: Math.min(board.fretX(board.firstFret), board.fretX(board.firstFret + board.frets))
        width: Math.abs(board.fretX(board.firstFret + board.frets) - board.fretX(board.firstFret))
        height: board.boardHeight
        color: KanteStyle.sunkenColor
    }

    // Inlays: quiet squares in the middle, two at 12 and 24 (diamonds are the root marker).
    Repeater {
        model: board.inlays
        delegate: Item {
            required property var modelData
            readonly property int fret: Number(modelData)
            readonly property bool twin: fret % 12 === 0
            visible: fret > board.firstFret && fret <= board.firstFret + board.frets
            Repeater {
                model: parent.twin ? 2 : 1
                delegate: Rectangle {
                    required property int index
                    width: Math.round(Math.min(board.rowHeight * 0.42, KanteStyle.unit(14)))
                    height: width
                    x: board.placeX(parent.fret) - width / 2
                    y: (parent.twin ? (index === 0 ? board.boardHeight * 0.25 : board.boardHeight * 0.75)
                                    : board.boardHeight / 2) - height / 2
                    color: KanteStyle.tint2Color
                }
            }
        }
    }

    // Frets and the nut.
    Repeater {
        model: board.frets + 1
        delegate: Rectangle {
            required property int index
            readonly property int n: board.firstFret + index
            readonly property bool nut: n === 0
            width: nut ? Math.max(4, KanteStyle.unit(6)) : Math.max(1, KanteStyle.unit(2))
            x: Math.round(board.fretX(n) - (board.leftHanded ? (nut ? 0 : width / 2) : (nut ? width : width / 2)))
            height: board.boardHeight
            color: nut ? KanteStyle.strongTextColor : KanteStyle.frameColor
        }
    }

    // Strings with their names (on the nut side).
    Repeater {
        model: board.strings
        delegate: Item {
            required property int index
            y: board.rowCenter(index)
            width: board.width
            Rectangle {
                x: board.leftHanded ? board.fretX(board.firstFret + board.frets) : board.gutter + KanteStyle.unit(4)
                width: board.leftHanded ? board.width - board.gutter - KanteStyle.unit(4) - x
                                        : board.fretX(board.firstFret + board.frets) - x
                height: Math.max(1, Math.round(KanteStyle.unit(1) + (board.strings - 1 - parent.index) * KanteStyle.unit(1) * 0.6))
                y: -height / 2
                color: board.stringColor(parent.index)
            }
            Text {
                x: board.leftHanded ? board.width - width - KanteStyle.unit(4) : KanteStyle.unit(4)
                y: -height / 2
                text: board.nameOf(parent.index)
                color: KanteStyle.strongTextColor
                font: nameMetrics.font
            }
        }
    }

    // Fret numbers under the inlay frets (and the first fret of a position).
    Repeater {
        model: board.fretNumbers ? board.frets : 0
        delegate: Text {
            required property int index
            readonly property int n: board.firstFret + index + 1
            visible: board.inlays.indexOf(n) >= 0 || (board.firstFret > 0 && index === 0)
            x: board.placeX(n) - width / 2
            y: board.boardHeight + KanteStyle.unit(3)
            text: n
            color: KanteStyle.mutedTextColor
            font: numberMetrics.font
        }
    }

    // Markers, quiet roles below: scale, root, next, current.
    Repeater {
        model: {
            var order = { scale: 0, root: 1, next: 2, current: 3 }
            var list = (board.markers || []).slice()
            list.sort(function (a, b) { return (order[a.role] || 0) - (order[b.role] || 0) })
            return list
        }
        delegate: Item {
            id: mk
            required property var modelData
            readonly property string role: String(modelData.role || "scale")
            readonly property int fret: Number(modelData.fret) || 0
            readonly property int str: Math.max(0, Math.min(board.strings - 1, Number(modelData.string) || 0))
            readonly property real size: role === "scale" ? board.markerSize * 0.62 : board.markerSize
            readonly property color tone: role === "current" ? KanteStyle.accentColor
                                        : role === "next" ? KanteStyle.focusColor
                                        : role === "root" ? KanteStyle.tagColor : KanteStyle.mutedTextColor
            visible: board.inView(fret)
            x: board.placeX(fret) - width / 2
            y: board.rowCenter(str) - height / 2
            width: size
            height: size
            Accessible.ignored: true

            Rectangle {
                anchors.centerIn: parent
                width: mk.role === "root" ? mk.size * 0.78 : mk.size
                height: width
                rotation: mk.role === "root" ? 45 : 0
                radius: mk.role === "scale" ? width / 2 : 0
                color: mk.role === "next" ? KanteStyle.backgroundColor : mk.tone
                border.width: mk.role === "next" ? Math.max(2, Math.round(mk.size * 0.14)) : 0
                border.color: mk.tone
            }
            Text {
                anchors.centerIn: parent
                text: mk.modelData.label !== undefined ? mk.modelData.label : ""
                color: mk.role === "next" ? KanteStyle.textColor : KanteStyle.inkOn(mk.tone)
                font.family: nameMetrics.font.family
                font.weight: Font.Medium
                font.pixelSize: Math.max(7, Math.round(mk.size * (mk.role === "scale" ? 0.6 : 0.5)))
            }
        }
    }
}
