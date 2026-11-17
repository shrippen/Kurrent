import QtQuick
import QtQuick.Controls as QQC2

/**
 * The platform's BusyIndicator, there only while it runs (1.77). Stop it to hide it:
 *
 *     KanteBusyIndicator { running: page.loading; Layout.preferredWidth: Kirigami.Units.iconSizes.small }
 *
 * Why not QQC2.BusyIndicator { running: x; visible: x }: Material fades a stopped indicator out
 * with an OpacityAnimator, and an Animator advances only while its item is drawn. Hidden as it
 * stopped, the fade never ended, and the window drew at the display rate for as long as it was open
 * (Plasmai on Android: ~90 frames a second and half a core while idle). This one removes the
 * indicator instead of hiding it.
 *   running    spins and takes its room; false: nothing is built and the item is hidden
 *   indicator  the BusyIndicator while running, else null
 */
Item {
    id: root

    property bool running: false
    readonly property Item indicator: spinner.item

    visible: running
    implicitWidth: spinner.item ? spinner.item.implicitWidth : 0
    implicitHeight: spinner.item ? spinner.item.implicitHeight : 0

    Loader {
        id: spinner
        anchors.fill: parent
        active: root.running
        sourceComponent: QQC2.BusyIndicator {
            running: true
        }
    }
}
