import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Pull to refresh for a Kirigami.Page with a QQC2.ScrollView (a
 * Kirigami.ScrollablePage has its own). Hang it onto the scroll view and
 * pass the view's Flickable:
 *
 *     KantePullToRefresh {
 *         parent: pageScroll
 *         anchors.fill: parent
 *         z: 10
 *         flickable: pageScroll.contentItem
 *         busy: page.loading
 *         onRefreshRequested: page.reload()
 *     }
 *
 * Pulling the content down past `threshold` and letting go emits
 * refreshRequested(); the indicator stays until `busy` turns false.
 *
 *     ┌──────────────┐
 *     │     (↻)      │  follows the pull, turns once armed
 *     │ content …    │
 */
Item {
    id: pull

    required property Flickable flickable
    /** The page is (re)loading; keeps the indicator spinning after the pull. */
    property bool busy: false

    signal refreshRequested()

    readonly property real threshold: Kirigami.Units.gridUnit * 3.5
    readonly property real pullDistance: flickable ? Math.max(0, -(flickable.contentY - flickable.originY)) : 0
    readonly property bool armed: pullDistance >= threshold
    property bool refreshing: false

    // Only the indicator is drawn here; touches go to the content below.
    enabled: false

    Component.onCompleted: {
        if (flickable) {
            flickable.boundsBehavior = Flickable.DragOverBounds
        }
    }

    Connections {
        target: pull.flickable
        function onDraggingChanged() {
            if (!pull.flickable.dragging && pull.armed && !pull.refreshing) {
                pull.refreshing = true
                minimumSpin.restart()
                pull.refreshRequested()
            }
        }
    }

    // Keep spinning at least briefly, then until the page is done.
    Timer {
        id: minimumSpin
        interval: 700
        onTriggered: pull.refreshing = pull.busy
    }
    onBusyChanged: {
        if (!busy && !minimumSpin.running) {
            refreshing = false
        }
    }

    Item {
        id: indicator
        readonly property real progress: pull.refreshing ? 1 : Math.min(1, pull.pullDistance / pull.threshold)
        width: Kirigami.Units.gridUnit * 2
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: pull.refreshing ? Kirigami.Units.largeSpacing : Math.min(pull.pullDistance, pull.threshold) - height
        visible: pull.refreshing || pull.pullDistance > 0
        opacity: progress

        // System: round, like the platform's own refresh bubbles.
        Rectangle {
            anchors.fill: parent
            visible: !KanteStyle.active
            radius: width / 2
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: KanteStyle.tint(KanteStyle.textColor, 0.15)
        }
        // Kante: square, accent frame.
        Rectangle {
            anchors.fill: parent
            visible: KanteStyle.active
            color: KanteStyle.dialogColor
            border.width: 1
            border.color: pull.armed || pull.refreshing ? KanteStyle.accentColor : KanteStyle.frameColor
        }

        QQC2.BusyIndicator {
            anchors.centerIn: parent
            width: parent.width * 0.8
            height: width
            visible: pull.refreshing
            running: visible
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            visible: !pull.refreshing
            source: "view-refresh"
            isMask: true
            color: pull.armed ? KanteStyle.accentColor : KanteStyle.textColor
            rotation: indicator.progress * 270
        }
    }
}
