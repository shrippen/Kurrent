import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import "."

/**
 * Days on a calendar grid (Kante 1.62, for Mitori's practice days): a column per week, a row per
 * weekday, the newest week on the right. The axes are labelled: weekday names on every second row
 * at the side, the month's name above the week it begins in (the first column names its month
 * when the next name is three weeks away or more). Each day has a level 0..4, coloured as KanteHeatmap
 * does (KanteStyle.levelColor); hovering a day, or tapping it (for a few seconds, on touch), shows
 * its date and `tips` entry; screen readers hear a week at a time, each day with its date in full
 * and its tip (1.75.1; the days are drawn as one shape, not an item each). Mirrored right to left with
 * LayoutMirroring (the newest week on the left). Pair it with a KanteLegend for the levels.
 *   endDate         the last day shown (today unless set); later days of its week stay empty
 *   weeks           how many weeks (columns)
 *   levels          {"2026-11-02": 3, …} by ISO day (isoDay()); a missing day is 0, above 4 is 4
 *   tips            {"2026-11-02": "5 techniques", …}: shown after the date
 *   firstDayOfWeek  Locale.Monday …, the locale's unless set
 *   locale          for day and month names and dates
 */
Item {
    id: heat

    property date endDate: new Date()
    property int weeks: 26
    property var levels: ({})
    property var tips: ({})
    property var locale: Qt.locale()
    property int firstDayOfWeek: locale.firstDayOfWeek
    property int cellSize: KanteStyle.unit(12)
    property int spacing: 2

    readonly property real step: cellSize + spacing
    readonly property real labelWidth: Math.ceil(Math.max(...weekdayLabels().map(t => monthMetrics.advanceWidth(t)))) + KanteStyle.unit(6)
    readonly property real labelHeight: monthMetrics.height + KanteStyle.unit(2)
    readonly property bool mirrored: LayoutMirroring.enabled
    // The day tapped last, its tooltip shown for a few seconds (touch has no hover).
    property int tappedIndex: -1

    Accessible.role: Accessible.Grouping

    // x of an item `w` wide at `x` from the leading edge; mirrored at the width it gets (1.62.1).
    function lead(x, w) {
        return mirrored ? width - x - w : x
    }

    implicitWidth: labelWidth + weeks * step - spacing
    implicitHeight: labelHeight + 7 * step - spacing

    // Local noon, so that adding days never crosses midnight on a change of summer time.
    function noon(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12)
    }
    function isoDay(d) {
        const p = n => (n < 10 ? "0" : "") + n
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
    }
    readonly property date lastDay: noon(endDate)
    // The first day of the first column.
    readonly property date firstDay: {
        const d = noon(endDate)
        const back = (d.getDay() - firstDayOfWeek + 7) % 7 + (weeks - 1) * 7
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - back, 12)
    }
    function dayAt(week, row) {
        return new Date(firstDay.getFullYear(), firstDay.getMonth(), firstDay.getDate() + week * 7 + row, 12)
    }
    function shown(week, row) {
        return dayAt(week, row) <= lastDay
    }
    function levelOf(day) {
        return Math.max(0, Math.min(4, Number(levels[isoDay(day)]) || 0))
    }
    function tipOf(day, format) {
        const date = day.toLocaleDateString(locale, format === undefined ? Locale.ShortFormat : format)
        const tip = tips[isoDay(day)]
        return tip ? date + " · " + tip : date
    }
    // Names on rows 1, 3 and 5 (Tue, Thu, Sat when weeks start on Monday), "" elsewhere.
    function weekdayLabels() {
        const rows = []
        for (let r = 0; r < 7; r++) {
            rows.push(r % 2 === 1 ? locale.dayName((firstDayOfWeek + r) % 7, Locale.ShortFormat) : "")
        }
        return rows
    }
    // [{week, month, text}]: the weeks a month begins in; the first column names the month of its
    // last drawn day when the next name is at least three weeks away.
    function monthLabels() {
        const result = []
        const label = (w, m) => ({ week: w, month: m, text: locale.standaloneMonthName(m, Locale.ShortFormat) })
        for (let w = 0; w < weeks; w++) {
            for (let r = 0; r < 7; r++) {
                const d = dayAt(w, r)
                if (d.getDate() === 1 && d <= lastDay) {
                    result.push(label(w, d.getMonth()))
                }
            }
        }
        if (result.length === 0 || result[0].week >= 3) {
            const last = dayAt(0, 6) > lastDay ? lastDay : dayAt(0, 6)     // one week: the last drawn day
            result.unshift(label(0, last.getMonth()))
        }
        return result
    }

    FontMetrics { id: monthMetrics; font: KanteStyle.smallFont }

    Repeater {
        model: heat.weekdayLabels()
        delegate: Text {
            required property int index
            required property string modelData
            x: heat.lead(0, implicitWidth)
            y: heat.labelHeight + index * heat.step + (heat.cellSize - height) / 2
            text: modelData
            font: KanteStyle.smallFont
            color: KanteStyle.mutedTextColor
        }
    }

    Repeater {
        model: heat.monthLabels()
        delegate: Text {
            required property var modelData
            // Kept inside the grid when a month begins in one of the last weeks.
            x: heat.lead(Math.min(heat.labelWidth + modelData.week * heat.step, heat.implicitWidth - implicitWidth), implicitWidth)
            y: 0
            text: modelData.text
            font: KanteStyle.smallFont
            color: KanteStyle.mutedTextColor
        }
    }

    // The days as one list, read once: a year of cells, several years on a page (All years in
    // Mitori): a Date per binding and per cell took twice the time.
    readonly property var cells: {
        const list = []
        const first = firstDay
        const last = lastDay
        for (let i = 0; i < weeks * 7; i++) {
            const date = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i, 12)
            list.push({ date: date, iso: isoDay(date), shown: date <= last })
        }
        return list
    }

    // Each day's level, in the order of `cells`.
    readonly property var cellLevels: cells.map(c => Math.max(0, Math.min(4, Number(levels[c.iso]) || 0)))

    // The days of each level as one path ("M14 20h12v12h-12z M28 20…"), drawn in the first frame:
    // not an item per day (1.75.1). Five years on a page are 1800 days; a Rectangle each with its
    // bindings took 120 ms, their names 170 ms more (Mitori).
    readonly property var levelPaths: {
        const paths = ["", "", "", "", ""]
        const c = cellSize
        for (let i = 0; i < cells.length; i++) {
            if (!cells[i].shown) {
                continue
            }
            const x = lead(labelWidth + Math.floor(i / 7) * step, c)
            const y = labelHeight + i % 7 * step
            paths[cellLevels[i]] += "M" + x + " " + y + "h" + c + "v" + c + "h" + (-c) + "z"
        }
        return paths
    }
    component LevelPath: ShapePath {
        property alias path: svg.path
        strokeWidth: -1
        PathSvg { id: svg }
    }
    Shape {
        id: days

        objectName: "days"
        anchors.fill: parent
        LevelPath { fillColor: heat.levelColors[0]; path: heat.levelPaths[0] }
        LevelPath { fillColor: heat.levelColors[1]; path: heat.levelPaths[1] }
        LevelPath { fillColor: heat.levelColors[2]; path: heat.levelPaths[2] }
        LevelPath { fillColor: heat.levelColors[3]; path: heat.levelPaths[3] }
        LevelPath { fillColor: heat.levelColors[4]; path: heat.levelPaths[4] }
    }

    // A screen reader hears a week at a time, each day with its date and tip ("Monday, 2 November
    // 2026 · 3 techniques, Tuesday, 3 November 2026 · no practice, …"): an item per week.
    function weekName(week) {
        const names = []
        for (let i = week * 7; i < week * 7 + 7 && i < cells.length; i++) {
            if (cells[i].shown) {
                names.push(tipOf(cells[i].date, Locale.LongFormat))
            }
        }
        return names.join(", ")
    }
    Repeater {
        model: heat.weeks
        delegate: Item {
            required property int index

            x: heat.lead(heat.labelWidth + index * heat.step, heat.cellSize)
            y: heat.labelHeight
            width: heat.cellSize
            height: 7 * heat.step - heat.spacing
            Accessible.role: Accessible.StaticText
            Accessible.name: heat.weekName(index)
        }
    }

    // The colours of the levels over the sunken ground, once: both may be translucent.
    readonly property var levelColors: {
        const under = KanteStyle.sunkenColor
        return [0, 1, 2, 3, 4].map(l => {
            if (l === 0) {
                return under
            }
            const c = KanteStyle.levelColor(l, 4)
            const rest = under.a * (1 - c.a)
            const a = c.a + rest
            return Qt.rgba((c.r * c.a + under.r * rest) / a, (c.g * c.a + under.g * rest) / a,
                           (c.b * c.a + under.b * rest) / a, a)
        })
    }

    // The index of the day at a point of this item, -1 outside the days.
    function cellAt(px, py) {
        const across = (mirrored ? width - px : px) - labelWidth
        const down = py - labelHeight
        const week = Math.floor(across / step)
        const row = Math.floor(down / step)
        if (week < 0 || week >= weeks || row < 0 || row > 6 || across - week * step > cellSize || down - row * step > cellSize) {
            return -1
        }
        const i = week * 7 + row
        return cells[i] && cells[i].shown ? i : -1
    }

    // One tooltip and one pair of handlers for all days.
    HoverHandler {
        id: hover
    }
    // The hover's delay here, not the tooltip's: a tooltip already waiting would not take a tap's
    // "at once" any more, and on touch a press counts as a hover first.
    property bool hoverWaited: false
    onHoveredIndexChanged: hoverWaited = hoverWaited && hoveredIndex >= 0
    Timer {
        interval: 300
        running: heat.hoveredIndex >= 0 && !heat.hoverWaited
        onTriggered: heat.hoverWaited = true
    }
    TapHandler {
        longPressThreshold: 0      // a resting finger taps too
        onTapped: eventPoint => {
            const i = heat.cellAt(eventPoint.position.x, eventPoint.position.y)
            heat.tappedIndex = i
            if (i >= 0) {
                tipTimer.restart()
            }
        }
    }
    readonly property int hoveredIndex: hover.hovered ? cellAt(hover.point.position.x, hover.point.position.y) : -1
    readonly property int tipIndex: tappedIndex >= 0 ? tappedIndex : hoveredIndex
    // The day the tooltip names: kept while it fades out, or it would fade at the corner, empty.
    property int tipDay: 0
    onTipIndexChanged: {
        if (tipIndex >= 0) {
            tipDay = tipIndex
        }
    }
    // Fewer weeks (a turned phone) may take the tapped day away.
    onCellsChanged: {
        if (tappedIndex >= cells.length) {
            tappedIndex = -1
        }
    }
    Item {
        id: tipPlace
        objectName: "dayTip"
        x: heat.lead(heat.labelWidth + Math.floor(heat.tipDay / 7) * heat.step, heat.cellSize)
        y: heat.labelHeight + heat.tipDay % 7 * heat.step
        width: heat.cellSize
        height: heat.cellSize
        QQC2.ToolTip.text: heat.cells[heat.tipDay] ? heat.tipOf(heat.cells[heat.tipDay].date) : ""
        QQC2.ToolTip.delay: 0
        QQC2.ToolTip.visible: heat.tappedIndex >= 0 || (heat.hoveredIndex >= 0 && heat.hoverWaited)
    }

    Timer {
        id: tipTimer
        interval: 3000
        onTriggered: heat.tappedIndex = -1
    }
}
