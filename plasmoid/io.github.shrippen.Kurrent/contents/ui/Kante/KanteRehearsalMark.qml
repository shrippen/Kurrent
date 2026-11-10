import QtQuick
import "."

/**
 * Rehearsal mark (Kante 1.50, for Kontra): the name of a part (Intro, Strophe, Refrain, or a
 * letter A, B …) in a framed box over the first bar of the part. KanteTabLane, KanteKeyLane,
 * KanteTabStaff and KanteBassStaff draw it from a bar's `section`; an app can place one itself.
 *
 *   text          the label; several names of one bar as KanteStyle.rehearsalText(["Refrain", "B"])
 *                 → "Refrain · B"
 *   pixelSize     size of the name (default: the platform font)
 *   maximumWidth  the room it has (default: none). A longer name is cut short with "…"
 *                 (`truncated`) instead of running into the next mark; screen readers hear
 *                 all of it ("Teil Refrain · B", KanteStyle.partText)
 *   groundColor   fill of the box, so bar lines behind it stop at the frame
 *
 *     ┌──────────┐◣
 *     │ REFRAIN  │   frame in the strong text colour; Kante and Kante Light cut the
 *     └──────────┘   top-right corner (cutSmall), System stays square
 *
 * Not colour alone: the frame and the word carry it. Nothing moves.
 */
Item {
    id: mark

    property string text: ""
    property real pixelSize: KanteStyle.fontPixels(KanteStyle.defaultFont)
    property real maximumWidth: Infinity
    property color groundColor: KanteStyle.backgroundColor
    /** The name is cut short to fit maximumWidth. */
    readonly property bool truncated: label.truncated
    /** Corner cut: KanteStyle.cutSmall (0 in System). */
    readonly property real cut: KanteStyle.cutSmall
    readonly property real stroke: Math.max(1, KanteStyle.unit(2))
    readonly property real padX: Math.round(pixelSize * 0.45) + cut / 2
    /** Room for at least one letter and "…"; else the mark draws nothing (no empty box). */
    readonly property bool fits: maximumWidth >= 2 * padX + pixelSize * 1.2

    objectName: "kanteRehearsalMark"
    // Capped by the room, so a layout (which sizes by implicitWidth) cuts it short too.
    implicitWidth: Math.max(Math.min(Math.ceil(label.implicitWidth + 2 * padX), maximumWidth), 0)
    implicitHeight: Math.ceil(label.implicitHeight + Math.round(pixelSize * 0.3))
    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: KanteStyle.partText.arg(text)

    KantePolygon {
        visible: mark.fits
        anchors.fill: parent
        fillColor: mark.groundColor
        strokeColor: KanteStyle.strongTextColor
        strokeWidth: mark.stroke
        cutTopRight: mark.cut
    }
    Text {
        id: label
        visible: mark.fits
        x: mark.padX
        width: Math.max(0, mark.width - 2 * mark.padX)
        anchors.verticalCenter: parent.verticalCenter
        text: mark.text
        elide: Text.ElideRight
        color: KanteStyle.strongTextColor
        font.family: KanteStyle.headingFont(10).family
        font.weight: Font.Bold
        font.capitalization: KanteStyle.themed ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: KanteStyle.themed ? mark.pixelSize * KantePalette.headingLetterSpacing : 0
        font.pixelSize: Math.max(8, Math.round(mark.pixelSize))
        Accessible.ignored: true
    }
}
