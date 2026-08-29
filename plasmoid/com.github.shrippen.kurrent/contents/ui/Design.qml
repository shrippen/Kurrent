pragma Singleton
import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami
import "colors.js" as Colors

// Prose reference for these decisions: Design.md at the repository root.
// Update Design.md in the same change whenever a visual rule here changes.
//
// Spacing scale (all UI padding/gaps should pick one of these, not raw Units):
//   spaceTiny   — icon-to-label gaps, compact sidebar row padding
//   spaceSmall  — default inner padding, task rows, control rows
//   spaceMedium — panel gaps, editor form padding, section breaks
//   spaceLarge  — floating overlay inset (content around a “window”)
//
// Other rules:
// - Full editor is an overlay card inside the plasmoid, never a QQC2.Dialog/window.
// - Dim is parented to the Plasma applet container so it paints over FrameSvg chrome
//   (sidebar, panes, rounded margins). Content itself stays inside Plasma's default
//   padding — do not collapseMarginsHint. The card stays inset; in wide mode it sits
//   on the task pane, in narrow mode over the whole widget.
// - Blurred background: desktop uses StandardBackground (container wallpaper blur);
//   panel flyout uses AppletPopup StandardBackground in applyPopupBackground().
//   Off: TranslucentBackground on desktop, SolidBackground on the flyout.
// - Scrollbars: thin overlay on the RIGHT, stretch top-to-bottom of the viewport.
//   Do not use QQC2.ScrollView for multi-line fields (it steals width and misplaces the bar).
// - Wheel over the full-editor card never scrolls the list/sidebar. Wheel over a
//   description field that has a scrollbar stays in that field (even at bounds).
// - Fill-height lists/sidebars must report implicitHeight 0 (or Layout.preferredHeight 0).
//   ListView contentHeight must never become the plasmoid’s max/preferred height.
// - Desktop fullRepresentation: implicit size is the default; Layout.maximumHeight is Infinity.
// - Do not bind PlasmoidItem width/height; do not set Layout.maximumWidth Infinity on the PlasmoidItem root.
// - Project/label accents live in `colors.js` (hash) plus optional overrides on this singleton (`setColorOverrides` / `colorForKey`). Do not duplicate palettes in views.
// - TaskDelegate height comes only from implicitHeight (never height ↔ implicitHeight).
// - Density (auto/compact/comfortable) sets taskRowPad. sidebarWidthUnits (6–20) sets sidebarWidth.
// - overlayDimStep 0/1/2 maps to 0.25 / 0.40 / 0.55. reducedMotion skips spinner and hover flash.
// - Main-pane view modes (FullView header): list | kanban | swimlane | plan | heatmap | calendar.
//   Persist per sidebar view id in kurrentrc (viewModeByView). Kanban column/card min widths below.

