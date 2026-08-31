import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

// Fixed-height wrapped text field. Flickable + right-edge scrollbar (not ScrollView):
// ScrollView reserves width on the right but can paint the bar on the left at implicit height.
Item {
    id: root

    property alias text: area.text
    property alias placeholderText: area.placeholderText
    property alias readOnly: area.readOnly
    property int preferredLines: 4

    signal escapePressed

    readonly property int linePx: Math.max(Kirigami.Units.gridUnit,
                                           Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.45))
    readonly property int preferredPixelHeight: linePx * preferredLines
    readonly property bool needsScroll: flick.contentHeight > flick.height + 1

    // Never drive parent/window width when the scrollbar appears.
    implicitWidth: 0
    implicitHeight: preferredPixelHeight
    Layout.fillWidth: true
    Layout.preferredHeight: preferredPixelHeight
    Layout.minimumHeight: preferredPixelHeight
    Layout.maximumHeight: preferredPixelHeight
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Design.inputRadius
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: area.activeFocus ? Kirigami.Theme.highlightColor : Design.windowBorderColor()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: false
        rightMargin: root.needsScroll ? Design.scrollGutter : 0
        contentWidth: Math.max(0, width - leftMargin - rightMargin)
        contentHeight: Math.max(height, area.implicitHeight)

        QQC2.TextArea {
            id: area
            width: flick.contentWidth
            // Fill the visible frame so empty space below the text is still
            // clickable/focusable (TextArea defaults to content height only).
            height: Math.max(implicitHeight, flick.height)
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: Item {}
            leftPadding: Design.spaceSmall
            rightPadding: Design.spaceSmall
            topPadding: Design.spaceTiny
            bottomPadding: Design.spaceTiny
            Keys.onEscapePressed: root.escapePressed()
        }

        QQC2.ScrollBar.vertical: ThinScrollBar {
            view: flick
            parent: flick
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
        }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
            policy: QQC2.ScrollBar.AlwaysOff
        }

        // When this field has a scrollbar, consume the wheel even at the bounds
        // so the task list, sidebar, or full-editor form do not scroll instead.
        WheelHandler {
            enabled: root.needsScroll
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                Design.applyWheel(flick, event)
                event.accepted = true
            }
        }
    }
}
