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
    signal edited(var points)

    readonly property int handle: KanteStyle.unit(14)
    readonly property real padLeft: KanteStyle.unit(30)
    readonly property real padBottom: KanteStyle.unit(18)
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
    // Axis labels.
    Text { x: 0; y: ed.py(ed.yMax) - height / 2; text: ed.yMax + ed.yUnit; color: KanteStyle.mutedTextColor; font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false) }
    Text { x: 0; y: ed.py(ed.yMin) - height / 2; text: ed.yMin + ed.yUnit; color: KanteStyle.mutedTextColor; font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false) }
    Text { x: ed.px(ed.xMin); y: ed.height - height; text: ed.xMin + ed.xUnit; color: KanteStyle.mutedTextColor; font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false) }
    Text { x: ed.px(ed.xMax) - width; y: ed.height - height; text: ed.xMax + ed.xUnit; color: KanteStyle.mutedTextColor; font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false) }

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
            color: selected ? KanteStyle.accentColor : KanteStyle.cardColor
            border.width: 2
            border.color: selected ? KanteStyle.focusColor : KanteStyle.accentColor
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
