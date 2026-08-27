/*
 * Locale-aware date/time helpers for segmented editor fields.
 */

function pad2(n) {
    return (n < 10 ? "0" : "") + String(n)
}

/** Short date format from system locale; year always 4 digits for editing. */
function dateFormatString() {
    return String(Qt.locale().dateFormat(Locale.ShortFormat)).replace(/y+/g, "yyyy")
}

function timeFormatString() {
    return String(Qt.locale().timeFormat(Locale.ShortFormat)).replace(/:?s+/g, "").replace(/\s+$/, "")
}

function _parseFormatTokens(fmt) {
    var tokens = []
    var i = 0
    var s = String(fmt)
    while (i < s.length) {
        var c = s.charAt(i)
        if (c === "'") {
            var end = s.indexOf("'", i + 1)
            if (end < 0) {
                tokens.push({ kind: "sep", text: s.substring(i) })
                break
            }
            tokens.push({ kind: "sep", text: s.substring(i + 1, end) })
            i = end + 1
            continue
        }
        if (c === "y" || c === "M" || c === "d" || c === "H" || c === "h" || c === "m") {
            var j = i
            while (j < s.length && s.charAt(j) === c) {
                ++j
            }
            var kind = "sep"
            var maxLen = 2
            if (c === "y") {
                kind = "year"
                maxLen = 4
            } else if (c === "M") {
                kind = "month"
                maxLen = 2
            } else if (c === "d") {
                kind = "day"
                maxLen = 2
            } else if (c === "H" || c === "h") {
                kind = "hour"
                maxLen = 2
            } else if (c === "m") {
                kind = "minute"
                maxLen = 2
            }
            tokens.push({ kind: kind, text: s.substring(i, j), maxLen: maxLen })
            i = j
            continue
        }
        // skip am/pm markers as non-editable noise for digit entry
        if (c === "a" || c === "A" || c === "t" || c === "p" || c === "P") {
            var j2 = i
            while (j2 < s.length) {
                var ch2 = s.charAt(j2)
                if (ch2 === "a" || ch2 === "A" || ch2 === "t" || ch2 === "p" || ch2 === "P") {
                    ++j2
                } else {
                    break
                }
            }
            tokens.push({ kind: "ampm", text: s.substring(i, j2), maxLen: 0 })
            i = j2
            continue
        }
        var k = i
        while (k < s.length) {
            var ch = s.charAt(k)
            if ("yMdHhmatA'pP".indexOf(ch) >= 0) {
                break
            }
            ++k
        }
        tokens.push({ kind: "sep", text: s.substring(i, k) })
        i = k
    }
    return tokens
}

function dateTokens() {
    return _parseFormatTokens(dateFormatString())
}

function timeTokens() {
    return _parseFormatTokens(timeFormatString())
}

/**
 * True for a usable date from C++ QDateTime (model roles) or JS Date.
 * Qt 6 no longer documents Date.isValid; prefer getTime(), keep isValid as fallback.
 */
function isValidDate(dt) {
    if (dt === undefined || dt === null) {
        return false
    }
    if (typeof dt.isValid === "boolean") {
        return dt.isValid
    }
    if (typeof dt.getTime === "function") {
        return !isNaN(dt.getTime())
    }
    // QML date value type without Date methods: try formatting.
    try {
        return Qt.formatDate(dt, "yyyy-MM-dd").length > 0
    } catch (e) {
        return false
    }
}

function formatDate(dt) {
    if (!isValidDate(dt)) {
        return ""
    }
    return Qt.formatDate(dt, dateFormatString())
}

function formatTime(dt) {
    if (!isValidDate(dt)) {
        return ""
    }
    return Qt.formatTime(dt, timeFormatString())
}

function datePlaceholder() {
    return dateFormatString()
}

function timePlaceholder() {
    return timeFormatString()
}

function digitsOnly(str) {
    return String(str || "").replace(/\D/g, "")
}

function maxDigitsFor(tokens) {
    var n = 0
    for (var i = 0; i < tokens.length; ++i) {
        if (tokens[i].kind !== "sep" && tokens[i].kind !== "ampm") {
            n += tokens[i].maxLen
        }
    }
    return n
}

