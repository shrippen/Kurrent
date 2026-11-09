import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import "."

/**
 * Labelled heat grid (Kante 1.63, from Kontra's fretboard quiz and Mitori's technique map):
 * rows × columns of cells on KanteHeatmap's scale (KanteStyle.levelColor), with row and column
 * labels, the value as a number in each cell, a legend, a tooltip per cell and keyboard focus.
 * KanteHeatmap stays the unlabelled contribution grid.
 *
 *          FRET  0    1    2    3   …
 *   STRING
 *      G        [90] [75] [ – ] [40]
 *      D        [60] [85] [100] [ 20]
 *   legend  ▢ 0  ▤ 25  ▥ 50  ▦ 75  ■ 100   ▭ no data
 *
 *   rowLabels      ["G", "D", "A", "E"], top to bottom
 *   columnLabels   ["0", "1", …, "12"]; "" leaves one out
 *   rowTitle       name of the rows, above their labels (e.g. "Saite"); optional
 *   columnTitle    name of the columns, above their labels (e.g. "Bund"); optional
 *   rowNames, columnNames   names in the accessible names and tooltips (e.g. "Bund 1" where
 *                  the label is ""); default the label; with neither, that part is left out
 *   cells          one list per row; an entry is a number, null (no data) or
 *                  {value, label, tip, accessibleName}: `label` replaces the number in the
 *                  cell ("" leaves the cell blank), `tip` is the tooltip, `accessibleName` what
 *                  a screen reader says (default "<row>, <column>: <label>", the tooltip's too)
 *   minValue, maxValue   ends of the scale; NaN (default) takes them from the cells. With
 *                  0 and 4 and whole values, each value is its level (discrete steps)
 *   showValues     the number (or label) in each cell (default true); the text carries the
 *                  value, so the colour is never the only sign
 *   formatter      function (value) -> string; default rounds to one decimal and adds `unit`
 *   showEmpty      a cell without data is drawn (ground, rule frame, `emptyText`) and takes
 *                  the focus (default true); false leaves a blank gap that the keys skip
 *                  ("no such combination"); then a grid of gaps only is no Tab stop, and a
 *                  current cell set onto a gap moves onto a drawn one before it takes the focus
 *   legend         the scale below the grid (default true), a KanteLegend: a key per level of
 *                  `legendLevels` (default 0..4) with the value it stands for
 *                  (`legendLabels[level]` overrides it), `legendTitle` before them and
 *                  `noDataText` after them when a cell has no data
 *   interactive    Tab focuses the current cell (default true); arrows move, Home / End go
 *                  to the row's ends, Ctrl+Home / End to the first and last cell, Enter /
 *                  Space or a click fire activated(row, column)
 *
 * Wide grids (Mitori: 20+ attacks on a phone): `scrollable` (default true) lets the cells
 * scroll sideways under row labels that stay, with a scroll bar, when the grid is narrower
 * than its cells; the focused cell is scrolled into view. `rowLabelWidth` caps the row labels
 * (longer ones elide, the full name in a tooltip); `columnLabelsVertical` turns the column
 * labels upright, reading upwards from the cells, so long names allow narrow columns;
 * `columnLabelMaxLength` caps their length (they elide, the full name in a tooltip), and
 * `columnTips` gives a column label a tooltip of its own. `rowLabelFont` sets the row labels'
 * font (e.g. KanteStyle.smallFont, so long names read on a phone).
 *
 * A fixed number of columns that fills the width (1.64, Mitori's form grid): `fillWidth` makes
 * the cells square and as large as the room beside the row labels allows, `cellSize` at least
 * (a text wider than that widens its column; without a width set from outside, the legend's
 * width counts).
 *
 *            ┌ upright column labels, starting on one line above the cells
 *   Ikkyo    [3] [ ] [1] ◂━━ scroll bar ━━▸
 *   Irimi-…  [ ]     [4]       (blank: no data with showEmpty false)
 *
 * Level of a value: round((value - min) / (max - min) × 4), 0 to 4 as
 * KanteStyle.levelColor(level, 4); all values alike on the scale are level 0. Level 0 is the
 * sunken ground with a frame in the frame colour, as the legend keys (apart from the page ground
 * and a gap); a cell without data is the page ground with that frame and `emptyText`. A cell with label "" still says its value
 * (the word of its level in `legendLabels`, else the number) to screen readers. The number takes the ink that reads best on
 * its fill (inkOf); where none reaches 4.5:1 (the middle of the scale), it sits on a small
 * plate of the ground. The focus ring is two lines: the focus colour outside the cell, against
 * the ground, and the ink of the fill inside its edge, so it shows on every level, the full
 * focus colour of level 4 included.
 */
