import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "../colors.js" as Colors
import ".."

ColumnLayout {
    id: root

    property var availableLabels: []
    property var selectedLabels: []
    property bool _ignoreMenuOpen: false
    /** Widget/overlay item used to clamp the upward popup to available height. */
    property Item boundsItem: null
    property int selectedIndex: 0

    spacing: Design.spaceSmall

    function _containsLabel(list, name) {
        for (var i = 0; i < list.length; ++i) {
            if (list[i] === name) {
                return true
            }
        }
        return false
    }

    function addLabel(name) {
        var trimmed = String(name || "").trim()
        if (!trimmed.length) {
            return
        }
        if (_containsLabel(selectedLabels, trimmed)) {
            return
        }
        selectedLabels = selectedLabels.concat([trimmed])
    }

    function removeLabel(name) {
        var out = []
        for (var i = 0; i < selectedLabels.length; ++i) {
            if (selectedLabels[i] !== name) {
                out.push(selectedLabels[i])
            }
        }
        selectedLabels = out
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
        labelPopup.height = Math.min(maxH, contentH)
        labelPopup.width = root.width
        labelPopup.x = 0
        labelPopup.y = -labelPopup.height - Design.spaceSmall
    }

    function openMenu() {
        if (_ignoreMenuOpen) {
            return
        }
        placePopup()
        if (!labelPopup.visible) {
            labelPopup.open()
        } else {
            placePopup()
        }
        selectedIndex = 0
    }

    function closeMenu() {
        labelPopup.close()
    }

    readonly property var menuEntries: {
        var query = searchField.text.trim()
        var queryLower = query.toLowerCase()
        var available = availableLabels || []
        var entries = []
        var exact = false

        for (var i = 0; i < available.length; ++i) {
            var label = String(available[i])
            if (_containsLabel(selectedLabels, label)) {
                continue
            }
            if (queryLower.length && label.toLowerCase().indexOf(queryLower) < 0) {
                continue
            }
            if (queryLower.length && label.toLowerCase() === queryLower) {
                exact = true
            }
            entries.push({ kind: "label", name: label })
        }

        if (query.length && !exact && !_containsLabel(selectedLabels, query)) {
            entries.push({ kind: "create", name: query })
        }

        return entries
    }

    onMenuEntriesChanged: {
        if (selectedIndex >= menuEntries.length) {
            selectedIndex = Math.max(0, menuEntries.length - 1)
        }
        if (labelPopup.visible) {
            placePopup()
        }
    }

    QQC2.TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: i18n("Search or create label\u2026")
        Keys.priority: Keys.BeforeItem

        onAccepted: {
            if (menuEntries.length > 0) {
                pickEntry(menuEntries[Math.max(0, Math.min(selectedIndex, menuEntries.length - 1))])
            }
        }

        Keys.onPressed: function (event) {
            if (!labelPopup.visible || menuEntries.length === 0) {
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

        // Re-open even when the field already has focus after a previous pick.
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: root.openMenu()
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Design.spaceSmall
        visible: selectedLabels.length > 0

        Repeater {
            model: selectedLabels
            delegate: QQC2.Button {
                text: modelData
                icon.name: "tag"
                icon.color: Design.colorForKey(String(modelData), "label")
                onClicked: root.removeLabel(modelData)
                QQC2.ToolTip.text: i18n("Remove label")
                QQC2.ToolTip.visible: hovered
            }
        }
    }

    QQC2.Popup {
        id: labelPopup
        popupType: QQC2.Popup.Item
        modal: false
        dim: false
        // Keep typing focus on the search field (do not steal ActiveFocus).
        focus: false
        padding: Design.spaceSmall
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        parent: root

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
                      ? i18n("Create label \u201c%1\u201d", modelData.name)
                      : modelData.name
                onClicked: root.pickEntry(modelData)

                contentItem: RowLayout {
                    spacing: Design.spaceSmall

                    Kirigami.Icon {
                        source: modelData.kind === "create" ? "list-add" : "tag"
                        color: modelData.kind === "create"
                               ? Kirigami.Theme.textColor
                               : Design.colorForKey(String(modelData.name), "label")
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
                text: i18n("No matching labels")
                opacity: 0.7
            }
        }

        onAboutToShow: placePopup()
    }

    Connections {
        target: searchField
        function onTextChanged() {
            selectedIndex = 0
            if (searchField.activeFocus && !labelPopup.visible) {
                root.openMenu()
            } else if (labelPopup.visible) {
                root.placePopup()
            }
        }
        function onActiveFocusChanged() {
            if (searchField.activeFocus) {
                root.openMenu()
            }
        }
    }

    function pickEntry(entry) {
        if (!entry || !entry.name) {
            return
        }
        _ignoreMenuOpen = true
        addLabel(entry.name)
        searchField.text = ""
        root.closeMenu()
        _ignoreMenuOpen = false
        searchField.forceActiveFocus()
    }
}
