import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "."

/**
 * Command palette (Kante 1.81, for Klappe): Ctrl+K in an editor. A card at the top middle of
 * the window with a search field over the list of matching commands. Presentational: the app
 * owns the commands and does the work on `triggered`.
 *
 *   commands   [{ id, text, group, keys, enabled }]
 *     id       given back by `triggered`
 *     text     the name shown and searched
 *     group    heading over its commands (also searched); "" for none, listed first
 *     keys     the shortcut as shown, a string ("Ctrl+S") or a list of strings (one cap each)
 *     enabled  false (default true): shown dimmed, skipped by the arrows, does not fire
 *   open(), close()   open clears the search and puts the cursor in the field
 *   triggered(id)     Enter or a click on an enabled command; the palette closes first
 *   placeholderText, emptyText, accessibleName   the app's words (German defaults)
 *   query      the text in the field; entries the matches in order, current the index of the
 *              highlighted one in `entries` (-1 for none)
 *
 * Filter: every word of the search is a part of the text or the group of a command, in any
 * case. An empty search lists everything. Matches stand under their group in the order the
 * groups first appear in `commands`, and within a group in the order of `commands`.
 * Keyboard: Up and Down move over the enabled entries (round at the ends), Enter fires,
 * Esc closes. The pointer highlights the entry under it and a click fires it.
 * Kante: the dialog card with the focus bar and the cut corner (`KantePopupSkin`);
 * the shortcuts as `KanteKeycap`, group headings as `KanteSectionLabel`.
 */
