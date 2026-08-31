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

    function openMenu() {
        if (_ignoreMenuOpen) {
            return
        }
        labelPopup.open()
        labelPopup.forceActiveFocus()
        listView.forceActiveFocus()
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

    QQC2.TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: i18n("Search or create label…")

        onAccepted: {
            if (menuEntries.length > 0) {
                pickEntry(menuEntries[0])
            }
        }

        Keys.onEscapePressed: {
            if (labelPopup.visible) {
                root.closeMenu()
                event.accepted = true
            } else {
                event.accepted = false
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
        x: 0
        y: searchField.height + Design.spaceSmall
        width: root.width
        height: Math.min(Kirigami.Units.gridUnit * 12, Math.max(Kirigami.Units.gridUnit * 4, listView.contentHeight + Design.spaceMedium))
        padding: Design.spaceSmall
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        parent: root
        focus: true

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
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            focus: true
            rightMargin: Design.spaceSmall

            QQC2.ScrollBar.vertical: ThinScrollBar {
                view: listView
            }
            QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
                policy: QQC2.ScrollBar.AlwaysOff
            }

            Keys.onEscapePressed: root.closeMenu()

            delegate: QQC2.ItemDelegate {
                id: delegate
                width: Math.max(1, listView.width - listView.rightMargin)
                text: modelData.kind === "create"
                      ? i18n("Create label “%1”", modelData.name)
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

        onOpened: listView.forceActiveFocus()
    }

    Connections {
        target: searchField
        function onTextChanged() {
            if (!labelPopup.visible) {
                root.openMenu()
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
