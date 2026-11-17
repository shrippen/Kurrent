import QtQuick
import QtTest
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/sidebarheight.js" as SidebarHeight

TestCase {
    name: "SidebarHeightJs"

    readonly property int headerH: 20
    readonly property int rowH: 30
    // Three sections: a views list without header, two lists with header.
    readonly property var hasHeader: [false, true, true]
    // Natural heights: 3 rows, 2 rows + header, 4 rows + header.
    readonly property var naturals: [92, 82, 144]

    function sum(list) {
        return list.reduce(function (a, b) { return a + b }, 0)
    }

    function dist(available, visible) {
        return SidebarHeight.distribute(available, naturals, visible, hasHeader, headerH, rowH)
    }

    function test_naturalListHeight() {
        // 3 rows, a header and 1 px between the 4 parts.
        compare(SidebarHeight.naturalListHeight(3, true, 10, 20), 10 + 60 + 3)
        compare(SidebarHeight.naturalListHeight(3, false, 10, 20), 60 + 2)
        compare(SidebarHeight.naturalListHeight(0, false, 10, 20), 0)
        compare(SidebarHeight.naturalListHeight(0, true, 10, 20), 10)
        compare(SidebarHeight.naturalListHeight(-2, false, 10, 20), 0)
    }

    function test_floorHeight() {
        // One row below the header, plus the gap.
        compare(SidebarHeight.floorHeight(true, headerH, rowH), 51)
        compare(SidebarHeight.floorHeight(false, headerH, rowH), 31)
    }

    function test_roomToSpareGrowsEverySection() {
        // 82 px left over: 27 each, the odd pixel goes to the first section.
        var alloc = dist(400, [true, true, true])
        compare(alloc, [120, 109, 171])
        compare(sum(alloc), 400)
    }

    function test_hiddenSectionsGetNothing() {
        var alloc = dist(400, [true, false, true])
        compare(alloc[1], 0)
        compare(sum(alloc), 400)
        compare(SidebarHeight.distribute(400, naturals, [false, false, false], hasHeader, headerH, rowH), null)
    }

    function test_shortColumnPinsViewsAndSharesTheRest() {
        // Views keep their natural 92 px; projects, short by less than a row, take from labels.
        compare(dist(250, [true, true, true]), [92, 82, 76])
    }

    function test_veryShortColumnCutsToFloors() {
        // The floors (31 + 51 + 51) do not fit: the first sections give up pixels first.
        compare(dist(100, [true, true, true]), [1, 48, 51])
        compare(dist(10, [true, true, true]), [1, 1, 8])
    }

    function test_neverBelowOnePixelNorOverAvailable() {
        for (var available = 4; available <= 400; available += 7) {
            var alloc = dist(available, [true, true, true])
            for (var i = 0; i < alloc.length; ++i) {
                verify(alloc[i] >= 1, "section " + i + " at " + available)
            }
            verify(sum(alloc) <= available, "sum at " + available)
        }
    }

    function test_squeezedColumnLosesNoPixels() {
        // Floors 31 + 51 + 51 = 133; natural total 318.
        for (var available = 133; available < 318; ++available) {
            compare(sum(dist(available, [true, true, true])), available, "sum at " + available)
        }
    }
}