QQC2.Popup {
    id: cmd

    property var commands: []
    property string placeholderText: "Befehl suchen …"
    property string emptyText: "Keine Treffer"
    property string accessibleName: "Befehle"

    readonly property string query: field.text
    /** The commands that match the search, in the order shown. */
    readonly property var entries: _filter(commands, query)
    /** Headings and entries as one list: { header, text } or { header: false, entry, command }. */
    readonly property var rows: _rowsOf(entries)
    property int current: -1
    /** What a screen reader hears for the chosen entry: its text and shortcut, else `emptyText`. */
    readonly property string spoken: {
        const c = entries[current]
        if (!c) {
            return entries.length > 0 ? "" : emptyText
        }
        const keys = !c.keys ? "" : (typeof c.keys === "string" ? c.keys : Array.from(c.keys).join(" "))
        return keys ? c.text + ", " + keys : c.text
    }

    signal triggered(string id)

    /** Words of a search that all occur in the text or group of a command (any case). */
    function _filter(list, text) {
        const words = text.toLowerCase().split(/\s+/).filter(w => w.length > 0)
        const hits = (list || []).filter(function (c) {
            const hay = ((c.text || "") + " " + (c.group || "")).toLowerCase()
            return words.every(w => hay.indexOf(w) >= 0)
        })

        // Grouped: the commands without a group first, then the groups as they first appear;
        // stable within a group.
        const order = hits.some(c => !c.group) ? [""] : []
        for (const c of hits) {
            const g = c.group || ""
            if (order.indexOf(g) < 0) {
                order.push(g)
            }
        }
        const sorted = []
        for (const g of order) {
            for (const c of hits) {
                if ((c.group || "") === g) {
                    sorted.push(c)
                }
            }
        }
        return sorted
    }

    function _rowsOf(list) {
        const out = []
        let group = ""
        for (let i = 0; i < list.length; i++) {
            const g = list[i].group || ""
            if (g !== group || (i === 0 && g !== "")) {
                out.push({ header: true, text: g })
                group = g
            }
            out.push({ header: false, entry: i, command: list[i] })
        }
        return out
    }

    function _isEnabled(i) {
        return i >= 0 && i < entries.length && entries[i].enabled !== false
    }

    /** The next enabled entry from `from` in direction dir (1 or -1), round at the ends; -1 for none. */
    function _next(from, dir) {
        const n = entries.length
        for (let step = 1; step <= n; step++) {
            const i = ((from + dir * step) % n + n) % n
            if (_isEnabled(i)) {
                return i
            }
        }
        return -1
    }

    function fire() {
        if (!_isEnabled(current)) {
            return
        }
        const id = entries[current].id
        close()
        triggered(id)
    }

    onEntriesChanged: current = _next(-1, 1)
    onCurrentChanged: {
        const row = rows.findIndex(r => !r.header && r.entry === current)
        if (row >= 0) {
            list.positionViewAtIndex(row, ListView.Contain)
        }
    }
    onAboutToShow: {
        field.text = ""
        current = _next(-1, 1)
    }
    onOpened: field.forceActiveFocus()

    parent: QQC2.Overlay.overlay
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: KanteStyle.unit(72)
    width: parent ? Math.min(KanteStyle.unit(560), parent.width - 2 * KanteStyle.unit(16)) : KanteStyle.unit(560)
    padding: KanteStyle.unit(14)
    topPadding: KanteStyle.unit(14) + (KanteStyle.themed ? KanteStyle.unit(3) : 0)
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    // A property, not a child: children go into the content.
    readonly property Item skin: KantePopupSkin {
        popup: cmd
    }

    contentItem: ColumnLayout {
        spacing: KanteStyle.unit(10)

        KanteTextField {
            id: field
            Layout.fillWidth: true
            placeholderText: cmd.placeholderText
            Accessible.name: cmd.accessibleName
            // Focus stays in the field: the chosen entry is read out through its description.
            Accessible.description: cmd.spoken

            Keys.onPressed: function (event) {
                switch (event.key) {
                case Qt.Key_Down:
                    cmd.current = cmd._next(cmd.current, 1)
                    break
                case Qt.Key_Up:
                    cmd.current = cmd._next(cmd.current, -1)
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    cmd.fire()
                    break
                default:
                    return
                }
                event.accepted = true
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, KanteStyle.unit(360))
            visible: cmd.entries.length > 0
            clip: true
            interactive: contentHeight > height
            model: cmd.rows

            Accessible.role: Accessible.List
            Accessible.name: cmd.accessibleName

            delegate: Item {
                id: row
                required property var modelData
                readonly property bool header: modelData.header
                readonly property bool selected: !header && modelData.entry === cmd.current
                readonly property bool usable: !header && modelData.command.enabled !== false
                // A string is one cap; a list is one cap each (Array.isArray is false for a list out of a model).
                readonly property var keys: header || !modelData.command.keys ? []
                                          : (typeof modelData.command.keys === "string" ? [modelData.command.keys] : Array.from(modelData.command.keys))

                width: ListView.view.width
                height: header ? KanteStyle.unit(26) : KanteStyle.heightMedium

                Accessible.role: header ? Accessible.Heading : Accessible.ListItem
                Accessible.name: modelData.text !== undefined ? modelData.text : modelData.command.text
                Accessible.selected: selected

                KanteSectionLabel {
                    visible: row.header
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: KanteStyle.unit(4)
                    anchors.leftMargin: KanteStyle.unit(8)
                    text: row.header ? row.modelData.text : ""
                }

                Rectangle {
                    visible: row.selected
                    anchors.fill: parent
                    color: KanteStyle.selectionColor
                    Rectangle {
                        width: KanteStyle.unit(3)
                        height: parent.height
                        color: KanteStyle.focusColor
                    }
                }

                RowLayout {
                    visible: !row.header
                    anchors.fill: parent
                    anchors.leftMargin: KanteStyle.unit(12)
                    anchors.rightMargin: KanteStyle.unit(8)
                    spacing: KanteStyle.unit(6)
                    opacity: row.usable ? 1 : 0.45

                    Text {
                        Layout.fillWidth: true
                        text: row.header ? "" : row.modelData.command.text
                        color: KanteStyle.textColor
                        font: KanteStyle.defaultFont
                        elide: Text.ElideRight
                        Accessible.ignored: true
                    }
                    Repeater {
                        model: row.keys
                        KanteKeycap {
                            required property string modelData
                            text: modelData
                        }
                    }
                }

                MouseArea {
                    enabled: !row.header
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: if (row.usable) cmd.current = row.modelData.entry
                    onClicked: {
                        if (!row.usable) {
                            return
                        }
                        cmd.current = row.modelData.entry
                        cmd.fire()
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: KanteStyle.unit(4)
            Layout.bottomMargin: KanteStyle.unit(4)
            visible: cmd.entries.length === 0
            text: cmd.emptyText
            color: KanteStyle.mutedTextColor
            font: KanteStyle.defaultFont
            horizontalAlignment: Text.AlignHCenter
            Accessible.role: Accessible.StaticText
        }
    }
}
