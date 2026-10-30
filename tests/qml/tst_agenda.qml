import QtQuick
import QtTest
import "../../plasmoid/com.github.shrippen.kurrent/contents/ui/agenda.js" as Agenda

TestCase {
    name: "AgendaJs"

    function test_drawnStart() {
        // A block from its start, also while its top handle is dragged down (10:00 → 11:00).
        compare(Agenda.drawnStart(600, 420, 1320, 30), 600)
        compare(Agenda.drawnStart(660, 420, 1320, 30), 660)
        // Short entries at the grid's end move up: 23:45 and 23:50 on a grid to 24:00 → 23:30.
        compare(Agenda.drawnStart(1425, 420, 1440, 30), 1410)
        compare(Agenda.drawnStart(1430, 0, 1440, 30), 1410)
        // Never above the grid.
        compare(Agenda.drawnStart(300, 360, 1440, 30), 360)
    }
}
