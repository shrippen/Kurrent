import QtQuick
import "."

/**
 * Timing spread (Kante 1.23, for Kontra): how early or late notes were played, as a
 * histogram in milliseconds. A KanteBarChart configured for bins: the count axis on the
 * left, bin edges in ms below (unit at the right end), a solid zero line and a dashed
 * mean line, both labelled, and the key under the chart: "◂ early" left, "late ▸" right.
 *
 *   counts      notes per bin, from the earliest bin
 *   firstBinMs  lower edge of the first bin (e.g. −100)
 *   binMs       width of a bin (e.g. 10)
 *   meanMs      mean deviation; NaN for none
 *   bandMinMs, bandMaxMs  a target band (1.44, e.g. +10…+30 for laid-back), labelled with
 *               bandText; NaN for none
 *   binText     a bar for screen readers (1.51): %1 and %2 its edges, %3 the unit, %4 the
 *               count as countText ("−20 bis −10 ms: 3 Noten"); an app translates it once
 */
Item {
    id: hist

    property var counts: []
    property real firstBinMs: -100
    property real binMs: 10
    property real meanMs: NaN
    property real bandMinMs: NaN
    property real bandMaxMs: NaN
    property string bandText: "Ziel"
    property string unit: "ms"
    property string earlyText: "früh"
    property string lateText: "spät"
    property string meanText: "Mittel"
    property string countText: "%1 Noten"
    property string binText: "%1 bis %2 %3: %4"
    /** Title of the count axis (1.49). */
    property string axisTitle: "Noten"
    property string accessibleName: "Timing"

    readonly property alias chart: bars
    readonly property int total: {
        var s = 0
        for (var i = 0; counts && i < counts.length; i++) s += Number(counts[i]) || 0
        return s
    }

    function ms(v) {
        var r = Math.round(v)
        return (r < 0 ? "−" : r > 0 ? "+" : "") + Math.abs(r)
    }
    function edges() {
        var n = counts ? counts.length : 0
        if (n === 0) return []
        // Every k-th edge on a multiple of k bins, at most about seven labels.
        var k = Math.max(1, Math.ceil((n + 1) / 7))
        var out = []
        for (var i = 0; i <= n; i++) {
            var v = firstBinMs + i * binMs
            var steps = Math.round(v / binMs)
            out.push(steps % k === 0 ? ms(v) : "")
        }
        return out
    }
    function binLabels() {
        var out = []
        for (var i = 0; counts && i < counts.length; i++) {
            var a = firstBinMs + i * binMs
            out.push(ms(a) + "…" + ms(a + binMs) + " " + unit)
        }
        return out
    }
    function markerList() {
        var out = []
        var n = counts ? counts.length : 0
        var zero = (0 - firstBinMs) / binMs
        if (zero >= 0 && zero <= n) out.push({ at: zero, label: "0", dashed: false })
        if (!isNaN(meanMs)) {
            out.push({ at: Math.max(0, Math.min(n, (meanMs - firstBinMs) / binMs)), label: meanText + " " + ms(meanMs) + " " + unit, dashed: true })
        }
        return out
    }

    /** Screen-reader name of bar i: "−20 bis −10 ms: 3 Noten". */
    function binName(i) {
        const a = firstBinMs + i * binMs
        return binText.arg(ms(a)).arg(ms(a + binMs)).arg(unit).arg(countText.arg(Number(counts[i]) || 0))
    }

    function bandLabel() {
        return bandText + " " + ms(Math.min(bandMinMs, bandMaxMs)) + "…" + ms(Math.max(bandMinMs, bandMaxMs)) + " " + unit
    }
    function rangeList() {
        const n = counts ? counts.length : 0
        if (isNaN(bandMinMs) || isNaN(bandMaxMs) || n === 0) return []
        const at = function (v) { return Math.max(0, Math.min(n, (v - firstBinMs) / binMs)) }
        return [{ from: at(Math.min(bandMinMs, bandMaxMs)), to: at(Math.max(bandMinMs, bandMaxMs)), label: bandLabel() }]
    }

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: KanteStyle.unit(200)

    Accessible.role: Accessible.Chart
    Accessible.name: accessibleName
    Accessible.description: countText.arg(total)
        + (isNaN(meanMs) ? "" : ", " + meanText + " " + ms(meanMs) + " " + unit
           + (Math.round(meanMs) < 0 ? " (" + earlyText + ")" : Math.round(meanMs) > 0 ? " (" + lateText + ")" : ""))
        + (isNaN(bandMinMs) || isNaN(bandMaxMs) ? "" : ", " + bandLabel())

    KanteBarChart {
        id: bars
        width: hist.width
        height: hist.height - key.height - KanteStyle.unit(4)
        values: (hist.counts || []).map(function (v) { return Number(v) || 0 })
        labels: hist.binLabels()
        edgeLabels: hist.edges()
        edgeUnit: hist.unit
        markers: hist.markerList()
        ranges: hist.rangeList()
        axis: true
        axisTitle: hist.axisTitle
        wholeSteps: true
        barFill: 0.9
        Accessible.ignored: true
    }

    // The bars for screen readers (1.51: they heard only "early" and "late"): one named item
    // over each bar, in the chart's order.
    Repeater {
        model: hist.counts ? hist.counts.length : 0
        delegate: Item {
            required property int index
            objectName: "kanteHistogramBar"
            x: bars.padLeft + index * bars.columnWidth
            width: bars.columnWidth
            height: bars.plotHeight
            Accessible.role: Accessible.StaticText
            Accessible.name: hist.binName(index)
        }
    }

    Item {
        id: key
        anchors.bottom: parent.bottom
        x: bars.padLeft
        width: hist.width - bars.padLeft
        height: Math.max(earlyRow.height, lateRow.height)
        Row {
            id: earlyRow
            spacing: KanteStyle.unit(4)
            KanteNoteMark { noteState: "early"; color: KanteStyle.mutedTextColor; anchors.verticalCenter: parent.verticalCenter }
            Text { text: hist.earlyText; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }
        }
        Row {
            id: lateRow
            anchors.right: parent.right
            spacing: KanteStyle.unit(4)
            Text { text: hist.lateText; color: KanteStyle.mutedTextColor; font: KanteStyle.labelFont() }
            KanteNoteMark { noteState: "late"; color: KanteStyle.mutedTextColor; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
