/*
 * Shared labels/icons for progress, status, secrecy (sidebar + row chips).
 */

function progressBandForPercent(pct) {
    var p = Number(pct)
    if (!(p >= 0)) {
        return ""
    }
    if (p <= 25) {
        return "0-25"
    }
    if (p <= 50) {
        return "26-50"
    }
    if (p <= 75) {
        return "51-75"
    }
    return "76-100"
}

function progressIconForBand(band) {
    switch (band) {
    case "0-25": return "battery-000"
    case "26-50": return "battery-040"
    case "51-75": return "battery-060"
    case "76-100": return "battery-100"
    default: return "battery-000"
    }
}

function progressIconForPercent(pct) {
    return progressIconForBand(progressBandForPercent(pct))
}

function progressLabelForPercent(pct) {
    var p = Math.round(Number(pct) || 0)
    return String(p) + "%"
}

function statusIconForValue(value) {
    switch (Number(value)) {
    case 4: return "view-task"
    case 6: return "media-playback-start"
    case 3: return "task-complete"
    case 5: return "dialog-cancel"
    default: return "task-new"
    }
}

function statusLabelForValue(value) {
    switch (Number(value)) {
    case 4: return "needs-action"
    case 6: return "in-process"
    case 3: return "completed"
    case 5: return "cancelled"
    default: return "none"
    }
}

function secrecyIconForValue(value) {
    switch (Number(value)) {
    case 1: return "lock"
    case 2: return "security-high"
    default: return "unlock"
    }
}

function secrecyLabelForValue(value) {
    switch (Number(value)) {
    case 1: return "private"
    case 2: return "confidential"
    default: return "public"
    }
}

function priorityValueForGroupKey(key) {
    switch (key) {
    case "high": return 1
    case "medium": return 5
    case "low": return 9
    default: return 0
    }
}

function statusValueForGroupKey(key) {
    var n = Number(key)
    if (n === 0 || n === 4 || n === 6 || n === 3 || n === 5) {
        return n
    }
    switch (key) {
    case "needs-action": return 4
    case "in-process": return 6
    case "completed": return 3
    case "cancelled": return 5
    default: return 0
    }
}

function secrecyValueForGroupKey(key) {
    switch (key) {
    case "private": return 1
    case "confidential": return 2
    default: return 0
    }
}

/** Icon name for a list section header (group mode + bucket key). Matches sidebar rows. */
function listSectionIcon(groupMode, sectionKey) {
    var mode = groupMode || ""
    var key = sectionKey || ""
    if (mode.length === 0 || mode === "none") {
        switch (key) {
        case "morning": return "weather-clear-am"
        case "afternoon": return "weather-clear"
        case "evening": return "weather-evening"
        case "unspecified": return "view-calendar-tasks"
        default: return ""
        }
    }
    switch (mode) {
    case "project": return "folder"
    case "label": return key === "none" ? "tag-delete" : "tag"
    case "priority": return "flag"
    case "progress": return progressIconForBand(key)
    case "status": return statusIconForValue(statusValueForGroupKey(key))
    case "secrecy": return secrecyIconForValue(secrecyValueForGroupKey(key))
    case "location": return "mark-location"
    default: return ""
    }
}

/** Tint metadata for list section icons (project/label/priority/location). */
function listSectionIconTint(groupMode, sectionKey) {
    var mode = groupMode || ""
    var key = sectionKey || ""
    if (mode === "project") {
        return { kind: "project", key: key === "inbox" ? "inbox" : key, opacity: 1 }
    }
    if (mode === "label") {
        if (key === "none") {
            return { opacity: 0.55 }
        }
        return { kind: "label", key: key, opacity: 1 }
    }
    if (mode === "priority") {
        return { priority: priorityValueForGroupKey(key), opacity: key === "none" ? 0.55 : 1 }
    }
    if (mode === "location") {
        if (key === "none") {
            return { opacity: 0.55 }
        }
        return { kind: "location", key: key, opacity: 1 }
    }
    return { opacity: 0.7 }
}
