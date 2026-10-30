import QtQuick
import "."

/**
 * Text with readings over the kanji (furigana, Kante 1.25, for Kaiwa; web: `.ruby`). Qt Text
 * has no ruby, so the text is a Flow of pieces: a word with a reading is one piece (reading
 * above, base below), every other character is a piece of its own, so the line wraps
 * anywhere in Japanese text. The room for the readings stays reserved in every density,
 * so switching never moves the lines. A reading wider than its word may reach half a
 * reading character over each neighbour when both neighbours have no reading, as in Japanese
 * typesetting, instead of opening a gap; next to another reading it never overlaps. Readings take the muted text colour, new words too
 * (decision D-1).
 *
 *   segments  [{text: "駅", reading: "えき", isNew: false}, {text: "までは"}, …]
 *   markup    the same as a string: "{駅|えき}までは{歩|ある|new}いて{五分|ごふん}です。"
 *   density   All (every reading), New (only isNew), None (none)
 *
 * Words to look up (Kante 1.33, Kaiwa /LF112/): a segment may carry `word`, a number ≥ 0;
 * segments with the same number form one word (食べ + ました). With `interactive`, a word
 * underlines on hover, Tab focuses the text, Left / Right (Home / End) move between words
 * with a focus line in the focus colour, and a click, Enter or Space fire
 * `wordActivated(word)`. `wordRect(word)` gives the word's box (in this item) to anchor a
 * popup, `wordText(word)` its text. Screen readers hear the focused word and `wordHint`.
 */
