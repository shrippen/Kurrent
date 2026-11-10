import QtQuick
import QtQuick.Shapes
import "."

/**
 * Curve editor: a line through draggable square points, e.g. a fan curve (temperature
 * to speed). `points` is a list of {x, y} in data units, sorted by x. Drag a point,
 * double-tap the plot to add one, Delete (or a double tap on a point) removes it. With the
 * keyboard: [ and ] pick a point, the arrow keys move it by `step`, + adds a point after
 * it. Points cannot cross their neighbours in x; with `monotonic` y never falls. Every
 * change emits `edited(points)`; `points` is not written back (bind it and update it in the slot).
 * The axes are labelled at 0, 25, 50, 75 and 100 % of the range. `markers` is a list of
 * {x, label, color}: live readings (e.g. sensor temperatures) drawn as a rule with a mark on
 * the curve at that x, captioned at the top of the plot; `valueAt(x)` is the curve's y there (flat outside the points).
 */
FocusScope {
    id: ed

    property var points: []
    property real xMin: 0
    property real xMax: 100
    property real yMin: 0
    property real yMax: 100
    property real step: 1
    property bool monotonic: true
    property int minPoints: 2
    property int maxPoints: 12
    property string xUnit: ""
    property string yUnit: ""
    property int current: -1
    property var markers: []
    signal edited(var points)

    readonly property int handle: KanteStyle.unit(14)
    readonly property real padLeft: KanteStyle.unit(40)
    readonly property real padBottom: KanteStyle.unit(22)
    readonly property real plotW: width - padLeft - handle / 2
    readonly property real plotH: height - padBottom - handle / 2

    implicitWidth: KanteStyle.unit(300)
    implicitHeight: KanteStyle.unit(180)
    activeFocusOnTab: true

    function px(x) { return padLeft + (x - xMin) / (xMax - xMin) * plotW }
    function py(y) { return handle / 2 + plotH - (y - yMin) / (yMax - yMin) * plotH }
    function dataX(pxv) { return xMin + (pxv - padLeft) / plotW * (xMax - xMin) }
    function dataY(pyv) { return yMin + (handle / 2 + plotH - pyv) / plotH * (yMax - yMin) }
    function snap(v) { return step > 0 ? Math.round(v / step) * step : v }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    /** The curve's y at x: linear between the points, flat before the first and after the last. */
    function valueAt(x) {
        var n = points.length
        if (n === 0) {
            return yMin
        }
        if (x <= points[0].x) {
            return points[0].y
        }
        for (var i = 1; i < n; i++) {
            if (x <= points[i].x) {
                var a = points[i - 1]
                var b = points[i]
                return b.x > a.x ? a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y) : b.y
            }
        }
        return points[n - 1].y
    }
    function label(v, unit) { return Math.round(v * 10) / 10 + unit }
    function copy() {
        var c = []
        for (var i = 0; i < points.length; i++) {
            c.push({ x: points[i].x, y: points[i].y })
        }
        return c
    }

    /** Move point i to (x, y): snapped, kept between its neighbours, y never falling when monotonic. */
    function setPoint(i, x, y) {
        if (i < 0 || i >= points.length) {
            return
        }
        var c = copy()
        var lo = i > 0 ? c[i - 1].x + step : xMin
        var hi = i < c.length - 1 ? c[i + 1].x - step : xMax
        var ylo = monotonic && i > 0 ? c[i - 1].y : yMin
        var yhi = monotonic && i < c.length - 1 ? c[i + 1].y : yMax
        c[i].x = clamp(snap(x), lo, hi)
        c[i].y = clamp(snap(y), ylo, yhi)
        edited(c)
    }

    /** Insert a point at (x, y) in x order. Returns its index, or -1 when full or too close to another. */
    function addPoint(x, y) {
        if (points.length >= maxPoints) {
            return -1
        }
        var c = copy()
        var xs = clamp(snap(x), xMin, xMax)
        var at = 0
        while (at < c.length && c[at].x < xs) {
            at++
        }
        if ((at < c.length && c[at].x - xs < step) || (at > 0 && xs - c[at - 1].x < step)) {
            return -1
        }
        var ys = clamp(snap(y), yMin, yMax)
        if (monotonic) {
            ys = clamp(ys, at > 0 ? c[at - 1].y : yMin, at < c.length ? c[at].y : yMax)
        }
        c.splice(at, 0, { x: xs, y: ys })
        current = at
        edited(c)
        return at
    }

    function removePoint(i) {
        if (points.length <= minPoints || i < 0 || i >= points.length) {
            return
        }
        var c = copy()
        c.splice(i, 1)
        current = Math.min(current, c.length - 1)
        edited(c)
    }

    Keys.onPressed: function (event) {
        var p = current >= 0 && current < points.length ? points[current] : null
        var handled = true
        if (event.key === Qt.Key_BracketLeft) {
            current = Math.max(0, current - 1)
        } else if (event.key === Qt.Key_BracketRight) {
            current = Math.min(points.length - 1, current + 1)
        } else if (event.key === Qt.Key_Plus && p) {
            var next = current < points.length - 1 ? points[current + 1] : { x: xMax, y: p.y }
            addPoint((p.x + next.x) / 2, (p.y + next.y) / 2)
        } else if (event.key === Qt.Key_Delete && p) {
            removePoint(current)
        } else if (p && event.key === Qt.Key_Left) {
            setPoint(current, p.x - step, p.y)
        } else if (p && event.key === Qt.Key_Right) {
            setPoint(current, p.x + step, p.y)
        } else if (p && event.key === Qt.Key_Up) {
            setPoint(current, p.x, p.y + step)
        } else if (p && event.key === Qt.Key_Down) {
            setPoint(current, p.x, p.y - step)
        } else {
            handled = false
        }
        event.accepted = handled
    }
    onActiveFocusChanged: if (activeFocus && current < 0 && points.length > 0) current = 0

    // Frame and grid.
    Rectangle {
        x: ed.padLeft
        y: ed.handle / 2
        width: ed.plotW
        height: ed.plotH
        color: KanteStyle.sunkenColor
        border.width: 1
        border.color: ed.activeFocus ? KanteStyle.focusColor : KanteStyle.frameColor
    }
    Repeater {
        model: 3
        delegate: Rectangle {
            required property int index
            x: ed.padLeft
            width: ed.plotW
            height: 1
            y: ed.handle / 2 + (index + 1) * ed.plotH / 4
            color: KanteStyle.ruleColor
        }
    }
    Repeater {
        model: 3
        delegate: Rectangle {
            required property int index
            y: ed.handle / 2
            height: ed.plotH
            width: 1
            x: ed.padLeft + (index + 1) * ed.plotW / 4
            color: KanteStyle.ruleColor
        }
    }
    // Axis labels at every grid line.
    Repeater {
        model: 5
        delegate: Text {
            required property int index
            x: ed.padLeft - width - KanteStyle.unit(6)
            y: ed.handle / 2 + ed.plotH - index * ed.plotH / 4 - height / 2
            text: ed.label(ed.yMin + index * (ed.yMax - ed.yMin) / 4, ed.yUnit)
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }
    Repeater {
        model: 5
        delegate: Text {
            required property int index
            x: Math.max(0, Math.min(ed.width - width, ed.padLeft + index * ed.plotW / 4 - width / 2))
            y: ed.height - height
            text: ed.label(ed.xMin + index * (ed.xMax - ed.xMin) / 4, ed.xUnit)
            color: KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }

    // The curve: flat before the first and after the last point, miter joins.
    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: KanteStyle.dataColor(0)
            strokeWidth: 2
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: {
                    var pts = []
                    if (ed.points.length > 0) {
                        pts.push(Qt.point(ed.px(ed.xMin), ed.py(ed.points[0].y)))
                        for (var i = 0; i < ed.points.length; i++) {
                            pts.push(Qt.point(ed.px(ed.points[i].x), ed.py(ed.points[i].y)))
                        }
                        pts.push(Qt.point(ed.px(ed.xMax), ed.py(ed.points[ed.points.length - 1].y)))
                    }
                    return pts
                }
            }
        }
    }

    // Live readings: a rule at x, a mark on the curve, a caption.
    Repeater {
        model: ed.markers
        delegate: Item {
            id: mk
            required property int index
            required property var modelData
            readonly property real mx: ed.px(Math.max(ed.xMin, Math.min(ed.xMax, modelData.x)))
            readonly property real my: ed.py(ed.valueAt(modelData.x))
            Rectangle {
                x: mk.mx
                y: ed.handle / 2
                width: 1
                height: ed.plotH
                color: mk.modelData.color
                opacity: 0.6
            }
            Rectangle {
                x: mk.mx - width / 2
                y: mk.my - height / 2
                width: KanteStyle.unit(8)
                height: width
                color: mk.modelData.color
            }
            // The caption sits at the top of the plot, one line lower per marker, so it never covers the curve.
            Text {
                x: mk.mx + width + KanteStyle.unit(10) > ed.padLeft + ed.plotW ? mk.mx - width - KanteStyle.unit(6) : mk.mx + KanteStyle.unit(6)
                y: ed.handle / 2 + KanteStyle.unit(4) + mk.index * (height + KanteStyle.unit(2))
                text: mk.modelData.label ? mk.modelData.label : ""
                color: mk.modelData.color
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
            }
        }
    }

    // Add on double tap.
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onDoubleTapped: function (point) {
            ed.forceActiveFocus()
            ed.addPoint(ed.dataX(point.position.x), ed.dataY(point.position.y))
        }
        onSingleTapped: ed.forceActiveFocus()
    }

    Repeater {
        model: ed.points.length
        delegate: Rectangle {
            id: dot
            required property int index
            readonly property bool selected: ed.current === index
            width: ed.handle
            height: ed.handle
            x: ed.px(ed.points[index].x) - width / 2
            y: ed.py(ed.points[index].y) - height / 2
            // Not a data colour: the handles must not read as a series of a chart next to it.
            color: selected ? KanteStyle.strongTextColor : KanteStyle.cardColor
            border.width: 2
            border.color: selected ? KanteStyle.focusColor : KanteStyle.strongTextColor
            z: selected ? 2 : 1

            DragHandler {
                target: null
                onActiveChanged: if (active) ed.current = dot.index
                onCentroidChanged: {
                    if (active) {
                        var p = dot.mapToItem(ed, centroid.position.x, centroid.position.y)
                        ed.setPoint(dot.index, ed.dataX(p.x), ed.dataY(p.y))
                    }
                }
            }
            TapHandler {
                onTapped: { ed.forceActiveFocus(); ed.current = dot.index }
                onDoubleTapped: ed.removePoint(dot.index)
            }
            Accessible.role: Accessible.Slider
            Accessible.name: ed.points[index].x + ed.xUnit + " " + ed.points[index].y + ed.yUnit
        }
    }

    // Readout of the selected point.
    Rectangle {
        visible: ed.current >= 0 && ed.current < ed.points.length
        x: ed.padLeft + KanteStyle.unit(8)
        y: ed.handle / 2 + KanteStyle.unit(6)
        width: readout.implicitWidth + KanteStyle.unit(14)
        height: readout.implicitHeight + KanteStyle.unit(6)
        color: KanteStyle.dialogColor
        border.width: 1
        border.color: KanteStyle.frameColor
        Text {
            id: readout
            anchors.centerIn: parent
            text: ed.current >= 0 && ed.current < ed.points.length ? ed.points[ed.current].x + ed.xUnit + "  →  " + ed.points[ed.current].y + ed.yUnit : ""
            color: KanteStyle.textColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
    }
}
