import QtQuick
import QtQuick.Shapes
import "."

/**
 * A learning path (Kante 1.25, for Kaiwa; web: `.path > .node`; decision D-6). A column of
 * nodes with a bar on the left and a sign, so the state never hangs on colour:
 *
 *   done     positive bar and a check
 *   current  accent bar, tinted surface and a filled square: the chosen node
 *   open     neutral bar and a hollow square: unlocked, to do, not the chosen node
 *   review   info bar and a diamond, indented as a side branch (repetition between units)
 *   locked   muted, dimmed, with `lockedText` after the meta line
 *
 * Every node but a locked one is a button: click, Enter or Space fire `activated(index)`.
 * KanteSteps stays for wizards (one line, no branches).
 *
 *   model  [{title: "An der Konbini", meta: "N5-03 · 2 von 4", state: "current"}, …]
 */
Column {
    id: path

    property var model: []
    property string lockedText: "gesperrt"
    property string doneText: "erledigt"
    property string reviewText: "Wiederholung"
    property string currentText: "aktuell"
    property string openText: "offen"

    signal activated(int index)

    spacing: KanteStyle.unit(6)
    width: KanteStyle.unit(360)

    Accessible.role: Accessible.List

    Repeater {
        model: path.model
        delegate: Item {
            id: node
            required property int index
            required property var modelData
            readonly property string st: modelData.state || "locked"
            readonly property bool locked: st === "locked"
            readonly property real indent: st === "review" ? KanteStyle.unit(26) : 0
            readonly property color tone: st === "done" ? KanteStyle.positiveTextColor
                : st === "current" ? KanteStyle.accentColor
                : st === "review" ? KanteStyle.infoColor : KanteStyle.frameColor
            readonly property string stateWord: st === "done" ? path.doneText : st === "current" ? path.currentText
                : st === "review" ? path.reviewText : st === "open" ? path.openText : path.lockedText

            width: path.width
            height: Math.max(KanteStyle.heightLarge, texts.implicitHeight + KanteStyle.unit(14))
            opacity: locked ? 0.55 : 1
            activeFocusOnTab: !locked

            Accessible.role: Accessible.ListItem
            Accessible.name: (modelData.title || "") + ", " + stateWord
            Accessible.description: modelData.meta || ""
            Accessible.onPressAction: if (!node.locked) path.activated(node.index)
            Keys.onReturnPressed: if (!node.locked) path.activated(node.index)
            Keys.onSpacePressed: if (!node.locked) path.activated(node.index)

            KantePolygon {
                x: node.indent
                width: parent.width - node.indent
                height: parent.height
                fillColor: node.st === "current" ? KanteStyle.tint(KanteStyle.accentColor, 0.12) : KanteStyle.cardColor
                cutTopRight: KanteStyle.active ? KanteStyle.unit(6) : 0
            }
            Rectangle {
                x: node.indent
                width: KanteStyle.unit(4)
                height: parent.height
                color: node.tone
            }
            Shape {
                id: sign
                x: node.indent + KanteStyle.unit(16)
                anchors.verticalCenter: parent.verticalCenter
                width: KanteStyle.unit(12)
                height: width
                visible: !node.locked
                antialiasing: true
                ShapePath {
                    readonly property real s: sign.width
                    readonly property bool line: node.st === "done" || node.st === "open"
                    strokeWidth: line ? 2 : -1
                    strokeColor: node.st === "open" ? KanteStyle.mutedTextColor : line ? node.tone : "transparent"
                    fillColor: line ? "transparent" : node.tone
                    PathSvg {
                        path: {
                            var s = sign.width
                            if (node.st === "done") return "M " + 0.1 * s + " " + 0.55 * s + " L " + 0.4 * s + " " + 0.85 * s + " L " + 0.95 * s + " " + 0.15 * s
                            if (node.st === "review") return "M " + s / 2 + " 0 L " + s + " " + s / 2 + " L " + s / 2 + " " + s + " L 0 " + s / 2 + " Z"
                            if (node.st === "open") return "M 1 1 L " + (s - 1) + " 1 L " + (s - 1) + " " + (s - 1) + " L 1 " + (s - 1) + " Z"
                            return "M 0 0 L " + s + " 0 L " + s + " " + s + " L 0 " + s + " Z"
                        }
                    }
                }
            }
            Column {
                id: texts
                x: node.indent + KanteStyle.unit(40)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - KanteStyle.unit(12)
                spacing: KanteStyle.unit(2)
                Text {
                    width: parent.width
                    text: node.modelData.title || ""
                    color: KanteStyle.strongTextColor
                    font: KanteStyle.titleFont(KanteStyle.defaultFont.pointSize)
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: [node.modelData.meta || "", node.locked ? path.lockedText : ""].filter(s => s.length > 0).join(" · ")
                    visible: text.length > 0
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.labelFont()
                    elide: Text.ElideRight
                }
            }
            KantePolygon {
                // Focus along the cut shape.
                visible: node.activeFocus
                x: node.indent
                width: parent.width - node.indent
                height: parent.height
                strokeColor: KanteStyle.focusColor
                strokeWidth: 2
                cutTopRight: KanteStyle.active ? KanteStyle.unit(6) : 0
            }
            TapHandler {
                enabled: !node.locked
                onTapped: { node.forceActiveFocus(Qt.MouseFocusReason); path.activated(node.index) }
            }
            HoverHandler { enabled: !node.locked; cursorShape: Qt.PointingHandCursor }
        }
    }
}
