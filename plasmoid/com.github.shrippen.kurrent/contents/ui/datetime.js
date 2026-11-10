/*
 * Locale-aware date/time helpers for segmented editor fields.
 */

// QLocale::FormatType as numbers: the Locale enum is not defined when this file is reached
// through another script's .import (matrixlabels.js), only in a QML component's context.
var LONG_FORMAT = 0
var SHORT_FORMAT = 1

function pad2(n) {
    return (n < 10 ? "0" : "") + String(n)
}

/** Short date format from system locale; year always 4 digits for editing. */
/*
 * The input fields mask digits per field with a fixed width, so every field gets its full
 * width: "M/d/yy" (en_US) becomes "MM/dd/yyyy" and "h:mm AP" becomes "hh:mm AP". With a
 * one-digit field, "11/7/2026" was re-split as "11/72/026" and could not be saved.
 * Quoted literals stay untouched.
 */
function _padSingleFields(fmt, letters) {
    var parts = String(fmt).split("'")
    for (var i = 0; i < parts.length; i += 2) {
        parts[i] = parts[i].replace(new RegExp("(^|[^" + letters + "])([" + letters + "])(?![" + letters + "])", "g"),
                                    function (m, before, ch) { return before + ch + ch })
    }
    return parts.join("'")
}

function _shortDateFormat(locale) {
    return String((locale || Qt.locale()).dateFormat(SHORT_FORMAT)).replace(/y+/g, "yyyy")
}

/** Format of the date input fields (and of parsing what they hold): every field full width. */
function dateFormatString(locale) {
    return _padSingleFields(_padSingleFields(_shortDateFormat(locale), "M"), "d")
}

/*
 * Format of the time input fields: always 24 hours. The digit mask cannot carry AM/PM, so a
 * 12-hour format ("h:mm AP") lost the marker and 9:05 PM came back as 09:05 in the morning.
 */
