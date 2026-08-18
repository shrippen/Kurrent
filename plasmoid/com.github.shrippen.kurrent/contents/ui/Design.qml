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

    // Apply a wheel event to a Flickable and keep it inside bounds.
    // Returns true if the view can scroll (caller should still accept the event
    // when a nested scroller is hovered so parents do not steal the wheel).
    function applyWheel(flick, event) {
        if (!flick) {
            return false
        }
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        if (maxY <= 0) {
            return false
        }
        var dy = event.pixelDelta && event.pixelDelta.y !== 0
                ? event.pixelDelta.y
                : event.angleDelta.y / 8
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - dy))
        return true
    }
}
