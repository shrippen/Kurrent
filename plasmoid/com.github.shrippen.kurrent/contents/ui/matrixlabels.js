/*
 * Column / row labels shared by the matrix views (Swimlanes, Project plan).
 *
 * Bucket keys come from the backend (see TaskLogic::matrixBucketKey):
 *   "overdue" | "later" | "unscheduled" | "YYYY-MM-DD" | "YYYY-Www" | "YYYY-MM"
 * `matrix` is the backend result (timeStart / timeEnd maps, currentTime, today).
 * `t` carries the translated fixed strings: { overdue, later, unscheduled, today, tomorrow, week }
 * where `week` is a function (number) -> string, so the strings stay in i18n() call sites.
 */

function parseIso(iso) {
    if (!iso) {
        return null
    }
    var p = String(iso).split("-")
    if (p.length < 3) {
        return null
    }
    return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10))
}

function isSpecial(key) {
    return key === "overdue" || key === "later" || key === "unscheduled"
}

function startDate(matrix, key) {
    return matrix && matrix.timeStart ? parseIso(matrix.timeStart[key]) : null
}

function endDate(matrix, key) {
    return matrix && matrix.timeEnd ? parseIso(matrix.timeEnd[key]) : null
}

function isWeekend(matrix, key, bucket) {
    if (bucket !== "day") {
        return false
    }
    var d = startDate(matrix, key)
    return !!d && (d.getDay() === 0 || d.getDay() === 6)
}

function title(matrix, key, bucket, t) {
    if (key === "overdue") return t.overdue
    if (key === "later") return t.later
    if (key === "unscheduled") return t.unscheduled
    var start = startDate(matrix, key)
    if (!start) {
        return key
    }
    if (bucket === "week") {
        return t.week(parseInt(String(key).substr(6), 10))
    }
    if (bucket === "month") {
        return Qt.locale().monthName(start.getMonth(), Locale.LongFormat)
    }
    var today = parseIso(matrix.today)
    if (today) {
        var diff = Math.round((start.getTime() - today.getTime()) / 86400000)
        if (diff === 0) return t.today
        if (diff === 1) return t.tomorrow
    }
    return Qt.locale().dayName(start.getDay(), Locale.ShortFormat) + " " + start.getDate()
}

function subtitle(matrix, key, bucket) {
    if (isSpecial(key)) {
        return ""
    }
    var start = startDate(matrix, key)
    var end = endDate(matrix, key)
    if (!start) {
        return ""
    }
    if (bucket === "week" && end) {
        var sameMonth = start.getMonth() === end.getMonth()
        var left = sameMonth ? String(start.getDate()) + "."
                             : Qt.locale().toString(start, "d. MMM")
        return left + " – " + Qt.locale().toString(end, "d. MMM")
    }
    if (bucket === "month") {
        return String(start.getFullYear())
    }
    return Qt.locale().toString(start, "d. MMM")
}

/** Long form for tooltips and the list drill-down chip. */
function fullLabel(matrix, key, bucket, t) {
    var ttl = title(matrix, key, bucket, t)
    var sub = subtitle(matrix, key, bucket)
    if (bucket === "month" || sub === "") {
        return sub !== "" && bucket === "month" ? ttl + " " + sub : ttl
    }
    return ttl + " · " + sub
}
