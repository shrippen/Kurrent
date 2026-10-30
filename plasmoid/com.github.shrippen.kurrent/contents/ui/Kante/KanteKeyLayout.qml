import QtQuick

/**
 * Key geometry and note names for a piano range (Kante 1.30), shared by KanteKeyboard and
 * KanteKeyLane, so a lane above a keyboard of the same width and range has its columns
 * over the keys. Non-visual; an app can use it to align its own items.
 *
 *   low, high      MIDI numbers of the lowest and highest key (60 = middle C); a range
 *                  that starts or ends on a black key starts or ends at that key's edge
 *   width          pixels the range spans
 *   noteNames      names of the 12 pitch classes from C; the app sets its language
 *                  (German: H for B), default C, C♯, D, E♭, E, F, F♯, G, A♭, A, B♭, B
 *   middleCOctave  octave number of MIDI 60 (4: C4, scientific pitch; some apps say C3)
 *
 * Proportions as on a piano: white keys equally wide, black keys 0.58 of a white key wide
 * and 0.63 of its length, set off the white key boundary as on a real keyboard (C♯ and F♯
 * a little to the left, D♯ and A♯ to the right, G♯ centred).
 *   x(m), keyWidth(m)  left edge and width of key m in pixels
 *   isBlack(m), nameOf(m)  e.g. nameOf(28) "E1", nameOf(61) "C♯4"
 */
QtObject {
    id: keys

    property int low: 28
    property int high: 67
    property real width: 0
    property var noteNames: ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    property int middleCOctave: 4

    /** Width of a black key in white keys, and its length as part of a white key's. */
    readonly property real blackWidth: 0.58
    readonly property real blackLength: 0.63

    // Pitch classes 0..11: black or not, and where a black key's centre sits off the white
    // boundary (in white keys).
    readonly property var black: [false, true, false, true, false, false, true, false, true, false, true, false]
    readonly property var offset: [0, -0.12, 0, 0.12, 0, 0, -0.15, 0, 0, 0, 0.15, 0]

    readonly property int first: Math.min(low, high)
    readonly property int last: Math.max(low, high)
    readonly property real leftUnits: leftOf(first)
    readonly property real spanUnits: Math.max(1e-6, rightOf(last) - leftUnits)
    /** Width of a white key in pixels. */
    readonly property real whiteWidth: width / spanUnits
    /** Number of keys in the range. */
    readonly property int count: last - first + 1

    function pc(m) {
        return ((m % 12) + 12) % 12
    }
    function isBlack(m) {
        return black[pc(m)]
    }
    // White keys below m on an endless keyboard (7 per octave).
    function whitesBelow(m) {
        var oct = Math.floor(m / 12), p = pc(m)
        var n = 0
        for (var i = 0; i < p; i++) {
            if (!black[i]) {
                n++
            }
        }
        return oct * 7 + n
    }
    // Left and right edge of key m, in white keys on the endless keyboard.
    function leftOf(m) {
        var w = whitesBelow(m)
        return isBlack(m) ? w + offset[pc(m)] - blackWidth / 2 : w
    }
    function rightOf(m) {
        return leftOf(m) + (isBlack(m) ? blackWidth : 1)
    }
    function x(m) {
        return (leftOf(m) - leftUnits) * whiteWidth
    }
    function keyWidth(m) {
        return (isBlack(m) ? blackWidth : 1) * whiteWidth
    }
    /** Key name with octave: nameOf(60) "C4" (middleCOctave 4). */
    function nameOf(m) {
        var n = noteNames && noteNames.length === 12 ? String(noteNames[pc(m)]) : String(pc(m))
        return n + (Math.floor(m / 12) - 5 + middleCOctave)
    }
    /** The key under x (pixels), black keys first when `blackLevel` is true; -1 outside. */
    function keyAt(px, blackLevel) {
        if (blackLevel) {
            for (var b = first; b <= last; b++) {
                if (isBlack(b) && px >= x(b) && px < x(b) + keyWidth(b)) {
                    return b
                }
            }
        }
        for (var w = first; w <= last; w++) {
            if (!isBlack(w) && px >= x(w) && px < x(w) + keyWidth(w)) {
                return w
            }
        }
        return -1
    }
}
