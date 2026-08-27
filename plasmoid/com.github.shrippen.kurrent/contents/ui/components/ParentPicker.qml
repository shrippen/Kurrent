import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "../colors.js" as Colors
import ".."

ColumnLayout {
    id: root

    property var controller
    property real itemId: -1
    property real collectionId: -1
    property string parentUid: ""
    /** Widget/overlay item used to clamp the upward popup to available height. */
    property Item boundsItem: null

    property var candidates: []
    property bool _ignoreMenuOpen: false
    property int selectedIndex: 0

    spacing: Design.spaceSmall

    readonly property string selectedSummary: {
        var want = parentUid || ""
        if (!want.length) {
            return ""
        }
        for (var i = 0; i < candidates.length; ++i) {
            if (candidates[i].uid === want) {
                return candidates[i].summary
            }
        }
        return ""
    }

    readonly property var menuEntries: {
        var query = searchField.text.trim()
        var queryLower = query.toLowerCase()
        var entries = []
        var list = candidates || []
        for (var i = 0; i < list.length; ++i) {
            var row = list[i]
            var uid = String(row.uid || "")
            if (uid.length && uid === (parentUid || "")) {
                continue
            }
            var summary = String(row.summary || "")
            if (queryLower.length && summary.toLowerCase().indexOf(queryLower) < 0) {
                continue
            }
            entries.push({
                uid: uid,
                summary: summary,
                priority: Number(row.priority || 0),
                categories: row.categories || []
            })
        }
        return entries
    }

    function rebuild() {
        var rows = []
        if (controller && typeof controller.parentCandidates === "function"
                && itemId > 0 && collectionId > 0) {
            var list = controller.parentCandidates(itemId, collectionId) || []
            for (var i = 0; i < list.length; ++i) {
                rows.push({
                    uid: String(list[i].uid || ""),
                    summary: String(list[i].summary || i18n("(Untitled)")),
                    priority: Number(list[i].priority || 0),
                    categories: list[i].categories || []
                })
            }
        }
        candidates = rows
        // Drop selection if the parent is no longer a valid candidate.
        if (parentUid && parentUid.length) {
            var found = false
            for (var j = 0; j < rows.length; ++j) {
                if (rows[j].uid === parentUid) {
                    found = true
                    break
                }
            }
            if (!found) {
                parentUid = ""
            }
        }
    }

    function availableAbove() {
        var host = boundsItem
        if (!host) {
            var p = root.parent
            while (p) {
                if (p.width > 0 && p.height > 0 && p !== root) {
                    host = p
                }
                p = p.parent
            }
        }
        if (!host) {
            return Kirigami.Units.gridUnit * 12
        }
        var top = searchField.mapToItem(host, 0, 0).y
        return Math.max(Kirigami.Units.gridUnit * 3, top - Design.spaceSmall)
    }

    function placePopup() {
        var maxH = availableAbove()
        var contentH = Math.max(Kirigami.Units.gridUnit * 3,
                                listView.contentHeight + Design.spaceMedium)
        parentPopup.height = Math.min(maxH, contentH)
        parentPopup.width = root.width
        parentPopup.x = 0
        parentPopup.y = -parentPopup.height - Design.spaceSmall
    }

    function openMenu() {
        if (_ignoreMenuOpen) {
            return
        }
        placePopup()
        if (!parentPopup.visible) {
            parentPopup.open()
        } else {
            placePopup()
        }
        selectedIndex = 0
    }

    function closeMenu() {
        parentPopup.close()
    }

    function clearParent() {
        parentUid = ""
        searchField.text = ""
        closeMenu()
    }

    function pickEntry(entry) {
        if (!entry) {
            return
        }
        _ignoreMenuOpen = true
        parentUid = String(entry.uid || "")
        searchField.text = ""
        closeMenu()
        _ignoreMenuOpen = false
        searchField.forceActiveFocus()
    }

    onItemIdChanged: rebuild()
    onCollectionIdChanged: rebuild()
    onMenuEntriesChanged: {
        if (selectedIndex >= menuEntries.length) {
            selectedIndex = Math.max(0, menuEntries.length - 1)
        }
        if (parentPopup.visible) {
            placePopup()
        }
    }
    Component.onCompleted: rebuild()

    QQC2.TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: i18n("Search parent task…")
        enabled: root.candidates.length > 0 || !!(root.parentUid && root.parentUid.length)
        // Keep Keys so arrow navigation works while the field stays focused for typing.
        Keys.priority: Keys.BeforeItem

        onAccepted: {
            if (menuEntries.length > 0) {
                var idx = Math.max(0, Math.min(selectedIndex, menuEntries.length - 1))
                pickEntry(menuEntries[idx])
            }
        }

        Keys.onPressed: function (event) {
            if (!parentPopup.visible || menuEntries.length === 0) {
                return
            }
            if (event.key === Qt.Key_Down) {
                selectedIndex = Math.min(menuEntries.length - 1, selectedIndex + 1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Up) {
                selectedIndex = Math.max(0, selectedIndex - 1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Escape) {
                root.closeMenu()
                event.accepted = true
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Design.spaceSmall
        visible: !!(root.parentUid && root.parentUid.length)

        QQC2.Button {
            text: root.selectedSummary.length ? root.selectedSummary : i18n("(Untitled)")
            icon.name: "go-up"
            onClicked: root.clearParent()
            QQC2.ToolTip.text: i18n("Clear parent")
            QQC2.ToolTip.visible: hovered
        }
    }

    QQC2.Popup {
        id: parentPopup
        parent: root
        popupType: QQC2.Popup.Item
        modal: false
        dim: false
        // Keep typing focus on the search field (do not steal ActiveFocus).
        focus: false
        padding: Design.spaceSmall
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        background: Rectangle {
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: Design.inputRadius
        }

        contentItem: ListView {
            id: listView
            clip: true
            model: root.menuEntries
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            focus: false

            delegate: QQC2.ItemDelegate {
                id: delegate
                required property var modelData
                required property int index
                readonly property var entry: modelData
                width: listView.width
                highlighted: index === root.selectedIndex
                onClicked: root.pickEntry(entry)

                contentItem: RowLayout {
                    spacing: Design.spaceSmall

                    Kirigami.Icon {
                        visible: Number(delegate.entry.priority || 0) > 0
                        source: "flag"
                        color: Colors.colorForPriority(delegate.entry.priority)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small

                        QQC2.ToolTip.text: {
                            var band = Colors.priorityLabel(delegate.entry.priority)
                            if (band === "high") {
                                return i18n("High priority (%1)", delegate.entry.priority)
                            }
                            if (band === "medium") {
                                return i18n("Medium priority (%1)", delegate.entry.priority)
                            }
                            if (band === "low") {
                                return i18n("Low priority (%1)", delegate.entry.priority)
                            }
                            return i18n("Priority %1", delegate.entry.priority)
                        }
                        QQC2.ToolTip.visible: prioHover.hovered
                        QQC2.ToolTip.delay: 400
                        HoverHandler { id: prioHover }
                    }

                    Repeater {
                        model: delegate.entry.categories || []
                        delegate: Kirigami.Icon {
                            required property var modelData
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: "tag"
                            color: Design.colorForKey(String(modelData), "label")
                            width: Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small

                            QQC2.ToolTip.text: String(modelData)
                            QQC2.ToolTip.visible: tagHover.hovered
                            QQC2.ToolTip.delay: 400
                            HoverHandler { id: tagHover }
                        }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: String(delegate.entry.summary || "")
                        elide: Text.ElideRight
                    }
                }
            }

            QQC2.Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: i18n("No matching tasks")
                opacity: 0.7
            }
        }

        onAboutToShow: placePopup()
    }

    Connections {
        target: searchField
        function onTextChanged() {
            selectedIndex = 0
            if (searchField.activeFocus && !parentPopup.visible) {
                root.openMenu()
            } else if (parentPopup.visible) {
                root.placePopup()
            }
        }
        function onActiveFocusChanged() {
            if (searchField.activeFocus) {
                root.openMenu()
            }
        }
    }
}
