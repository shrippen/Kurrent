import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Pick a level (Kante 1.60, for Mitori): a row of equal buttons, each with its number large
 * and its word small under it ("3" / "sure"), the chosen one filled with the accent. For a
 * rating such as how well a technique sits. Unlike KanteSegmented a tap on the chosen level
 * picks it again: rating the same today is a new rating.
 *
 *   count    4 by default; levels are 1..count
 *   value    the chosen level, 0 for none
 *   names    words per level, names[1] for level 1 (names[0], the word for none, is unused)
 *   picked(level)   a tap, Space or Enter; the app sets `value` (presentational)
 *
 * Keyboard: Tab into the row, Left / Right move the focus, Space or Enter picks the focused
 * level. Screen readers hear radio buttons "3 sure", the chosen one checked.
 * Fills the width it is given; implicitly as wide as its widest word needs. Narrower, the words
 * set tight (no letter spacing, `tight`), so "prüfungsreif" stays whole on a small phone; only
 * narrower still they elide inside their buttons.
 */
FocusScope {
    id: picker

    property int count: 4
    property int value: 0
    property var names: []
    signal picked(int level)

    // The level with the keyboard focus (1..count).
    property int focusLevel: Math.max(1, value)

    readonly property real cellWidth: Math.max(KanteStyle.unit(56), widestWord + KanteStyle.unit(12))
    // The widest word in pixels (measured below).
    property real widestWord: 0
    // The room a word has in its button, and whether the words set tight to fit it (Kante's
    // labels only: the platform's small font has no letter spacing to give up).
    readonly property real wordRoom: (width - (count - 1) * row.spacing) / count - KanteStyle.unit(6)
    readonly property bool tight: KanteStyle.active && widestWord > wordRoom
    // The label font without its letter spacing: the same size, never below Kante's 7 pt.
    readonly property font tightFont: {
        const f = KanteStyle.labelFont()
        return Qt.font({ family: f.family, pointSize: f.pointSize, capitalization: f.capitalization, letterSpacing: 0 })
    }

    implicitWidth: count * cellWidth + (count - 1) * row.spacing
    implicitHeight: KanteStyle.unit(52)
    activeFocusOnTab: true

    function nameOf(level) {
        return names && names.length > level ? String(names[level]) : ""
    }

    // Left and right on screen; right to left level 1 stands at the right.
    function moveFocus(dir) {
        focusLevel = Math.max(1, Math.min(count, focusLevel + (LayoutMirroring.enabled ? -dir : dir)))
    }
    Keys.onLeftPressed: moveFocus(-1)
    Keys.onRightPressed: moveFocus(1)
    Keys.onSpacePressed: picked(focusLevel)
    Keys.onReturnPressed: picked(focusLevel)
    Keys.onEnterPressed: picked(focusLevel)
    onValueChanged: if (value > 0) focusLevel = value
    onCountChanged: focusLevel = Math.max(1, Math.min(focusLevel, count))

    // Measures the words, so every cell has room for the widest.
    Repeater {
        id: measure
        model: picker.count
        delegate: Text {
            required property int index
            visible: false
            font: KanteStyle.labelFont()
            text: picker.nameOf(index + 1)
            onImplicitWidthChanged: picker.measureWords()
            Component.onCompleted: picker.measureWords()
        }
    }
    function measureWords() {
        var w = 0
        for (var i = 0; i < measure.count; i++) {
            var t = measure.itemAt(i)
            if (t) {
                w = Math.max(w, t.implicitWidth)
            }
        }
        widestWord = w
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: KanteStyle.unit(6)

        Repeater {
            model: picker.count
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property int level: index + 1
                readonly property bool chosen: picker.value === level
                readonly property bool focused: picker.activeFocus && picker.focusLevel === level
                readonly property color ink: chosen ? KanteStyle.accentForegroundColor : KanteStyle.textColor
                width: (row.width - (picker.count - 1) * row.spacing) / picker.count
                height: row.height
                color: chosen ? KanteStyle.accentColor : (hover.hovered ? KanteStyle.cardColor : KanteStyle.backgroundColor)
                border.width: KanteStyle.borderWidth
                border.color: chosen ? KanteStyle.accentColor : KanteStyle.frameColor
                Behavior on color { ColorAnimation { duration: KanteStyle.durationFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: KanteStyle.unit(1)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cell.level
                        font: KanteStyle.headingFont(15)
                        color: cell.ink
                    }
                    // Narrower than the word: tight first, then the word elides (labels stay at
                    // Kante's 7 pt or more).
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text.length > 0
                        width: Math.min(implicitWidth, cell.width - KanteStyle.unit(6))
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: picker.nameOf(cell.level)
                        font: picker.tight ? picker.tightFont : KanteStyle.labelFont()
                        color: cell.chosen ? cell.ink : KanteStyle.mutedTextColor
                    }
                }
                // Keyboard focus: a ring inside the cell, also on the chosen one.
                Rectangle {
                    visible: cell.focused
                    anchors.fill: parent
                    anchors.margins: KanteStyle.unit(3)
                    color: "transparent"
                    border.width: KanteStyle.borderWidth
                    border.color: cell.chosen ? KanteStyle.accentForegroundColor : KanteStyle.focusColor
                }
                HoverHandler { id: hover }
                TapHandler {
                    onTapped: {
                        picker.focusLevel = cell.level
                        picker.picked(cell.level)
                    }
                }
                Accessible.role: Accessible.RadioButton
                Accessible.name: cell.level + (picker.nameOf(cell.level) ? " " + picker.nameOf(cell.level) : "")
                Accessible.checked: cell.chosen
                Accessible.focused: cell.focused
                Accessible.onPressAction: picker.picked(cell.level)
            }
        }
    }
}
