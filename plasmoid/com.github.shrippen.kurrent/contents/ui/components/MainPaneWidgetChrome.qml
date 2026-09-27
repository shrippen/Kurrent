import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

// Main-pane loading chrome: editor-style dim + gear (sidebar stays undimmed).
Item {
    id: root

    required property bool active
    property bool dimBehind: false

    anchors.fill: parent
    visible: active
    z: 1990

    Rectangle {
        anchors.fill: parent
        radius: Design.inputRadius
        color: Qt.rgba(0, 0, 0, Design.overlayDim)
        opacity: root.active && root.dimBehind ? 1 : 0
        visible: opacity > 0.001

        Behavior on opacity {
            enabled: !Design.reducedMotion
            NumberAnimation { duration: Design.mainPaneSortOverlayFadeMs }
        }
    }

    Item {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.large
        height: Kirigami.Units.iconSizes.large
        visible: root.active

        Kirigami.Icon {
            id: gearIcon
            anchors.fill: parent
            source: Qt.resolvedUrl("../../icons/boot-gear.svg")
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: 0.85
        }

        RotationAnimator {
            target: gearIcon
            running: root.active && !Design.reducedMotion
            from: 0
            to: 360
            duration: Kirigami.Units.longDuration * 6
            loops: Animation.Infinite
        }
    }
}
