import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import "."

/**
 * Filterable combo box: type to narrow a long list (customers, projects, activities).
 * `model` is a JS list of strings or objects (`textRole`, and `colorRole` for an entity
 * square; entities without a colour get `KanteStyle.entityFallbackColor`). Typing filters
 * (any part, case-insensitive); ↑ ↓ move, Enter picks, Esc closes; the button shows the
 * whole list. `activated(index)` gives the index in `model`.
 * `allowNew` adds an "add" row when nothing matches exactly: Enter or a tap emits
 * `newEntered(text)`. `keepText: false` clears the field after a pick (see KanteTagPicker);
 * `exclude` hides entries by text. `sectionRole` groups the rows under headings (entries of
 * one section next to each other, as in a ListView section).
 * The popup stays inside the window: above the field when there is no room below (`popupAbove`
 * true / false forces a side), shifted left at the right edge, capped to the free height.
 * `openList()` / `close()` drive it.
 *   System  a plain text field, platform popup, rows in the roles.
 *   Kante   sunken Kante field, the popup as a Kante card, the current row cyan.
 */
FocusScope {
    id: root

    property var model: []
    property string textRole: ""
    property string colorRole: ""
    /** Role of the section heading of an entry (e.g. "customer"); "" = no headings. */
    property string sectionRole: ""
    /** Side of the popup: undefined = below, above when there is no room (true / false force it). */
    property var popupAbove: undefined
    /** The list opens above or below this item (default the field; a tag picker hands its box). */
    property Item popupAnchor: null
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
    readonly property alias popupOpen: listPopup.visible
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

    function sectionAt(i) {
        var e = model && i >= 0 && i < model.length ? model[i] : null
        if (sectionRole === "" || e === null || typeof e !== "object") {
            return ""
        }
        var v = e[sectionRole]
        return v === undefined || v === null ? "" : String(v)
    }
    /** List row `row` starts a section: it gets a heading above it. */
    function startsSection(row) {
        if (sectionRole === "" || row >= matches.length) {
            return false
        }
        var here = sectionAt(matches[row])
        return here !== "" && (row === 0 || sectionAt(matches[row - 1]) !== here)
    }
    /** Height of the first `rows` list rows with their headings. */
    function listHeight(rows) {
        var h = 0
        for (var r = 0; r < rows; r++) {
            h += rowHeight + (startsSection(r) ? headingHeight : 0)
        }
        return h
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
        listPopup.open()
    }
    /** The list's place: x from the field, the side from `popupAnchor` (in the field's coordinates). */
    function placeList(w, h) {
        var side = popupAnchor || root
        var across = KanteStyle.popupPlace(root, w, h, popupAbove)
        var along = KanteStyle.popupPlace(side, w, h, popupAbove)
        var top = side.mapToItem(root, 0, 0).y
        return { x: across.x, y: top + along.y, above: along.above, room: along.room, top: top }
    }
    /** Closes the list and ends the filter (the field shows the current entry again). */
    function close() {
        listPopup.close()
        reset()
    }
    function move(delta) {
        if (!listPopup.visible) {
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
        listPopup.close()
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
        if (listPopup.visible && rowCount > 0) {
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
                if (!listPopup.visible) {
                    listPopup.open()
                }
            }
            onActiveFocusChanged: {
                // Focus selects the text, so typing replaces the current entry and filters.
                if (activeFocus) {
                    selectAll()
                    return
                }
                listPopup.close()
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
                if (!listPopup.visible) {
                    event.accepted = false
                    return
                }
                listPopup.close()
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
                if (listPopup.visible) {
                    listPopup.close()
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
        id: listPopup
        objectName: "popup"
        width: root.width
        padding: KanteStyle.unit(4)
        topPadding: KanteStyle.unit(6)
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        implicitHeight: (root.rowCount > 0 ? root.listHeight(Math.min(root.maxRows, root.rowCount)) : root.rowHeight)
                        + topPadding + bottomPadding
        // Inside the window: above the field when there is no room below, capped to the free height.
        readonly property var place: visible ? root.placeList(width, implicitHeight)
                                             : ({ x: 0, y: root.height + KanteStyle.unit(2), above: false, room: implicitHeight, top: 0 })
        readonly property real minHeight: root.rowHeight + topPadding + bottomPadding
        x: place.x
        y: place.above ? place.top - height - KanteStyle.unit(2) : place.y
        height: Math.max(minHeight, Math.min(implicitHeight, place.room))

        KantePopupSkin { popup: listPopup }

        contentItem: ListView {
            id: list
            clip: true
            model: root.rowCount
            currentIndex: root.highlighted
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }

            delegate: Item {
                id: row
                required property int index
                readonly property bool isNew: index >= root.matches.length
                readonly property int modelIndex: isNew ? -1 : root.matches[index]
                readonly property bool current: index === root.highlighted
                readonly property real headHeight: root.startsSection(index) ? root.headingHeight : 0
                width: ListView.view.width
                height: headHeight + root.rowHeight

                // Section heading: a small label over the first row of its section.
                Text {
                    visible: row.headHeight > 0
                    x: KanteStyle.unit(10)
                    width: parent.width - 2 * x
                    height: row.headHeight
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: KanteStyle.unit(3)
                    elide: Text.ElideRight
                    text: visible ? root.sectionAt(row.modelIndex) : ""
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.labelFont()
                }
                Rectangle {
                    y: row.headHeight
                    width: parent.width
                    height: root.rowHeight
                    color: row.current ? KanteStyle.selectionColor : (rowHover.hovered ? KanteStyle.tint1Color : "transparent")

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
    }

    readonly property real rowHeight: KanteStyle.unit(32)
    readonly property real headingHeight: KanteStyle.unit(24)
}