/** Rebuild text from digit stream using format tokens (auto-insert separators). */
function formatDigitsWithTokens(digits, tokens) {
    var d = String(digits || "")
    var pos = 0
    var chunks = []
    for (var i = 0; i < tokens.length; ++i) {
        var t = tokens[i]
        if (t.kind === "sep" || t.kind === "ampm") {
            chunks.push(t)
            continue
        }
        if (pos >= d.length) {
            break
        }
        var take = Math.min(t.maxLen, d.length - pos)
        chunks.push({
            kind: t.kind,
            text: d.substring(pos, pos + take),
            maxLen: t.maxLen,
            complete: take >= t.maxLen
        })
        pos += take
    }

    var out = ""
    for (var j = 0; j < chunks.length; ++j) {
        var c = chunks[j]
        if (c.kind === "sep") {
            var prev = null
            var next = null
            for (var k = j - 1; k >= 0; --k) {
                if (chunks[k].kind !== "sep" && chunks[k].kind !== "ampm") {
                    prev = chunks[k]
                    break
                }
            }
            for (var n = j + 1; n < chunks.length; ++n) {
                if (chunks[n].kind !== "sep" && chunks[n].kind !== "ampm") {
                    next = chunks[n]
                    break
                }
            }
            if (prev && next && (prev.complete || next.text.length > 0)) {
                out += c.text
            }
        } else if (c.kind !== "ampm") {
            out += c.text
        }
    }
    return out
}

function formatDateDigits(digits) {
    return formatDigitsWithTokens(digits, dateTokens())
}

function formatTimeDigits(digits) {
    return formatDigitsWithTokens(digits, timeTokens())
}

function computeSegments(text, tokens) {
    var s = String(text || "")
    var segments = []
    var cursor = 0
    for (var i = 0; i < tokens.length; ++i) {
        var t = tokens[i]
        if (t.kind === "sep") {
            if (cursor < s.length && s.substring(cursor, cursor + t.text.length) === t.text) {
                cursor += t.text.length
            }
            continue
        }
        if (t.kind === "ampm") {
            continue
        }
        var start = cursor
        var n = 0
        while (cursor < s.length && n < t.maxLen && /\d/.test(s.charAt(cursor))) {
            ++cursor
            ++n
        }
        segments.push({ kind: t.kind, start: start, end: Math.max(start, cursor), maxLen: t.maxLen })
    }
    return segments
}

function segmentAtPosition(text, tokens, pos) {
    var segments = computeSegments(text, tokens)
    if (!segments.length) {
        return null
    }
    for (var i = 0; i < segments.length; ++i) {
        var seg = segments[i]
        if (pos >= seg.start && pos < seg.end) {
            return seg
        }
        // Exactly at end of a non-empty segment: still that segment unless next starts here empty
        if (pos === seg.end && seg.end > seg.start) {
            if (i + 1 < segments.length && segments[i + 1].start === pos && segments[i + 1].end === pos) {
                return segments[i + 1]
            }
            return seg
        }
    }
    for (var j = 0; j < segments.length; ++j) {
        if (pos <= segments[j].start) {
            return segments[j]
        }
    }
    return segments[segments.length - 1]
}

function parseDate(str) {
    var s = String(str || "").trim()
    if (!s.length) {
        return null
    }
    var d = Date.fromLocaleDateString(Qt.locale(), s, dateFormatString())
    if (isValidDate(d)) {
        return d
    }
    var m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/)
    if (m) {
        var iso = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 0, 0, 0, 0)
        if (!isNaN(iso.getTime())) {
            return iso
        }
    }
    return null
}

function parseTime(str) {
    var s = String(str || "").trim()
    if (!s.length) {
        return { hours: 0, minutes: 0 }
    }
    var t = Date.fromLocaleTimeString(Qt.locale(), s, timeFormatString())
    if (isValidDate(t)) {
        return { hours: t.getHours(), minutes: t.getMinutes() }
    }
    var m = s.match(/^(\d{1,2}):(\d{2})$/)
    if (!m) {
        return null
    }
    var h = Number(m[1])
    var min = Number(m[2])
    if (h < 0 || h > 23 || min < 0 || min > 59) {
        return null
    }
    return { hours: h, minutes: min }
}

function combineDateTime(dateStr, timeStr, allDay) {
    var d = parseDate(dateStr)
    if (!d) {
        return null
    }
    if (allDay) {
        d.setHours(0, 0, 0, 0)
        return d
    }
    var t = parseTime(timeStr)
    if (!t) {
        return null
    }
    d.setHours(t.hours, t.minutes, 0, 0)
    return d
}
