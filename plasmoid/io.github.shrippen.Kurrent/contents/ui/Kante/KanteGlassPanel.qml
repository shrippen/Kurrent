import QtQuick
import QtQuick.Effects
import "."

/**
 * A layer over the app's content that lets it shimmer through blurred, like Plasma's
 * popups and panels. It slides in from an edge instead of pushing the layout.
 *
 * Place it as a sibling above `blurSource` (never inside it), anchor it across its
 * edge (e.g. left, right and top for `edge: Top`) and set `panelSize` or leave it to
 * the content; the size along the edge's axis comes from there. While it slides it lies
 * outside its place: clip the parent (`clip: true`), or it passes over what is next to it. Content goes in as
 * children. Closed, it is invisible and costs nothing (no blur, no copy of the source).
 *
 * Blur: a live `ShaderEffectSource` of the part of `blurSource` under the panel, through
 * `MultiEffect`; it follows the slide and both items' geometry, and redraws only when
 * something under it changes. Without a GPU
 * (Qt Quick software renderer) or without `blurSource` there is no blur; the tint is
 * denser then (`KanteStyle.glassDenseColor`) so text stays readable. The panel is
 * a rectangle: the blur cannot follow a cut corner.
 * Tint, blur radius: `KanteStyle.glassColor`, `glassDenseColor`, `glassBlur`.
 * System style: tint from the platform ground. Motion only with `KanteStyle.animate`;
 * without it the panel jumps.
 */
Item {
    id: panel

    enum Edge {
        Top,
        Bottom,
        Left,
        Right
    }

    /** The content behind the panel. Not an ancestor of the panel. */
    property Item blurSource: null
    /** The side it comes from. */
    property int edge: KanteGlassPanel.Edge.Top
    /** Shown (true) or slid out (false). */
    property bool open: false
    /** Size along the edge's axis (height for Top and Bottom, width for Left and Right); default: the content's. */
    property real panelSize: (vertical ? box.childrenRect.height : box.childrenRect.width) + 2 * padding
    /** Space between the panel's sides and its content. */
    property real padding: KanteStyle.unit(12)
    /** Colour of a 4 px bar on the inner edge; "transparent" for none. */
    property color barColor: "transparent"
    /** Screen readers hear this as the panel's name. */
    property string accessibleName: ""
    /** Off: never blur (a low-power setting). */
    property bool blurAllowed: true
    /** True on the software renderer. Writable for tests only. */
    property bool software: GraphicsInfo.api === GraphicsInfo.Software

    default property alias content: box.data

    /** 0 slid out, 1 shown. */
    property real slide: open ? 1 : 0
    /** Visible, also while moving. */
    readonly property bool shown: open || slide > 0
    /** The blur is drawn. */
    readonly property bool blurred: blurAllowed && !software && blurSource !== null && shown
    readonly property bool moving: slide !== (open ? 1 : 0)
    readonly property bool vertical: edge === KanteGlassPanel.Edge.Top || edge === KanteGlassPanel.Edge.Bottom

    visible: shown
    implicitWidth: vertical ? 0 : panelSize
    implicitHeight: vertical ? panelSize : 0
    Accessible.role: Accessible.Pane
    Accessible.name: accessibleName

    // In slowly, out quickly. By the target, not by `open`: the animation starts before a
    // binding on `open` would follow (review #158).
    Behavior on slide {
        id: slideBehavior
        NumberAnimation {
            duration: slideBehavior.targetValue > 0 ? KanteStyle.durationSlow : KanteStyle.duration
            easing.type: Easing.OutCubic
        }
    }

    // Slides along the axis of `edge`; a transform, so the caller's anchors stay.
    transform: Translate {
        readonly property real away: 1 - panel.slide
        x: panel.edge === KanteGlassPanel.Edge.Left ? -away * panel.width
         : panel.edge === KanteGlassPanel.Edge.Right ? away * panel.width : 0
        y: panel.edge === KanteGlassPanel.Edge.Top ? -away * panel.height
         : panel.edge === KanteGlassPanel.Edge.Bottom ? away * panel.height : 0
    }

    // The part of blurSource under the panel, in blurSource's coordinates. The arguments are
    // what moves it: the slide and both items' geometry. A binding on them, not a copy every
    // frame: still, the panel draws nothing (review #158: 97 frames a second while still).
    // Content moving inside blurSource shows through anyway: the copy is live.
    function underRect(slide, x, y, w, h, sx, sy, sw, sh) {
        return blurSource.mapFromItem(panel, 0, 0, w, h)
    }

    ShaderEffectSource {
        id: grab
        objectName: "glassGrab"
        visible: false
        width: panel.width
        height: panel.height
        sourceItem: panel.blurred ? panel.blurSource : null
        live: panel.blurred
        sourceRect: panel.blurred
            ? panel.underRect(panel.slide, panel.x, panel.y, panel.width, panel.height,
                              panel.blurSource.x, panel.blurSource.y, panel.blurSource.width, panel.blurSource.height)
            : Qt.rect(0, 0, 0, 0)
    }

    Loader {
        objectName: "glassBlur"
        anchors.fill: parent
        active: panel.blurred
        sourceComponent: MultiEffect {
            source: grab
            blurEnabled: true
            blur: 1.0
            blurMax: Math.max(KanteStyle.glassBlur, 2)
            autoPaddingEnabled: false
        }
    }

    // Tint over the blur; denser where there is none.
    Rectangle {
        anchors.fill: parent
        color: panel.blurred ? KanteStyle.glassColor : KanteStyle.glassDenseColor
    }

    // Line toward the content, on the edge facing the page.
    Rectangle {
        color: KanteStyle.frameColor
        readonly property real line: KanteStyle.unit(1)
        x: panel.edge === KanteGlassPanel.Edge.Right ? 0 : panel.edge === KanteGlassPanel.Edge.Left ? panel.width - line : 0
        y: panel.edge === KanteGlassPanel.Edge.Bottom ? 0 : panel.edge === KanteGlassPanel.Edge.Top ? panel.height - line : 0
        width: panel.vertical ? panel.width : line
        height: panel.vertical ? line : panel.height
    }

    // Optional accent bar along the same edge, inside the line.
    Rectangle {
        color: panel.barColor
        visible: panel.barColor.a > 0
        readonly property real bar: KanteStyle.unit(4)
        x: panel.edge === KanteGlassPanel.Edge.Right ? 0 : panel.edge === KanteGlassPanel.Edge.Left ? panel.width - bar : 0
        y: panel.edge === KanteGlassPanel.Edge.Bottom ? 0 : panel.edge === KanteGlassPanel.Edge.Top ? panel.height - bar : 0
        width: panel.vertical ? panel.width : bar
        height: panel.vertical ? bar : panel.height
    }

    Item {
        id: box
        anchors.fill: parent
        anchors.margins: panel.padding
    }
}
