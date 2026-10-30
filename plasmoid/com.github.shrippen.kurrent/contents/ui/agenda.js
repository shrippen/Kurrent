/*
 * Agenda day grid drawing helpers; importable from qmltestrunner.
 */

// Top of an entry drawn at least minShown long: its start, moved up at the grid's end so it
// stays inside (AgendaLogic::kMinShown, as the lanes in TaskController::agendaDays), never above
// the grid. Follows a live start while a handle is dragged.
function drawnStart(start, gridStart, gridEnd, minShown) {
    return Math.max(gridStart, Math.min(start, gridEnd - minShown))
}
