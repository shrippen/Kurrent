import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "."

/**
 * Filterable combo box: type to narrow a long list (customers, projects, activities).
 * `model` is a JS list of strings or objects (`textRole`, and `colorRole` for an entity
 * square; entities without a colour get `KanteStyle.entityFallbackColor`). Typing filters
 * (any part, case-insensitive); ↑ ↓ move, Enter picks, Esc closes; the button shows the
 * whole list. `activated(index)` gives the index in `model`.
 * `allowNew` adds an "add" row when nothing matches exactly: Enter or a tap emits
 * `newEntered(text)`. `keepText: false` clears the field after a pick (see KanteTagPicker);
 * `exclude` hides entries by text.
 *   System  a plain text field, platform popup, rows in the roles.
 *   Kante   sunken Kante field, the popup as a Kante card, the current row cyan.
 */
FocusScope {
    id: root

    property var model: []
    property string textRole: ""
    property string colorRole: ""
    property int currentIndex: -1
    readonly property string currentText: textAt(currentIndex)
    property string placeholderText: ""
    property bool allowNew: false
    property string newText: qsTr("Add “%1”")
    property bool keepText: true
    property var exclude: []
    property int maxRows: 8
    /** Kante: draw the field's sunken box (false inside a framed container). */
    property bool kanteFrame: true
    readonly property alias popupOpen: popup.visible
    readonly property alias editText: input.text
    /** Row under the keyboard in the list (index in `matches`). */
    property int highlighted: 0
    /** The user typed since the list opened: filter by the text. */
    property bool filtering: false
    signal activated(int index)
    signal newEntered(string text)
    /** Backspace in the empty field (a tag picker removes its last tag). */
    signal backspaceOnEmpty()

    implicitWidth: KanteStyle.unit(220)
    implicitHeight: input.implicitHeight

    function textAt(i) {
        if (!model || i < 0 || i >= model.length) {
            return ""
        }
        var e = model[i]
        return textRole !== "" && e !== null && typeof e === "object" ? String(e[textRole]) : String(e)
    }
    function colorAt(i) {
        var e = model[i]
        if (colorRole === "" || e === null || typeof e !== "object") {
            return KanteStyle.entityFallbackColor
        }
        var c = e[colorRole]
        return c === undefined || c === null || c === "" ? KanteStyle.entityFallbackColor : c
    }

    readonly property string query: filtering ? input.text.trim() : ""
    /** Indices into `model` that match the query and are not excluded. */
    readonly property var matches: {
        var out = []
        var q = query.toLowerCase()
        var n = model ? model.length : 0
        for (var i = 0; i < n; i++) {
            var t = textAt(i)
            if (exclude && exclude.indexOf(t) >= 0) {
                continue
            }
            if (q !== "" && t.toLowerCase().indexOf(q) < 0) {
                continue
            }
            out.push(i)
        }
        return out
    }
    readonly property bool exactMatch: {
        var q = query.toLowerCase()
        for (var i = 0; i < matches.length; i++) {
            if (textAt(matches[i]).toLowerCase() === q) {
                return true
            }
        }
        return false
    }
    readonly property bool offersNew: allowNew && query !== "" && !exactMatch
    readonly property int rowCount: matches.length + (offersNew ? 1 : 0)

    function openList() {
        highlighted = 0
        popup.open()
    }
    function move(delta) {
        if (!popup.visible) {
            openList()
            return
        }
        highlighted = Math.max(0, Math.min(rowCount - 1, highlighted + delta))
        list.positionViewAtIndex(highlighted, ListView.Contain)
    }
    /** Picks row `row` of the list (a match, or the "add" row after the matches). */
    function choose(row) {
        if (row < 0 || row >= rowCount) {
            return
        }
        // Read the row before the list changes: closing ends the filter.
        var isNew = row >= matches.length
        var index = isNew ? -1 : matches[row]
        var text = query
        popup.close()
        filtering = false
        if (isNew) {
            input.text = keepText ? text : ""
            newEntered(text)
            return
        }
        currentIndex = index
        input.text = keepText ? textAt(index) : ""
        activated(index)
    }
    /** Enter: picks the keyboard row; typed text with a closed list opens it first. */
    function enter(event) {
        if (popup.visible && rowCount > 0) {
            choose(highlighted)
            return
        }
        if (filtering && rowCount > 0) {
            choose(0)
            return
        }
        event.accepted = false
    }
    function reset() {
        filtering = false
        input.text = keepText ? currentText : ""
    }

    onCurrentTextChanged: {
        if (!filtering && keepText) {
            input.text = currentText
        }
    }

    // The button sits inside the field's right end; the text keeps clear of it.
    Item {
        anchors.fill: parent

        KanteTextField {
            id: input
            anchors.fill: parent
            rightPadding: button.width + KanteStyle.unit(6)
            focus: true
            kanteFrame: root.kanteFrame
            text: root.keepText ? root.currentText : ""
            placeholderText: root.placeholderText
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextEdited: {
                root.filtering = true
                root.highlighted = 0
                if (!popup.visible) {
                    popup.open()
                }
            }
            onActiveFocusChanged: {
                // Focus selects the text, so typing replaces the current entry and filters.
                if (activeFocus) {
                    selectAll()
                    return
                }
                popup.close()
                root.reset()
            }
            Keys.onPressed: function (event) {
                event.accepted = event.key === Qt.Key_Backspace && text === ""
                if (event.accepted) {
                    root.backspaceOnEmpty()
                }
            }
            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
            Keys.onReturnPressed: function (event) { root.enter(event) }
            Keys.onEnterPressed: function (event) { root.enter(event) }
            Keys.onEscapePressed: function (event) {
                if (!popup.visible) {
                    event.accepted = false
                    return
                }
                popup.close()
                root.reset()
            }
        }
        // Entity square of the current entry, left in the field.
        Rectangle {
            id: swatch
            visible: root.colorRole !== "" && root.currentIndex >= 0 && root.keepText && !root.filtering
            x: KanteStyle.unit(9)
            anchors.verticalCenter: parent.verticalCenter
            width: KanteStyle.unit(10)
            height: width
            color: root.currentIndex >= 0 ? root.colorAt(root.currentIndex) : "transparent"
        }
        Binding {
            target: input
            property: "leftPadding"
            value: swatch.x + swatch.width + KanteStyle.unit(7)
            when: swatch.visible
            restoreMode: Binding.RestoreBindingOrValue
        }
        KanteToolButton {
            id: button
            anchors.right: parent.right
            anchors.rightMargin: KanteStyle.unit(2)
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(KanteStyle.unit(20), input.height - KanteStyle.unit(4))
            width: height
            padding: 0
            display: QQC2.AbstractButton.IconOnly
            focusPolicy: Qt.NoFocus
            Accessible.name: root.placeholderText
            onClicked: {
                if (popup.visible) {
                    popup.close()
                    return
                }
                root.filtering = false
                input.forceActiveFocus()
                root.openList()
            }

            // Down chevron: a flat triangle.
            Shape {
                anchors.centerIn: parent
                width: KanteStyle.unit(10)
                height: KanteStyle.unit(6)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: KanteStyle.textColor
                    startX: 0; startY: 0
                    PathLine { x: KanteStyle.unit(10); y: 0 }
                    PathLine { x: KanteStyle.unit(5); y: KanteStyle.unit(6) }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
    }

    QQC2.Popup {
        id: popup
        y: root.height + KanteStyle.unit(2)
        width: root.width
        padding: KanteStyle.unit(4)
        topPadding: KanteStyle.unit(6)
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        implicitHeight: Math.min(root.maxRows, Math.max(1, root.rowCount)) * root.rowHeight + topPadding + bottomPadding

        KantePopupSkin { popup: popup }

        contentItem: ListView {
            id: list
            clip: true
            model: root.rowCount
            currentIndex: root.highlighted
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }

            delegate: Rectangle {
                id: row
                required property int index
                readonly property bool isNew: index >= root.matches.length
                readonly property int modelIndex: isNew ? -1 : root.matches[index]
                readonly property bool current: index === root.highlighted
                width: ListView.view.width
                height: root.rowHeight
                color: current ? KanteStyle.selectionColor : (rowHover.hovered ? KanteStyle.tint1Color : "transparent")

                // Cyan edge on the keyboard row, as on selected rows elsewhere.
                Rectangle {
                    visible: row.current && KanteStyle.active
                    width: KanteStyle.unit(3)
                    height: parent.height
                    color: KanteStyle.focusColor
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: KanteStyle.unit(10)
                    anchors.rightMargin: KanteStyle.unit(10)
                    spacing: KanteStyle.unit(8)
                    Rectangle {
                        visible: root.colorRole !== "" && !row.isNew
                        Layout.preferredWidth: KanteStyle.unit(10)
                        Layout.preferredHeight: KanteStyle.unit(10)
                        color: row.isNew ? "transparent" : root.colorAt(row.modelIndex)
                    }
                    Text {
                        visible: row.isNew
                        text: "+"
                        color: KanteStyle.focusColor
                        font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.isNew ? root.newText.arg(root.query) : root.textAt(row.modelIndex)
                        color: row.isNew ? KanteStyle.focusColor : (row.current ? KanteStyle.strongTextColor : KanteStyle.textColor)
                        font: KanteStyle.defaultFont
                    }
                }
                HoverHandler { id: rowHover }
                TapHandler { onTapped: root.choose(row.index) }
            }
        }
    }

    readonly property real rowHeight: KanteStyle.unit(32)
}
