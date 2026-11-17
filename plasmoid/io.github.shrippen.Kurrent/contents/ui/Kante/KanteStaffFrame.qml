import QtQuick

/**
 * What KanteBassStaff and KanteTabStaff share besides their notation (Kante 1.35, 1.81):
 * the room the layout uses, the layouts of the lines on show, the loop cut into lines, and the
 * lookups in time (note and bar at a time, bar label). Has no look of its own.
 *
 *   room        `width`, `height`, `spacing`, `minBarWidth` follow the staff. The layout takes
 *               them over at once, or `settleMs` after the last change (while a window is
 *               dragged the drawn lines stay), as `layoutSize`, `layoutSpacing`,
 *               `layoutMinBarWidth`.
 *   lines       a line keeps its layout (`lineCache` by line index) while it stays in view, so
 *               a page turn lays out only the line that comes in. Any change of `inputs`
 *               lays all out again, once per turn of the event loop however many inputs
 *               changed. `layoutLine(first, per)` is the staff's own layout of one line;
 *               `lineModel` holds the line indexes on show.
 *   loop        cutLoop() cuts the loop range into lines; `headerWidth`, `barWidth` locate a bar.
 *   time        lastAtOrBefore(), barAt(), barLabel(), loopX(): what the staffs ask of a time.
 */
QtObject {
    id: frame

    property real width: 0
    property real height: 0
    property real spacing: 0
    property real minBarWidth: 0
    /** Wait after the last change of the room before laying out again, in ms; 0: at once. */
    property int settleMs: 0

    property size layoutSize: Qt.size(0, 0)
    property real layoutSpacing: spacing
    property real layoutMinBarWidth: minBarWidth

    /** Shown long enough that its room has settled: before, a change of the room (a page still
     *  laying out) lands at once instead of growing in (Kontra 12.11.). */
    property bool grown: false

    property int perSystem: 1
    property int firstBar: 0
    property int systems: 1
    property int barCount: 0
    /** The staff's header and bar widths on a line, for loopX(). */
    property real headerWidth: 0
    property real barWidth: 0
    /** Everything the layout of a line depends on; a new value lays all lines out again. */
    property var inputs: []
    /** function (first, per): the layout of the one line that starts at bar `first`. */
    property var layoutLine

    property var lineCache: ({})
    property bool lineCacheStale: false
    property int lineRevision: 0
    readonly property ListModel lineModel: ListModel {}

    function takeSize() {
        layoutSize = Qt.size(width, height)
        layoutSpacing = spacing
        layoutMinBarWidth = minBarWidth
    }
    function sizeChanged() {
        if (settleMs <= 0 || layoutSize.width <= 0) {
            takeSize()
            return
        }
        settleTimer.restart()
    }
    onWidthChanged: sizeChanged()
    onHeightChanged: sizeChanged()
    onSpacingChanged: sizeChanged()
    onMinBarWidthChanged: sizeChanged()

    readonly property Timer settleTimer: Timer {
        interval: frame.settleMs
        onTriggered: frame.takeSize()
    }
    readonly property Timer grownTimer: Timer {
        running: frame.layoutSize.width > 0
        interval: KanteStyle.durationSlow
        onTriggered: frame.grown = true
    }

    onInputsChanged: {
        lineCacheStale = true
        Qt.callLater(syncLines)
    }
    onFirstBarChanged: Qt.callLater(syncLines)
    onSystemsChanged: Qt.callLater(syncLines)

    function syncLines() {
        const per = perSystem
        const top = Math.floor(firstBar / per)
        const want = []
        for (let k = 0; k < systems; k++) {
            if ((top + k) * per < barCount) {
                want.push(top + k)
            }
        }

        const cache = lineCacheStale ? ({}) : lineCache
        for (const n of want) {
            if (!cache[n]) {
                cache[n] = layoutLine(n * per, per)
            }
        }
        lineCache = cache
        lineCacheStale = false
        lineRevision++

        // The model keeps the lines that stay and adds or drops the others (A1, A2).
        for (let i = lineModel.count - 1; i >= 0; i--) {
            if (want.indexOf(lineModel.get(i).lineIndex) < 0) {
                lineModel.remove(i)
            }
        }
        for (let k = 0; k < want.length; k++) {
            if (k < lineModel.count && lineModel.get(k).lineIndex === want[k]) {
                continue
            }
            lineModel.insert(k, { lineIndex: want[k] })
        }
    }

    /** Index of the last entry of `list` (sorted by `time`) at or before time t; -1 before the first. */
    function lastAtOrBefore(list, t) {
        let a = 0
        let b = list ? list.length : 0
        while (a < b) {
            const m = (a + b) >> 1
            if (Number(list[m].time) <= t + 1e-6) {
                a = m + 1
            } else {
                b = m
            }
        }
        return a - 1
    }
    /** The bar of `bars` at time t; the first bar before the start. */
    function barAt(bars, t) {
        return Math.max(0, lastAtOrBefore(bars, t))
    }
    /** Label of a bar (1.28): its `number` as sent (written bar number), else index + 1. */
    function barLabel(o, i) {
        const n = typeof o === "object" && o !== null ? o.number : undefined
        return n === undefined || n === null || String(n) === "" ? String(i + 1) : String(n)
    }
    /**
     * x of a loop edge at time t in bar b: on the bar line at a bar start or end, else
     * `xOf(t, b)`, the staff's own x of a time in a bar.
     */
    function loopX(bars, t, b, xOf) {
        const bar = bars[b]
        const left = headerWidth + ((b - firstBar) % perSystem) * barWidth
        if (Math.abs(t - bar.time) < 1e-3) {
            return left
        }
        if (Math.abs(t - bar.end) < 1e-3) {
            return left + barWidth
        }
        return xOf(t, b)
    }

    /**
     * The loop cut into lines: per line the part of [from, to] it shows: [{x, w, sys, left,
     * right}]. left / right: the loop starts / ends on this line (bracket edge), else it runs
     * on (open edge). `bl` the bars with `time` and `end`; `xOf(t, b)` the staff's x of a time
     * in a bar.
     */
    function cutLoop(first, per, nsys, w, bl, from, to, xOf) {
        const out = []
        if (w <= 0 || bl.length === 0 || from < 0 || to <= from) {
            return out
        }

        const last = Math.min(bl.length - 1, first + per * nsys - 1)
        for (let s = 0; s < nsys; s++) {
            const b0 = first + s * per
            const b1 = Math.min(last, b0 + per - 1)
            if (b1 < b0) {
                break
            }
            const t0 = Math.max(from, bl[b0].time)
            const t1 = Math.min(to, bl[b1].end)
            if (t1 <= t0 + 1e-6) {
                continue
            }

            // The bar of each edge, kept on this line; the end belongs to the bar before it.
            const x0 = loopX(bl, t0, Math.max(b0, Math.min(b1, barAt(bl, t0))), xOf)
            const x1 = loopX(bl, t1, Math.max(b0, Math.min(b1, barAt(bl, t1 - 1e-3))), xOf)
            out.push({ x: x0, w: Math.max(1, x1 - x0), sys: s, left: from >= bl[b0].time - 1e-6,
                       right: to <= bl[b1].end + 1e-6 })
        }
        return out
    }
}
