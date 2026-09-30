import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../Kante"

// Narrow layout (panel flyout, small desktop widget): the everyday views as tabs, the sidebar
// behind a toggle. System and Kante Light: text tabs with a highlight underline like Plasma's
// TabBar. Kante: KanteTabBar (notched tabs, sliding accent tab, counter badges).
RowLayout {
    id: bar

    required property var controller
    // [{ viewId, label, icon }] — the sidebar's ordered, visible primary views.
    property var views: []
    property bool sidebarOpen: false

    signal toggleSidebar()
    signal viewPicked(string viewId)

    spacing: Design.spaceTiny

    // Kante: the view labels and counters as KanteTabBar input.
    readonly property var _tabLabels: views.map(function(v) { return v.label })
    readonly property var _tabCounts: views.map(function(v) {
        var n = controller ? controller.viewTaskCounts[v.viewId] : 0
        return n === undefined || n === 0 ? "" : String(n)
    })
    readonly property var _tabKinds: views.map(function(v) {
        return v.viewId === "overdue" ? KanteCounter.Kind.Error : KanteCounter.Kind.Normal
    })
    readonly property int _tabIndex: {
        for (var i = 0; i < views.length; ++i) {
            if (controller && controller.currentView === views[i].viewId) {
                return i
            }
        }
        return -1
    }

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

    // Overflow: arrows at the edges say there are more tabs and scroll by one page (n1).
    KanteToolButton {
        Layout.alignment: Qt.AlignVCenter
        visible: !KanteStyle.themed && strip.contentX > 1
        icon.name: "go-previous"
        display: QQC2.AbstractButton.IconOnly
        text: i18n("Previous")
        onClicked: strip.scrollBy(-strip.width * 0.8)
    }

    KanteTabBar {
        id: kanteTabs
        visible: KanteStyle.themed
        Layout.fillWidth: true
        model: bar._tabLabels
        counts: bar._tabCounts
        countKinds: bar._tabKinds
        badges: true
        onActivated: function(index) { bar.viewPicked(bar.views[index].viewId) }
    }

    // A binding on currentIndex would break at the first click.
    Binding {
        target: kanteTabs
        property: "currentIndex"
        value: bar._tabIndex
        when: bar._tabIndex !== undefined
    }

    Flickable {
        id: strip
        visible: !KanteStyle.themed

        function scrollBy(dx) {
            contentX = Math.max(0, Math.min(contentWidth - width, contentX + dx))
        }
        Behavior on contentX {
            enabled: !Design.reducedMotion && !strip.dragging && !strip.flicking
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
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
                            visible: tab.current
                            color: Kirigami.Theme.highlightColor
                        }
                    }

                    contentItem: RowLayout {
                        spacing: Design.spaceTiny

                        QQC2.Label {
                            text: tab.modelData.label
                            opacity: tab.current ? 1 : 0.8
                        }

                        CountBadge {
                            visible: tab.countText.length > 0
                            text: tab.countText
                            negative: tab.modelData.viewId === "overdue"
                        }
                    }
                }
            }
        }
    }

    KanteToolButton {
        Layout.alignment: Qt.AlignVCenter
        visible: !KanteStyle.themed && strip.contentX < strip.contentWidth - strip.width - 1
        icon.name: "go-next"
        display: QQC2.AbstractButton.IconOnly
        text: i18n("Next")
        onClicked: strip.scrollBy(strip.width * 0.8)
    }
}
