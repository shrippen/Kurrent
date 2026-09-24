import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

// Shared scrolling grid for the matrix views (Swimlanes, Project plan).
//
// One GridLayout inside a Flickable: row heights follow the tallest cell of a row
// for free, and the column header row / row header column stay pinned to the viewport
// by translating those items with the scroll offset (no second synchronised Flickable).
//
// Delegates are plain Components; the item created by each Loader reads its keys from
// the Loader (`parent.rowKey`, `parent.columnKey`, `parent.rowIndex`, `parent.columnIndex`).
Item {
    id: grid

    property var rows: []
    property var columns: []
    property real columnWidth: Design.swimlaneColumnWidth
    property real rowHeaderWidth: Design.matrixRowHeaderMinWidth
    property real headerHeight: Design.matrixHeaderHeight
    property string currentColumn: ""
    // Grow columns to use spare width (never below `columnWidth`).
    property bool stretchColumns: true
    readonly property real effectiveColumnWidth: (stretchColumns && columnCount > 0)
            ? Math.max(columnWidth, Math.floor((width - rowHeaderWidth) / columnCount))
            : columnWidth

    property Component cornerDelegate: null
    property Component columnHeaderDelegate: null
    property Component rowHeaderDelegate: null
    property Component cellDelegate: null

    readonly property alias flickable: flick
    readonly property int columnCount: columns.length
    readonly property int rowCount: rows.length

    // Throttled scroll offset for viewport culling in cell delegates. Binding those to
    // `flick.contentX/contentY` directly would re-evaluate one binding per cell on every
    // scrolled pixel; with a few hundred cells that alone drops the scroll frame rate.
    // Pinned headers still follow the raw offset — they must not lag.
    property real viewX: 0
    property real viewY: 0

    function syncViewport() {
        viewX = flick.contentX
        viewY = flick.contentY
    }

    function maybeSyncViewport() {
        // Resync at once when the view moved far enough that culling could be stale
        // (delegates keep one screen of margin), otherwise coalesce into a short idle tick.
        if (Math.abs(flick.contentX - viewX) > width * 0.5
                || Math.abs(flick.contentY - viewY) > height * 0.5) {
            syncViewport()
        } else {
            viewportIdle.restart()
        }
    }

    Component.onCompleted: syncViewport()
    onWidthChanged: viewportIdle.restart()
    onHeightChanged: viewportIdle.restart()

    Timer {
        id: viewportIdle
        interval: 80
        repeat: false
        onTriggered: grid.syncViewport()
    }

    Connections {
        target: flick
        function onContentXChanged() { grid.maybeSyncViewport() }
        function onContentYChanged() { grid.maybeSyncViewport() }
    }

    clip: true

    function columnIndexOf(key) {
        for (var i = 0; i < columns.length; ++i) {
            if (columns[i] === key) {
                return i
            }
        }
        return -1
    }

    // Bring a column right next to the pinned row header.
    function scrollToColumn(key, animated) {
        var idx = columnIndexOf(key)
        if (idx < 0) {
            return
        }
        var maxX = Math.max(0, flick.contentWidth - flick.width)
        var target = Math.max(0, Math.min(maxX, idx * effectiveColumnWidth))
        if (animated === false || Design.reducedMotion) {
            flick.contentX = target
            return
        }
        scrollAnim.to = target
        scrollAnim.restart()
    }

    NumberAnimation {
        id: scrollAnim
        target: flick
        property: "contentX"
        duration: Kirigami.Units.longDuration
        easing.type: Easing.OutCubic
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: layout.implicitWidth
        contentHeight: layout.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalAndVerticalFlick

        Kirigami.WheelHandler {
            target: flick
            filterMouseEvents: true
        }

        GridLayout {
            id: layout
            columns: grid.columnCount + 1
            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: (grid.rowCount + 1) * (grid.columnCount + 1)

                delegate: Loader {
                    id: slot
                    required property int index

                    readonly property int rowIndex: Math.floor(index / (grid.columnCount + 1)) - 1
                    readonly property int columnIndex: index % (grid.columnCount + 1) - 1
                    readonly property bool isCorner: rowIndex < 0 && columnIndex < 0
                    readonly property bool isColumnHeader: rowIndex < 0 && columnIndex >= 0
                    readonly property bool isRowHeader: rowIndex >= 0 && columnIndex < 0
                    readonly property string rowKey: rowIndex >= 0 ? String(grid.rows[rowIndex]) : ""
                    readonly property string columnKey: columnIndex >= 0 ? String(grid.columns[columnIndex]) : ""

                    Layout.preferredWidth: columnIndex < 0 ? grid.rowHeaderWidth : grid.effectiveColumnWidth
                    Layout.minimumWidth: Layout.preferredWidth
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.preferredHeight: rowIndex < 0 ? grid.headerHeight : -1
                    Layout.fillHeight: rowIndex >= 0

                    // Pinned header row / column: stacked above the cells, following the scroll offset.
                    z: isCorner ? 4 : (isColumnHeader ? 3 : (isRowHeader ? 2 : 0))
                    transform: Translate {
                        x: (slot.isCorner || slot.isRowHeader) ? flick.contentX : 0
                        y: (slot.isCorner || slot.isColumnHeader) ? flick.contentY : 0
                    }

                    sourceComponent: isCorner ? grid.cornerDelegate
                                   : isColumnHeader ? grid.columnHeaderDelegate
                                   : isRowHeader ? grid.rowHeaderDelegate
                                   : grid.cellDelegate
                }
            }
        }

        // Middle-button pan (matches Kanban).
        MouseArea {
            id: panArea
            x: flick.contentX
            y: flick.contentY
            width: flick.width
            height: flick.height
            z: 50
            acceptedButtons: Qt.MiddleButton
            property real lastX: 0
            property real lastY: 0
            onPressed: function(mouse) {
                lastX = mouse.x
                lastY = mouse.y
                flick.cancelFlick()
            }
            onPositionChanged: function(mouse) {
                if (!(mouse.buttons & Qt.MiddleButton)) {
                    return
                }
                var maxX = Math.max(0, flick.contentWidth - flick.width)
                var maxY = Math.max(0, flick.contentHeight - flick.height)
                flick.contentX = Math.max(0, Math.min(maxX, flick.contentX - (mouse.x - lastX)))
                flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - (mouse.y - lastY)))
                lastX = mouse.x
                lastY = mouse.y
            }
        }

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            policy: flick.contentHeight > flick.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
            policy: flick.contentWidth > flick.width ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }
    }
}
