import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Scatter chart (from Klecks): points on an x / y plane, e.g. a sparse point cloud and its
 * cameras seen from above. Drawn in one Canvas, batched by shape and colour, so 20 000 points
 * stay cheap; only the hovered or focused point gets items of its own (ring, tooltip).
 *
 *   yTitle (unit)
 *   4 ┼ · ·  ·   ▲         · dot   ▲ triangle (turned by `angle`)   + cross
 *   2 ┼  · ▪ · +   ·       colour: `valueKey` on a sequential scale, else `series`,
 *   0 ┼──┼───┼───┼──       else `pointColor`
 *      0   2   4  xTitle (unit)
 *   legend  ■ series  ▤ 1–5  ▥ 5–10 …
 *
 *   points      [{ x, y, series, shape, label, size, angle }]: `shape` "dot" (default; a
 *               square in the Kante style, round elsewhere, as KanteStyle.markerRadius),
 *               "triangle" or "cross"; `size` scales the mark (default 1); `angle` turns a
 *               triangle, in degrees counter-clockwise from +x (default 90: up), e.g. a
 *               camera's view direction; `label` names the point in the tooltip
 *   valueKey    a field of the points ("views") that colours them on a scale of four levels
 *               (KanteStyle.levelColor) between `minValue` and `maxValue` (NaN: from the
 *               points); a point without that field takes its series colour
 *   seriesNames names of the series for the legend ("Kameras"); "" leaves one out
 *   equalAspect the same unit per pixel on both axes (a map, a top view); the shorter axis
 *               grows, centred, and both axes tick at the same step
 *   xMin, xMax, yMin, yMax   fixed ends (NaN: from the points, rounded out to a step)
 *   xTitle, yTitle, xUnit, yUnit   axis names; the unit follows the title in brackets and the
 *               numbers in the tooltip ("1,2 m"); `unit` sets both units
 *   legend      a KanteLegend under the chart (default true when it has entries):
 *               a key per series name, then one per level ("1–5") after `valueTitle`;
 *               when all points have one value (no fixed end), only that value ("5")
 *   interactive Tab focuses a point; the arrows go to the nearest point in their direction,
 *               Home / End to the first and last point of `points`, Enter / Space or a click
 *               fire activated(index)
 *
 * Tooltip on hover and on focus (`tipOf(i)`): label, the coordinates, and the value. Marks are
 * drawn dots first, then crosses, then triangles, each by ascending level, so the cameras and
 * the strongest points lie on top. The x axis is data, so it is not mirrored right to left.
 */
