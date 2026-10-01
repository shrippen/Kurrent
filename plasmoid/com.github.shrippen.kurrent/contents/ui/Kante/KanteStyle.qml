pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami

/**
 * Colors, fonts and shapes of a Kante app. Views read them here instead of
 * Kirigami.Theme, so the style is switched in one place.
 *
 *   KanteStyle.Kind.System      the platform theme (Kirigami.Theme), unchanged
 *   KanteStyle.Kind.Kante       Kante: Gruvbox dark or "Leinen" light (follows
 *                               the platform theme's brightness), Rajdhani
 *                               titles, JetBrains Mono figures, top-right cut
 *                               corners, square controls. Surfaces are tints:
 *                               a translucent or blurred platform ground shows
 *                               through.
 *   KanteStyle.Kind.KanteLight  Kante shapes on the platform theme: every color
 *                               is Kirigami.Theme (live, follows any color
 *                               scheme), controls stay the platform's. Kante
 *                               adds cut corners and accent bars on cards,
 *                               Rajdhani titles, JetBrains Mono figures and
 *                               section labels, and the Kante layouts.
 *
 *   active  Kante or Kante Light: shapes, type, layouts
 *   themed  Kante only: own palette, own control skins
 *
 * The app binds `kind` (e.g. from a "Style" setting). In the System kind
 * every role forwards Kirigami.Theme, so a view written against KanteStyle
 * looks exactly like a plain Kirigami view.
 *
 * Reference implementation: Plasmai (Plasma widget + Kirigami app).
 */
