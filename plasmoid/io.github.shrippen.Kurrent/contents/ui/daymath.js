.pragma library

// Small day and clock helpers for the agenda and the heatmap. Apart from datetime.js, which
// formats and parses dates for the input fields and is at its size limit.

/** Minutes since midnight as "HH:mm", 24 hours: 545 -> "09:05". */
function clockOfMinute(minute) {
    return String(Math.floor(minute / 60)).padStart(2, "0") + ":" + String(minute % 60).padStart(2, "0")
}

/** Today at local midnight. */
function today() {
    var now = new Date()
    return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

/** Local midnight of d, n calendar days later (n may be negative); d is not changed. */
function addDays(d, n) {
    var r = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    r.setDate(r.getDate() + n)
    return r
}