Flow {
    id: ruby

    enum Density {
        All,
        New,
        None
    }

    property var segments: []
    property string markup: ""
    property int density: KanteRubyText.Density.All
    /** In the Japanese family (Kante 1.34, KanteStyle.japaneseFont). */
    property font font: KanteStyle.japaneseFont()
    property color color: KanteStyle.textColor
    property color readingColor: KanteStyle.mutedTextColor
    /** Reading size as a share of the base size. */
    property real readingScale: 0.5
    /** Words can be hovered, focused and activated (Kante 1.33). */
    property bool interactive: false
    /** The focused word while the text has focus (interactive), -1 none. */
    property int focusWord: -1
    /** Read after the focused word by screen readers. */
    property string wordHint: "Eingabe: nachschlagen"
    readonly property int hoverWord: hover.hovered ? wordAt(hover.point.position.x, hover.point.position.y) : -1

    /** A word was clicked, or Enter / Space pressed on it. */
    signal wordActivated(int word)

    /** The plain base text (what a screen reader reads, what a copy takes). */
    readonly property string text: {
        var s = ""
        for (var i = 0; i < pieces.length; i++) s += pieces[i].text
        return s
    }

    /** "{漢字|かんじ}" or "{漢字|かんじ|new}" around words with a reading; anything else is plain text. */
    function parse(m) {
        var out = []
        var re = /\{([^|}]+)\|([^|}]*)(\|new)?\}/g
        var last = 0, hit
        while ((hit = re.exec(m)) !== null) {
            if (hit.index > last) out.push({ text: m.slice(last, hit.index) })
            out.push({ text: hit[1], reading: hit[2], isNew: hit[3] !== undefined })
            last = re.lastIndex
        }
        if (last < m.length) out.push({ text: m.slice(last) })
        return out
    }

    // Plain runs split into single characters, so Flow can break between them.
    readonly property var pieces: {
        var src = markup.length > 0 ? parse(markup) : (segments || [])
        var out = []
        for (var i = 0; i < src.length; i++) {
            var s = src[i]
            var w = s.word !== undefined && s.word !== null && Number(s.word) >= 0 ? Number(s.word) : -1
            if (s.reading && s.reading.length > 0) {
                out.push({ text: s.text, reading: s.reading, isNew: !!s.isNew, word: w })
            } else {
                var chars = Array.from(s.text || "")
                for (var c = 0; c < chars.length; c++) out.push({ text: chars[c], reading: "", isNew: false, word: w })
            }
        }
        // Whether the neighbours have no reading (a long reading may reach over them).
        for (var k = 0; k < out.length; k++) {
            out[k].openBefore = k > 0 && out[k - 1].reading.length === 0
            out[k].openAfter = k < out.length - 1 && out[k + 1].reading.length === 0
        }
        return out
    }

    readonly property font readingFont: Qt.font({
        family: font.family,
        pointSize: Math.max(6, font.pointSize * readingScale)
    })

    /** The word numbers in reading order, each once. */
    readonly property var words: {
        var out = []
        for (var i = 0; i < pieces.length; i++) {
            var w = pieces[i].word
            if (w >= 0 && out.indexOf(w) < 0) out.push(w)
        }
        return out
    }

    /** The text of a word ("" for an unknown number). */
    function wordText(word) {
        var t = ""
        for (var i = 0; i < pieces.length; i++) {
            if (pieces[i].word === word) t += pieces[i].text
        }
        return t
    }

    /** The box of a word in this item, over all its pieces (a word may wrap: then the first line's part). */
    function wordRect(word) {
        var r = null
        for (var i = 0; i < repeater.count; i++) {
            var it = repeater.itemAt(i)
            if (!it || it.modelData.word !== word) continue
            if (r && Math.abs(it.y - r.y) > 1) break
            if (!r) r = { x: it.x, y: it.y, width: it.width, height: it.height }
            else r.width = it.x + it.width - r.x
        }
        return r ? Qt.rect(r.x, r.y, r.width, r.height) : Qt.rect(0, 0, 0, 0)
    }

    /** The word under a point of this item, -1 none. */
    function wordAt(x, y) {
        for (var i = 0; i < repeater.count; i++) {
            var it = repeater.itemAt(i)
            if (it && x >= it.x && x < it.x + it.width && y >= it.y && y < it.y + it.height) return it.modelData.word
        }
        return -1
    }

    function moveWord(step) {
        if (words.length === 0) return
        var k = words.indexOf(focusWord)
        k = k < 0 ? (step > 0 ? 0 : words.length - 1) : Math.max(0, Math.min(words.length - 1, k + step))
        focusWord = words[k]
    }

    spacing: 0
    activeFocusOnTab: interactive && words.length > 0
    onActiveFocusChanged: if (activeFocus && words.indexOf(focusWord) < 0) focusWord = words.length > 0 ? words[0] : -1

    Accessible.role: interactive ? Accessible.List : Accessible.StaticText
    Accessible.name: text
    Accessible.description: interactive && activeFocus && focusWord >= 0 ? wordText(focusWord) + ". " + wordHint : ""

    Keys.enabled: interactive
    Keys.onLeftPressed: moveWord(-1)
    Keys.onRightPressed: moveWord(1)
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Home && words.length > 0) {
            focusWord = words[0]
        } else if (event.key === Qt.Key_End && words.length > 0) {
            focusWord = words[words.length - 1]
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && focusWord >= 0) {
            wordActivated(focusWord)
        } else {
            return
        }
        event.accepted = true
    }

    HoverHandler {
        id: hover
        enabled: ruby.interactive
        cursorShape: ruby.hoverWord >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        enabled: ruby.interactive
        onTapped: function (point) {
            var w = ruby.wordAt(point.position.x, point.position.y)
            if (w < 0) return
            ruby.focusWord = w
            ruby.wordActivated(w)
        }
    }

    Repeater {
        id: repeater
        model: ruby.pieces
        delegate: Item {
            id: piece
            required property var modelData
            readonly property bool shown: modelData.reading.length > 0
                && (ruby.density === KanteRubyText.Density.All
                    || (ruby.density === KanteRubyText.Density.New && modelData.isNew))
            readonly property real reach: readingText.text.length > 0 ? readingText.implicitWidth / Math.max(1, readingText.text.length) : 0
            // Centred, so it reaches out on both sides alike: only when both neighbours are free, half a reading character each.
            readonly property real allowance: modelData.openBefore && modelData.openAfter ? reach : 0
            implicitWidth: Math.max(baseText.implicitWidth, modelData.reading.length > 0 ? readingText.implicitWidth - allowance : 0)
            implicitHeight: readingText.implicitHeight + baseText.implicitHeight
            width: implicitWidth
            height: implicitHeight
            Text {
                id: readingText
                // Always laid out, so every line keeps the same height in every density.
                anchors.horizontalCenter: parent.horizontalCenter
                text: piece.modelData.reading.length > 0 ? piece.modelData.reading : " "
                opacity: piece.shown ? 1 : 0
                font: ruby.readingFont
                color: ruby.readingColor
                Accessible.ignored: true
            }
            Text {
                id: baseText
                anchors.horizontalCenter: parent.horizontalCenter
                y: readingText.implicitHeight
                text: piece.modelData.text
                font: ruby.font
                color: ruby.color
                Accessible.ignored: true
            }
            // Under a word: a thin muted line on hover, the focus line on the focused word.
            Rectangle {
                readonly property bool focused: ruby.interactive && ruby.activeFocus && piece.modelData.word >= 0
                    && piece.modelData.word === ruby.focusWord
                readonly property bool hovered: ruby.interactive && piece.modelData.word >= 0
                    && piece.modelData.word === ruby.hoverWord
                visible: focused || hovered
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: focused ? 2 : 1
                color: focused ? KanteStyle.focusColor : ruby.readingColor
            }
        }
    }
}
