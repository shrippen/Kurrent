import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigami.delegates as KirigamiDelegates
import org.kde.plasma.components as PlasmaComponents3
import ".."
import "../Kante"

// One filter section of the sidebar (projects, labels, priorities, ...): a header with an
// "All" entry and a list of values, one of them selected. The sections differ only in the
// properties below. A value is picked with `choose`; the owner writes it to the controller
// and hands the new selection back in.
//
//   ┌ Labels ───────── All ┐   header, "All" clears the filter
//   │ ▸ Work             3 │   selected row
//   │   Home             1 │   row with its count
//   └──────────────────────┘
Item {
    id: section

    // The SidebarView: row sizes, the room it gives the section, the hints for locked filters.
    required property Item sidebar
    // Key of the section in the sidebar's space allocation, e.g. "projects".
    required property string sectionId
    required property string title
    // Which filter the section sets, for "not available in this view": "project", "label", ...
    required property string filterKind
    required property var items
    // Where an item holds its key and its text: the role name, or "" if the item is the value.
    // Labels and locations are plain strings, projects are { collectionId, name },
    // the fixed lists are { value, label }.
    required property string keyRole
    required property string textRole
    // The current selection, and the value that means "all": -1 for numbers, "" for strings.
    required property var selection
    required property var allValue
    // Count per key.
    required property var counts
    // { source, color, opacity } of the icon of an item; no colour leaves the icon untinted.
    required property var iconOf
    // For an item: the hint while a task is dragged over it, and the drop itself (true if done).
    required property var hintFor
    required property var dropOn
    // For an item: whether a task may be dropped there (on top of the filter being usable).
    property var canDropOn: function(item) { return true }

    property bool isLastVisible: false

    signal choose(var value)

    readonly property bool allSelected: typeof allValue === "number" ? selection < 0 : !selection

    function keyOf(item) {
        return keyRole === "" ? item : item[keyRole]
    }

    function textOf(item) {
        return textRole === "" ? item : item[textRole]
    }

    function sameKey(key, value) {
        return typeof allValue === "number" ? Number(key) === value : String(key) === value
    }

    function toggle(item) {
        var key = keyOf(item)
        choose(sameKey(key, selection) ? allValue : key)
    }

    onSelectionChanged: list.syncIndex()

    width: parent ? parent.width : 0
    height: list.height + (visible && !isLastVisible ? sidebar.separatorStrip : 0)

    component SelectionBackground: Item {
        id: selectionBg
        required property Item sidebar
        required property Item control
        required property bool selected

        anchors.fill: parent

        StyledHighlight {
            anchors.fill: parent
            visible: selectionBg.selected
            hovered: true
            pressed: selectionBg.control.down
        }

        SidebarHoverBackground {
            sidebar: selectionBg.sidebar
            control: selectionBg.control
        }
    }

    ListView {
        id: list
        width: parent ? parent.width : 0
        height: section.sidebar.allocFor(section.sectionId)
        clip: true
        implicitHeight: 0
        implicitWidth: width
        interactive: section.sidebar.listNeedsScroll(list) || section.sidebar.comfortableRows
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        model: section.items
        currentIndex: -1
        highlight: StyledHighlight { visible: !KanteStyle.active }
        highlightMoveDuration: Kirigami.Units.longDuration
        leftMargin: 0
        rightMargin: section.sidebar.scrollMarginFor(list)

        function syncIndex() {
            var m = model || []
            for (var i = 0; i < m.length; ++i) {
                if (section.sameKey(section.keyOf(m[i]), section.selection)) {
                    currentIndex = i; return
                }
            }
            currentIndex = -1
        }
        Component.onCompleted: syncIndex()
        onModelChanged: Qt.callLater(syncIndex)

        QQC2.ScrollBar.vertical: SidebarScrollBar { view: list }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AlwaysOff }
        onContentHeightChanged: Qt.callLater(section.sidebar.redistributeSections)

        headerPositioning: ListView.InlineHeader
        header: RowLayout {
            width: section.sidebar.listContentWidth(list)
            height: section.sidebar.sectionHeaderHeight
            Layout.leftMargin: Design.spaceSmall
            Layout.rightMargin: Design.spaceSmall
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: section.title
                // Section label: small uppercase JetBrains Mono in Kante and Kante Light.
                font: KanteStyle.active ? KanteStyle.labelFont()
                                         : Qt.font({ family: Kirigami.Theme.defaultFont.family, pointSize: Kirigami.Theme.smallFont.pointSize, bold: true })
                opacity: 0.65
                verticalAlignment: Text.AlignVCenter
            }

            PlasmaComponents3.ItemDelegate {
                id: allDelegate
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.preferredHeight: section.sidebar.sectionHeaderHeight
                hoverEnabled: section.sidebar.rowHoverEnabled
                highlighted: section.allSelected
                readonly property bool filterUsable: section.sidebar.filterEnabled(section.filterKind)
                enabled: filterUsable
                opacity: filterUsable ? 1.0 : 0.45

                onClicked: {
                    if (filterUsable) {
                        section.choose(section.allValue)
                    }
                }

                QQC2.ToolTip {
                    visible: !allDelegate.filterUsable && allDelegate.hovered
                    text: section.sidebar.filterDisabledReason(section.filterKind)
                }

                background: SelectionBackground {
                    sidebar: section.sidebar
                    control: allDelegate
                    selected: allDelegate.highlighted
                }

                contentItem: QQC2.Label {
                    text: i18n("All")
                    color: KanteStyle.themed && parent && parent.highlighted ? KanteStyle.accentForegroundColor : Kirigami.Theme.textColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: allDelegate.highlighted || allDelegate.down ? 1.0 : 0.75
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: Design.spaceSmall
                    rightPadding: Design.spaceSmall
                }
            }
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: rowDelegate
            width: section.sidebar.listContentWidth(list)
            hoverEnabled: section.sidebar.rowHoverEnabled
            readonly property bool filterUsable: section.sidebar.filterEnabled(section.filterKind)
            highlighted: ListView.isCurrentItem
            height: KanteStyle.active ? rowKante.implicitHeight : implicitHeight
            enabled: filterUsable
            opacity: filterUsable || KanteStyle.active ? 1.0 : 0.45
            leftPadding: 0
            rightPadding: Design.spaceSmall
            topPadding: section.sidebar.rowVPad
            bottomPadding: section.sidebar.rowVPad

            readonly property var iconSpec: section.iconOf(modelData)

            background: Item {
                visible: !KanteStyle.active
                anchors.fill: parent

                SidebarHoverBackground {
                    sidebar: section.sidebar
                    control: rowDelegate
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Design.inputRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: rowDrop.containsDrag ? 0.28 : 0
                    visible: opacity > 0
                }
            }

            DropArea {
                id: rowDrop
                anchors.fill: parent
                keys: ["application/x-kurrent-task"]
                enabled: section.sidebar.isDragging && filterUsable && section.canDropOn(modelData)

                readonly property string hintText: section.hintFor(modelData)

                onEntered: function(drag) {
                    drag.acceptProposedAction()
                    if (section.sidebar.dragHost) {
                        section.sidebar.dragHost.setDropHint(hintText)
                    }
                }
                onExited: {
                    if (section.sidebar.dragHost) {
                        section.sidebar.dragHost.clearDropHint(hintText)
                    }
                }
                onDropped: function(drop) {
                    if (section.dropOn(modelData)) {
                        drop.acceptProposedAction()
                    }
                }
            }

            onClicked: {
                if (!filterUsable) {
                    return
                }
                section.toggle(modelData)
            }

            QQC2.ToolTip {
                visible: !rowDelegate.filterUsable && rowDelegate.hovered
                text: section.sidebar.filterDisabledReason(section.filterKind)
            }

            SidebarKanteRow {
                id: rowKante
                sidebar: section.sidebar
                control: rowDelegate
                text: section.textOf(modelData)
                count: section.sidebar.showSidebarCounts ? rowCount.text : ""
                dropTarget: rowDrop.containsDrag
                disabledReason: rowDelegate.filterUsable ? "" : section.sidebar.filterDisabledReason(section.filterKind)

                Kirigami.Icon {
                    source: rowDelegate.iconSpec.source
                    color: rowDelegate.iconSpec.color ?? "transparent"
                    opacity: rowDelegate.iconSpec.opacity ?? 1
                    width: section.sidebar.rowIconSize
                    height: section.sidebar.rowIconSize
                }
            }

            contentItem: RowLayout {
                visible: !KanteStyle.active
                spacing: Design.spaceSmall

                Item { width: section.sidebar.rowLeftInset }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: section.sidebar.rowIconSize
                    Layout.preferredHeight: section.sidebar.rowIconSize
                    source: rowDelegate.iconSpec.source
                    color: rowDelegate.iconSpec.color ?? "transparent"
                    opacity: rowDelegate.iconSpec.opacity ?? 1
                    width: section.sidebar.rowIconSize
                    height: section.sidebar.rowIconSize
                }

                KirigamiDelegates.TitleSubtitle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: section.sidebar.listContentWidth(list)
                    Layout.alignment: Qt.AlignVCenter
                    title: section.textOf(modelData)
                    selected: rowDelegate.highlighted || rowDelegate.down || rowDrop.containsDrag
                }

                CountBadge {
                    id: rowCount
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    text: {
                        var n = section.counts[section.keyOf(modelData)]
                        return n === undefined ? "" : String(n)
                    }
                    visible: section.sidebar.showSidebarCounts && text.length > 0
                    selected: rowDelegate.highlighted || rowDelegate.down
                }
            }
        }
    }

    Kirigami.Separator {
        width: parent ? parent.width : 0
        anchors.bottom: parent.bottom
        visible: !section.isLastVisible
    }
}
