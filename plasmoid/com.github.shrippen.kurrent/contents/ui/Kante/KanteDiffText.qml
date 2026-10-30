import QtQuick
import "."

/**
 * A correction as a diff (Kante 1.25, for Kaiwa; web: `.diff del`, `.diff ins`). Removed text
 * is struck through with a 2 px line in the negative colour and muted, added text sits on
 * the focus tint with a 2 px focus underline (marked). Strike and underline carry the
 * meaning, so it never hangs on colour. Every character is a piece of its own, so the line
 * wraps anywhere in Japanese text. Title of a KanteHintCard.
 *
 *   parts  [{text: "コーヒー"}, {text: "を", kind: "removed"}, {text: "が", kind: "added"}, {text: "好きです"}]
 *          kind "same" (default), "removed" or "added"
 */
Flow {
    id: diff

    property var parts: []
    /** In the Japanese family (Kante 1.34, KanteStyle.japaneseFont). */
    property font font: KanteStyle.japaneseFont()
    property color color: KanteStyle.textColor
    property string removedWord: "gestrichen"
    property string addedWord: "neu"

    readonly property var pieces: {
        var out = []
        var src = parts || []
        for (var i = 0; i < src.length; i++) {
            var chars = Array.from(src[i].text || "")
            var kind = src[i].kind || "same"
            for (var c = 0; c < chars.length; c++) out.push({ text: chars[c], kind: kind })
        }
        return out
    }
    /** "コーヒー, gestrichen を, neu が, 好きです": what a screen reader says. */
    readonly property string spoken: {
        var s = []
        var src = parts || []
        for (var i = 0; i < src.length; i++) {
            var k = src[i].kind || "same"
            s.push((k === "removed" ? removedWord + " " : k === "added" ? addedWord + " " : "") + src[i].text)
        }
        return s.join(", ")
    }

    spacing: 0
    Accessible.role: Accessible.StaticText
    Accessible.name: spoken

    Repeater {
        model: diff.pieces
        delegate: Item {
            id: piece
            required property var modelData
            readonly property bool removed: modelData.kind === "removed"
            readonly property bool added: modelData.kind === "added"
            implicitWidth: glyph.implicitWidth
            implicitHeight: glyph.implicitHeight + KanteStyle.unit(3)
            width: implicitWidth
            height: implicitHeight
            Rectangle {
                visible: piece.added
                anchors.fill: parent
                color: KanteStyle.tintHighlightColor
            }
            Text {
                id: glyph
                text: piece.modelData.text
                font: diff.font
                color: piece.removed ? KanteStyle.mutedTextColor : (piece.added ? KanteStyle.strongTextColor : diff.color)
                Accessible.ignored: true
            }
            Rectangle {
                // Strike: 2 px through the middle of the glyphs.
                visible: piece.removed
                width: parent.width
                height: 2
                y: Math.round(glyph.height * 0.55)
                color: KanteStyle.negativeTextColor
            }
            Rectangle {
                // Underline of added text.
                visible: piece.added
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                color: KanteStyle.focusColor
            }
        }
    }
}
