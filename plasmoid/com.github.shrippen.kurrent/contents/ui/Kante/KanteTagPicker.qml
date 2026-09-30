import QtQuick
import QtQuick.Layouts
import "."

/**
 * Tags as chips with a search field to add more: the chips wrap, the field follows the last one.
 * `tags` and `suggestions` are lists of strings or of {name, color}; a tag without a colour is
 * purple (`KanteStyle.tagColor`). Typing filters the suggestions not yet picked (a
 * KanteSearchCombo); Enter or a tap adds one, `allowNew` also adds typed text. The ×
 * of a chip removes it, Backspace in the empty field the last one.
 * The picker does not change `tags` itself: `edited(tags)` hands the new list to the app
 * (`onEdited: function (t) { tags = t }`).
 *   System  the platform text field inside, chips in the roles.
 *   Kante   one sunken box around chips and field with the 2 px edge, cyan on focus.
 */
Item {
    id: root

    property var tags: []
    property var suggestions: []
    property bool allowNew: true
    property string placeholderText: ""
    property string removeText: qsTr("Remove %1")
    signal edited(var tags)

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: flow.implicitHeight + 2 * pad

    readonly property real pad: KanteStyle.themed ? KanteStyle.unit(4) : 0
    readonly property var tagNames: tags.map(nameOf)
    readonly property alias search: combo

    function nameOf(t) {
        return t !== null && typeof t === "object" ? String(t.name) : String(t)
    }
    function colorOf(t) {
        if (t !== null && typeof t === "object" && t.color !== undefined && t.color !== "") {
            return t.color
        }
        return KanteStyle.tagColor
    }
    function add(t) {
        if (tagNames.indexOf(nameOf(t)) >= 0) {
            return
        }
        edited(tags.concat([t]))
    }
    function remove(i) {
        var out = tags.slice()
        out.splice(i, 1)
        edited(out)
    }

    // One sunken box with the Kante field edge around everything (Kante only).
    Rectangle {
        anchors.fill: parent
        visible: KanteStyle.themed
        color: combo.activeFocus ? KanteStyle.selectionColor : KanteStyle.sunkenColor
        border.width: 1
        border.color: combo.activeFocus ? KanteStyle.tint(KanteStyle.focusColor, 0.55) : KanteStyle.frameColor
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: combo.activeFocus ? KanteStyle.focusColor : KanteStyle.frameColor
        }
    }

    Flow {
        id: flow
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: KanteStyle.unit(4)

        Repeater {
            model: root.tags
            delegate: KanteChip {
                required property var modelData
                required property int index
                // Centred on the field's line.
                y: 0
                height: combo.height
                text: root.nameOf(modelData)
                chipColor: root.colorOf(modelData)
                removable: true
                onRemoveRequested: root.remove(index)
                Accessible.description: root.removeText.arg(text)
            }
        }
        KanteSearchCombo {
            id: combo
            width: Math.max(KanteStyle.unit(140), Math.min(KanteStyle.unit(220), flow.width))
            kanteFrame: false
            keepText: false
            allowNew: root.allowNew
            placeholderText: root.placeholderText
            model: root.suggestions.map(root.nameOf)
            exclude: root.tagNames
            onActivated: function (index) { root.add(root.suggestions[index]) }
            onNewEntered: function (text) { root.add(text) }
            onBackspaceOnEmpty: {
                if (root.tags.length > 0) {
                    root.remove(root.tags.length - 1)
                }
            }
        }
    }
}
