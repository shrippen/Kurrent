pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Swatch picker (Kante 1.43, from lmix): a row of colour swatches to choose one, such as an
 * input's colour tag in a menu row or a colour source. Each swatch is a `KanteSwatch`; the
 * chosen one gets its selection ring.
 *   colors        the colours (list of color or "#rrggbb")
 *   names         their names for screen readers and tooltips ("Red", …), same order
 *   currentIndex  the chosen one; -1: none
 *   noneText      non-empty: a first swatch "none" (hollow, struck through) that picks -1
 *   size          KanteSwatch.Size (Normal by default; Small in a menu row)
 *   picked(index) a click, Space or Enter on a swatch (-1 for "none")
 * Keyboard: one tab stop; Left / Right move the focus, Space / Enter pick. Screen readers
 * hear each swatch as a radio button with its name. Kante, Kante Light and System alike
 * (a swatch shows a colour in every style).
 */
FocusScope {
    id: picker

    property var colors: []
    property var names: []
    property int currentIndex: -1
    property string noneText: ""
    property int size: KanteSwatch.Size.Normal
    signal picked(int index)

    // Index in the row, "none" first when there is one.
    readonly property int offset: noneText.length > 0 ? 1 : 0
    readonly property int count: colors.length + offset
    property int focusIndex: Math.max(0, currentIndex + offset)
    // The app sets currentIndex (another input chosen): the keyboard frame goes with it.
    onCurrentIndexChanged: if (ready) focusIndex = Math.max(0, currentIndex + offset)
    // The handlers only after creation: while the properties arrive they would see half of
    // them; once complete the frame starts on the chosen cell.
    property bool ready: false
    Component.onCompleted: {
        focusIndex = Math.max(0, Math.min(currentIndex + offset, count - 1))
        ready = true
    }
    // Fewer colours than before: the frame stays on a cell that is there.
    // Colours that come later: the frame goes to the chosen one once it is there.
    onCountChanged: if (ready) focusIndex = Math.max(0, Math.min(currentIndex >= 0 && currentIndex + offset < count
        ? (focusIndex === 0 ? currentIndex + offset : focusIndex) : focusIndex, count - 1))
    // "None" added or taken away: the frame stays on the same colour.
    // (count may not have followed offset yet: the limit from colours and offset.)
    onOffsetChanged: if (ready) focusIndex = Math.max(0, Math.min(focusIndex + (offset > 0 ? 1 : -1), colors.length + offset - 1))

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Grouping

    Keys.onLeftPressed: focusIndex = Math.max(0, focusIndex - 1)
    Keys.onRightPressed: focusIndex = Math.min(count - 1, focusIndex + 1)
    Keys.onSpacePressed: if (count > 0) picked(focusIndex - offset)
    Keys.onReturnPressed: if (count > 0) picked(focusIndex - offset)
    Keys.onEnterPressed: if (count > 0) picked(focusIndex - offset)

    Row {
        id: row
        spacing: KanteStyle.unit(6)

        Repeater {
            model: picker.count

            Item {
                id: cell

                required property int index
                readonly property int pick: cell.index - picker.offset
                readonly property bool none: cell.pick < 0
                readonly property string name: cell.none ? picker.noneText : (picker.names[cell.pick] || String(picker.colors[cell.pick]))

                width: swatch.width + KanteStyle.unit(4)
                height: swatch.height + KanteStyle.unit(4)

                Accessible.role: Accessible.RadioButton
                Accessible.name: name
                Accessible.checkable: true
                Accessible.checked: picker.currentIndex === pick
                Accessible.onPressAction: picker.picked(pick)
                QQC2.ToolTip.visible: hover.hovered && name.length > 0
                QQC2.ToolTip.text: name
                QQC2.ToolTip.delay: 500

                KanteSwatch {
                    id: swatch
                    anchors.centerIn: parent
                    size: picker.size
                    swatchColor: cell.none ? "transparent" : picker.colors[cell.pick]
                    selected: picker.currentIndex === cell.pick
                    onClicked: {
                        picker.focusIndex = cell.index
                        picker.picked(cell.pick)
                    }
                }
                // "None": a hollow square, struck through.
                Rectangle {
                    visible: cell.none
                    anchors.centerIn: parent
                    width: swatch.width
                    height: swatch.height
                    color: "transparent"
                    border.color: KanteStyle.mutedTextColor
                    border.width: 1
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 1.3
                        height: 1
                        rotation: -45
                        color: KanteStyle.mutedTextColor
                    }
                }
                // Keyboard focus: a frame around the swatch.
                Rectangle {
                    visible: picker.activeFocus && picker.focusIndex === cell.index
                    anchors.fill: parent
                    color: "transparent"
                    border.color: KanteStyle.focusColor
                    border.width: 1
                }
                HoverHandler {
                    id: hover
                }
            }
        }
    }
}
