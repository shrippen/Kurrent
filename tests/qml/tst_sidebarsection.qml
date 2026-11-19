import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../plasmoid/io.github.shrippen.Kurrent/contents/ui/components"

// One sidebar section for every filter: the "All" entry, the selected row, the click that
// picks or clears a value, and the locked filter (a layout already uses it).
Item {
    id: scene
    width: 300; height: 400

    // What a section asks of the SidebarView.
    Item {
        id: fakeSidebar
        property int separatorStrip: 5
        property bool comfortableRows: false
        property bool denseRows: false
        property bool rowHoverEnabled: true
        property bool isDragging: false
        property Item dragHost: null
        property bool showSidebarCounts: true
        property int sectionHeaderHeight: 24
        property int rowIconSize: 16
        property int rowLeftInset: 4
        property int rowVPad: 1
        property bool locked: false
        property int redistributed: 0
        function allocFor(id) { return 200 }
        function listNeedsScroll(list) { return false }
        function scrollMarginFor(list) { return 4 }
        function listContentWidth(list) { return list.width }
        function redistributeSections() { fakeSidebar.redistributed++ }
        function filterEnabled(kind) { return !locked }
        function filterDisabledReason(kind) { return "locked: " + kind }
    }

    Component {
        id: priorities
        SidebarSection {
            width: 300
            sidebar: fakeSidebar
            sectionId: "priorities"
            title: "Priorities"
            filterKind: "priority"
            items: [{ value: 1, label: "High" }, { value: 5, label: "Medium" }, { value: 9, label: "Low" }]
            keyRole: "value"
            textRole: "label"
            selection: -1
            allValue: -1
            counts: ({ "1": 2, "9": 1 })
            iconOf: function(item) { return { source: "flag", color: "red", opacity: 1 } }
            hintFor: function(item) { return "Set " + item.label }
            dropOn: function(item) { return true }
        }
    }

    Component {
        id: labels
        SidebarSection {
            width: 300
            sidebar: fakeSidebar
            sectionId: "labels"
            title: "Labels"
            filterKind: "label"
            items: ["Home", "Work"]
            keyRole: ""
            textRole: ""
            selection: ""
            allValue: ""
            counts: ({ "Work": 3 })
            iconOf: function(item) { return { source: "tag", color: "blue", opacity: 1 } }
            hintFor: function(item) { return "Add " + item }
            dropOn: function(item) { return true }
        }
    }

    Component { id: plainIcon; Kirigami.Icon { source: "tag" } }

    SignalSpy { id: chosen; signalName: "choose" }

    TestCase {
        name: "SidebarSection"
        when: windowShown

        function listOf(section) {
            return section.children.filter(c => c.headerItem !== undefined)[0]
        }

        function rowOf(section, index) {
            const list = listOf(section)
            tryVerify(() => list.itemAtIndex(index) !== null, 2000, "row " + index)
            return list.itemAtIndex(index)
        }

        function allEntry(section) {
            const list = listOf(section)
            tryVerify(() => list.headerItem !== null, 2000, "header")
            return list.headerItem.children.filter(c => c.highlighted !== undefined)[0]
        }

        function make(component, props) {
            fakeSidebar.locked = false
            const section = createTemporaryObject(component, scene, props || {})
            verify(section, "the section")
            chosen.target = section
            chosen.clear()
            return section
        }

        function test_allEntryMarkedWithoutSelection() {
            const section = make(priorities)
            compare(listOf(section).currentIndex, -1)
            verify(allEntry(section).highlighted, "All is selected")
        }

        function test_selectionMarksRow() {
            const section = make(priorities)
            section.selection = 5
            compare(listOf(section).currentIndex, 1)
            verify(!allEntry(section).highlighted, "All is not selected")
            section.selection = 9
            compare(listOf(section).currentIndex, 2)
            section.selection = -1
            compare(listOf(section).currentIndex, -1)
        }

        function test_stringSelectionMarksRow() {
            const section = make(labels, { selection: "Work" })
            compare(listOf(section).currentIndex, 1)
            verify(!allEntry(section).highlighted, "All is not selected")
            section.selection = ""
            compare(listOf(section).currentIndex, -1)
            verify(allEntry(section).highlighted, "All is selected")
        }

        function test_clickChoosesValue() {
            const section = make(priorities)
            mouseClick(rowOf(section, 1))
            compare(chosen.count, 1)
            compare(chosen.signalArguments[0][0], 5)
        }

        function test_clickOnSelectedClears() {
            const section = make(priorities, { selection: 5 })
            mouseClick(rowOf(section, 1))
            compare(chosen.count, 1)
            compare(chosen.signalArguments[0][0], -1)
        }

        function test_clickOnStringValue() {
            const section = make(labels)
            mouseClick(rowOf(section, 0))
            compare(chosen.signalArguments[0][0], "Home")
            section.selection = "Home"
            mouseClick(rowOf(section, 0))
            compare(chosen.signalArguments[1][0], "")
        }

        function test_allEntryClears() {
            const section = make(priorities, { selection: 5 })
            mouseClick(allEntry(section))
            compare(chosen.count, 1)
            compare(chosen.signalArguments[0][0], -1)
        }

        function test_lockedFilterIgnoresClicks() {
            const section = make(priorities)
            fakeSidebar.locked = true
            verify(!allEntry(section).enabled, "All is disabled")
            verify(!rowOf(section, 0).enabled, "the row is disabled")
            mouseClick(rowOf(section, 0))
            mouseClick(allEntry(section))
            compare(chosen.count, 0)
        }

        function test_contentHeightAsksForSpace() {
            fakeSidebar.redistributed = 0
            make(priorities)
            tryVerify(() => fakeSidebar.redistributed > 0, 2000, "the sidebar is asked to share the height")
        }

        // The icon of a section without a colour (progress, status, secrecy) leaves it unset.
        function test_noColourIsNoTint() {
            const icon = createTemporaryObject(plainIcon, scene)
            compare(icon.color, Qt.rgba(0, 0, 0, 0))
        }
    }
}
