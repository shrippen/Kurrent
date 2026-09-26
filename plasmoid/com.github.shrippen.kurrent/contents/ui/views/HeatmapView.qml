import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../Kante"
import "../datetime.js" as DateTime

ColumnLayout {
    id: root

    required property TaskController controller
    // The tiles above the pane show the figures (FullView); then the own row stays hidden.
    property bool factsInTiles: false
    property bool interactionsSuspended: false
    property Item dragHost: null
    property var onOpenFullEditor: null

    implicitHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredHeight: 0
    Layout.minimumHeight: 0
    spacing: Design.spaceSmall

    property string heatmapMode: "completed"
    property bool showYear: false

    property var monthStart: {
        var d = new Date()
        return new Date(d.getFullYear(), d.getMonth(), 1)
    }

    // Day whose tasks the list beside the month grid shows: today, or the 1st of another month.
    property var selectedDay: {
        var d = new Date()
        return new Date(d.getFullYear(), d.getMonth(), d.getDate())
    }
    onMonthStartChanged: {
        var t = new Date()
        selectedDay = (t.getFullYear() === monthStart.getFullYear() && t.getMonth() === monthStart.getMonth())
                ? new Date(t.getFullYear(), t.getMonth(), t.getDate()) : new Date(monthStart)
    }

    // Tasks behind the selected cell; re-read whenever the counts change.
    readonly property var selectedDayTasks: {
        var dep = activeCounts
        return controller && selectedDay ? controller.heatmapTasksForDay(selectedDay, heatmapMode) : []
    }

    function sameDay(a, b) {
        return !!a && !!b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth()
                && a.getDate() === b.getDate()
    }

    function openTask(task) {
        if (dragHost && dragHost.inspectorActive) {
            dragHost.inspectTask(task.itemId)
        } else if (onOpenFullEditor) {
            onOpenFullEditor(task)
        }
    }

    // ── Sizing ─────────────────────────────────────────────────────
    readonly property int cellSize: showYear ? Math.max(6, Math.min(Design.heatmapCellSize,
            Math.floor((root.width - Kirigami.Units.gridUnit * 3.5) / Math.max(1, yearWeekCount)) - 2))
                                             : Math.max(Design.heatmapCellSize, Math.floor((root.width - 20) / 7) - 2)
    readonly property int cellPitch: cellSize + 2

    // ── Helpers ────────────────────────────────────────────────────
    function addDays(d, n) {
        var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        r.setDate(r.getDate() + n)
        return r
    }

    function mondayOf(d) {
        var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        r.setDate(r.getDate() - ((r.getDay() + 6) % 7))
        return r
    }

    function computeYearWeeks(y) {
        var first = mondayOf(new Date(y, 0, 1))
        var last = new Date(y, 11, 31)
        var weeks = []
        for (var w = first; w <= last; w = addDays(w, 7))
            weeks.push(new Date(w.getFullYear(), w.getMonth(), w.getDate()))
        return weeks
    }

    function computeYearCells(y, weeks) {
        var yearStart = new Date(y, 0, 1)
        var yearEnd = new Date(y, 11, 31)
        var cells = []
        for (var wd = 0; wd < 7; ++wd) {
            for (var wi = 0; wi < weeks.length; ++wi) {
                var d = addDays(weeks[wi], wd)
                cells.push((d >= yearStart && d <= yearEnd) ? d : null)
            }
        }
        return cells
    }

    function computeYearMonthLabels(y, weeks) {
        var labels = []
        for (var w = 0; w < weeks.length; ++w) {
            var mon = weeks[w]
            var prev = w > 0 ? weeks[w - 1] : null
            labels.push((w === 0 || (prev && mon.getMonth() !== prev.getMonth()))
                        ? Qt.locale().toString(mon, "MMM") : "")
        }
        return labels
    }

    function dateKey(d) {
        return Qt.locale().toString(d, "yyyy-MM-dd")
    }

    // ── Month data ─────────────────────────────────────────────────
    readonly property var monthCells: {
        var y = monthStart.getFullYear()
        var m = monthStart.getMonth()
        var days = new Date(y, m + 1, 0).getDate()
        var lead = (new Date(y, m, 1).getDay() + 6) % 7
        var cells = []
        for (var i = 0; i < lead; ++i) cells.push(null)
        for (var day = 1; day <= days; ++day) cells.push(new Date(y, m, day))
        while (cells.length % 7 !== 0) cells.push(null)
        return cells
    }

    // ── Year data: first year for cellSize calculation ──────────────
    readonly property var yearWeeks: computeYearWeeks(monthStart.getFullYear())
    readonly property int yearWeekCount: yearWeeks.length

    // ── Multi-year: how many years fit vertically ──────────────────
    readonly property int selectedYear: monthStart.getFullYear()
    // month labels (16) + grid (7 * cellPitch) + year label (20) + spacing
    readonly property int yearBlockHeight: 16 + 7 * cellPitch + 20 + Kirigami.Units.largeSpacing
    readonly property int maxVisibleYears: {
        var avail = root.height - 100 // header + mode bar + legend + margins
        return Math.max(1, Math.floor(avail / Math.max(1, yearBlockHeight)))
    }
    readonly property var visibleYearNumbers: {
        var arr = []
        for (var i = 0; i < maxVisibleYears; i++)
            arr.push(selectedYear - i)
        return arr
    }

    // ── Counts: merged for all visible years in year mode ──────────
    readonly property var activeCounts: {
        if (!controller) return ({})
        if (showYear) {
            var merged = {}
            for (var i = 0; i < visibleYearNumbers.length; i++) {
                var yc = controller.heatmapCountsForYear(visibleYearNumbers[i], heatmapMode)
                var keys = Object.keys(yc)
                for (var j = 0; j < keys.length; j++)
                    merged[keys[j]] = yc[keys[j]]
            }
            return merged
        }
        return controller.heatmapCountsForMonth(monthStart, heatmapMode)
    }

    // Figures for the facts row: total, average per day so far, best day (shown period).
    readonly property var periodFacts: {
        var keys = Object.keys(activeCounts)
        var total = 0
        var bestCount = 0
        var bestKey = ""
        for (var i = 0; i < keys.length; ++i) {
            var n = activeCounts[keys[i]] || 0
            total += n
            if (n > bestCount) {
                bestCount = n
                bestKey = keys[i]
            }
        }
        var start = showYear ? new Date(monthStart.getFullYear(), 0, 1) : new Date(monthStart)
        var end = showYear ? new Date(monthStart.getFullYear() + 1, 0, 1)
                           : new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 1)
        var now = new Date()
        var until = now < end ? now : end
        var days = Math.max(1, Math.ceil((until - start) / 86400000))
        var bestDate = bestKey.length ? new Date(bestKey + "T00:00:00") : null
        return {
            total: total,
            perDay: now < start ? 0 : total / days,
            bestCount: bestCount,
            bestLabel: bestDate && !isNaN(bestDate) ? Qt.locale().toString(bestDate, Qt.locale().dateFormat(Locale.ShortFormat)) : ""
        }
    }

    function countForDate(d) {
        var key = dateKey(d)
        return activeCounts[key] !== undefined ? activeCounts[key] : 0
    }

    function heatmapTooltip(d, count) {
        if (!d) {
            return ""
        }
        if (count === 0) {
            return Qt.locale().toString(d, "ddd, MMM d")
        }
        var noun = heatmapMode === "completed"
            ? (count === 1 ? i18n("task completed") : i18n("tasks completed"))
            : (count === 1 ? i18n("task due") : i18n("tasks due"))
        return i18n("%1 %2 on %3", count, noun, Qt.locale().toString(d, "ddd, MMM d"))
    }

    // ── Year block component (used in year mode Flickable) ─────────
    component YearBlock: ColumnLayout {
        required property int yearNumber
        spacing: 2

        readonly property var _weeks: root.computeYearWeeks(yearNumber)
        readonly property int _weekCount: _weeks.length
        readonly property var _cells: root.computeYearCells(yearNumber, _weeks)
        readonly property var _monthLabels: root.computeYearMonthLabels(yearNumber, _weeks)

        QQC2.Label {
            text: yearNumber
            font.bold: true
            font.family: Design.headingFamily
            font.capitalization: KanteStyle.themed ? Font.AllUppercase : Font.MixedCase
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.8
        }

        Row {
            spacing: 2
            Repeater {
                model: _monthLabels
                delegate: Item {
                    required property string modelData
                    width: root.cellPitch
                    height: 16
                    QQC2.Label {
                        visible: modelData !== ""
                        text: modelData
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.7
                    }
                }
            }
        }

        Grid {
            rows: 7
            columns: _weekCount
            spacing: 2
            Repeater {
                model: _cells
                delegate: Rectangle {
                    required property var modelData
                    readonly property int count: modelData ? root.countForDate(modelData) : 0
                    width: root.cellSize
                    height: root.cellSize
                    radius: 2
                    visible: modelData !== null
                    color: count > 0 ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                            Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b,
                            Math.min(0.85, 0.15 + count * 0.15)) : "transparent"
                    opacity: modelData !== null ? 1 : 0
                    border.color: modelData !== null && count === 0
                                  ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                            Kirigami.Theme.textColor.b, 0.14) : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData !== null
                        hoverEnabled: enabled && !root.interactionsSuspended
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            controller.agendaSelectedDate = modelData
                            controller.requestMainPaneMode("calendar")
                        }
                        QQC2.ToolTip.text: root.heatmapTooltip(modelData, count)
                        QQC2.ToolTip.visible: containsMouse && modelData !== null
                    }
                }
            }
        }
    }

    // ── Header: period navigation, Month / Year and mode in one row ──
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceSmall

        KanteToolButton {
            icon.name: "go-previous"
            Accessible.name: i18n("Previous")
            onClicked: {
                var d = new Date(root.monthStart)
                if (root.showYear) d.setFullYear(d.getFullYear() - 1)
                else d.setMonth(d.getMonth() - 1)
                root.monthStart = d
            }
        }

        KanteToolButton {
            text: i18n("Today")
            onClicked: root.monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
        }

        KanteToolButton {
            icon.name: "go-next"
            Accessible.name: i18n("Next")
            onClicked: {
                var d = new Date(root.monthStart)
                if (root.showYear) d.setFullYear(d.getFullYear() + 1)
                else d.setMonth(d.getMonth() + 1)
                root.monthStart = d
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: root.showYear
                  ? (root.visibleYearNumbers.length > 1
                     ? root.visibleYearNumbers[root.visibleYearNumbers.length - 1] + " \u2013 " + root.visibleYearNumbers[0]
                     : Qt.locale().toString(root.monthStart, "yyyy"))
                  : Qt.locale().toString(root.monthStart, "MMMM yyyy")
            elide: Text.ElideRight
            font.bold: true
            font.family: Design.headingFamily
            font.capitalization: KanteStyle.themed ? Font.AllUppercase : Font.MixedCase
        }

        KanteToolButton {
            text: i18n("Month")
            checkable: true
            checked: !root.showYear
            onClicked: root.showYear = false
        }
        KanteToolButton {
            text: i18n("Year")
            checkable: true
            checked: root.showYear
            onClicked: root.showYear = true
        }

        QQC2.ComboBox {
            KanteFieldSkin { control: parent }
            Accessible.name: i18n("Mode:")
            model: [
                { text: i18n("Completions"), value: "completed" },
                { text: i18n("Due dates"), value: "due" }
            ]
            textRole: "text"
            onActivated: root.heatmapMode = model[currentIndex].value
        }
    }

    // Same figures as tiles for the row above the pane (FullView / ViewTiles).
    readonly property var tileFacts: [
        { label: heatmapMode === "completed" ? i18n("Completed") : i18n("Due"),
          value: String(periodFacts.total), tone: heatmapMode === "completed" ? KanteStyle.positiveTextColor : KanteStyle.mutedTextColor },
        { label: i18n("Per day"), value: periodFacts.perDay.toLocaleString(Qt.locale(), "f", 1),
          tone: KanteStyle.mutedTextColor },
        { label: periodFacts.bestCount > 0 ? i18n("Best day · %1", periodFacts.bestLabel) : i18n("Best day"),
          value: periodFacts.bestCount > 0 ? String(periodFacts.bestCount) : "–", tone: KanteStyle.mutedTextColor },
        { label: i18n("Overdue"), viewId: "overdue", tone: KanteStyle.negativeTextColor,
          value: String(controller && controller.viewTaskCounts ? (controller.viewTaskCounts["overdue"] || 0) : 0) }
    ]

    // ── Facts: total · per day · best day (Kante: big Rajdhani figures) ─────
    RowLayout {
        Layout.fillWidth: true
        visible: !root.factsInTiles
        spacing: Design.spaceMedium

        Repeater {
            model: [
                { value: String(root.periodFacts.total),
                  label: root.heatmapMode === "completed" ? i18n("Completed") : i18n("Due") },
                { value: root.periodFacts.perDay.toLocaleString(Qt.locale(), "f", 1), label: i18n("Per day") },
                { value: root.periodFacts.bestCount > 0 ? String(root.periodFacts.bestCount) : "–",
                  label: root.periodFacts.bestCount > 0 ? i18n("Best day · %1", root.periodFacts.bestLabel) : i18n("Best day") }
            ]

            delegate: ColumnLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 2

                Rectangle {
                    visible: KanteStyle.active
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    color: KanteStyle.frameColor
                }
                QQC2.Label {
                    text: parent.modelData.value
                    font: KanteStyle.active ? KanteStyle.titleFont(Kirigami.Theme.defaultFont.pointSize * 2)
                                            : Qt.font({ family: Kirigami.Theme.defaultFont.family,
                                                        pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6, bold: true })
                    color: KanteStyle.active && parent.index === 0 ? KanteStyle.accentTextColor : KanteStyle.strongTextColor
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: parent.modelData.label
                    font: KanteStyle.active ? KanteStyle.labelFont() : Kirigami.Theme.smallFont
                    color: KanteStyle.mutedTextColor
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── Month: compact grid with its legend; the selected day's tasks beside (wide) or below ──
    Item {
        id: monthArea
        Layout.fillWidth: true
        Layout.fillHeight: !root.showYear
        visible: !root.showYear

        readonly property bool listBeside: width >= Kirigami.Units.gridUnit * 30
        readonly property int rows: Math.max(1, root.monthCells.length / 7)
        readonly property real gridWidth: listBeside ? Math.min(width * 0.55, width - Kirigami.Units.gridUnit * 13) : width
        readonly property real gridHeight: listBeside ? height : height - Kirigami.Units.gridUnit * 9
        // Square cells: as large as width and height allow, capped so the month stays compact.
        readonly property int cell: Math.max(Kirigami.Units.gridUnit, Math.floor(Math.min(
                (gridWidth - 12) / 7,
                (gridHeight - Kirigami.Units.gridUnit * 2.6 - rows * 2) / rows,
                Kirigami.Units.gridUnit * 4)))

        ColumnLayout {
            id: monthGridColumn
            width: monthArea.gridWidth
            spacing: Design.spaceSmall

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 7
                spacing: 2

                Repeater {
                    model: [i18n("Mo"), i18n("Tu"), i18n("We"), i18n("Th"), i18n("Fr"), i18n("Sa"), i18n("Su")]
                    delegate: QQC2.Label {
                        required property string modelData
                        width: monthArea.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.6
                    }
                }

                Repeater {
                    model: root.monthCells
                    delegate: Rectangle {
                        id: dayCell
                        required property var modelData
                        readonly property int count: modelData ? root.countForDate(modelData) : 0
                        readonly property bool selected: root.sameDay(modelData, root.selectedDay)
                        readonly property bool isToday: root.sameDay(modelData, new Date())
                        width: monthArea.cell
                        height: monthArea.cell
                        radius: KanteStyle.active ? 0 : 3
                        opacity: modelData !== null ? 1 : 0
                        color: count > 0 ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b,
                                Math.min(0.85, 0.15 + count * 0.15)) : "transparent"
                        border.width: selected ? 2 : 1
                        border.color: selected ? Kirigami.Theme.focusColor
                                    : (count === 0 ? KanteStyle.tint(Kirigami.Theme.textColor, 0.14) : "transparent")

                        // Day number top left, count in the middle.
                        QQC2.Label {
                            x: 4
                            y: 2
                            text: dayCell.modelData ? dayCell.modelData.getDate() : ""
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.bold: dayCell.isToday
                            color: dayCell.count > 0 ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            opacity: dayCell.isToday || dayCell.count > 0 ? 1 : 0.6
                        }
                        QQC2.Label {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: monthArea.cell > Kirigami.Units.gridUnit * 2 ? 3 : 0
                            visible: dayCell.count > 0 && monthArea.cell >= Kirigami.Units.gridUnit * 1.6
                            text: dayCell.count
                            font: KanteStyle.active
                                  ? KanteStyle.titleFont(Kirigami.Theme.defaultFont.pointSize * 1.2)
                                  : Qt.font({ family: Kirigami.Theme.defaultFont.family,
                                              pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1, bold: true })
                            color: Kirigami.Theme.highlightedTextColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: dayCell.modelData !== null
                            hoverEnabled: enabled && !root.interactionsSuspended
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedDay = dayCell.modelData
                            QQC2.ToolTip.text: root.heatmapTooltip(dayCell.modelData, dayCell.count)
                            QQC2.ToolTip.visible: containsMouse && dayCell.modelData !== null
                        }
                    }
                }
            }

            HeatmapLegend {
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Tasks of the selected day.
        ColumnLayout {
            x: monthArea.listBeside ? monthArea.gridWidth + Design.spaceMedium : 0
            y: monthArea.listBeside ? 0 : monthGridColumn.height + Design.spaceMedium
            width: monthArea.width - x
            height: monthArea.height - y
            spacing: Design.spaceSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.spaceSmall

                KanteHeading {
                    Layout.fillWidth: true
                    level: 5
                    elide: Text.ElideRight
                    text: root.selectedDay
                          ? (root.heatmapMode === "completed"
                             ? i18n("Completed on %1", Qt.locale().toString(root.selectedDay, "ddd, d. MMM"))
                             : i18n("Due on %1", Qt.locale().toString(root.selectedDay, "ddd, d. MMM")))
                          : ""
                }
                CountBadge {
                    text: String(root.selectedDayTasks.length)
                }
                KanteToolButton {
                    icon.name: "view-calendar-day"
                    display: QQC2.AbstractButton.IconOnly
                    text: i18n("Open in calendar")
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    onClicked: {
                        controller.agendaSelectedDate = root.selectedDay
                        controller.requestMainPaneMode("calendar")
                    }
                }
            }

            ListView {
                id: dayList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.selectedDayTasks
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                delegate: QQC2.ItemDelegate {
                    id: dayTask
                    required property var modelData
                    width: dayList.width
                    hoverEnabled: !root.interactionsSuspended
                    onClicked: root.openTask(modelData)
                    contentItem: RowLayout {
                        spacing: Design.spaceSmall
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: dayTask.modelData.completed ? "checkbox" : "view-task"
                            color: dayTask.modelData.completed ? KanteStyle.positiveTextColor : Kirigami.Theme.textColor
                            isMask: true
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: dayTask.modelData.summary
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            text: dayTask.modelData.collectionName || ""
                            visible: text.length > 0 && dayList.width > Kirigami.Units.gridUnit * 14
                            font: Kirigami.Theme.smallFont
                            color: KanteStyle.mutedTextColor
                            elide: Text.ElideRight
                            Layout.maximumWidth: dayList.width * 0.35
                        }
                    }
                }

                QQC2.Label {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: dayList.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: i18n("Nothing on this day.")
                    color: KanteStyle.mutedTextColor
                }
            }
        }
    }

    // ── Year grid: GitHub-style multi-year with weekday axis ────────
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: root.showYear
        visible: root.showYear
        spacing: Design.spaceTiny

        // Weekday axis (fixed left, spans all year blocks)
        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignTop
            // Month-labels spacer
            Item { width: 1; height: 36 }

            Repeater {
                model: [i18n("Mo"), "", i18n("We"), "", i18n("Fr"), "", ""]
                delegate: QQC2.Label {
                    required property string modelData
                    width: Math.round(Kirigami.Units.gridUnit * 1.6)
                    height: root.cellSize
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: modelData !== "" ? 0.6 : 0
                }
            }
        }

        // Scrollable year blocks
        Flickable {
            id: yearFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: yearColumn.implicitHeight
            contentWidth: yearColumn.implicitWidth
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: yearColumn
                width: yearFlick.width
                spacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: root.visibleYearNumbers
                    delegate: YearBlock {
                        required property int modelData
                        yearNumber: modelData
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // ── Legend (year mode; the month grid carries its own) ──
    HeatmapLegend {
        visible: root.showYear && Object.keys(root.activeCounts).length > 0
    }

    component HeatmapLegend: RowLayout {
        spacing: Design.spaceTiny

        QQC2.Label { text: i18n("Few"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.5 }

        Repeater {
            model: [0.15, 0.30, 0.45, 0.60, 0.80]
            delegate: Rectangle {
                required property var modelData
                width: Design.heatmapCellSize * 0.6
                height: Design.heatmapCellSize * 0.6
                radius: KanteStyle.active ? 0 : 2
                color: Kirigami.Theme.highlightColor
                opacity: modelData
            }
        }

        QQC2.Label { text: i18n("Many"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.5 }
    }
}
