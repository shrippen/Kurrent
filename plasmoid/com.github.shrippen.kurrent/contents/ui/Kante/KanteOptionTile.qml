import QtQuick
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "."

/**
 * Option tile (Kante 1.43, from lmix): one of several kinds to choose from, as a tile with an
 * icon, a name and a hint, such as the source kinds in "Add input" (Camera, Video, Stream, …).
 * Use it where the choice needs to be seen at once; a combo box hides it.
 *   icon.name / icon.source  the icon (drawn in the text colour, focus colour when chosen)
 *   text      the name
 *   hint      up to two lines under it ("Capture, webcam")
 *   checked   chosen; tiles of one group are `autoExclusive` (default true)
 *   glyph     (1.59) a character in place of the icon, such as a kanji (技 for "programme" in
 *             Mitori's start menu): drawn in the Japanese family, in the icon's colour
 * Chosen: the selection tint and a 2 px frame in the focus colour; hover: tint step 1;
 * keyboard focus: a 1 px ring inside, also on the chosen tile (further in). Screen readers hear a radio button with name and hint.
 * Launch tile (1.59): `checkable: false` makes it a tile that opens something (a start menu,
 * Mitori): no chosen state, and screen readers hear a button with name and hint.
 * Kante and Kante Light cut the top right corner; System: square, platform colours.
 */
QQC2.AbstractButton {
    id: tile

    property string hint: ""
    property string glyph: ""

    checkable: true
    autoExclusive: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    // As Space does (checked, toggled, clicked; a binding on `checked` stays).
    Keys.onReturnPressed: tile.click()
    Keys.onEnterPressed: tile.click()
    padding: KanteStyle.unit(10)

    implicitWidth: Math.max(KanteStyle.unit(116), implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(KanteStyle.unit(84), implicitContentHeight + topPadding + bottomPadding)

    Accessible.role: checkable ? Accessible.RadioButton : Accessible.Button
    Accessible.name: text
    Accessible.description: hint

    background: KanteCard {
        color: tile.checked ? KanteStyle.selectionColor
             : tile.hovered ? Qt.tint(KanteStyle.cardColor, KanteStyle.tint1Color)
             : KanteStyle.cardColor
        borderColor: tile.checked ? "transparent" : KanteStyle.frameColor
        chamfer: KanteStyle.chamferSmall

        // Selection frame (2 px) and keyboard ring (1 px, further in on a chosen tile): outlines
        // that follow the cut corner.
        Outline {
            visible: tile.checked
            inset: 0
            lineWidth: 2
        }
        Outline {
            visible: tile.visualFocus
            inset: tile.checked ? 4 : 2
            lineWidth: 1
        }
    }

    /** An outline of the card, `inset` px in, the cut corner kept. */
    component Outline: Shape {
        id: outline
        property real inset: 0
        property real lineWidth: 1
        readonly property real d: inset + lineWidth / 2
        // The card is the parent (an inline component does not see the file's ids).
        readonly property real c: parent ? parent.chamfer : 0
        // How far the cut runs along each edge at this inset: the cut moved in by d along its
        // normal (45°: d·√2), none when the card has no cut corner (System).
        readonly property real e: Math.max(0, c - d * (2 - Math.SQRT2))
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            fillColor: "transparent"
            strokeColor: KanteStyle.focusColor
            strokeWidth: outline.lineWidth
            joinStyle: ShapePath.MiterJoin
            startX: outline.d; startY: outline.d
            PathLine { x: outline.width - outline.d - outline.e; y: outline.d }
            PathLine { x: outline.width - outline.d; y: outline.d + outline.e }
            PathLine { x: outline.width - outline.d; y: outline.height - outline.d }
            PathLine { x: outline.d; y: outline.height - outline.d }
            PathLine { x: outline.d; y: outline.d }
        }
    }

    contentItem: ColumnLayout {
        spacing: KanteStyle.unit(4)

        KanteIcon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            iconSource: tile.icon.name !== "" ? tile.icon.name : tile.icon.source
            color: tile.checked ? KanteStyle.focusColor : KanteStyle.textColor
            visible: tile.glyph === "" && (tile.icon.name !== "" || tile.icon.source.toString() !== "")
        }
        Text {
            visible: tile.glyph !== ""
            text: tile.glyph
            color: tile.checked ? KanteStyle.focusColor : KanteStyle.textColor
            font.family: KanteStyle.japaneseFamily
            font.pixelSize: Kirigami.Units.iconSizes.medium
            Accessible.ignored: true
        }
        Item {
            Layout.fillHeight: true
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: tile.text
            font.weight: Font.DemiBold
            color: KanteStyle.strongTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: tile.hint.length > 0
            text: tile.hint
            font: KanteStyle.smallFont
            color: KanteStyle.mutedTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
