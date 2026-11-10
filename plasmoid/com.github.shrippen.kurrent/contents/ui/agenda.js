/*
 * Agenda day grid drawing helpers; importable from qmltestrunner.
 */

// Top of an entry drawn at least minShown long: its start, moved up at the grid's end so it
// stays inside (AgendaLogic::kMinShown, as the lanes in TaskController::agendaDays), never above
// the grid. Follows a live start while a handle is dragged.
function drawnStart(start, gridStart, gridEnd, minShown) {
    return Math.max(gridStart, Math.min(start, gridEnd - minShown))
}

// What a task drag carries to the drop targets (dragHost.draggingTask).
function dragPayload(task) {
    return {
        "itemId": task.itemId,
        "uid": task.uid,
        "summary": task.summary || "",
        "parentUid": task.parentUid || "",
        "categories": task.categories || [],
        "collectionId": task.collectionId,
        "priority": task.priority,
        "recurring": !!task.recurring
    }
}

// Title for a narrow column (wrapMode WordWrap): each word wider than `width` is cut with "…",
// so lines break only between words ("Wochenplanung" → "Wochenpla…", not "Wochenplanun/g").
// A line may also break inside a word (after a hyphen, see _fitWord), so "Anwohner-Dankeschön"
// is measured in its two parts.
// `metrics` is a FontMetrics in the label's font. Without a width yet the text passes through.
function fitWords(text, width, metrics) {
    var s = text === undefined || text === null ? "" : String(text)
    if (width <= 0) {
        return s
    }

    // Split keeps the whitespace runs (odd indices), so spacing stays as typed.
    // A no-break space (U+00A0) joins words, so it is no split point.
    var parts = s.split(/([ \t\n\r]+)/)
    for (var i = 0; i < parts.length; i += 2) {
        parts[i] = _fitWord(parts[i], width, metrics)
    }
    return parts.join("")
}

// One word, cut part by part where Qt may break a line inside it: after "-", "/", "–" or "—"
// before a letter ("Wochenplanung-Dankeschön" → "Wochenpla…-Dankeschön"); "2026-11-10" and
// 'Mail-"News"' stay one part. Runs of a script Qt breaks anywhere are left to Qt.
function _fitWord(word, width, metrics) {
    var pieces = _breakPieces(word)
    for (var i = 0; i < pieces.length; ++i) {
        pieces[i] = _fitPiece(pieces[i], width, metrics)
    }
    return pieces.join("")
}

// "会议Wochenplanungsbesprechung": Qt breaks after "会议", so only the Latin run is measured.
function _fitPiece(piece, width, metrics) {
    var runs = _scriptRuns(piece)
    for (var i = 0; i < runs.length; ++i) {
        var run = runs[i]
        if (_breaksAnywhere(run.charCodeAt(0)) || metrics.advanceWidth(run) <= width) {
            continue
        }
        var mark = _BREAK_MARKS.indexOf(run.slice(-1)) >= 0 ? run.slice(-1) : ""
        var stem = run.slice(0, run.length - mark.length)
        runs[i] = metrics.elidedText(stem, Qt.ElideRight, width - metrics.advanceWidth(mark)) + mark
    }
    return runs.join("")
}

var _BREAK_MARKS = "-/–—"

// Scripts Qt 6 breaks between any two characters (checked with WordWrap): Thai, Myanmar,
// CJK with kana, fullwidth forms. Not Lao, Khmer or Hangul: Korean words are cut like Latin.
var _BREAK_ANYWHERE = [[0x0E00, 0x0E7F], [0x1000, 0x109F], [0x2E80, 0x9FFF], [0xF900, 0xFAFF],
                       [0xFF00, 0xFFEF]]

function _breaksAnywhere(code) {
    for (var r = 0; r < _BREAK_ANYWHERE.length; ++r) {
        if (code >= _BREAK_ANYWHERE[r][0] && code <= _BREAK_ANYWHERE[r][1]) {
            return true
        }
    }
    return false
}

// Split into runs inside and outside the break-anywhere scripts: "会议Wo" → ["会议", "Wo"].
function _scriptRuns(piece) {
    var runs = []
    for (var i = 0; i < piece.length; ++i) {
        var anywhere = _breaksAnywhere(piece.charCodeAt(i))
        if (runs.length && _breaksAnywhere(runs[runs.length - 1].charCodeAt(0)) === anywhere) {
            runs[runs.length - 1] += piece.charAt(i)
            continue
        }
        runs.push(piece.charAt(i))
    }
    return runs
}

// A letter in a cased script (QML's JS has no \p{L}).
function _isLetter(ch) {
    return ch !== undefined && ch.toLowerCase() !== ch.toUpperCase()
}

function _breakPieces(word) {
    var pieces = []
    var from = 0
    for (var i = 0; i + 1 < word.length; ++i) {
        if (_BREAK_MARKS.indexOf(word.charAt(i)) < 0 || !_isLetter(word.charAt(i + 1))) {
            continue
        }
        pieces.push(word.slice(from, i + 1))
        from = i + 1
    }
    pieces.push(word.slice(from))
    return pieces
}