QtObject {
    id: root

    enum Kind {
        System,
        Kante,
        KanteLight
    }

    property int kind: KanteStyle.Kind.System
    /** Kante shapes, type and layouts (Kante and Kante Light). */
    readonly property bool active: kind !== KanteStyle.Kind.System
    /** Kante's own palette and control skins (Kante only). */
    readonly property bool themed: kind === KanteStyle.Kind.Kante

    /** Force the dark palette (e.g. an Android app that always runs Material Dark). */
    property bool preferDark: false

    /**
     * The app runs the Material style (Android). Kirigami then derives its
     * colors from the Material attached properties, so the app hands Kante's
     * colors to those (on its window) and KanteScope leaves Kirigami.Theme
     * alone: Kirigami's Material bridge would write Material.theme Light and
     * fixed colors onto every item whose Kirigami colors change, which cannot
     * be undone when Kante is switched off.
     */
    property bool materialStyle: false

    /** Leinen when the platform theme is light, unless preferDark. */
    readonly property bool light: !preferDark && Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property QtObject palette: light ? KantePalette.light : KantePalette.dark

    // ── Theme roles (palette only in Kante; Kante Light keeps the theme) ──
    readonly property color textColor: themed ? palette.text : Kirigami.Theme.textColor
    readonly property color disabledTextColor: themed ? palette.disabledText : Kirigami.Theme.disabledTextColor
    readonly property color backgroundColor: themed ? palette.ground : Kirigami.Theme.backgroundColor
    readonly property color highlightColor: themed ? palette.accent : Kirigami.Theme.highlightColor
    readonly property color positiveTextColor: themed ? palette.positive : Kirigami.Theme.positiveTextColor
    readonly property color neutralTextColor: themed ? palette.neutral : Kirigami.Theme.neutralTextColor
    readonly property color negativeTextColor: themed ? palette.negative : Kirigami.Theme.negativeTextColor

    readonly property font defaultFont: Kirigami.Theme.defaultFont
    readonly property font smallFont: Kirigami.Theme.smallFont

    // ── Surfaces (System values match a plain Kirigami look) ─────────────
    readonly property color strongTextColor: themed ? palette.strongText : Kirigami.Theme.textColor
    readonly property color mutedTextColor: themed ? palette.mutedText : tint(Kirigami.Theme.textColor, 0.75)
    /** Fill of primary buttons and accent bars; accent-colored text uses accentTextColor. */
    readonly property color accentColor: themed ? palette.accent : Kirigami.Theme.highlightColor
    readonly property color accentTextColor: themed ? palette.accentText : readable(Kirigami.Theme.highlightColor, Kirigami.Theme.backgroundColor)
    readonly property color accentForegroundColor: themed ? palette.accentForeground : Kirigami.Theme.highlightedTextColor
    readonly property color infoColor: themed ? palette.info : Kirigami.Theme.linkColor
    /** Tags, topics, categories (purple in Kante; the visited-link colour of the platform otherwise). */
    readonly property color tagColor: themed ? palette.tag : Kirigami.Theme.visitedLinkColor
    // Warnings below "neutral" (e.g. stale dates, dead links); the platform has no own role, so neutral.
    readonly property color warningColor: themed ? palette.warning : Kirigami.Theme.neutralTextColor
    /** Focus ring, brackets, data lines (cyan; the platform's focus color otherwise). */
    readonly property color focusColor: themed ? palette.focus : Kirigami.Theme.focusColor
    /** Ground of a selected row or a focused field (cyan-tint; a tint of the highlight otherwise). */
    readonly property color selectionColor: themed ? palette.selection : tint(Kirigami.Theme.highlightColor, 0.16)
    /** Primary fill on hover (one step lighter) and pressed. */
    readonly property color accentHoverColor: themed ? palette.accentHover : Qt.lighter(Kirigami.Theme.highlightColor, 1.12)
    readonly property color accentPressedColor: themed ? palette.accentPressed : Qt.darker(Kirigami.Theme.highlightColor, 1.12)
    /** The dim behind a modal dialog. */
    readonly property color scrimColor: themed ? palette.scrim : tint(Kirigami.Theme.textColor, 0.5)
    // Tint steps for hover, drop targets, selection and outlines: translucent, so any ground shows through.
    readonly property color tint1Color: tint(textColor, 0.08)
    readonly property color tint2Color: tint(textColor, 0.16)
    readonly property color tintHighlightColor: tint(focusColor, 0.12)
    readonly property color tintHighlight2Color: tint(focusColor, 0.25)
    readonly property color tintWarnColor: tint(warningColor, 0.14)
    /** Series colours of charts, in this order (cyan, yellow, purple, aqua, orange, grey); red stays danger. */
    function dataColor(i) {
        // Second series: the text-safe yellow (Leinen: ochre); off Kante the highlight is
        // the first colour, so yellow would repeat it.
        var colors = themed
            ? [focusColor, accentTextColor, tagColor, positiveTextColor, warningColor, disabledTextColor]
            : [focusColor, warningColor, tagColor, positiveTextColor, disabledTextColor, accentTextColor]
        return colors[((i % colors.length) + colors.length) % colors.length]
    }
    // Map and entity roles, as on the web (--map-marker, --map-route, --entity-fallback).
    /** Pins and markers on a map (cyan). */
    readonly property color mapMarkerColor: focusColor
    /** A route or track on a map (yellow; the platform highlight otherwise). */
    readonly property color mapRouteColor: accentColor
    /** An entity (customer, project, tag) without a colour of its own. */
    readonly property color entityFallbackColor: disabledTextColor
    // Day roles (KanteDayStrip): daylight is a warm tint, the work band a quiet bar.
    readonly property color daylightColor: tint(accentColor, light ? 0.22 : 0.13)
    readonly property color sunColor: accentColor
    readonly property color moonColor: mutedTextColor
    readonly property color workBandColor: mutedTextColor
    /** Text on a filled state color (danger button, counter). */
    readonly property color onStateColor: themed ? palette.onState : Kirigami.Theme.highlightedTextColor
    readonly property color cardColor: themed ? palette.card : tint(Kirigami.Theme.textColor, 0.04)
    readonly property color sunkenColor: themed ? palette.sunken : tint(Kirigami.Theme.textColor, 0.06)
    readonly property color frameColor: themed ? palette.frame : tint(Kirigami.Theme.textColor, 0.12)
    readonly property color ruleColor: themed ? palette.rule : tint(Kirigami.Theme.textColor, 0.12)
    readonly property color dialogColor: themed ? palette.dialog : Kirigami.Theme.backgroundColor

    /** Top-right corner cut of cards (px), scaled with the grid unit; 0 in System. */
    readonly property int chamfer: active ? Math.round(KantePalette.chamfer * Kirigami.Units.gridUnit / 18) : 0
    readonly property int chamferSmall: active ? Math.round(KantePalette.chamferSmall * Kirigami.Units.gridUnit / 18) : 0

    /** A size in px of the web tokens (--h-*, --cut-*), scaled with the grid unit. */
    function unit(px) {
        return Math.round(px * Kirigami.Units.gridUnit / 18)
    }
    /**
     * Where a popup of `w` × `h` next to `anchor` fits in the window, in `anchor`'s
     * coordinates: {x, y, above, room}. It opens below, or above when there is no room
     * below and more above; `above` true or false forces the side (undefined: choose).
     * x shifts so the popup stays inside the window; `room` is the height free on the
     * chosen side (a list popup caps its height to it), y already uses min(h, room).
     *   field at the right edge   popup shifted left, right edges flush with the window
     *   field at the bottom       popup above the field
     */
    function popupPlace(anchor, w, h, above) {
        var gap = unit(2)
        var margin = unit(4)
        var top = anchor
        while (top.parent) {
            top = top.parent
        }
        var p = anchor.mapToItem(top, 0, 0)
        var roomBelow = top.height - p.y - anchor.height - gap - margin
        var roomAbove = p.y - gap - margin
        var up = above === true || above === false ? above : (h > roomBelow && roomAbove > roomBelow)
        var room = Math.max(0, up ? roomAbove : roomBelow)
        var x = Math.max(margin - p.x, Math.min(0, top.width - margin - w - p.x))
        var y = up ? -Math.min(h, room) - gap : anchor.height + gap
        return { x: x, y: y, above: up, room: room }
    }

    /** Control heights: 32 / 40 / 48 px at a grid unit of 18. */
    readonly property int heightSmall: unit(KantePalette.heightSmall)
    readonly property int heightMedium: unit(KantePalette.heightMedium)
    readonly property int heightLarge: unit(KantePalette.heightLarge)
    /** Smallest cut (stickers, small buttons); 0 in System. */
    readonly property int cutSmall: active ? unit(KantePalette.cutSmall) : 0

    // ── Motion ───────────────────────────────────────────────────────────
    // Warm and mechanical, never glitch. An app binds `motion` to its own
    // "animations" setting; without platform animations (durations 0) nothing moves.
    property bool motion: true
    readonly property bool animate: active && motion && Kirigami.Units.longDuration > 0
    readonly property int durationFast: animate ? 120 : 0
    readonly property int duration: animate ? 200 : 0
    readonly property int durationSlow: animate ? 450 : 0
    /** Overshoot of the snap easing (Easing.OutBack), a small mechanical settle. */
    readonly property real snapOvershoot: 1.5

    function relLum(c) {
        function f(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function contrastOf(a, b) {
        var x = relLum(a), y = relLum(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }
    /** c moved in lightness (hue kept) until it reads at 4.5:1 on bg. */
    function readable(c, bg) {
        var dark = relLum(bg) < 0.5
        var h = Math.max(0, c.hslHue), sat = c.hslSaturation, l = c.hslLightness
        var out = Qt.hsla(h, sat, l, 1)
        for (var i = 0; i < 40 && contrastOf(out, bg) < 4.5; i++) {
            l = dark ? Math.min(1, l + 0.025) : Math.max(0, l - 0.025)
            out = Qt.hsla(h, sat, l, 1)
        }
        return out
    }
    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    // ── Fonts ────────────────────────────────────────────────────────────
    // Bundled (SIL OFL, fonts/OFL.txt); loaded for the process, never installed.
    readonly property FontLoader headingFace: FontLoader { source: Qt.resolvedUrl("fonts/Rajdhani-700.ttf") }
    readonly property FontLoader monoFace: FontLoader { source: Qt.resolvedUrl("fonts/JetBrainsMono-400.ttf") }
    readonly property FontLoader monoMediumFace: FontLoader { source: Qt.resolvedUrl("fonts/JetBrainsMono-500.ttf") }

    readonly property string monoFamily: active ? monoFace.font.family : "monospace"

    /** Page and app titles: uppercase Rajdhani in Kante and Kante Light; System: the default font, bold. */
    function titleFont(pointSize) {
        if (!active) {
            return Qt.font({ family: defaultFont.family, pointSize: pointSize, bold: true })
        }
        return kanteHeading(pointSize)
    }

    /** Card and button headings: uppercase Rajdhani in Kante; otherwise the default font, bold. */
    function headingFont(pointSize) {
        if (!themed) {
            return Qt.font({ family: defaultFont.family, pointSize: pointSize, bold: true })
        }
        return kanteHeading(pointSize)
    }

    function kanteHeading(pointSize) {
        return Qt.font({
            family: headingFace.font.family,
            pointSize: pointSize,
            weight: Font.Bold,
            capitalization: Font.AllUppercase,
            letterSpacing: pointSize * KantePalette.headingLetterSpacing
        })
    }

    /** Figures (timers, times, durations, amounts): JetBrains Mono in Kante and Kante Light. */
    function monoFont(pointSize, bold) {
        // Platforms that size the small font in pixels report pointSize -1: fall back to a small size.
        var size = pointSize > 0 ? pointSize : Math.max(7, defaultFont.pointSize * 0.85)
        if (!active) {
            return Qt.font({ family: "monospace", pointSize: size, bold: !!bold })
        }
        return Qt.font({
            family: (bold ? monoMediumFace : monoFace).font.family,
            pointSize: size,
            weight: bold ? Font.Medium : Font.Normal
        })
    }

    /** Small uppercase label with letter spacing (section titles, field labels). */
    function labelFont() {
        if (!active) {
            return smallFont
        }
        var size = Math.max(7, smallFont.pointSize * 0.9)
        return Qt.font({
            family: monoFace.font.family,
            pointSize: size,
            capitalization: Font.AllUppercase,
            letterSpacing: size * KantePalette.labelLetterSpacing
        })
    }
}
