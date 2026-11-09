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
 * Must agree with Qt.formatDate — a value that passes here must not throw in safeFormatDate.
 */
function isValidDate(dt) {
    if (dt === undefined || dt === null) {
        return false
    }
    if (typeof dt === "string") {
        if (!String(dt).trim().length) {
            return false
        }
    }
    if (typeof dt.isValid === "boolean" && !dt.isValid) {
        return false
    }
    if (typeof dt.getTime === "function" && isNaN(dt.getTime())) {
        return false
    }
    return isoDateKey(dt).length >= 10
}

function safeFormatDate(dt, fmt) {
    if (!isValidDate(dt)) {
        return ""
    }
    try {
        return typeof fmt === "string" ? Qt.locale().toString(dt, fmt) : Qt.formatDate(dt, fmt)
    } catch (e) {
        return ""
    }
}

function safeFormatTime(dt, fmt) {
    if (!isValidDate(dt)) {
        return ""
    }
    try {
        return Qt.formatTime(dt, fmt)
    } catch (e) {
        return ""
    }
}

/** ISO calendar day for comparisons (yyyy-MM-dd); empty when invalid. */
function isoDateKey(dt) {
    if (dt === undefined || dt === null) {
        return ""
    }
    if (typeof dt.isValid === "boolean" && !dt.isValid) {
        return ""
    }
    if (typeof dt.getTime === "function" && isNaN(dt.getTime())) {
        return ""
    }
    try {
        var key = Qt.formatDate(dt, "yyyy-MM-dd")
        if (!key || key.length < 10 || key.indexOf("Invalid") >= 0) {
            return ""
        }
        return key
    } catch (e) {
        return ""
    }
}

/**
 * Task row due chip: locale short date, optional relative Today/Tomorrow/Yesterday, optional time.
 * labels: { today, tomorrow, yesterday } — pass i18n strings from QML.
 */
function formatDueRowLabel(due, options) {
    if (!isValidDate(due)) {
        return ""
    }
    options = options || {}
    var dueDay = isoDateKey(due)
    var label = safeFormatDate(due, Qt.DefaultLocaleShortDate)
    if (options.relativeDates === true && dueDay.length) {
        var todayDate = new Date()
        var today = isoDateKey(todayDate)
        if (dueDay === today && options.today) {
            label = options.today
        } else {
            var tomorrow = new Date(todayDate)
            tomorrow.setDate(tomorrow.getDate() + 1)
            var yesterday = new Date(todayDate)
            yesterday.setDate(yesterday.getDate() - 1)
            if (dueDay === isoDateKey(tomorrow) && options.tomorrow) {
                label = options.tomorrow
            } else if (dueDay === isoDateKey(yesterday) && options.yesterday) {
                label = options.yesterday
            }
        }
    }
    if (options.showTime !== false && options.allDay !== true) {
        var timeText = safeFormatTime(due, Qt.DefaultLocaleShortDate)
        if (timeText && timeText.length) {
            label += " " + timeText
        }
    }
    return label
}

function formatDate(dt) {
    if (!isValidDate(dt)) {
        return ""
    }
    return safeFormatDate(dt, dateFormatString())
}