FocusScope {
    id: grid

    property var rowLabels: []
    property var columnLabels: []
    property string rowTitle: ""
    property string columnTitle: ""
    /** Row and column names for screen readers and tooltips; default the labels. */
    property var rowNames: []
    property var columnNames: []
    /** Tooltips of the column labels (e.g. the Japanese name); default none, or the name when elided. */
    property var columnTips: []
    property var cells: []
    property real minValue: NaN
    property real maxValue: NaN
    property bool showValues: true
    property var formatter: null
    property string unit: ""
    /** Text of a cell without data. */
    property string emptyText: "–"
    /** Cells without data are drawn and focusable; false leaves blank gaps the keys skip. */
    property bool showEmpty: true
    property bool legend: true
    property string legendTitle: ""
    /** The levels the legend shows, in this order. */
    property var legendLevels: [0, 1, 2, 3, 4]
    /** Texts of the legend keys by level (index 0..4); default the value of each level. */
    property var legendLabels: []
    /** Legend entry for cells without data; "" leaves it out. */
    property string noDataText: "Keine Daten"
    property bool interactive: true
    /** Smallest side of a cell; a cell grows to fit its text (and with `fillWidth` to fill the width). */
    property real cellSize: KanteStyle.unit(30)
    /**
     * The columns fill the grid's width (1.64): square cells as wide as the width allows,
     * `cellSize` at least (Mitori's form grid: 8 a row on a phone, 11 on a tablet).
     */
    property bool fillWidth: false
    /** Font of the row labels (1.64); default the small mono label font of the column labels. */
    property font rowLabelFont: labelFont
    property real spacing: KanteStyle.unit(3)
    /** The cells scroll sideways under the row labels when the grid is narrower than they are. */
    property bool scrollable: true
    /** Widest the row labels may be (0: as wide as the longest); longer labels elide. */
    property real rowLabelWidth: 0
    /** Column labels upright, reading upwards from the cells. */
    property bool columnLabelsVertical: false
    /** Longest an upright column label may be (0: as long as the longest); longer ones elide. */
    property real columnLabelMaxLength: 0
    /** The focused (or last focused) cell. */
    property int currentRow: 0
    property int currentColumn: 0
    /** Name of the whole grid for screen readers. */
    property string accessibleName: ""

    /** A cell was clicked or chosen with Enter / Space (interactive). */
    signal activated(int row, int column)

    readonly property int rowCount: Math.max(rowLabels.length, cells.length)
    readonly property int columnCount: {
        let n = columnLabels.length
        for (let r = 0; r < cells.length; r++) {
            n = Math.max(n, cells[r] ? cells[r].length : 0)
        }
        return n
    }
    readonly property var dataRange: {
        let lo = Infinity
        let hi = -Infinity
        for (let r = 0; r < cells.length; r++) {
            for (let c = 0; cells[r] && c < cells[r].length; c++) {
                const v = valueOf(r, c)
                if (!isNaN(v)) {
                    lo = Math.min(lo, v)
                    hi = Math.max(hi, v)
                }
            }
        }
        return lo <= hi ? [lo, hi] : [0, 1]
    }
    readonly property real scaleMin: isNaN(minValue) ? dataRange[0] : minValue
    readonly property real scaleMax: isNaN(maxValue) ? dataRange[1] : maxValue
    readonly property bool hasEmpty: {
        for (let r = 0; r < rowCount; r++) {
            for (let c = 0; c < columnCount; c++) {
                if (isEmpty(r, c)) {
                    return true
                }
            }
        }
        return false
    }

    /** Some cell can take the focus (with showEmpty false, not every cell is a gap). */
    readonly property bool hasFocusable: rowCount > 0 && columnCount > 0 && (showEmpty || hasData)
    readonly property bool hasData: {
        for (let r = 0; r < rowCount; r++) {
            for (let c = 0; c < columnCount; c++) {
                if (!isEmpty(r, c)) {
                    return true
                }
            }
        }
        return false
    }
    /** All values alike on the scale: one level (0). */
    readonly property bool flat: scaleMax - scaleMin <= 0

    /** Contrast the number keeps on its cell (WCAG AA for small text). */
    readonly property real minContrast: 4.5
    readonly property font labelFont: KanteStyle.monoFont(KanteStyle.labelFont().pointSize * 0.85, false)
    readonly property font valueFont: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
    /** Side of a cell with `fillWidth`: the room beside the row labels shared by the columns; 0 without. */
    readonly property real fillSide: fillWidth && columnCount > 0
        ? Math.floor((width - labelWidth - spacing - Math.max(0, columnCount - 1) * spacing - 2 * ringRoom) / columnCount)
        : 0
    /** Height of a row of cells: `cellSize`, or the fill side when that is larger. */
    readonly property real cellSide: Math.max(cellSize, fillSide)
    /** Width of a cell: the natural width, or the fill side when that is larger. */
    readonly property real cellWidth: Math.max(naturalCellWidth, cellSide)
    // Cells as wide as the widest text (and the widest column label lying flat).
    readonly property real naturalCellWidth: {
        let w = cellSize
        for (let r = 0; showValues && r < rowCount; r++) {
            for (let c = 0; c < columnCount; c++) {
                w = Math.max(w, valueMetrics.advanceWidth(textOf(r, c)) + KanteStyle.unit(8))
            }
        }
        if (columnLabelsVertical) {
            w = Math.max(w, labelMetrics.height + KanteStyle.unit(4))
        } else {
            for (let c = 0; c < columnLabels.length; c++) {
                w = Math.max(w, labelMetrics.advanceWidth(String(columnLabels[c])) + KanteStyle.unit(4))
            }
        }
        return Math.ceil(w)
    }
    /** Row labels as wide as the widest label (and the row title). */
    readonly property real naturalLabelWidth: {
        // The title as drawn (capitals and letter spacing of the label font), not its bare advance.
        let w = rowTitle !== "" ? rowTitleProbe.implicitWidth : 0
        // Measured anew when the row label font changes.
        void rowLabelMetrics.font
        for (let r = 0; r < rowLabels.length; r++) {
            w = Math.max(w, rowLabelMetrics.advanceWidth(String(rowLabels[r])))
        }
        return Math.ceil(w)
    }
    /** Width of the row labels: the natural width, at most `rowLabelWidth`. */
    readonly property real labelWidth: rowLabelWidth > 0 ? Math.min(naturalLabelWidth, rowLabelWidth) : naturalLabelWidth
    /** Length of an upright column label: the longest, at most `columnLabelMaxLength`. */
    readonly property real columnLabelLength: {
        let w = 0
        for (let c = 0; c < columnLabels.length; c++) {
            w = Math.max(w, labelMetrics.advanceWidth(String(columnLabels[c])))
        }
        w = Math.ceil(w) + 1
        return columnLabelMaxLength > 0 ? Math.min(w, columnLabelMaxLength) : w
    }
    // The header line: lying labels and the row title share a baseline; upright labels start on
    // one line above the cells, the row title stands on it.
    readonly property real headerHeight: columnLabelsVertical
        ? Math.ceil(Math.max(columnLabelLength + KanteStyle.unit(4), titleMetrics.height))
        : Math.ceil(Math.max(labelMetrics.ascent, titleMetrics.ascent) + Math.max(labelMetrics.descent, titleMetrics.descent))
    readonly property real headerBaseline: columnLabelsVertical
        ? headerHeight - KanteStyle.unit(2)
        : Math.max(labelMetrics.ascent, titleMetrics.ascent)
    /** Room around the cells for the focus ring, so a scrolled view does not cut it. */
    readonly property real ringRoom: KanteStyle.lineWidth
    /** Width of all cells (with the ring's room on both sides). */
    readonly property real cellsWidth: columnCount * cellWidth + Math.max(0, columnCount - 1) * spacing + 2 * ringRoom
    /** The same at the natural cell width; the grid's implicit width (the fill follows the width). */
    readonly property real naturalCellsWidth: columnCount * naturalCellWidth + Math.max(0, columnCount - 1) * spacing + 2 * ringRoom
    /** True while the cells scroll under the row labels. */
    readonly property bool scrolling: view.contentWidth > view.width + 0.5
    /** The legend's entries as KanteLegend takes them ({color, text}). */
    readonly property var legendModel: {
        const out = []
        // A flat scale (all values alike) has one level, 0.
        const levels = flat ? [0] : legendLevels
        for (let i = 0; i < levels.length; i++) {
            const k = Math.max(0, Math.min(4, levels[i]))
            out.push({ color: KanteStyle.levelColor(k, 4), text: legendText(k) })
        }
        // No data: a framed key like the framed cell, or a blank one like the gap.
        if (hasEmpty && noDataText !== "") {
            out.push(showEmpty ? { color: "transparent", text: emptyText + " " + noDataText, frame: true }
                               : { color: "transparent", text: noDataText, frame: false })
        }
        return out
    }
    // The legend on one line, so an unsized grid is wide enough for it.
    readonly property real legendNaturalWidth: {
        let w = legendTitle !== "" ? legendTitleText.implicitWidth + KanteStyle.unit(12) : 0
        for (let i = 0; i < legendModel.length; i++) {
            w += KanteStyle.swatchSize + KanteStyle.unit(6) + smallMetrics.advanceWidth(legendModel[i].text) + KanteStyle.unit(12)
        }
        return Math.ceil(w)
    }

    /** Entry of a cell as given: a number, null or an object. */
    function entryOf(r, c) {
        const row = cells[r]
        return row && c < row.length ? row[c] : null
    }
    /** Value of a cell; NaN without data. */
    function valueOf(r, c) {
        const e = entryOf(r, c)
        if (e === null || e === undefined) {
            return NaN
        }
        const v = typeof e === "object" ? e.value : e
        return v === null || v === undefined || v === "" ? NaN : Number(v)
    }
    function hasLabel(r, c) {
        const e = entryOf(r, c)
        return !!e && typeof e === "object" && e.label !== undefined && e.label !== null
    }
    /** A cell without a value and without a label. */
    function isEmpty(r, c) {
        return isNaN(valueOf(r, c)) && !hasLabel(r, c)
    }
    /** A cell the focus can go to: inside the grid, and drawn. */
    function focusable(r, c) {
        return r >= 0 && r < rowCount && c >= 0 && c < columnCount && (showEmpty || !isEmpty(r, c))
    }
    /** A value as the cells and the legend show it. */
    function format(v) {
        if (typeof formatter === "function") {
            return String(formatter(v))
        }
        return Math.round(v * 10) / 10 + unit
    }
    /** Text in a cell: its label, the formatted value or `emptyText`. */
    function textOf(r, c) {
        if (hasLabel(r, c)) {
            return String(entryOf(r, c).label)
        }
        const v = valueOf(r, c)
        return isNaN(v) ? emptyText : format(v)
    }
    /** Level 0 to 4 of a value on the scale, -1 for no data. */
    function levelOf(v) {
        if (isNaN(v)) {
            return -1
        }
        const span = scaleMax - scaleMin
        if (span <= 0) {
            return 0
        }
        return Math.max(0, Math.min(4, Math.round((v - scaleMin) / span * 4)))
    }
    /** Entry i of `names`, else of `labels`, else "" (no invented index: a gap stays a gap). */
    function pick(names, labels, i) {
        if (names && i < names.length && String(names[i]) !== "") {
            return String(names[i])
        }
        return labels && i < labels.length ? String(labels[i]) : ""
    }
    function rowName(r) {
        return pick(rowNames, rowLabels, r)
    }
    function columnName(c) {
        return pick(columnNames, columnLabels, c)
    }
    /** What a screen reader says for a cell; also the default tooltip. */
    function nameOf(r, c) {
        const e = entryOf(r, c)
        if (e && typeof e === "object" && e.accessibleName) {
            return String(e.accessibleName)
        }
        // "G, 3: 80 %"; without a name the part is left out: "G: 80 %", "80 %".
        const where = [rowName(r), columnName(c)].filter(n => n !== "").join(", ")
        // A blank cell (label "") still says its value: the word of its level, else the number.
        let what = textOf(r, c)
        const v = valueOf(r, c)
        if (what === "" && !isNaN(v)) {
            const word = legendLabels && legendLabels[levelOf(v)]
            what = word ? String(word) : format(v)
        }
        if (what === "") {
            return where
        }
        return where !== "" ? where + ": " + what : what
    }
    function tipOf(r, c) {
        const e = entryOf(r, c)
        return e && typeof e === "object" && e.tip ? String(e.tip) : nameOf(r, c)
    }
    /** Text of the legend key of level k: `legendLabels[k]` or the value at level k. */
    function legendText(k) {
        if (legendLabels && k < legendLabels.length && legendLabels[k] !== undefined && legendLabels[k] !== null) {
            return String(legendLabels[k])
        }
        return format(scaleMin + (scaleMax - scaleMin) * k / 4)
    }
    /** `top` over `base` by its alpha, opaque. */
    function over(top, base) {
        const a = top.a
        return Qt.rgba(top.r * a + base.r * (1 - a), top.g * a + base.g * (1 - a), top.b * a + base.b * (1 - a), 1)
    }
    /** Fill of a level as drawn on the page ground (opaque); -1 (no data) is the ground. */
    function fillOf(level) {
        const ground = over(KanteStyle.backgroundColor, KanteStyle.backgroundColor)
        if (level < 0) {
            return ground
        }
        return over(KanteStyle.levelColor(level, 4), ground)
    }
    /**
     * Text colour on a fill: the ground, the strong text or the text on a state colour,
     * whichever reads best (the middle of the cyan scale needs the darkest of them).
     */
    function inkOf(fill) {
        const inks = [KanteStyle.backgroundColor, KanteStyle.strongTextColor, KanteStyle.onStateColor]
        let best = inks[0]
        for (let i = 1; i < inks.length; i++) {
            if (KanteStyle.contrastOf(over(inks[i], fill), fill) > KanteStyle.contrastOf(over(best, fill), fill)) {
                best = inks[i]
            }
        }
        return best
    }
    /** Inner line of the focus ring on a level: the ground or the strong text, whichever stands out on the fill. */
    function ringInnerOf(level) {
        return KanteStyle.inkOn(fillOf(level))
    }
    /** The cell item at row r, column c, or null. */
    function cellAt(r, c) {
        const row = rows.itemAt(r)
        return row ? row.cellAt(c) : null
    }
    /** Moves the focus to a cell, clamped to the grid. */
    function moveTo(r, c) {
        const rr = Math.max(0, Math.min(rowCount - 1, r))
        const cc = Math.max(0, Math.min(columnCount - 1, c))
        // A gap (showEmpty false) never takes the focus.
        if (!focusable(rr, cc)) {
            return
        }
        currentRow = rr
        currentColumn = cc
        const cell = cellAt(currentRow, currentColumn)
        if (cell) {
            cell.forceActiveFocus(Qt.TabFocusReason)
        }
    }
    /** Moves the focus from (r, c) by (dr, dc) to the next focusable cell; stays at the edge. */
    function step(r, c, dr, dc) {
        for (let rr = r + dr, cc = c + dc; rr >= 0 && rr < rowCount && cc >= 0 && cc < columnCount; rr += dr, cc += dc) {
            if (focusable(rr, cc)) {
                moveTo(rr, cc)
                return
            }
        }
    }
    /** First (`last`: last) focusable cell of row r, or of the grid for r < 0, as [row, column]; null if none. */
    function endOf(r, last) {
        const n = rowCount * columnCount
        for (let i = 0; i < n; i++) {
            const k = last ? n - 1 - i : i
            const rr = Math.floor(k / columnCount)
            const cc = k % columnCount
            if ((r < 0 || rr === r) && focusable(rr, cc)) {
                return [rr, cc]
            }
        }
        return null
    }

    /**
     * The focusable cell nearest to (r, c) as [row, column], null if none: (r, c) itself, else
     * the nearest in the same row, else in the same column, else the nearest by rows plus
     * columns. Of two alike, the one further on (right, below) first.
     */
    function nearestOf(r, c) {
        if (focusable(r, c)) {
            return [r, c]
        }
        for (let d = 1; d < columnCount; d++) {
            if (focusable(r, c + d)) {
                return [r, c + d]
            }
            if (focusable(r, c - d)) {
                return [r, c - d]
            }
        }
        for (let d = 1; d < rowCount; d++) {
            if (focusable(r + d, c)) {
                return [r + d, c]
            }
            if (focusable(r - d, c)) {
                return [r - d, c]
            }
        }
        // Backwards, so that of two alike the one further on (below, right) wins.
        let best = null
        let bestDistance = Infinity
        for (let rr = rowCount - 1; rr >= 0; rr--) {
            for (let cc = columnCount - 1; cc >= 0; cc--) {
                const distance = Math.abs(rr - r) + Math.abs(cc - c)
                if (distance < bestDistance && focusable(rr, cc)) {
                    best = [rr, cc]
                    bestDistance = distance
                }
            }
        }
        return best
    }
    /**
     * Keeps the current cell inside the grid and on a focusable cell, so a cell holds the focus:
     * the nearest drawn cell, so the focus stays where it was and the view does not jump.
     */
    function clampCurrent() {
        const r = Math.max(0, Math.min(rowCount - 1, currentRow))
        const c = Math.max(0, Math.min(columnCount - 1, currentColumn))
        const to = nearestOf(r, c) || [r, c]
        currentRow = to[0]
        currentColumn = to[1]
    }
    onRowCountChanged: clampCurrent()
    onColumnCountChanged: clampCurrent()
    onCellsChanged: clampCurrent()
    onShowEmptyChanged: clampCurrent()
    // The app may set the current cell onto a gap while a cell has the focus: settle it on a
    // drawn cell once the change is done (not at once: a cell taking the focus sets the row,
    // then the column, and the step between may be a gap). Only with the focus in the grid:
    // without it, the app may set the row now and the column later, and the focus settles the
    // cell when it comes (focusCurrent).
    onCurrentRowChanged: Qt.callLater(settleCurrent)
    onCurrentColumnChanged: Qt.callLater(settleCurrent)
    function settleCurrent() {
        if (activeFocus && !focusable(currentRow, currentColumn)) {
            focusCurrent()
        }
    }
    Component.onCompleted: clampCurrent()
    // The scope itself holds the focus only when no cell took it (e.g. its cell went away):
    // hand it on, and send keys there.
    onActiveFocusChanged: {
        if (activeFocus) {
            Qt.callLater(focusCurrent)
        }
    }
    function focusCurrent() {
        // The app may have set the current cell onto a gap: move it onto a drawn cell first.
        clampCurrent()
        const cell = focusable(currentRow, currentColumn) ? cellAt(currentRow, currentColumn) : null
        if (activeFocus && cell && !cell.activeFocus) {
            cell.forceActiveFocus(Qt.TabFocusReason)
        }
    }
    Keys.onPressed: function (event) {
        clampCurrent()
        const cell = focusable(currentRow, currentColumn) ? cellAt(currentRow, currentColumn) : null
        if (!interactive || !cell || cell.activeFocus) {
            return
        }
        cell.forceActiveFocus(Qt.TabFocusReason)
        event.accepted = true
    }

    /** Scrolls the cells so that `item` (a cell) shows whole, its focus ring included. */
    function reveal(item) {
        if (!item) {
            return
        }
        const x = item.mapToItem(view.contentItem, 0, 0).x
        let cx = view.contentX
        if (x - ringRoom < cx) {
            cx = x - ringRoom
        } else if (x + item.width + ringRoom > cx + view.width) {
            cx = x + item.width + ringRoom - view.width
        }
        view.contentX = Math.max(0, Math.min(Math.max(0, view.contentWidth - view.width), cx))
    }
    /** After a size change: the focused cell stays in view, else the first column shows (right to left the right end). */
    function keepInView() {
        const cell = cellAt(currentRow, currentColumn)
        if (cell && cell.activeFocus) {
            reveal(cell)
        } else {
            view.contentX = header.effectiveLayoutDirection === Qt.RightToLeft ? Math.max(0, view.contentWidth - view.width) : 0
        }
    }

    implicitWidth: Math.max(labelWidth + spacing + naturalCellsWidth, legend ? legendNaturalWidth : 0)
    implicitHeight: body.implicitHeight

    // A focus scope in the Tab chain: Tab enters at the current cell, the next Tab leaves.
    // No Tab stop when every cell is a gap. While the scope itself holds the focus (its cell
    // turned into a gap), it stays in the chain until the focus leaves: Qt does not take an
    // active focus item out of it, and Tab from outside the chain would run backwards.
    activeFocusOnTab: (interactive && hasFocusable) || (activeFocus && Window.activeFocusItem === grid)

    Accessible.role: Accessible.Table
    Accessible.name: accessibleName

    FontMetrics {
        id: labelMetrics
        font: grid.labelFont
    }
    FontMetrics {
        id: rowLabelMetrics
        font: grid.rowLabelFont
    }
    FontMetrics {
        id: titleMetrics
        font: KanteStyle.labelFont()
    }
    FontMetrics {
        id: valueMetrics
        font: grid.valueFont
    }
    FontMetrics {
        id: smallMetrics
        font: KanteStyle.smallFont
    }
    Text {
        id: rowTitleProbe
        visible: false
        text: grid.rowTitle
        font: KanteStyle.labelFont()
    }

    Column {
        id: body
        width: grid.width
        spacing: grid.spacing

        // Column title, above the column labels; it stays while the cells scroll.
        Row {
            visible: grid.columnTitle !== ""
            spacing: grid.spacing
            Item {
                width: grid.labelWidth + grid.ringRoom
                height: 1
            }
            Text {
                text: grid.columnTitle
                color: KanteStyle.mutedTextColor
                font: KanteStyle.labelFont()
                Accessible.ignored: true
            }
        }

        // The row title and labels on the start side, standing; the cells beside them.
        Row {
            spacing: grid.spacing

            Column {
                spacing: grid.spacing
                Item {
                    width: grid.labelWidth
                    height: grid.headerHeight
                    Text {
                        objectName: "kanteHeatRowTitle"
                        width: parent.width
                        y: grid.headerBaseline - titleMetrics.ascent
                        text: grid.rowTitle
                        elide: Text.ElideRight
                        color: KanteStyle.mutedTextColor
                        font: KanteStyle.labelFont()
                        Accessible.ignored: true
                    }
                }
                Repeater {
                    model: grid.rowCount
                    delegate: Text {
                        id: rowLabel
                        required property int index
                        objectName: "kanteHeatRowLabel"
                        width: grid.labelWidth
                        height: grid.cellSide
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: index < grid.rowLabels.length ? String(grid.rowLabels[index]) : ""
                        color: KanteStyle.mutedTextColor
                        font: grid.rowLabelFont
                        Accessible.ignored: true

                        // The full name where the label is cut.
                        HoverHandler {
                            id: rowHover
                        }
                        QQC2.ToolTip.text: grid.rowName(index)
                        QQC2.ToolTip.visible: rowHover.hovered && truncated
                        QQC2.ToolTip.delay: 300
                    }
                }
            }

            Column {
                Flickable {
                    id: view
                    objectName: "kanteHeatView"
                    width: grid.scrollable
                        ? Math.max(0, Math.min(contentWidth, grid.width - grid.labelWidth - grid.spacing))
                        : contentWidth
                    height: contentHeight
                    contentWidth: grid.cellsWidth
                    contentHeight: cellBody.implicitHeight + grid.ringRoom
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: grid.scrolling
                    clip: grid.scrolling
                    QQC2.ScrollBar.horizontal: bar

                    onWidthChanged: Qt.callLater(grid.keepInView)
                    onContentWidthChanged: Qt.callLater(grid.keepInView)

                    Column {
                        id: cellBody
                        x: grid.ringRoom
                        spacing: grid.spacing

                        // Column labels above their cells: lying on the row title's baseline,
                        // or upright, starting on one line above the cells.
                        Row {
                            id: header
                            spacing: grid.spacing
                            Repeater {
                                model: grid.columnCount
                                delegate: Item {
                                    id: columnHead
                                    required property int index
                                    readonly property string tip: index < grid.columnTips.length && String(grid.columnTips[index]) !== ""
                                        ? String(grid.columnTips[index])
                                        : columnLabel.truncated ? grid.columnName(index) : ""
                                    width: grid.cellWidth
                                    height: grid.headerHeight

                                    Text {
                                        id: columnLabel
                                        objectName: "kanteHeatColumnLabel"
                                        readonly property real length: grid.columnLabelsVertical ? grid.columnLabelLength : grid.cellWidth
                                        width: length
                                        height: grid.columnLabelsVertical ? labelMetrics.height : implicitHeight
                                        x: (parent.width - width) / 2
                                        // Upright: the box turns about its centre, its start (left end) down
                                        // onto the line above the cells.
                                        y: grid.columnLabelsVertical
                                            ? grid.headerBaseline - length / 2 - height / 2
                                            : grid.headerBaseline - labelMetrics.ascent
                                        rotation: grid.columnLabelsVertical ? -90 : 0
                                        LayoutMirroring.enabled: false
                                        horizontalAlignment: grid.columnLabelsVertical ? Text.AlignLeft : Text.AlignHCenter
                                        elide: grid.columnLabelsVertical ? Text.ElideRight : Text.ElideNone
                                        text: columnHead.index < grid.columnLabels.length ? String(grid.columnLabels[columnHead.index]) : ""
                                        color: KanteStyle.mutedTextColor
                                        font: grid.labelFont
                                        Accessible.ignored: true
                                    }
                                    HoverHandler {
                                        id: columnHover
                                    }
                                    QQC2.ToolTip.text: tip
                                    QQC2.ToolTip.visible: columnHover.hovered && tip !== ""
                                    QQC2.ToolTip.delay: 300
                                }
                            }
                        }

                        // One row of cells per label.
                        Repeater {
                            id: rows
                            model: grid.rowCount
                            delegate: Row {
                                id: rowItem
                                required property int index
                                readonly property int row: index
                                spacing: grid.spacing

                                function cellAt(c) {
                                    return cellRepeater.itemAt(c)
                                }

                                Repeater {
                                    id: cellRepeater
                                    model: grid.columnCount
                                    delegate: Item {
                                        id: cell
                                        required property int index
                                        readonly property int row: rowItem.row
                                        readonly property int column: index
                                        readonly property real value: grid.valueOf(row, column)
                                        readonly property int level: grid.levelOf(value)
                                        readonly property string text: grid.textOf(row, column)
                                        readonly property bool current: grid.currentRow === row && grid.currentColumn === column
                                        /** Drawn; with showEmpty false a cell without data is a blank gap. */
                                        readonly property bool shown: grid.showEmpty || !grid.isEmpty(row, column)

                                        objectName: "kanteHeatCell"
                                        width: grid.cellWidth
                                        height: grid.cellSide
                                        focus: current && shown

                                        Accessible.role: Accessible.Cell
                                        Accessible.name: grid.nameOf(row, column)
                                        Accessible.focusable: grid.interactive && shown
                                        Accessible.focused: activeFocus
                                        Accessible.ignored: !shown

                                        QQC2.ToolTip.text: grid.tipOf(row, column)
                                        QQC2.ToolTip.visible: shown && (hover.hovered || activeFocus)
                                        QQC2.ToolTip.delay: hover.hovered ? 300 : 0

                                        onActiveFocusChanged: {
                                            if (activeFocus) {
                                                grid.currentRow = row
                                                grid.currentColumn = column
                                                grid.reveal(cell)
                                            }
                                        }

                                        Item {
                                            anchors.fill: parent
                                            visible: cell.shown

                                            Rectangle {
                                                objectName: "kanteHeatFill"
                                                anchors.fill: parent
                                                color: cell.level < 0 ? "transparent" : KanteStyle.levelColor(cell.level, 4)
                                                // No data and level 0 framed in the frame colour, as the
                                                // legend keys: level 0 stays apart from the ground and a gap.
                                                border.width: cell.level <= 0 ? KanteStyle.borderWidth : 0
                                                border.color: KanteStyle.frameColor
                                            }
                                            // The number in its best ink; where no ink reaches 4.5:1 on the
                                            // fill (the middle of the scale), on a plate of the ground.
                                            Rectangle {
                                                objectName: "kanteHeatPlate"
                                                readonly property color fill: grid.fillOf(cell.level)
                                                readonly property color ink: grid.inkOf(fill)
                                                readonly property bool needed: cell.level >= 0
                                                    && KanteStyle.contrastOf(grid.over(ink, fill), fill) < grid.minContrast
                                                visible: grid.showValues && cell.text !== ""
                                                anchors.centerIn: parent
                                                width: valueText.implicitWidth + KanteStyle.unit(4)
                                                height: valueText.implicitHeight
                                                color: needed ? KanteStyle.backgroundColor : "transparent"
                                                Text {
                                                    id: valueText
                                                    objectName: "kanteHeatValue"
                                                    anchors.centerIn: parent
                                                    text: cell.text
                                                    color: cell.level < 0 ? KanteStyle.mutedTextColor
                                                         : parent.needed ? KanteStyle.strongTextColor : parent.ink
                                                    font: grid.valueFont
                                                    Accessible.ignored: true
                                                }
                                            }
                                            // Focus ring: the focus colour outside the cell (against the
                                            // ground), the fill's ink inside its edge (against the fill),
                                            // so it shows on every level, the full focus colour too.
                                            Rectangle {
                                                objectName: "kanteHeatRing"
                                                visible: cell.activeFocus
                                                anchors.fill: parent
                                                anchors.margins: -grid.ringRoom
                                                color: "transparent"
                                                border.width: grid.ringRoom
                                                border.color: KanteStyle.focusColor
                                                Rectangle {
                                                    objectName: "kanteHeatRingInner"
                                                    anchors.fill: parent
                                                    anchors.margins: grid.ringRoom
                                                    color: "transparent"
                                                    border.width: KanteStyle.lineWidth
                                                    border.color: grid.ringInnerOf(cell.level)
                                                }
                                            }
                                        }

                                        HoverHandler {
                                            id: hover
                                            enabled: cell.shown
                                        }
                                        TapHandler {
                                            enabled: grid.interactive && cell.shown
                                            onTapped: {
                                                grid.moveTo(cell.row, cell.column)
                                                grid.activated(cell.row, cell.column)
                                            }
                                        }

                                        Keys.enabled: grid.interactive
                                        Keys.onPressed: function (event) {
                                            const ctrl = event.modifiers & Qt.ControlModifier
                                            // Right to left the columns run from the right: Left goes on.
                                            const ahead = rowItem.effectiveLayoutDirection === Qt.RightToLeft ? -1 : 1
                                            if (event.key === Qt.Key_Left) {
                                                grid.step(row, column, 0, -ahead)
                                            } else if (event.key === Qt.Key_Right) {
                                                grid.step(row, column, 0, ahead)
                                            } else if (event.key === Qt.Key_Up) {
                                                grid.step(row, column, -1, 0)
                                            } else if (event.key === Qt.Key_Down) {
                                                grid.step(row, column, 1, 0)
                                            } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                                                const to = grid.endOf(ctrl ? -1 : row, event.key === Qt.Key_End)
                                                if (to) {
                                                    grid.moveTo(to[0], to[1])
                                                }
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                                grid.activated(row, column)
                                            } else {
                                                return
                                            }
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Where the view stands while the cells scroll.
                QQC2.ScrollBar {
                    id: bar
                    objectName: "kanteHeatScrollBar"
                    width: view.width
                    orientation: Qt.Horizontal
                    visible: grid.scrolling
                    policy: QQC2.ScrollBar.AlwaysOn
                }
            }
        }

        // Legend: a key per level with the value it stands for, then "no data"; wraps when narrow.
        Row {
            id: legendRow
            objectName: "kanteHeatLegend"
            visible: grid.legend
            spacing: KanteStyle.unit(12)
            topPadding: KanteStyle.unit(4)

            Text {
                id: legendTitleText
                visible: grid.legendTitle !== ""
                text: grid.legendTitle
                color: KanteStyle.mutedTextColor
                font: KanteStyle.labelFont()
            }
            KanteLegend {
                id: legendKeys
                objectName: "kanteHeatLegendKeys"
                width: Math.max(KanteStyle.unit(40), grid.width - (legendTitleText.visible ? legendTitleText.width + legendRow.spacing : 0))
                model: grid.legendModel
            }
        }
    }
}
