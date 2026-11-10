.pragma library

// Whether `item` (usually Window.activeFocusItem) is `scope` or inside it. On the desktop Kurrent
// shares its window with the folder view and other widgets; keys of its own only count then.
function inside(item, scope) {
    if (!scope) {
        return false
    }
    for (var it = item; it; it = it.parent) {
        if (it === scope) {
            return true
        }
    }
    return false
}
