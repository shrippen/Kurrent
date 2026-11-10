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
// A line may also break after a hyphen, so "Anwohner-Dankeschön" is measured in its two parts.
// `metrics` is a FontMetrics in the label's font. Without a width yet the text passes through.
function fitWords(text, width, metrics) {
    var s = text === undefined || text === null ? "" : String(text)
    if (width <= 0) {
        return s
    }

    // Split keeps the whitespace runs (odd indices), so spacing stays as typed.
    var parts = s.split(/(\s+)/)
    for (var i = 0; i < parts.length; i += 2) {
        parts[i] = _fitWord(parts[i], width, metrics)
    }
    return parts.join("")
}

// One word, cut part by part at its hyphens: "Wochenplanung-Dankeschön" → "Wochenpla…-Dankeschön".
function _fitWord(word, width, metrics) {
    var pieces = word.match(/[^-]+-?|-/g) || [word]
    for (var i = 0; i < pieces.length; ++i) {
        if (metrics.advanceWidth(pieces[i]) <= width) {
            continue
        }
        var hyphen = pieces[i].endsWith("-") ? "-" : ""
        var stem = pieces[i].slice(0, pieces[i].length - hyphen.length)
        pieces[i] = metrics.elidedText(stem, Qt.ElideRight, width - metrics.advanceWidth(hyphen)) + hyphen
    }
    return pieces.join("")
}
