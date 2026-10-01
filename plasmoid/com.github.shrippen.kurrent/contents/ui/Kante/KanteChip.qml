import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Chip: an entity (a tag, a customer) or a filter. A colour square and a name in
 * a 1 px frame of that colour. `checked` fills it (filters, `checkable`);
 * `removable` adds a cross and emits `removeRequested`. Entity colours are
 * squares, never circles.
 *   iconName   an icon after the square, in the chip's ink
 *   compact    only the colour square (dense places: kanban cards); the name is the tooltip
 *   width      a chip narrower than its text elides the name, and squeezed below a few
 *              letters shows only square, icon and cross (the name moves to the tooltip);
 *              a short name at its natural width always shows ("IT")
 * A colour close to the ground (#202020 on dark Kante) would vanish: frame and ink then take
 * the text colour and the square gets a frame (`nearGround`, as KanteSwatch). The cross has a
 * touch target of 32 units without making the chip bigger.
 *   interactive  false: a plain label (a state, a topic): no focus, no tap, no hover
 *   toolTip      shown on hover (a full path behind a short name); without it the name is the
 *                tooltip only while it is elided
 */
Item {
    id: chip

    property string text: ""
    property color chipColor: KanteStyle.tagColor
    property bool checkable: false
    property bool checked: false
    property bool removable: false
    property string iconName: ""
    property bool compact: false
    property string removeText: qsTr("Remove %1")
    property bool interactive: true
    property string toolTip: ""
    readonly property bool hovered: hover.hovered
    signal clicked()
    signal removeRequested()

    readonly property real squareSize: KanteStyle.unit(8)
    readonly property real iconSize: KanteStyle.unit(14)
    readonly property bool nearGround: Math.abs(chipColor.hslLightness - KanteStyle.backgroundColor.hslLightness) < 0.15
    /** Frame and text: the chip colour, or the text colour when it would vanish on the ground. */
    readonly property color ink: checked ? KanteStyle.onStateColor : (nearGround ? KanteStyle.textColor : chipColor)
    readonly property color edge: nearGround ? KanteStyle.frameColor : chipColor
    /** The name is shown (false when compact or squeezed below a few letters). */
    readonly property bool textShown: !compact && textRoom >= Math.min(KanteStyle.unit(20), Math.ceil(labelMetrics.advanceWidth))
    readonly property real textRoom: width - KanteStyle.unit(16) - squareSize - row.spacing
                                     - (iconName !== "" ? iconSize + row.spacing : 0)
                                     - (removable ? cross.implicitWidth + row.spacing : 0)

    implicitHeight: compact ? KanteStyle.unit(14) : KanteStyle.unit(24)
    implicitWidth: compact ? implicitHeight
                           : KanteStyle.unit(16) + squareSize + row.spacing + Math.ceil(labelMetrics.advanceWidth)
                             + (iconName !== "" ? iconSize + row.spacing : 0)
                             + (removable ? cross.implicitWidth + row.spacing : 0)
    activeFocusOnTab: interactive

    // Natural width of the name: the elided label's own implicitWidth follows its width.
    TextMetrics {
        id: labelMetrics
        font: label.font
        text: chip.text
    }

    function activate() {
        if (checkable) {
            checked = !checked
        }
        clicked()
    }

    Keys.onReturnPressed: activate()
    Keys.onSpacePressed: activate()
    Keys.onDeletePressed: {
        if (removable) {
            removeRequested()
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !chip.compact
        color: chip.checked ? chip.chipColor : (hover.hovered && chip.interactive ? KanteStyle.tint1Color : "transparent")
        border.width: 1
        border.color: chip.edge
    }
    // Compact: the colour square alone, framed so dark colours stay visible.
    Rectangle {
        anchors.fill: parent
        visible: chip.compact
        color: chip.chipColor
        border.width: chip.nearGround || chip.checked ? 1 : 0
        border.color: chip.checked ? KanteStyle.strongTextColor : KanteStyle.frameColor
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        visible: chip.activeFocus
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.focusColor
    }

    RowLayout {
        id: row
        visible: !chip.compact
        anchors.fill: parent
        anchors.leftMargin: KanteStyle.unit(8)
        anchors.rightMargin: KanteStyle.unit(8)
        spacing: KanteStyle.unit(6)
        Rectangle {
            id: square
            Layout.preferredWidth: chip.squareSize
            Layout.preferredHeight: chip.squareSize
            Layout.minimumWidth: chip.squareSize
            color: chip.checked ? KanteStyle.onStateColor : chip.chipColor
            border.width: chip.nearGround && !chip.checked ? 1 : 0
            border.color: KanteStyle.textColor
        }
        Kirigami.Icon {
            id: icon
            visible: chip.iconName !== ""
            Layout.preferredWidth: chip.iconSize
            Layout.preferredHeight: chip.iconSize
            Layout.minimumWidth: chip.iconSize
            source: chip.iconName
            color: chip.ink
            isMask: true
        }
        Text {
            id: label
            visible: chip.textShown
            Layout.fillWidth: true
            text: chip.text
            elide: Text.ElideRight
            color: chip.ink
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
        Item { visible: !chip.textShown; Layout.fillWidth: true }
        Text {
            id: cross
            visible: chip.removable
            text: "×"
            color: chip.ink
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)

            // Touch target: 32 units around the cross, outside the chip's own size.
            Item {
                id: crossTarget
                objectName: "crossTarget"
                anchors.centerIn: parent
                width: KanteStyle.unit(32)
                height: KanteStyle.unit(32)
                TapHandler { onTapped: chip.removeRequested() }
                Accessible.role: Accessible.Button
                Accessible.name: chip.removeText.arg(chip.text)
                Accessible.onPressAction: chip.removeRequested()
            }
        }
    }

    HoverHandler { id: hover; cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: chip.interactive; onTapped: chip.activate() }
    QQC2.ToolTip.visible: hover.hovered && (chip.toolTip !== "" || (!chip.textShown && chip.text !== ""))
    QQC2.ToolTip.text: chip.toolTip !== "" ? chip.toolTip : chip.text
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    Accessible.role: !chip.interactive ? Accessible.StaticText : (chip.checkable ? Accessible.CheckBox : Accessible.Button)
    Accessible.name: chip.text
    Accessible.checked: chip.checked
}
