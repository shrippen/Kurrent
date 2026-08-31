import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

ColumnLayout {
    id: root

    property var availableLocations: []
    property string selectedLocation: ""
    /** Widget/overlay item used to clamp the upward popup to available height. */
    property Item boundsItem: null
    property bool _ignoreMenuOpen: false
    property bool _syncingField: false
    property int selectedIndex: 0

    spacing: Design.spaceSmall

    readonly property string currentLocation: String(selectedLocation || "").trim()
    readonly property bool hasLocation: currentLocation.length > 0
    /** Field still shows the chosen location — do not use that text as a filter. */
    readonly property bool showingSelection: hasLocation
            && searchField.text.trim() === currentLocation

    function setLocation(name) {
        selectedLocation = String(name || "").trim()
        _syncingField = true
        searchField.text = selectedLocation
        _syncingField = false
    }

    function clearLocation() {
        _ignoreMenuOpen = true
        selectedLocation = ""
        _syncingField = true
        searchField.text = ""
        _syncingField = false
        closeMenu()
        _ignoreMenuOpen = false
        searchField.forceActiveFocus()
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
        locationPopup.height = Math.min(maxH, contentH)
        locationPopup.width = root.width
        locationPopup.x = 0
        locationPopup.y = -locationPopup.height - Design.spaceSmall
    }

    function openMenu() {
        if (_ignoreMenuOpen) {
            return
        }
        placePopup()
        if (!locationPopup.visible) {
            locationPopup.open()
        } else {
            placePopup()
        }
        selectedIndex = 0
    }

    function closeMenu() {
        locationPopup.close()
    }

    function pickEntry(entry) {
        if (!entry || !entry.name) {
            return
        }
        _ignoreMenuOpen = true
        setLocation(entry.name)
        closeMenu()
        _ignoreMenuOpen = false
        searchField.forceActiveFocus()
    }

    readonly property var menuEntries: {
        var query = showingSelection ? "" : searchField.text.trim()
        var queryLower = query.toLowerCase()
        var available = availableLocations || []
        var entries = []
        var exact = false
        var current = currentLocation

        for (var i = 0; i < available.length; ++i) {
            var loc = String(available[i])
            if (current.length && loc === current) {
                continue
            }
            if (queryLower.length && loc.toLowerCase().indexOf(queryLower) < 0) {
                continue
            }
            if (queryLower.length && loc.toLowerCase() === queryLower) {
                exact = true
            }
            entries.push({ kind: "location", name: loc })
        }

        if (query.length && !exact && query !== current) {
            entries.push({ kind: "create", name: query })
        }

        return entries
    }

    onSelectedLocationChanged: {
        if (_syncingField) {
            return
        }
        var want = String(selectedLocation || "").trim()
        if (searchField.text.trim() !== want && (showingSelection || !searchField.activeFocus)) {
            _syncingField = true
            searchField.text = want
            _syncingField = false
        }
    }

    onMenuEntriesChanged: {
        if (selectedIndex >= menuEntries.length) {
            selectedIndex = Math.max(0, menuEntries.length - 1)
        }
        if (locationPopup.visible) {
            placePopup()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: i18n("Search or set location…")
            Keys.priority: Keys.BeforeItem

            onAccepted: {
                if (menuEntries.length > 0) {
                    var idx = Math.max(0, Math.min(selectedIndex, menuEntries.length - 1))
                    pickEntry(menuEntries[idx])
                }
            }

            Keys.onPressed: function (event) {
                if (!locationPopup.visible || menuEntries.length === 0) {
                    if (event.key === Qt.Key_Escape && locationPopup.visible) {
                        root.closeMenu()
                        event.accepted = true
                    }
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

        QQC2.ToolButton {
            icon.name: "edit-clear"
            visible: root.hasLocation
            onClicked: root.clearLocation()
            QQC2.ToolTip.text: i18n("Clear location")
            QQC2.ToolTip.visible: hovered
        }
    }

    QQC2.Popup {
        id: locationPopup
        parent: root
        popupType: QQC2.Popup.Item
        modal: false
        dim: false
        // Keep typing focus on the search field.
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
            rightMargin: Design.spaceSmall

            QQC2.ScrollBar.vertical: ThinScrollBar {
                view: listView
            }
            QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
                policy: QQC2.ScrollBar.AlwaysOff
            }

            delegate: QQC2.ItemDelegate {
                id: delegate
                required property var modelData
                required property int index
                width: Math.max(1, listView.width - listView.rightMargin)
                highlighted: index === root.selectedIndex
                text: modelData.kind === "create"
                      ? i18n("Use “%1”", modelData.name)
                      : modelData.name
                onClicked: root.pickEntry(modelData)

                contentItem: RowLayout {
                    spacing: Design.spaceSmall

                    Kirigami.Icon {
                        source: modelData.kind === "create" ? "list-add" : "mark-location"
                        color: modelData.kind === "create"
                               ? Kirigami.Theme.textColor
                               : Design.colorForKey(String(modelData.name), "location")
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: delegate.text
                        elide: Text.ElideRight
                    }
                }
            }

            QQC2.Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: i18n("No matching locations")
                opacity: 0.7
            }
        }

        onAboutToShow: placePopup()
    }

    Connections {
        target: searchField
        function onTextChanged() {
            if (root._syncingField) {
                return
            }
            selectedIndex = 0
            if (searchField.activeFocus && !locationPopup.visible) {
                root.openMenu()
            } else if (locationPopup.visible) {
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
