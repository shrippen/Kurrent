import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../Kante"

// Narrow layout (panel flyout, small desktop widget): the everyday views as tabs, the sidebar
// behind a toggle. System and Kante Light: text tabs with a highlight underline like Plasma's
// TabBar. Kante: the active tab gets the accent fill, labels in uppercase Rajdhani.
RowLayout {
    id: bar

    required property var controller
    // [{ viewId, label, icon }] — the sidebar's ordered, visible primary views.
    property var views: []
    property bool sidebarOpen: false

    signal toggleSidebar()
    signal viewPicked(string viewId)

    spacing: Design.spaceTiny

    KanteToolButton {
        Layout.alignment: Qt.AlignVCenter
        icon.name: bar.sidebarOpen ? "sidebar-collapse-left" : "sidebar-expand-left"
        text: bar.sidebarOpen ? i18n("Hide sidebar") : i18n("Show sidebar")
        display: QQC2.AbstractButton.IconOnly
        checkable: true
        checked: bar.sidebarOpen
        onClicked: bar.toggleSidebar()
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    Flickable {
        id: strip
        Layout.fillWidth: true
        Layout.preferredHeight: tabRow.implicitHeight
        contentWidth: tabRow.implicitWidth
        contentHeight: height
        clip: true
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        // Height comes from the tabs' own content; binding it back to the strip made a loop
        // (strip ← row ← tab ← row) that collapsed the whole bar to 0 px.
        Row {
            id: tabRow
            spacing: Design.spaceTiny

            Repeater {
                model: bar.views

                delegate: QQC2.AbstractButton {
                    id: tab
                    required property var modelData
                    readonly property bool current: bar.controller
                            && bar.controller.currentView === modelData.viewId
                    readonly property string countText: {
                        if (!bar.controller) {
                            return ""
                        }
                        var n = bar.controller.viewTaskCounts[modelData.viewId]
                        return n === undefined || n === 0 ? "" : String(n)
                    }

                    hoverEnabled: true
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                    topPadding: Design.spaceSmall
                    bottomPadding: Design.spaceSmall
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.checked: current
                    onClicked: bar.viewPicked(modelData.viewId)

                    onCurrentChanged: {
                        if (current) {
                            // Keep the active tab in view when the strip scrolls.
                            var left = tab.x
                            var right = tab.x + tab.width
                            if (left < strip.contentX) {
                                strip.contentX = left
                            } else if (right > strip.contentX + strip.width) {
                                strip.contentX = right - strip.width
                            }
                        }
                    }

                    background: Item {
                        StyledHighlight {
                            anchors.fill: parent
                            visible: KanteStyle.themed && tab.current
                            pressed: tab.down
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: tab.hovered && !tab.current
                            radius: Design.radius
                            color: Design.withAlpha(Kirigami.Theme.textColor, 0.07)
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            visible: !KanteStyle.themed && tab.current
                            color: Kirigami.Theme.highlightColor
                        }
                    }

                    contentItem: RowLayout {
                        spacing: Design.spaceTiny

                        QQC2.Label {
                            text: tab.modelData.label
                            color: KanteStyle.themed && tab.current
                                   ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            opacity: tab.current ? 1 : 0.8
                            font: KanteStyle.themed ? KanteStyle.headingFont(Kirigami.Theme.defaultFont.pointSize)
                                                    : Kirigami.Theme.defaultFont
                        }

                        CountBadge {
                            visible: tab.countText.length > 0
                            text: tab.countText
                            selected: KanteStyle.themed && tab.current
                            negative: tab.modelData.viewId === "overdue" && !(KanteStyle.themed && tab.current)
                        }
                    }
                }
            }
        }
    }
}
