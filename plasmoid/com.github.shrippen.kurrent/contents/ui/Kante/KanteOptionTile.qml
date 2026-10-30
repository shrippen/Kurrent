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
 *   hint      one short line under it ("Capture, webcam")
 *   checked   chosen; tiles of one group are `autoExclusive` (default true)
 * Chosen: the selection tint and a 2 px frame in the focus colour; hover: tint step 1;
 * keyboard focus: a 1 px ring inside, also on the chosen tile (further in). Screen readers hear a radio button with name and hint.
 * Kante and Kante Light cut the top right corner; System: square, platform colours.
 */
QQC2.AbstractButton {
    id: tile

    property string hint: ""

    checkable: true
    autoExclusive: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    padding: KanteStyle.unit(10)

    implicitWidth: Math.max(KanteStyle.unit(116), implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(KanteStyle.unit(84), implicitContentHeight + topPadding + bottomPadding)

    Accessible.role: Accessible.RadioButton
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

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            source: tile.icon.name !== "" ? tile.icon.name : tile.icon.source
            color: tile.checked ? KanteStyle.focusColor : KanteStyle.textColor
            isMask: true
            visible: tile.icon.name !== "" || tile.icon.source.toString() !== ""
        }
        Item {
            Layout.fillHeight: true
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: tile.text
            font.weight: Font.DemiBold
            color: KanteStyle.strongTextColor
            elide: Text.ElideRight
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: tile.hint.length > 0
            text: tile.hint
            font: KanteStyle.smallFont
            color: KanteStyle.mutedTextColor
            elide: Text.ElideRight
        }
    }
}
