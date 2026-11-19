.pragma library

// The recurrence choice of the task editor: the position in its combo box and the
// preset name the controller takes. Position 0 is "none".

function indexFor(preset) {
    switch (String(preset)) {
    case "daily":
        return 1
    case "weekly":
        return 2
    case "monthly":
        return 3
    case "yearly":
        return 4
    default:
        return 0
    }
}

function valueFor(index) {
    switch (index) {
    case 1:
        return "daily"
    case 2:
        return "weekly"
    case 3:
        return "monthly"
    case 4:
        return "yearly"
    default:
        return "none"
    }
}
