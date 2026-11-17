import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import ".."
import "../Kante"

Item {
    id: hoverBg

    // The SidebarView, for its hover switch.
    required property Item sidebar
    required property Item control

    anchors.fill: parent
    visible: !Kirigami.Settings.isMobile
    opacity: sidebar.rowHoverEnabled && control.hovered && !control.down ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.veryShortDuration
            easing.type: Easing.OutQuad
        }
    }

    KSvg.FrameSvgItem {
        anchors.fill: parent
        visible: !KanteStyle.themed
        imagePath: "widgets/listitem"
        prefix: "hover"
    }

    // Kante: sunken tint instead of Plasma's rounded hover frame. Never over the selected
    // row: the dark tint on the accent fill turned it muddy brown.
    Rectangle {
        anchors.fill: parent
        visible: KanteStyle.themed && !hoverBg.control.highlighted
        color: KanteStyle.sunkenColor
    }
}