function formatTime(dt) {
    if (!isValidDate(dt)) {
        return ""
    }
    return safeFormatTime(dt, timeFormatString())
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

/**
 * Editor save helper: { clear: true } | { clear: false, date: Date } | null on invalid input.
 */
function resolveDateFields(dateStr, timeStr, allDay, clearRequested) {
    if (clearRequested) {
        return { clear: true }
    }
    var ds = String(dateStr || "").trim()
    if (!ds.length) {
        return { clear: true }
    }
    var combined = combineDateTime(dateStr, timeStr, allDay)
    if (!combined) {
        return null
    }
    return { clear: false, date: combined }
}

/*
 * Day labels in the locale's own order (#27). Every format is derived from the locale's long
 * (or short) date format by dropping fields, so "Thursday, October 29" stays American,
 * "Donnerstag, 29. Oktober" German and "10月29日木曜日" Japanese. Use with
 * Qt.locale().toString(date, DateTime.longDayMonthFormat()).
 *
 * A literal right after a field without whitespace or a comma belongs to that field
 * (German "d.", Japanese "M月", "d日") and goes or stays with it.
 */

function _dateFormatTokens(fmt) {
    var tokens = []
    var s = String(fmt)
    var i = 0
    while (i < s.length) {
        var c = s.charAt(i)
        if (c === "d" || c === "M" || c === "y") {
            var j = i
            while (j < s.length && s.charAt(j) === c) {
                ++j
            }
            tokens.push({ field: true, ch: c, text: s.substring(i, j) })
            i = j
            continue
        }
        var start = i
        while (i < s.length) {
            var ch = s.charAt(i)
            if (ch === "'") {
                var close = s.indexOf("'", i + 1)
                i = close < 0 ? s.length : close + 1
                continue
            }
            if (ch === "d" || ch === "M" || ch === "y") {
                break
            }
            ++i
        }
        tokens.push({ field: false, text: s.substring(start, i) })
    }
    return tokens
}

/** Leading part of a literal that sticks to the field before it ("." in ". ", "日", "('a')"). */
function _fieldSuffix(text) {
    var m = /^(?:[^\s,']|'[^']*')*/.exec(text)
    return m ? m[0] : ""
}

function _isWeekday(token) {
    return token.field && token.ch === "d" && token.text.length >= 3
}

function _isDay(token) {
    return token.field && token.ch === "d" && token.text.length <= 2
}

function _isYear(token) {
    return token.field && token.ch === "y"
}

/** Removes the first field matching `pred` and the separator that only it needed. */
function _dropField(tokens, pred) {
    var idx = -1
    for (var i = 0; i < tokens.length; ++i) {
        if (pred(tokens[i])) {
            idx = i
            break
        }
    }
    if (idx < 0) {
        return tokens
    }
    var hasPrevField = false
    var hasNextField = false
    for (var k = 0; k < tokens.length; ++k) {
        if (tokens[k].field && k < idx) {
            hasPrevField = true
        } else if (tokens[k].field && k > idx) {
            hasNextField = true
        }
    }
    var out = tokens.slice()
    var next = idx + 1 < out.length && !out[idx + 1].field ? out[idx + 1] : null
    var prev = idx > 0 && !out[idx - 1].field ? out[idx - 1] : null
    var rest = next ? next.text.substring(_fieldSuffix(next.text).length) : ""
    if (!hasPrevField) {
        rest = ""                      // leading field: its separator goes too
    } else if (!hasNextField) {
        rest = ""                      // trailing field: the separator before it goes,
        if (prev) {                    // but not what belongs to the field before
            out[idx - 1] = { field: false, text: _fieldSuffix(prev.text) }
        }
    } else if (prev && prev.text.length > 0) {
        rest = ""                      // middle: keep the separator before it
    }
    out.splice(idx, next ? 2 : 1)
    if (rest.length > 0) {
        out.splice(idx, 0, { field: false, text: rest })
    }
    return out
}

function _joinFormat(tokens, mapField) {
    var s = ""
    for (var i = 0; i < tokens.length; ++i) {
        var t = tokens[i]
        s += t.field && mapField ? mapField(t) : t.text
    }
    return s.replace(/^[\s,\/-]+/, "").replace(/[\s,\/-]+$/, "")
}

function _shortNames(t) {
    if (t.text === "dddd") {
        return "ddd"
    }
    if (t.text === "MMMM") {
        return "MMM"
    }
    return t.text
}

var _formatCache = ({})

function _cachedFormat(locale, kind, build) {
    var loc = locale || Qt.locale()
    var key = loc.name + "|" + kind
    if (_formatCache[key] === undefined) {
        _formatCache[key] = build(loc)
    }
    return _formatCache[key]
}

function _longTokens(locale) {
    return _dateFormatTokens(locale.dateFormat(Locale.LongFormat))
}

/** "dddd, d. MMMM yyyy" in German: the locale's long date format. */
function longDateFormat(locale) {
    return _cachedFormat(locale, "longDate", function (loc) {
        return loc.dateFormat(Locale.LongFormat)
    })
}

/** Weekday, day and month, no year: "Donnerstag, 29. Oktober", "Thursday, October 29". */
function longDayMonthFormat(locale) {
    return _cachedFormat(locale, "longDayMonth", function (loc) {
        return _joinFormat(_dropField(_longTokens(loc), _isYear))
    })
}

/** Short weekday and month names: "Do., 29. Okt.", "Thu, Oct 29". */
function shortDayMonthFormat(locale) {
    return _cachedFormat(locale, "shortDayMonth", function (loc) {
        return _joinFormat(_dropField(_longTokens(loc), _isYear), _shortNames)
    })
}

/** Day and short month: "29. Okt.", "Oct 29". */
function dayMonthFormat(locale) {
    return _cachedFormat(locale, "dayMonth", function (loc) {
        return _joinFormat(_dropField(_dropField(_longTokens(loc), _isYear), _isWeekday), _shortNames)
    })
}

/** Day, short month and year: "29. Okt. 2026", "Oct 29, 2026". */
function dayMonthYearFormat(locale) {
    return _cachedFormat(locale, "dayMonthYear", function (loc) {
        return _joinFormat(_dropField(_longTokens(loc), _isWeekday), _shortNames)
    })
}

/** Month and year: "Oktober 2026", "2026年10月"; `shortMonth` for "Okt. 2026". */
function monthYearFormat(locale, shortMonth) {
    return _cachedFormat(locale, shortMonth ? "monthYearShort" : "monthYear", function (loc) {
        var tokens = _dropField(_dropField(_longTokens(loc), _isWeekday), _isDay)
        return _joinFormat(tokens, shortMonth ? _shortNames : null)
    })
}

/** Numeric day and month from the short date format: "29.10.", "10/29", "10/29". */
function numericDayMonthFormat(locale) {
    return _cachedFormat(locale, "numericDayMonth", function (loc) {
        var tokens = _dropField(_dateFormatTokens(loc.dateFormat(Locale.ShortFormat)), _isYear)
        return _joinFormat(tokens, function (t) {
            return t.text === "dd" ? "d" : (t.text === "MM" ? "M" : t.text)
        })
    })
}

/**
 * Format for the start of a day range within one month: only the day where the day comes
 * before the month ("2." for "2. – 8. Nov.", "2" in en_GB), else the full day and month
 * ("Nov 2 – Nov 8").
 */
function rangeStartFormat(locale) {
    return _cachedFormat(locale, "rangeStart", function (loc) {
        var tokens = _dateFormatTokens(dayMonthFormat(loc))
        var day = -1
        var month = -1
        for (var i = 0; i < tokens.length; ++i) {
            if (_isDay(tokens[i]) && day < 0) {
                day = i
            } else if (tokens[i].field && tokens[i].ch === "M" && month < 0) {
                month = i
            }
        }
        if (day < 0 || month < 0 || day > month) {
            return dayMonthFormat(loc)
        }
        return _joinFormat(_dropField(tokens, function (t) { return t.field && t.ch === "M" }))
    })
}

/** Short weekday before the numeric date: "Do. 29.10.", "Thu 10/29". */
function weekdayNumericFormat(locale) {
    return "ddd " + numericDayMonthFormat(locale)
}