function timeFormatString(locale) {
    var parts = String((locale || Qt.locale()).timeFormat(SHORT_FORMAT)).split("'")
    for (var i = 0; i < parts.length; i += 2) {
        parts[i] = parts[i].replace(/:?s+/g, "").replace(/\s*(?:[Aa][Pp]|[Aa])\s*/g, "").replace(/h/g, "H")
    }
    // A literal that only belonged to the AM/PM marker (Korean "AP h:mm") goes with it.
    var fmt = parts.join("'").replace(/^(?:'[^']*')+(?=H)/, "").trim()
    return _padSingleFields(_padSingleFields(fmt, "H"), "m")
}

/** A date for display, in the locale's own short form (one-digit fields stay one digit). */
function displayDate(dt) {
    if (!isValidDate(dt)) {
        return ""
    }
    return safeFormatDate(dt, _shortDateFormat())
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

function dateTokens(locale) {
    return _parseFormatTokens(dateFormatString(locale))
}

function timeTokens(locale) {
    return _parseFormatTokens(timeFormatString(locale))
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

/*
 * Input fields hold ASCII digits in the locale's field order, exactly as the digit mask writes
 * them: fa_IR "2026/11/07", not "۲۰۲۶/۱۱/۰۷" (the mask kept no native digit), ko_KR
 * "2026. 11. 07" (the mask writes no literal after the last field).
 */
function _fieldDigits(tokens, values) {
    var digits = ""
    for (var i = 0; i < tokens.length; ++i) {
        var v = values[tokens[i].kind]
        if (v === undefined) {
            continue
        }
        var text = String(v)
        while (text.length < tokens[i].maxLen) {
            text = "0" + text
        }
        digits += text
    }
    return digits
}

function formatDate(dt, locale) {
    if (!isValidDate(dt)) {
        return ""
    }
    var tokens = dateTokens(locale)
    var values = { year: dt.getFullYear(), month: dt.getMonth() + 1, day: dt.getDate() }
    return formatDigitsWithTokens(_fieldDigits(tokens, values), tokens)
}

function formatTime(dt, locale) {
    if (!isValidDate(dt)) {
        return ""
    }
    var tokens = timeTokens(locale)
    return formatDigitsWithTokens(_fieldDigits(tokens, { hour: dt.getHours(), minute: dt.getMinutes() }), tokens)
}

function datePlaceholder() {
    return dateFormatString()
}

function timePlaceholder() {
    return timeFormatString()
}

// Zero of each Unicode decimal digit block a locale may write or a keyboard may type
// (Arabic-Indic, Persian, Devanagari, Bengali, …, Thai, Tibetan, Myanmar, fullwidth).
var _NATIVE_ZEROS = [0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, 0x0BE6,
                     0x0C66, 0x0CE6, 0x0D66, 0x0DE6, 0x0E50, 0x0ED0, 0x0F20, 0x1040, 0x1090,
                     0x17E0, 0x1810, 0x1946, 0x19D0, 0x1A80, 0x1A90, 0x1B50, 0x1BB0, 0x1C40,
                     0x1C50, 0xA620, 0xA8D0, 0xA900, 0xA9D0, 0xA9F0, 0xAA50, 0xABF0, 0xFF10]

/** Native digits as ASCII: "۲۰۲۶" → "2026"; everything else stays. */
function asciiDigits(str) {
    return String(str || "").replace(/[^\x00-\x7F]/g, function (ch) {
        var code = ch.charCodeAt(0)
        for (var i = 0; i < _NATIVE_ZEROS.length; ++i) {
            if (code >= _NATIVE_ZEROS[i] && code <= _NATIVE_ZEROS[i] + 9) {
                return String(code - _NATIVE_ZEROS[i])
            }
        }
        return ch
    })
}

function digitsOnly(str) {
    return asciiDigits(str).replace(/\D/g, "")
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

/*
 * Field values of an input text by the format's field order: { year: "2026", month: "11", … }.
 * Reads the digits, not the literals, so a missing trailing "." (ko_KR) or leading "Kl. "
 * (nds_DE) does not matter.
 */
function _readFields(s, tokens) {
    var fields = {}
    var segments = computeSegments(s, tokens)
    for (var i = 0; i < segments.length; ++i) {
        var seg = segments[i]
        if (seg.end > seg.start) {
            fields[seg.kind] = s.substring(seg.start, seg.end)
        }
    }
    return fields
}

function _dateFromFields(f) {
    if (!f.year || f.year.length !== 4 || !f.month || !f.day) {
        return null
    }
    var y = Number(f.year)
    var m = Number(f.month)
    var day = Number(f.day)
    var d = new Date(y, m - 1, day, 0, 0, 0, 0)
    // 31.02. rolls over into March: no such day.
    if (d.getFullYear() !== y || d.getMonth() !== m - 1 || d.getDate() !== day) {
        return null
    }
    return d
}

function parseDate(str, locale) {
    var s = asciiDigits(str).trim()
    if (!s.length) {
        return null
    }
    var d = _dateFromFields(_readFields(s, dateTokens(locale)))
    if (d) {
        return d
    }
    // ISO input in any locale, range-checked like the fields (2026-02-31 is no date).
    var m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/)
    if (!m) {
        return null
    }
    return _dateFromFields({ year: m[1], month: m[2], day: m[3] })
}

function parseTime(str, locale) {
    var s = asciiDigits(str).trim()
    if (!s.length) {
        return { hours: 0, minutes: 0 }
    }
    var f = _readFields(s, timeTokens(locale))
    var m = f.hour && f.minute && f.minute.length === 2 ? [s, f.hour, f.minute] : s.match(/^(\d{1,2}):(\d{2})$/)
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

function combineDateTime(dateStr, timeStr, allDay, locale) {
    var d = parseDate(dateStr, locale)
    if (!d) {
        return null
    }
    if (allDay) {
        d.setHours(0, 0, 0, 0)
        return d
    }
    var t = parseTime(timeStr, locale)
    if (!t) {
        return null
    }
    d.setHours(t.hours, t.minutes, 0, 0)
    return d
}

/**
 * Editor save helper: { clear: true } | { clear: false, date: Date } | null on invalid input.
 */
function resolveDateFields(dateStr, timeStr, allDay, clearRequested, locale) {
    if (clearRequested) {
        return { clear: true }
    }
    var ds = String(dateStr || "").trim()
    if (!ds.length) {
        return { clear: true }
    }
    var combined = combineDateTime(dateStr, timeStr, allDay, locale)
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
            // Up to a comma it is the field's ("d 'd'., dddd" in lt), else only what sticks
            // to it ("d日"; the "de" before a Spanish year goes with the year).
            var comma = prev.text.lastIndexOf(",")
            var keep = comma > 0 ? prev.text.substring(0, comma) : _fieldSuffix(prev.text)
            out[idx - 1] = { field: false, text: keep }
        }
    } else if (prev && prev.text.length > 0) {
        // middle: keep the separator before it, unless only the one after separates the
        // weekday ("d MMMM yyyy, dddd" in az keeps its comma without the year)
        var nextField = null
        for (var n = idx + 1; n < tokens.length; ++n) {
            if (tokens[n].field) {
                nextField = tokens[n]
                break
            }
        }
        if (rest.indexOf(",") >= 0 && prev.text.indexOf(",") < 0 && nextField && _isWeekday(nextField)) {
            out[idx - 1] = { field: false, text: rest }
        }
        rest = ""
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
    return _dateFormatTokens(locale.dateFormat(LONG_FORMAT))
}

/** "dddd, d. MMMM yyyy" in German: the locale's long date format. */
function longDateFormat(locale) {
    return _cachedFormat(locale, "longDate", function (loc) {
        return loc.dateFormat(LONG_FORMAT)
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
        var tokens = _dropField(_dateFormatTokens(loc.dateFormat(SHORT_FORMAT)), _isYear)
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

/** True where the long date names the weekday after the day (hu, ja, ko, tr, az). */
function _weekdayLast(locale) {
    var tokens = _longTokens(locale)
    var weekday = -1
    var day = -1
    for (var i = 0; i < tokens.length; ++i) {
        if (_isWeekday(tokens[i]) && weekday < 0) {
            weekday = i
        } else if (_isDay(tokens[i]) && day < 0) {
            day = i
        }
    }
    return weekday >= 0 && day >= 0 && weekday > day
}

/** Short weekday and the numeric date, in the locale's order: "Do. 29.10.", "Thu 10/29", "10/29 木". */
function weekdayNumericFormat(locale) {
    return _cachedFormat(locale, "weekdayNumeric", function (loc) {
        var numeric = numericDayMonthFormat(loc)
        return _weekdayLast(loc) ? numeric + " ddd" : "ddd " + numeric
    })
}

function _unquote(text) {
    // '…' quotes a literal; '' inside or outside a quote is one apostrophe ("'o''clock'").
    return String(text).replace(/'((?:[^']|'')*)'/g, function (m, inner) {
        return inner.length ? inner.replace(/''/g, "'") : "'"
    })
}

/**
 * Month and year as a heading: like monthYearFormat, but with the month's standalone name
 * (nominative) where the language inflects it: Russian "октябрь 2026 г.", not the "октября"
 * a date uses. Elsewhere, and where a suffix is glued to the month (bo, mn), the format's own
 * name stays (German "Okt. 2026" keeps its period).
 */
function monthYearLabel(date, shortMonth, locale) {
    var loc = locale || Qt.locale()
    if (!date || isNaN(date.getTime())) {
        return ""
    }
    var tokens = _dateFormatTokens(monthYearFormat(loc, shortMonth))
    var out = ""
    for (var i = 0; i < tokens.length; ++i) {
        var t = tokens[i]
        var glued = i + 1 < tokens.length && !tokens[i + 1].field && /^[^\s,]/.test(tokens[i + 1].text)
        var month = date.getMonth()
        var inflects = loc.standaloneMonthName(month, LONG_FORMAT) !== loc.monthName(month, LONG_FORMAT)
        if (t.field && t.ch === "M" && t.text.length >= 3 && inflects && !glued) {
            out += loc.standaloneMonthName(month, t.text.length >= 4 ? LONG_FORMAT : SHORT_FORMAT)
        } else if (t.field) {
            out += loc.toString(date, t.text)
        } else {
            out += _unquote(t.text)
        }
    }
    return out
}
