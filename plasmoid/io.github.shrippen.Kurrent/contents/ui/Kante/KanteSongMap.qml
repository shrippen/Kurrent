pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Song map (Kante 1.76, from Kontra's LH-FOR-06): a strip over a whole piece, one column per
 * bar, its height the value of the bar (e.g. the hit rate over the last runs). Weak bars show
 * as low columns at a glance; dragging over bars (or Shift + arrows) chooses a range, e.g. the
 * loop to practise. Meant for between runs, not while playing.
 *
 *   ▁▃█▇▅▂▂▇██▆▃  ← height = value, colour on the KanteHeatGrid scale (levelColor)
 *   └──┘          ← the chosen range, framed in the focus colour, bars underlined
 *   1   5   9     ← bar numbers every `labelEvery` bars
 *
 *   values      one entry per bar: a number from minValue to maxValue, or null (no data:
 *               a flat dashed mark at the floor, never a zero)
 *   labels      bar names ("1", "2", … default the bar number from 1)
 *   tips        tooltip and accessible text per bar; default "<barText> <label>: <value>"
 *   barText     the word for a bar in the default tips ("Takt"); noDataText when null
 *   formatter   function (value) -> string; default a share as whole percent ("82 %")
 *   minValue, maxValue   the scale (default 0 and 1)
 *   selectionFrom, selectionTo   the chosen range (bar indices, -1: none), drawn framed.
 *               A shorter piece cuts the range at its last bar, or clears it (-1) when no
 *               bar of it is left, without rangeChosen: a loop bound to it never names a
 *               bar that does not exist
 *   interactive Tab focuses the current bar; Left / Right move, Home / End go to the ends,
 *               Shift with them extends the range from the anchor, Enter / Space choose it
 *               (rangeChosen); a press and drag over bars chooses the range dragged
 *
 * The height carries the value and the tooltip says it as a number, so the colour is never
 * the only sign. A narrow strip on a long song keeps each bar at least `minBarWidth` wide
 * and scrolls sideways; the focused bar is scrolled into view. Otherwise the view starts at
 * bar 1 (mirrored: at the right end) and keeps its distance from bar 1 (`viewFromStart`) on a
 * new width or direction; another number of bars starts at bar 1 again.
 */
FocusScope {
    id: strip

    property var values: []
    property var labels: []
    property var tips: []
    property string barText: "Takt"
    property string noDataText: "noch nicht gespielt"
    property var formatter: null
    property real minValue: 0
    property real maxValue: 1
    property int selectionFrom: -1
    property int selectionTo: -1
    property bool interactive: true
    /** A bar number under every `labelEvery`-th bar (and the first). */
    property int labelEvery: 4
    property real minBarWidth: KanteStyle.unit(6)
    property real barHeight: KanteStyle.unit(48)
    property real spacing: KanteStyle.unit(2)
    /** The focused (or last focused) bar. */
    property int currentIndex: 0
    property string accessibleName: ""

    /** A range was dragged over or chosen with the keys: bar indices, from ≤ to. */
    signal rangeChosen(int from, int to)

    readonly property int count: values ? values.length : 0
    /** Start of a range chosen with Shift and the arrows. */
    property int anchorIndex: -1
    /** Bar under the press while dragging, -1 otherwise. */
    property int pressIndex: -1

    readonly property font labelFont: KanteStyle.labelFont()
    readonly property real labelHeight: labelMetrics.height + KanteStyle.unit(4)
    readonly property real barWidth: count > 0
        ? Math.max(minBarWidth, (width - spacing * (count - 1)) / count) : minBarWidth
    readonly property real stripWidth: count > 0 ? count * barWidth + (count - 1) * spacing : 0
    readonly property int lowIndex: Math.min(selectionFrom, selectionTo)
    readonly property int highIndex: Math.max(selectionFrom, selectionTo)
    readonly property bool mirrored: LayoutMirroring.enabled

    // A shorter piece: focus, anchor and range stay on bars that exist.
    // E.g. range 1..5, then 3 bars: 1..2; range 2..2, then 2 bars: none (-1).
    onCountChanged: {
        currentIndex = Math.max(0, Math.min(currentIndex, count - 1))
        anchorIndex = -1
        fitRange()
        // Another number of bars starts at bar 1.
        viewFromStart = 0
    }

    /** How far the view is scrolled away from bar 1, in either direction. */
    property real viewFromStart: 0

    // A new size, length or direction: the focused bar stays in view, else the view keeps its
    // distance from bar 1 (bar 1 shows on another number of bars).
    onStripWidthChanged: placeView()
    onWidthChanged: placeView()
    onMirroredChanged: placeView()

    implicitWidth: stripWidth
    implicitHeight: barHeight + labelHeight + (flick.contentWidth > flick.width ? KanteStyle.unit(8) : 0)
    activeFocusOnTab: interactive && count > 0

    Accessible.role: Accessible.List
    Accessible.name: accessibleName

    function valueOf(i) {
        const v = values && i >= 0 && i < values.length ? values[i] : null
        return v === null || v === undefined || isNaN(Number(v)) ? NaN : Number(v)
    }
    function share(v) {
        const span = maxValue - minValue
        return span > 0 ? Math.max(0, Math.min(1, (v - minValue) / span)) : 0
    }
    function levelOf(v) {
        return isNaN(v) ? 0 : Math.round(share(v) * 4)
    }
    function format(v) {
        if (formatter) {
            return formatter(v)
        }
        return Math.round(share(v) * 100) + " %"
    }
    function labelOf(i) {
        return labels && i < labels.length ? String(labels[i]) : String(i + 1)
    }
    function tipOf(i) {
        if (tips && i < tips.length && tips[i]) {
            return String(tips[i])
        }
        const v = valueOf(i)
        return barText + " " + labelOf(i) + ": " + (isNaN(v) ? noDataText : format(v))
    }
    function selected(i) {
        return selectionFrom >= 0 && selectionTo >= 0 && i >= lowIndex && i <= highIndex
    }
    /** Left edge of bar i; mirrored, the first bar stands on the right. */
    function barX(i) {
        const left = i * (barWidth + spacing)
        return mirrored ? stripWidth - barWidth - left : left
    }
    function indexAt(x) {
        const along = mirrored ? stripWidth - x : x
        const i = Math.floor((along + spacing / 2) / (barWidth + spacing))
        return Math.max(0, Math.min(count - 1, i))
    }
    function choose(from, to) {
        selectionFrom = Math.min(from, to)
        selectionTo = Math.max(from, to)
        rangeChosen(selectionFrom, selectionTo)
    }
    function moveTo(i, extend) {
        const next = Math.max(0, Math.min(count - 1, i))
        if (extend) {
            if (anchorIndex < 0) {
                anchorIndex = currentIndex
            }
            selectionFrom = Math.min(anchorIndex, next)
            selectionTo = Math.max(anchorIndex, next)
        } else {
            anchorIndex = -1
        }
        currentIndex = next
        keepInView()
    }
    function fitRange() {
        if (selectionFrom < 0 || selectionTo < 0) {
            return
        }
        if (lowIndex >= count) {
            selectionFrom = -1
            selectionTo = -1
            return
        }
        selectionFrom = Math.min(selectionFrom, count - 1)
        selectionTo = Math.min(selectionTo, count - 1)
    }
    function placeView() {
        if (activeFocus) {
            keepInView()
            return
        }
        // Mirrored, bar 1 stands at the right end of the strip.
        const room = Math.max(0, stripWidth - width)
        const away = Math.max(0, Math.min(viewFromStart, room))
        flick.contentX = mirrored ? room - away : away
    }
    function keepInView() {
        const left = barX(currentIndex)
        if (left < flick.contentX) {
            flick.contentX = left
        } else if (left + barWidth > flick.contentX + flick.width) {
            flick.contentX = left + barWidth - flick.width
        }
    }

    Keys.onPressed: function (event) {
        if (!interactive || count === 0) {
            return
        }
        const extend = (event.modifiers & Qt.ShiftModifier) !== 0
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const step = (event.key === Qt.Key_Right) !== strip.mirrored ? 1 : -1
            moveTo(currentIndex + step, extend)
        } else if (event.key === Qt.Key_Home) {
            moveTo(0, extend)
        } else if (event.key === Qt.Key_End) {
            moveTo(count - 1, extend)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            const ranged = anchorIndex >= 0 && selected(currentIndex)
            choose(ranged ? lowIndex : currentIndex, ranged ? highIndex : currentIndex)
            anchorIndex = -1
        } else {
            return
        }
        event.accepted = true
    }

    TextMetrics {
        id: labelMetrics
        font: strip.labelFont
        text: "0"
    }

    Flickable {
        id: flick
        anchors.fill: parent
        onContentXChanged: strip.viewFromStart = strip.mirrored
            ? Math.max(0, strip.stripWidth - strip.width) - contentX : contentX
        contentWidth: strip.stripWidth
        contentHeight: height
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
            policy: flick.contentWidth > flick.width ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff
        }

        // The floor of the scale.
        Rectangle {
            x: 0
            y: strip.barHeight
            width: strip.stripWidth
            height: KanteStyle.borderWidth
            color: KanteStyle.ruleColor
        }

        Repeater {
            id: bars
            model: strip.count
            delegate: Item {
                id: bar
                required property int index
                readonly property real value: strip.valueOf(index)
                readonly property bool empty: isNaN(value)
                readonly property bool current: strip.currentIndex === index
                objectName: "kanteSongMapBar"
                x: strip.barX(index)
                width: strip.barWidth
                height: strip.barHeight + strip.labelHeight

                Accessible.role: Accessible.ListItem
                Accessible.name: strip.tipOf(index)
                Accessible.selected: strip.selected(index)
                Accessible.focused: current && strip.activeFocus

                QQC2.ToolTip.text: strip.tipOf(index)
                QQC2.ToolTip.visible: hover.hovered || (current && strip.activeFocus)
                QQC2.ToolTip.delay: hover.hovered ? 300 : 0

                HoverHandler {
                    id: hover
                }

                // The chosen range: a tint behind the bar.
                Rectangle {
                    width: parent.width + strip.spacing
                    x: -strip.spacing / 2
                    height: strip.barHeight
                    visible: strip.selected(bar.index)
                    color: KanteStyle.tintHighlightColor
                }

                // The value as height; at least a sliver above the floor.
                Rectangle {
                    objectName: "kanteSongMapFill"
                    visible: !bar.empty
                    width: parent.width
                    height: Math.max(KanteStyle.borderWidth * 2, strip.share(bar.value) * strip.barHeight)
                    y: strip.barHeight - height
                    color: KanteStyle.levelColor(Math.max(1, strip.levelOf(bar.value)), 4)
                    border.width: strip.levelOf(bar.value) === 0 ? KanteStyle.borderWidth : 0
                    border.color: KanteStyle.frameColor
                }

                // No data: a dashed mark on the floor, not a zero.
                Row {
                    visible: bar.empty
                    y: strip.barHeight - KanteStyle.borderWidth * 3
                    spacing: KanteStyle.borderWidth
                    Repeater {
                        model: Math.max(1, Math.floor(bar.width / (KanteStyle.borderWidth * 2)))
                        delegate: Rectangle {
                            required property int index
                            width: KanteStyle.borderWidth
                            height: KanteStyle.borderWidth
                            color: index % 2 === 0 ? KanteStyle.mutedTextColor : "transparent"
                        }
                    }
                }

                // Underline of a chosen bar, so the range shows without colour too.
                Rectangle {
                    visible: strip.selected(bar.index)
                    y: strip.barHeight + KanteStyle.borderWidth
                    width: parent.width
                    height: KanteStyle.lineWidth
                    color: KanteStyle.focusColor
                }

                // Focus ring around the current bar.
                Rectangle {
                    visible: bar.current && strip.activeFocus
                    anchors.fill: parent
                    anchors.bottomMargin: strip.labelHeight - KanteStyle.lineWidth * 2
                    color: "transparent"
                    border.width: KanteStyle.lineWidth
                    border.color: KanteStyle.focusColor
                }

                Text {
                    visible: bar.index === 0 || (bar.index + 1) % strip.labelEvery === 0
                    y: strip.barHeight + KanteStyle.unit(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: strip.labelOf(bar.index)
                    font: strip.labelFont
                    color: KanteStyle.mutedTextColor
                    Accessible.ignored: true
                }
            }
        }

        // Press and drag over bars: the range follows the pointer, release chooses it.
        MouseArea {
            width: strip.stripWidth
            height: strip.barHeight + strip.labelHeight
            enabled: strip.interactive
            hoverEnabled: false
            onPressed: function (mouse) {
                strip.forceActiveFocus()
                strip.pressIndex = strip.indexAt(mouse.x)
                strip.currentIndex = strip.pressIndex
                strip.selectionFrom = strip.pressIndex
                strip.selectionTo = strip.pressIndex
            }
            onPositionChanged: function (mouse) {
                if (strip.pressIndex < 0) {
                    return
                }
                strip.currentIndex = strip.indexAt(mouse.x)
                strip.selectionFrom = Math.min(strip.pressIndex, strip.currentIndex)
                strip.selectionTo = Math.max(strip.pressIndex, strip.currentIndex)
            }
            onReleased: {
                if (strip.pressIndex < 0) {
                    return
                }
                // Enter afterwards confirms the dragged range, not just the last bar.
                strip.anchorIndex = strip.pressIndex
                strip.pressIndex = -1
                strip.choose(strip.selectionFrom, strip.selectionTo)
            }
            onCanceled: strip.pressIndex = -1
        }
    }
}