Item {
    id: chart

    property var points: []
    property string valueKey: ""
    property real minValue: NaN
    property real maxValue: NaN
    /** The first level starts at the lowest value (`minValue`, else the points') instead of a
     *  multiple of the step rounded down: "3–23", not "0–20". Default off. */
    property bool exactLevelStart: false
    /** The top level reads "≥ n" (n its start) and holds every value above, instead of a
     *  closed range that may reach past the highest value. Default off. */
    property bool openTopLevel: false
    /** Whole-number levels, for counts ("views"): steps are whole numbers (at least 1), keys
     *  have no decimals ("3", "3–5"), and values spanning fewer integers than `levels` get
     *  only as many levels as integers, the top ones of the scale. Default off. */
    property bool integerLevels: false
    property string valueTitle: ""
    property var seriesNames: []
    property bool equalAspect: false
    property real xMin: NaN
    property real xMax: NaN
    property real yMin: NaN
    property real yMax: NaN
    property string xTitle: ""
    property string yTitle: ""
    property string unit: ""
    property string xUnit: unit
    property string yUnit: unit
    /** function (value) -> string for the tooltip and the legend; default by locale. */
    property var formatter: null
    /** Colour of a point without value and series. */
    property color pointColor: KanteStyle.dataColor(0)
    /** Base of the value scale (level 4 is this colour, lower levels fade it). */
    property color scaleColor: KanteStyle.focusColor
    /** Side of a dot at size 1; a cross is 1.5 times, a triangle 2.5 times as large. */
    property real pointSize: KanteStyle.unit(4)
    property bool legend: legendModel.length > 0
    property bool interactive: true
    property string accessibleName: ""
    /** The focused (or last focused) point; -1 for none. */
    property int currentIndex: -1
    /** The point under the pointer; -1 for none. */
    property int hoverIndex: -1

    signal activated(int index)

    readonly property int count: points ? points.length : 0
    readonly property int levels: 4
    /** Levels in use: `levels`, or fewer with `integerLevels` when the values span fewer integers. */
    readonly property int levelCount: levelScale.count
    readonly property bool valued: valueKey !== "" && isFinite(valueRange.low) && isFinite(valueRange.high)

    // Layout: y labels on the left, a title row above, x labels and title below, legend last.
    readonly property real captionHeight: captionProbe.implicitHeight
    readonly property real padLeft: KanteStyle.unit(44)
    readonly property real padRight: KanteStyle.unit(12)
    readonly property real padTop: (yCaption !== "" ? captionHeight + KanteStyle.unit(4) : 0) + KanteStyle.unit(4)
    readonly property real legendHeight: legend && legendModel.length > 0 ? legendView.implicitHeight + KanteStyle.unit(8) : 0
    readonly property real padBottom: captionHeight + KanteStyle.unit(6)
        + (xCaption !== "" ? captionHeight + KanteStyle.unit(2) : 0) + legendHeight
    readonly property real plotWidth: Math.max(1, width - padLeft - padRight)
    readonly property real plotHeight: Math.max(1, height - padTop - padBottom)
    /** Room inside the plot, so a mark on the edge of the range shows whole (a triangle's tip too). */
    readonly property real inset: Math.max(KanteStyle.unit(6), Math.ceil(pointSize * bounds.mark * 0.6))
    readonly property string xCaption: caption(xTitle, xUnit)
    readonly property string yCaption: caption(yTitle, yUnit)

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: KanteStyle.unit(240)
    activeFocusOnTab: interactive && count > 0

    Accessible.role: Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: activeFocus && currentIndex >= 0 ? tipOf(currentIndex) : ""

    // ── Data range ──────────────────────────────────────────────────────

    /** Extent of the points: { x0, x1, y0, y1, mark }; an empty chart spans 0..1. `mark`: largest mark in point sizes. */
    readonly property var bounds: {
        let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity, mark = 1
        for (let i = 0; i < count; i++) {
            const p = points[i]
            if (!p || !isFinite(p.x) || !isFinite(p.y)) {
                continue
            }
            x0 = Math.min(x0, p.x)
            x1 = Math.max(x1, p.x)
            y0 = Math.min(y0, p.y)
            y1 = Math.max(y1, p.y)
            mark = Math.max(mark, markScale(p))
        }
        if (x0 > x1) {
            return { x0: 0, x1: 1, y0: 0, y1: 1, mark: 1 }
        }
        return { x0: x0, x1: x1, y0: y0, y1: y1, mark: mark }
    }
    /** Ends of the value scale: { low, high }; NaN without values. */
    readonly property var valueRange: {
        let lo = Infinity, hi = -Infinity
        for (let i = 0; valueKey !== "" && i < count; i++) {
            const v = rawValue(i)
            if (!isFinite(v)) {
                continue
            }
            lo = Math.min(lo, v)
            hi = Math.max(hi, v)
        }
        return {
            low: isFinite(minValue) ? minValue : (lo <= hi ? lo : NaN),
            high: isFinite(maxValue) ? maxValue : (lo <= hi ? hi : NaN)
        }
    }

    /**
     * The axes: { x0, x1, y0, y1, xStep, yStep }. Ends round out to a 1-2-2.5-5 step; with
     * `equalAspect` the shorter axis grows around its centre until a unit is as long on
     * both, and both tick at the larger step. E.g. x 0..10, y 0..2 in a square plot:
     * y becomes −4..6.
     */
    readonly property var axes: {
        const w = Math.max(1, plotWidth - 2 * inset)
        const h = Math.max(1, plotHeight - 2 * inset)
        const tx = Math.max(2, Math.floor(w / KanteStyle.unit(70)))
        const ty = Math.max(2, Math.floor(h / KanteStyle.unit(40)))
        const xs = axisOf(isFinite(xMin) ? xMin : bounds.x0, isFinite(xMax) ? xMax : bounds.x1,
                          isFinite(xMin), isFinite(xMax), tx)
        const ys = axisOf(isFinite(yMin) ? yMin : bounds.y0, isFinite(yMax) ? yMax : bounds.y1,
                          isFinite(yMin), isFinite(yMax), ty)
        if (!equalAspect) {
            return { x0: xs.lo, x1: xs.hi, y0: ys.lo, y1: ys.hi, xStep: xs.step, yStep: ys.step }
        }
        // Same units per pixel: the axis with fewer pixels per unit sets the scale.
        const perPx = Math.max((xs.hi - xs.lo) / w, (ys.hi - ys.lo) / h)
        const xc = (xs.lo + xs.hi) / 2
        const yc = (ys.lo + ys.hi) / 2
        const step = Math.max(KanteStyle.niceStep(perPx * w / tx), KanteStyle.niceStep(perPx * h / ty))
        return {
            x0: xc - perPx * w / 2, x1: xc + perPx * w / 2,
            y0: yc - perPx * h / 2, y1: yc + perPx * h / 2,
            xStep: step, yStep: step
        }
    }
    readonly property var xTicks: ticksOf(axes.x0, axes.x1, axes.xStep)
    readonly property var yTicks: ticksOf(axes.y0, axes.y1, axes.yStep)
    readonly property int xDecimals: decimalsOf(axes.xStep)
    readonly property int yDecimals: decimalsOf(axes.yStep)

    /**
     * The value levels: `levels` steps of a nice size from a multiple of the step, grown to
     * the next nice step until the top bound reaches the highest value. The legend shows
     * exactly these bounds and `levelOf` uses them. The scale may reach past the highest
     * value, so a top level can stay empty. Without a fixed end, one value (or all equal)
     * takes the top level and the legend shows only that value. `exactLevelStart` starts the
     * first level at the lowest value itself. `openTopLevel` writes the top key as "≥ n" and
     * shrinks the step until that start is not above the highest value, so all bounds and
     * `levelOf` change with it (`levelOf` always puts values above the last bound on the top
     * level). `integerLevels`
     * works on whole numbers: `count` levels (at most `levels`), a step of at least 1, a
     * level key ends on the integer before the next level's start.
     */
    readonly property var levelScale: {
        const whole = integerLevels
        const low = whole ? Math.floor(valueRange.low) : valueRange.low
        const high = whole ? Math.ceil(valueRange.high) : valueRange.high
        // Integers from low to high; fewer than `levels` of them: one level each.
        const count = whole ? Math.max(1, Math.min(levels, high - low + 1)) : levels
        const wholeStep = st => whole ? Math.max(1, Math.ceil(st)) : st
        let step = wholeStep(KanteStyle.niceStep(whole ? (high - low + 1) / count : (high - low) / levels))
        const startOf = st => exactLevelStart ? low : Math.floor(low / st) * st
        let start = startOf(step)
        // Whole numbers: the highest value is itself in the top level, so its bound lies above.
        const short = () => whole ? start + count * step <= high : start + count * step < high
        while (short()) {
            step = wholeStep(KanteStyle.niceStep(step * 1.01))
            start = startOf(step)
        }
        // An open top level starts at or below the highest value: it is never an empty "≥ n".
        // Exact start 3, top 60: step 20 would give "≥ 63", so step 10 gives "≥ 33".
        while (openTopLevel && high > low && step > (whole ? 1 : 0) && start + (count - 1) * step > high) {
            // Whole numbers round down (2.5 -> 2): rounding up could return the old step.
            const smaller = niceStepBelow(step * 0.99)
            const next = whole ? Math.max(1, Math.floor(smaller)) : smaller
            if (!(next < step)) {
                break
            }
            step = next
            start = startOf(step)
        }
        if (!(high > low)) {
            // One value: nothing to compare with, so it takes the top level (full colour).
            start -= (count - 1) * step
        }
        return { start: start, step: step, count: count }
    }
    readonly property real levelStep: levelScale.step

    /** The legend's entries as KanteLegend takes them ({color, text}). */
    readonly property var legendModel: {
        const out = []
        for (let s = 0; s < seriesNames.length; s++) {
            if (seriesNames[s] === "") {
                continue
            }
            out.push({ color: KanteStyle.dataColor(s), text: String(seriesNames[s]) })
        }
        if (!valued) {
            return out
        }
        const digits = integerLevels ? 0 : decimalsOf(levelStep)
        const offset = levels - levelCount
        if (!isFinite(minValue) && !isFinite(maxValue) && !(valueRange.high > valueRange.low)) {
            // All points have one value: no ranges to tell apart, just that value in its
            // colour, written as the tooltip writes it. A fixed end keeps the level keys.
            const v = valueRange.high
            out.push({ color: KanteStyle.levelColor(levelOf(v), levels, scaleColor),
                       text: numberText(v, Number.isInteger(v) ? 0 : 2) })
            return out
        }
        for (let k = 1; k <= levelCount; k++) {
            const lo = levelScale.start + (k - 1) * levelStep
            const hi = levelScale.start + k * levelStep
            const open = openTopLevel && k === levelCount
            // Whole numbers: a key ends on the last integer it holds, "3" when that is one.
            const last = hi - 1
            const range = integerLevels && last <= lo ? numberText(lo, digits)
                : numberText(lo, digits) + "–" + numberText(integerLevels ? last : hi, digits)
            out.push({ color: KanteStyle.levelColor(offset + k, levels, scaleColor),
                       text: open ? "≥ " + numberText(lo, digits) : range })
        }
        return out
    }

    function caption(title, u) {
        if (u === "") {
            return title
        }
        return title === "" ? u : title + " (" + u + ")"
    }
    /** 1-2-2.5-5 step at most `raw`. */
    function niceStepBelow(raw) {
        const p10 = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10))
        const f = raw / p10
        return (f >= 5 ? 5 : f >= 2.5 ? 2.5 : f >= 2 ? 2 : 1) * p10
    }
    /**
     * One axis: ends rounded out to its step unless fixed; an empty span (one value, or the
     * points beyond a fixed end) grows by one on the free side, by ±0.5 when both are free
     * or both fixed. A fixed end never moves.
     */
    function axisOf(lo, hi, fixedLo, fixedHi, ticks) {
        if (!(hi > lo)) {
            if (fixedLo !== fixedHi) {
                hi = fixedLo ? lo + 1 : hi
                lo = fixedLo ? lo : hi - 1
            } else {
                lo -= 0.5
                hi += 0.5
            }
        }
        const step = KanteStyle.niceStep((hi - lo) / ticks)
        return {
            lo: fixedLo ? lo : Math.floor(lo / step + 1e-9) * step,
            hi: fixedHi ? hi : Math.ceil(hi / step - 1e-9) * step,
            step: step
        }
    }
    function ticksOf(lo, hi, step) {
        const out = []
        for (let v = Math.ceil(lo / step - 1e-9) * step; v <= hi + step * 1e-9 && out.length < 100; v += step) {
            out.push(Math.abs(v) < step * 1e-9 ? 0 : v)
        }
        return out
    }
    /** Decimals a step needs: 2 → 0, 2.5 → 1, 0.25 → 2. */
    function decimalsOf(step) {
        let d = 0
        while (d < 6 && Math.abs(step * Math.pow(10, d) - Math.round(step * Math.pow(10, d))) > 1e-6) {
            d++
        }
        return d
    }
    function numberText(v, digits) {
        if (formatter) {
            return formatter(v)
        }
        return Number(v).toLocaleString(Qt.locale(), 'f', digits)
    }

    // ── Mapping ─────────────────────────────────────────────────────────

    /** x of a value in the chart's coordinates. */
    function xOf(v) {
        return padLeft + inset + (v - axes.x0) / (axes.x1 - axes.x0) * (plotWidth - 2 * inset)
    }
    /** y of a value in the chart's coordinates (up is larger). */
    function yOf(v) {
        return padTop + inset + (axes.y1 - v) / (axes.y1 - axes.y0) * (plotHeight - 2 * inset)
    }
    function rawValue(i) {
        const p = points[i]
        return p && valueKey !== "" && p[valueKey] !== undefined && p[valueKey] !== null ? Number(p[valueKey]) : NaN
    }
    /** Level 1..4 of a value on the scale; 0 without a value. */
    function levelOf(v) {
        if (!isFinite(v) || !valued) {
            return 0
        }
        // 1e-9: 0.3 / 0.1 is 2.9999… and still belongs to the level starting at 0.3.
        const index = Math.floor((v - levelScale.start) / levelStep + 1e-9)
        // Fewer levels than `levels` take the top colours, as one value does.
        return levels - levelCount + Math.max(1, Math.min(levelCount, 1 + index))
    }
    function shapeOf(i) {
        const s = points[i] ? points[i].shape : undefined
        return s === "triangle" || s === "cross" ? s : "dot"
    }
    /** A point's mark in point sizes: its `size` times 2.5 for a triangle, 1.5 for a cross. */
    function markScale(p) {
        const f = p && p.size > 0 ? p.size : 1
        return f * (p && p.shape === "triangle" ? 2.5 : p && p.shape === "cross" ? 1.5 : 1)
    }
    /** Extent of point i's mark in pixels. */
    function markSize(i) {
        return pointSize * markScale(points[i])
    }
    /** Colour key: "v<level>", "s<series>" or "d" (pointColor). */
    function colorKeyOf(i) {
        const level = levelOf(rawValue(i))
        if (level > 0) {
            return "v" + level
        }
        const p = points[i]
        return p && p.series !== undefined && p.series !== null ? "s" + p.series : "d"
    }
    function colorOfKey(key) {
        if (key[0] === "v") {
            return KanteStyle.levelColor(Number(key.slice(1)), levels, scaleColor)
        }
        return key[0] === "s" ? KanteStyle.dataColor(Number(key.slice(1))) : pointColor
    }
    function colorOf(i) {
        return colorOfKey(colorKeyOf(i))
    }

    /** Tooltip and accessible text: "Kamera 3\nx 1,20 m · y 3,40 m\nAnsichten 12". */
    function tipOf(i) {
        const p = i >= 0 && i < count ? points[i] : null
        if (!p) {
            return ""
        }
        const lines = []
        if (p.label !== undefined && p.label !== "") {
            lines.push(String(p.label))
        }
        const u = function (t) { return t === "" ? "" : " " + t }
        lines.push("x " + numberText(p.x, xDecimals + 1) + u(xUnit) + " · y " + numberText(p.y, yDecimals + 1) + u(yUnit))
        const v = rawValue(i)
        if (isFinite(v)) {
            const name = valueTitle !== "" ? valueTitle : valueKey
            lines.push(name + " " + numberText(v, Number.isInteger(v) ? 0 : 2))
        }
        return lines.join("\n")
    }

    // ── Screen positions, draw groups and a grid for hit tests ─────────

    property bool _dirty: true
    property var _px: []
    property var _py: []
    property var _groups: []
    property var _cells: ({})
    readonly property real hitRadius: KanteStyle.unit(8)
    /** Largest hit distance: the hit radius or half of the biggest mark. Sets the grid's cell. */
    readonly property real hitReach: Math.max(hitRadius, pointSize * bounds.mark / 2)
    readonly property string layoutKey: [count, width, height, axes.x0, axes.x1, axes.y0, axes.y1,
        padLeft, padTop, plotWidth, plotHeight, valueKey, valueRange.low, valueRange.high, levelScale.start, levelScale.step, levelScale.count, pointSize].join(",")
    onLayoutKeyChanged: invalidate()
    onPointsChanged: invalidate()

    function invalidate() {
        _dirty = true
        Qt.callLater(chart.repaint)
    }
    function repaint() {
        ensureLayout()
        canvas.requestPaint()
    }
    function ensureLayout() {
        if (!_dirty) {
            return
        }
        _dirty = false
        const xs = new Array(count)
        const ys = new Array(count)
        const byKey = {}
        const grid = {}
        const cell = hitReach * 2
        for (let i = 0; i < count; i++) {
            const p = points[i]
            if (!p || !isFinite(p.x) || !isFinite(p.y)) {
                xs[i] = NaN
                ys[i] = NaN
                continue
            }
            xs[i] = xOf(p.x)
            ys[i] = yOf(p.y)
            const shape = shapeOf(i)
            const key = shape + "|" + colorKeyOf(i)
            if (!byKey[key]) {
                byKey[key] = { shape: shape, color: colorKeyOf(i), idx: [] }
            }
            byKey[key].idx.push(i)
            const g = Math.floor(xs[i] / cell) + ":" + Math.floor(ys[i] / cell)
            if (!grid[g]) {
                grid[g] = []
            }
            grid[g].push(i)
        }
        // Dots under crosses under triangles; within a shape the higher level on top.
        const rank = { dot: 0, cross: 1, triangle: 2 }
        const out = Object.keys(byKey).map(function (k) { return byKey[k] })
        out.sort(function (a, b) {
            return rank[a.shape] - rank[b.shape] || (a.color < b.color ? -1 : a.color > b.color ? 1 : 0)
        })
        _px = xs
        _py = ys
        _groups = out
        _cells = grid
    }

    /** Index of the point nearest to (x, y) within its mark or the hit radius; -1 for none. */
    function pointAt(x, y) {
        ensureLayout()
        const cell = hitReach * 2
        const cx = Math.floor(x / cell)
        const cy = Math.floor(y / cell)
        let best = -1
        let bestD = Infinity
        for (let gx = cx - 1; gx <= cx + 1; gx++) {
            for (let gy = cy - 1; gy <= cy + 1; gy++) {
                const list = _cells[gx + ":" + gy]
                if (!list) {
                    continue
                }
                for (let k = 0; k < list.length; k++) {
                    const i = list[k]
                    const d = Math.hypot(_px[i] - x, _py[i] - y)
                    // Ties: the later point, drawn on top.
                    if (d <= Math.max(hitRadius, markSize(i) / 2) && d <= bestD) {
                        best = i
                        bestD = d
                    }
                }
            }
        }
        return best
    }

    /**
     * Next point from `from` in a direction (dx, dy on screen, e.g. 1, 0 for Right): the one
     * with the least distance along it plus twice the distance across; only points ahead count.
     * -1 when none is ahead.
     */
    function neighbour(from, dx, dy) {
        ensureLayout()
        let best = -1
        let bestScore = Infinity
        for (let i = 0; i < count; i++) {
            if (i === from || !inPlot(i)) {
                continue
            }
            const ox = _px[i] - _px[from]
            const oy = _py[i] - _py[from]
            const along = ox * dx + oy * dy
            if (along <= 0) {
                continue
            }
            const score = along + 2 * Math.abs(ox * dy - oy * dx)
            if (score < bestScore) {
                best = i
                bestScore = score
            }
        }
        return best
    }
    /** Whether point i has a position inside the plot. */
    function inPlot(i) {
        return _px[i] >= padLeft && _px[i] <= padLeft + plotWidth
            && _py[i] >= padTop && _py[i] <= padTop + plotHeight
    }
    function firstDrawn(from, step) {
        ensureLayout()
        for (let i = from; i >= 0 && i < count; i += step) {
            if (inPlot(i)) {
                return i
            }
        }
        return -1
    }

    onActiveFocusChanged: {
        if (activeFocus && (currentIndex < 0 || currentIndex >= count)) {
            currentIndex = firstDrawn(0, 1)
        }
    }
    onCountChanged: {
        if (currentIndex >= count) {
            currentIndex = firstDrawn(count - 1, -1)
        }
        hoverIndex = -1
    }

    Keys.onPressed: function (event) {
        if (!interactive || count === 0) {
            return
        }
        const from = currentIndex >= 0 && currentIndex < count ? currentIndex : firstDrawn(0, 1)
        let next = -2
        if (event.key === Qt.Key_Left) {
            next = neighbour(from, -1, 0)
        } else if (event.key === Qt.Key_Right) {
            next = neighbour(from, 1, 0)
        } else if (event.key === Qt.Key_Up) {
            next = neighbour(from, 0, -1)
        } else if (event.key === Qt.Key_Down) {
            next = neighbour(from, 0, 1)
        } else if (event.key === Qt.Key_Home) {
            next = firstDrawn(0, 1)
        } else if (event.key === Qt.Key_End) {
            next = firstDrawn(count - 1, -1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (from >= 0) {
                activated(from)
            }
            event.accepted = true
            return
        } else {
            return
        }
        // At the edge the focus stays where it is.
        if (next >= 0) {
            currentIndex = next
        } else if (currentIndex < 0) {
            currentIndex = from
        }
        event.accepted = true
    }

    // ── Drawing ─────────────────────────────────────────────────────────

    Text {
        id: captionProbe
        visible: false
        text: "0"
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
    }

    // Grid lines at the ticks; the bottom and left edges of the plot as the axes.
    Repeater {
        model: chart.xTicks
        delegate: Rectangle {
            required property var modelData
            x: Math.round(chart.xOf(modelData))
            y: chart.padTop
            width: 1
            height: chart.plotHeight
            color: KanteStyle.ruleColor
        }
    }
    Repeater {
        model: chart.yTicks
        delegate: Rectangle {
            required property var modelData
            x: chart.padLeft
            y: Math.round(chart.yOf(modelData))
            width: chart.plotWidth
            height: 1
            color: KanteStyle.ruleColor
        }
    }
    Rectangle {
        x: chart.padLeft
        y: chart.padTop + chart.plotHeight - 1
        width: chart.plotWidth
        height: 1
        color: KanteStyle.frameColor
    }
    Rectangle {
        x: chart.padLeft
        y: chart.padTop
        width: 1
        height: chart.plotHeight
        color: KanteStyle.frameColor
    }

    // Tick labels and captions.
    Repeater {
        model: chart.xTicks
        delegate: Text {
            required property var modelData
            objectName: "kanteScatterXTick"
            x: Math.max(0, Math.min(chart.width - width, chart.xOf(modelData) - width / 2))
            y: chart.padTop + chart.plotHeight + KanteStyle.unit(4)
            text: Number(modelData).toLocaleString(Qt.locale(), 'f', chart.xDecimals)
            color: KanteStyle.mutedTextColor
            font: captionProbe.font
        }
    }
    Repeater {
        model: chart.yTicks
        delegate: Text {
            required property var modelData
            objectName: "kanteScatterYTick"
            x: chart.padLeft - width - KanteStyle.unit(6)
            y: Math.max(0, Math.min(chart.padTop + chart.plotHeight - height, chart.yOf(modelData) - height / 2))
            text: Number(modelData).toLocaleString(Qt.locale(), 'f', chart.yDecimals)
            color: KanteStyle.mutedTextColor
            font: captionProbe.font
        }
    }
    Text {
        visible: text !== ""
        x: 0
        y: 0
        text: chart.yCaption
        color: KanteStyle.mutedTextColor
        font: captionProbe.font
    }
    Text {
        visible: text !== ""
        x: chart.padLeft + (chart.plotWidth - width) / 2
        y: chart.padTop + chart.plotHeight + chart.captionHeight + KanteStyle.unit(8)
        text: chart.xCaption
        color: KanteStyle.mutedTextColor
        font: captionProbe.font
    }

    // The colours the canvas uses: a theme switch repaints it.
    readonly property var paintColors: [pointColor, scaleColor, KanteStyle.dataColor(0), KanteStyle.dataColor(1),
        KanteStyle.dataColor(2), KanteStyle.dataColor(3), KanteStyle.dataColor(4), KanteStyle.dataColor(5),
        KanteStyle.sunkenColor, KanteStyle.markerRadius]
    onPaintColorsChanged: canvas.requestPaint()

    // Every mark in one canvas, clipped to the plot; one path per shape and colour.
    Canvas {
        id: canvas
        objectName: "kanteScatterCanvas"
        x: chart.padLeft
        y: chart.padTop
        width: chart.plotWidth
        height: chart.plotHeight
        property int paints: 0
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            chart.ensureLayout()
            const ox = x
            const oy = y
            const round = KanteStyle.markerRadius > 0
            const groups = chart._groups
            for (let g = 0; g < groups.length; g++) {
                const grp = groups[g]
                const tone = chart.colorOfKey(grp.color)
                const idx = grp.idx
                ctx.beginPath()
                for (let k = 0; k < idx.length; k++) {
                    const i = idx[k]
                    const cx = chart._px[i] - ox
                    const cy = chart._py[i] - oy
                    const s = chart.markSize(i)
                    if (grp.shape === "triangle") {
                        // Tip along the angle (counter-clockwise from +x; y grows downwards on screen).
                        const p = chart.points[i]
                        const a = -(p.angle !== undefined ? p.angle : 90) * Math.PI / 180
                        const ca = Math.cos(a)
                        const sa = Math.sin(a)
                        const tip = s * 0.6
                        const back = s * 0.4
                        const half = s * 0.4
                        ctx.moveTo(cx + ca * tip, cy + sa * tip)
                        ctx.lineTo(cx - ca * back - sa * half, cy - sa * back + ca * half)
                        ctx.lineTo(cx - ca * back + sa * half, cy - sa * back - ca * half)
                        ctx.closePath()
                    } else if (grp.shape === "cross") {
                        ctx.moveTo(cx - s / 2, cy - s / 2)
                        ctx.lineTo(cx + s / 2, cy + s / 2)
                        ctx.moveTo(cx - s / 2, cy + s / 2)
                        ctx.lineTo(cx + s / 2, cy - s / 2)
                    } else if (round) {
                        ctx.moveTo(cx + s / 2, cy)
                        ctx.arc(cx, cy, s / 2, 0, 2 * Math.PI)
                    } else {
                        ctx.rect(cx - s / 2, cy - s / 2, s, s)
                    }
                }
                if (grp.shape === "cross") {
                    ctx.lineWidth = KanteStyle.lineWidth
                    ctx.strokeStyle = tone
                    ctx.stroke()
                } else {
                    ctx.fillStyle = tone
                    ctx.fill()
                }
            }
            paints++
        }
    }

    // The hovered point, else the focused one: a ring in the focus colour and the tooltip.
    readonly property int shownIndex: hoverIndex >= 0 && hoverIndex < count ? hoverIndex
        : (activeFocus && currentIndex >= 0 && currentIndex < count ? currentIndex : -1)
    Item {
        id: probe
        objectName: "kanteScatterProbe"
        readonly property var spot: chart.shownIndex >= 0 ? chart.points[chart.shownIndex] : null
        readonly property bool shown: !!spot && isFinite(spot.x) && isFinite(spot.y)
        readonly property real size: shown ? chart.markSize(chart.shownIndex) + KanteStyle.unit(6) : 0
        visible: shown
        width: size
        height: size
        x: shown ? chart.xOf(spot.x) - size / 2 : 0
        y: shown ? chart.yOf(spot.y) - size / 2 : 0

        QQC2.ToolTip.text: shown ? chart.tipOf(chart.shownIndex) : ""
        QQC2.ToolTip.visible: shown
        QQC2.ToolTip.delay: chart.hoverIndex >= 0 ? 300 : 0

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: KanteStyle.markerRadius > 0 ? width / 2 : 0
            border.width: KanteStyle.lineWidth
            border.color: KanteStyle.focusColor
        }
    }

    KanteLegend {
        id: legendView
        visible: chart.legendHeight > 0
        x: chart.padLeft
        y: chart.height - chart.legendHeight + KanteStyle.unit(8)
        width: chart.plotWidth
        model: chart.legendModel
    }

    HoverHandler {
        id: hover
        onPointChanged: {
            const p = point.position
            const inPlot = hovered && p.x >= chart.padLeft && p.x <= chart.padLeft + chart.plotWidth
                && p.y >= chart.padTop && p.y <= chart.padTop + chart.plotHeight
            chart.hoverIndex = inPlot ? chart.pointAt(p.x, p.y) : -1
        }
        onHoveredChanged: {
            if (!hovered) {
                chart.hoverIndex = -1
            }
        }
    }
    TapHandler {
        enabled: chart.interactive
        onTapped: function (eventPoint) {
            const i = chart.pointAt(eventPoint.position.x, eventPoint.position.y)
            if (i < 0) {
                return
            }
            chart.currentIndex = i
            chart.forceActiveFocus()
            chart.activated(i)
        }
    }
}
