import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "../colors.js" as Colors
import ".."

Item {
    id: root

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias cursorPosition: field.cursorPosition
    property Item popupHost: null
    property var controller: null
    property var projects: []
    property string uiLanguage: Qt.locale().name

    signal accepted()

    implicitHeight: field.implicitHeight
    implicitWidth: field.implicitWidth
    Layout.fillWidth: true

    property var parsed: ({})
    property var suggestions: []
    property int tokenStart: 0
    property int tokenEnd: 0
    property int selectedIndex: 0

    function forceActiveFocus() {
        field.forceActiveFocus()
    }

    function selectAll() {
        field.selectAll()
    }

    function hexColor(c) {
        if (!c) {
            return "#808080"
        }
        var r = Math.round(c.r * 255)
        var g = Math.round(c.g * 255)
        var b = Math.round(c.b * 255)
        return "#" + ("00000" + ((r << 16) | (g << 8) | b).toString(16)).slice(-6)
    }

    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function colorForSpan(span) {
        if (!span) {
            return hexColor(Kirigami.Theme.textColor)
        }
        if (span.kind === "priority") {
            return hexColor(Colors.colorForPriority(Number(span.value)))
        }
        if (span.kind === "label") {
            return hexColor(Design.colorForKey(span.value, "label"))
        }
        if (span.kind === "project") {
            return hexColor(Design.colorForKey(span.value, "project"))
        }
        return hexColor(Kirigami.Theme.linkColor)
    }

    function highlightHtml() {
        var value = field.text || ""
        if (!value.length) {
            return ""
        }
        var spans = (parsed && parsed.spans) ? parsed.spans.slice() : []
        spans.sort(function (a, b) { return a.start - b.start })
        var parts = []
        var i = 0
        for (var s = 0; s < spans.length; ++s) {
            var span = spans[s]
            var start = Math.max(0, Math.min(value.length, span.start))
            var end = Math.max(start, Math.min(value.length, span.start + span.length))
            if (start > i) {
                parts.push(esc(value.substring(i, start)))
            }
            parts.push('<font color="' + colorForSpan(span) + '"><b>' + esc(value.substring(start, end)) + '</b></font>')
            i = end
        }
        if (i < value.length) {
            parts.push(esc(value.substring(i)))
        }
        return parts.join("")
    }

    function suggestionTitle(item) {
        if (!item) {
            return ""
        }
        if (item.kind === "date") {
            switch (item.value) {
            case "today": return i18n("Today")
            case "tomorrow": return i18n("Tomorrow")
            case "yesterday": return i18n("Yesterday")
            case "nextweek": return i18n("Next week")
            case "tonight": return i18n("Tonight")
            default: return item.insertText
            }
        }
        if (item.kind === "priority") {
            if (Number(item.priority) <= 0) {
                return i18n("No priority")
            }
            if (Number(item.priority) <= 3) {
                return i18n("High")
            }
            if (Number(item.priority) <= 6) {
                return i18n("Medium")
            }
            return i18n("Low")
        }
        return item.insertText
    }

    function suggestionIcon(item) {
        if (!item) {
            return "help-hint"
        }
        if (item.kind === "date" || item.kind === "time") {
            return "view-calendar"
        }
        if (item.kind === "priority") {
            return "flag"
        }
        if (item.kind === "label") {
            return "tag"
        }
        if (item.kind === "project") {
            return "folder"
        }
        return "help-hint"
    }

    function suggestionColor(item) {
        if (!item) {
            return Kirigami.Theme.textColor
        }
        if (item.kind === "priority") {
            return Colors.colorForPriority(Number(item.priority))
        }
        if (item.kind === "label") {
            return Design.colorForKey(item.value, "label")
        }
        if (item.kind === "project") {
            return Design.colorForKey(item.value, "project")
        }
        return Kirigami.Theme.linkColor
    }

    function currentToken() {
        return field.text.substring(tokenStart, tokenEnd)
    }

    function applySuggestion(item) {
        if (!item) {
            return
        }
        var before = field.text.substring(0, tokenStart)
        var after = field.text.substring(tokenEnd)
        var insert = item.insertText || ""
        if (!after.length || after[0] !== " ") {
            insert += " "
        }
        field.text = before + insert + after
        field.cursorPosition = before.length + insert.length
        suggestPopup.close()
        Qt.callLater(root.refresh)
    }

    function applySelected() {
        if (selectedIndex >= 0 && selectedIndex < suggestions.length) {
            applySuggestion(suggestions[selectedIndex])
            return true
        }
        return false
    }

    function placePopup() {
        var host = suggestPopup.parent
        if (!host) {
            return
        }
        var p = field.mapToItem(host, 0, 0)
        suggestPopup.width = field.width
        var above = p.y - suggestPopup.implicitHeight - Design.spaceTiny
        if (above >= 0) {
            suggestPopup.x = p.x
            suggestPopup.y = above
        } else {
            suggestPopup.x = p.x
            suggestPopup.y = p.y + field.height + Design.spaceTiny
        }
    }

    function refresh() {
        if (!controller || typeof controller.parseQuickAdd !== "function") {
            parsed = ({})
            suggestions = []
            suggestPopup.close()
            return
        }
        parsed = controller.parseQuickAdd(field.text, root.uiLanguage, root.projects) || ({})
        if (!field.text.length) {
            suggestions = []
            suggestPopup.close()
            return
        }
        var result = controller.suggestQuickAdd(field.text, field.cursorPosition, root.uiLanguage, root.projects) || ({})
        tokenStart = result.tokenStart || 0
        tokenEnd = result.tokenEnd || 0
        var items = result.items || []
        suggestions = items
        if (!items.length) {
            suggestPopup.close()
            return
        }
        var token = currentToken()
        if (items.length === 1 && String(items[0].insertText).toLowerCase() === token.toLowerCase()) {
            suggestPopup.close()
            return
        }
        selectedIndex = 0
        placePopup()
        if (!suggestPopup.visible) {
            suggestPopup.open()
        } else {
            placePopup()
        }
    }

    QQC2.TextField {
        id: field
        width: root.width
        height: implicitHeight
        readonly property bool hasSelection: selectionStart !== selectionEnd
        color: (highlightLabel.visible && !hasSelection) ? "transparent" : Kirigami.Theme.textColor
        selectedTextColor: Kirigami.Theme.highlightedTextColor
        selectionColor: Kirigami.Theme.highlightColor
        cursorDelegate: Rectangle {
            width: 2
            color: Kirigami.Theme.textColor
            visible: field.activeFocus
            Behavior on y { NumberAnimation { duration: 100 } }
        }
        Keys.priority: Keys.BeforeItem

        onTextChanged: root.refresh()
        onCursorPositionChanged: {
            if (activeFocus) {
                root.refresh()
            }
        }

        Keys.onPressed: function (event) {
            if (suggestPopup.visible && suggestions.length) {
                if (event.key === Qt.Key_Down) {
                    selectedIndex = Math.min(suggestions.length - 1, selectedIndex + 1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Up) {
                    selectedIndex = Math.max(0, selectedIndex - 1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Tab) {
                    root.applySelected()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Escape) {
                    suggestPopup.close()
                    event.accepted = true
                    return
                }
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var token = root.currentToken()
                var item = suggestions.length ? suggestions[selectedIndex] : null
                if (suggestPopup.visible && item && String(item.insertText).toLowerCase() !== token.toLowerCase()) {
                    root.applySelected()
                    event.accepted = true
                    return
                }
                suggestPopup.close()
                root.accepted()
                event.accepted = true
            }
        }
    }

    Text {
        id: highlightLabel
        x: field.leftPadding
        y: field.topPadding
        width: field.width - field.leftPadding - field.rightPadding
        height: field.height - field.topPadding - field.bottomPadding
        font: field.font
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.StyledText
        text: root.highlightHtml()
        color: Kirigami.Theme.textColor
        elide: Text.ElideRight
        clip: true
        renderType: field.renderType
        visible: field.text.length > 0 && !field.hasSelection
    }

    QQC2.Popup {
        id: suggestPopup
        parent: root.popupHost || root
        popupType: QQC2.Popup.Item
        modal: false
        dim: false
        focus: false
        padding: Design.spaceTiny
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Design.inputRadius
            color: Kirigami.Theme.backgroundColor
            border.color: Design.windowBorderColor()
            border.width: 1
        }

        contentItem: ListView {
            id: suggestList
            implicitWidth: field.width
            implicitHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 8)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.suggestions
            currentIndex: root.selectedIndex
            spacing: 0
            delegate: QQC2.ItemDelegate {
                required property var modelData
                required property int index
                width: suggestList.width
                highlighted: index === root.selectedIndex
                onClicked: root.applySuggestion(modelData)
                contentItem: RowLayout {
                    spacing: Design.spaceTiny
                    Kirigami.Icon {
                        source: root.suggestionIcon(modelData)
                        color: root.suggestionColor(modelData)
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: root.suggestionTitle(modelData)
                        elide: Text.ElideRight
                        color: root.suggestionColor(modelData)
                        font.bold: true
                    }
                    QQC2.Label {
                        visible: String(modelData.insertText) !== root.suggestionTitle(modelData)
                        text: modelData.insertText
                        opacity: 0.65
                        elide: Text.ElideRight
                    }
                }
            }

            QQC2.ScrollBar.vertical: ThinScrollBar {
                view: suggestList
            }
        }

        onAboutToShow: root.placePopup()
    }
}
