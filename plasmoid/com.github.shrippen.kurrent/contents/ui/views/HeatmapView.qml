import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import com.github.shrippen.kurrent 1.0
import "../components"
import ".."
import "../datetime.js" as DateTime

ColumnLayout {
    id: root

    required property TaskController controller
    property bool interactionsSuspended: false

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
                        ? Qt.formatDate(mon, "MMM") : "")
        }
        return labels
    }

    function dateKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd")
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

    function countForDate(d) {
        var key = dateKey(d)
        return activeCounts[key] !== undefined ? activeCounts[key] : 0
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
                            controller.mainPaneMode = "calendar"
                        }
                    }
                }
            }
        }
    }

    // ── Header navigation ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceSmall

        QQC2.ToolButton {
            icon.name: "go-previous"
            onClicked: {
                var d = new Date(root.monthStart)
                if (root.showYear) d.setFullYear(d.getFullYear() - 1)
                else d.setMonth(d.getMonth() - 1)
                root.monthStart = d
            }
        }

        QQC2.ToolButton {
            text: i18n("Today")
            onClicked: root.monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
        }

        QQC2.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.showYear
                  ? (root.visibleYearNumbers.length > 1
                     ? root.visibleYearNumbers[root.visibleYearNumbers.length - 1] + " \u2013 " + root.visibleYearNumbers[0]
                     : Qt.formatDate(root.monthStart, "yyyy"))
                  : Qt.formatDate(root.monthStart, "MMMM yyyy")
            font.bold: true
        }

        QQC2.ToolButton {
            icon.name: "go-next"
            onClicked: {
                var d = new Date(root.monthStart)
                if (root.showYear) d.setFullYear(d.getFullYear() + 1)
                else d.setMonth(d.getMonth() + 1)
                root.monthStart = d
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceSmall

        QQC2.Label { text: i18n("Mode:"); opacity: 0.7 }
        QQC2.ComboBox {
            model: [
                { text: i18n("Completions"), value: "completed" },
                { text: i18n("Due dates"), value: "due" }
            ]
            textRole: "text"
            onActivated: root.heatmapMode = model[currentIndex].value
        }

        Item { Layout.fillWidth: true }

        QQC2.Label { text: i18n("View:"); opacity: 0.7 }
        QQC2.ToolButton {
            text: i18n("Month")
            checkable: true
            checked: !root.showYear
            onClicked: root.showYear = false
        }
        QQC2.ToolButton {
            text: i18n("Year")
            checkable: true
            checked: root.showYear
            onClicked: root.showYear = true
        }
    }

    // ── Month grid with weekday axis ────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: !root.showYear
        visible: !root.showYear

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            spacing: 2
            horizontalItemAlignment: Grid.AlignHCenter

            Repeater {
                model: [i18n("Mo"), i18n("Tu"), i18n("We"), i18n("Th"), i18n("Fr"), i18n("Sa"), i18n("Su")]
                delegate: QQC2.Label {
                    required property string modelData
                    width: root.cellSize
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: 0.6
                }
            }

            Repeater {
                model: root.monthCells
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

                    QQC2.Label {
                        anchors.centerIn: parent
                        visible: modelData !== null
                        text: modelData ? modelData.getDate() : ""
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: count > 0 ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData !== null
                        hoverEnabled: enabled && !root.interactionsSuspended
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            controller.agendaSelectedDate = modelData
                            controller.mainPaneMode = "calendar"
                        }
                    }
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
                model: ["Mo", "", "We", "", "Fr", "", ""]
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

    // ── Legend ──────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.spaceTiny
        visible: Object.keys(root.activeCounts).length > 0

        QQC2.Label { text: i18n("Few"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.5 }

        Repeater {
            model: [0.15, 0.30, 0.45, 0.60, 0.80]
            delegate: Rectangle {
                required property var modelData
                width: Design.heatmapCellSize * 0.6
                height: Design.heatmapCellSize * 0.6
                radius: 2
                color: Kirigami.Theme.highlightColor
                opacity: modelData
            }
        }

        QQC2.Label { text: i18n("Many"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.5 }
    }
}