QtObject {
    id: d

    readonly property int spaceTiny: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
    readonly property int spaceSmall: Kirigami.Units.smallSpacing
    readonly property int spaceMedium: Kirigami.Units.largeSpacing
    readonly property int spaceLarge: Kirigami.Units.largeSpacing * 2

    // Gap between sidebar and main pane (plus the 1px separator).
    readonly property int panelGap: spaceSmall

    // Padding inside lists, sidebar rows, compact editors.
    readonly property int padInner: spaceSmall

    // Padding inside the full-editor card (form + footer).
    readonly property int padEditor: spaceMedium

    // Visible frame of underlying UI around the full-editor card.
    readonly property int overlayInset: Kirigami.Units.gridUnit + spaceSmall

    readonly property int windowRadius: Math.max(4, spaceSmall + 2)
    readonly property int overlayHostRadius: Math.max(windowRadius, spaceSmall * 2)
    readonly property int inputRadius: Math.max(3, spaceTiny + 1)
    readonly property real windowBorderOpacity: 0.28

    // Overridable from main.qml / SharedSettings (not one-off tokens in views).
    property string density: "auto"
    property int sidebarWidthUnits: 10
    property int overlayDimStep: 1
    property bool reducedMotion: false
    property var projectColorOverrides: ({})
    property var labelColorOverrides: ({})

    function setColorOverrides(projects, labels) {
        projectColorOverrides = projects || {}
        labelColorOverrides = labels || {}
        Colors.setColorOverrides(projectColorOverrides, labelColorOverrides)
    }

    function colorForKey(key, kind) {
        var s = String(key)
        var map = (kind === "label") ? labelColorOverrides : projectColorOverrides
        if (map && map[s]) {
            return map[s]
        }
        return Colors.colorForKey(s, kind)
    }

    readonly property bool compactDensity: {
        if (density === "comfortable") {
            return false
        }
        if (density === "compact") {
            return true
        }
        return !(Kirigami.Settings.tabletMode
                 || Kirigami.Settings.hasTransientTouchInput
                 || Kirigami.Settings.isMobile)
    }

    readonly property int taskRowPad: compactDensity ? spaceTiny : spaceSmall
    readonly property real overlayDim: overlayDimStep <= 0 ? 0.25 : (overlayDimStep >= 2 ? 0.55 : 0.40)
    readonly property int sidebarWidth: Kirigami.Units.gridUnit * Math.max(6, Math.min(20, sidebarWidthUnits))

    readonly property int scrollBarExtent: 6
    readonly property int scrollBarPadding: 1
    readonly property int scrollGutter: scrollBarExtent + spaceSmall
    // Fallback step for Design.applyWheel (editor/fields). Task list uses Kirigami.WheelHandler.
    readonly property int wheelNotchPx: Math.max(48, Math.round(Kirigami.Units.gridUnit * 3.5))
    // 0–100; reserved for config / field helpers (task list follows Kirigami defaults).
    property int scrollSpeed: 50

    // Line box for wrapped multiline fields (Quick Add, ScrollableTextArea).
    readonly property int textLinePx: Math.max(Kirigami.Units.gridUnit,
                                               Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.45))
    // Quick Add grows with wrapped lines up to this many, then scrolls inside.
    readonly property int quickAddMaxLines: 5

    // Main-pane presentation modes (see Design.md § Hauptfläche).
    readonly property string viewModeList: "list"
    readonly property string viewModeKanban: "kanban"
    readonly property string viewModeSwimlane: "swimlane"
    readonly property string viewModePlan: "plan"
    readonly property string viewModeHeatmap: "heatmap"
    readonly property string viewModeCalendar: "calendar"

    readonly property int kanbanColumnMinWidth: Kirigami.Units.gridUnit * 14
    readonly property int kanbanCardGap: spaceSmall
    readonly property int heatmapCellSize: Math.max(Kirigami.Units.gridUnit * 2,
                                                    Math.round(Kirigami.Units.iconSizes.smallMedium))

    // Task row: reserved collapse-arrow column, then hierarchy indent, then checkbox.
    readonly property int taskCollapseCol: Kirigami.Units.iconSizes.small
    readonly property int taskIndentUnit: Math.round(Kirigami.Units.gridUnit * 1.25)

    function windowBorderColor() {
        var c = Kirigami.Theme.textColor
        return Qt.rgba(c.r, c.g, c.b, windowBorderOpacity)
    }

    function scrollBarOpacity(pressed, hovered) {
        if (pressed) {
            return 0.55
        }
        if (hovered) {
            return 0.4
        }
        return 0.28
    }

    function listNeedsScroll(flick) {
        if (!flick || flick.height <= 0) {
            return false
        }
        return flick.contentHeight > flick.height + 1
    }

    // Discrete wheel helper for fields that must consume the event (e.g. editor text).
    function applyWheel(flick, event) {
        if (!flick || !event) {
            return
        }
        var pixel = event.pixelDelta ? event.pixelDelta.y : 0
        var angle = event.angleDelta ? event.angleDelta.y : 0
        var dy = pixel !== 0 ? pixel : (angle / 120.0) * wheelNotchPx
        if (dy === 0) {
            return
        }
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - dy))
    }
}
