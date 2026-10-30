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

    /**
     * Presses a button from the keyboard (Return, Enter) as a click does (1.49). Qt 6.8 and
     * later animate it; older versions only emit clicked().
     */
    function pressByKey(button, event) {
        if (!button.enabled) {
            event.accepted = false
            return
        }
        if (typeof button.animateClick === "function") {
            button.animateClick()
        } else {
            button.clicked()
        }
    }

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
    /**
     * The platform's small font, but never larger than the default font: without a
     * platform theme (Kirigami's basic theme, e.g. Fusion on any desktop) smallFont can come
     * out larger than defaultFont, which turned hints and labels bigger than their titles
     * (found in Kontra at 200 %). Then 85 % of the default font is used.
     */
    readonly property font smallFont: {
        var s = Kirigami.Theme.smallFont, d = Kirigami.Theme.defaultFont
        if (fontPixels(s) <= fontPixels(d)) {
            return s
        }
        return d.pointSize > 0
            ? Qt.font({ family: d.family, pointSize: Math.max(7, d.pointSize * 0.85) })
            : Qt.font({ family: d.family, pixelSize: Math.max(9, Math.round(d.pixelSize * 0.85)) })
    }
    /** Size of a font in pixels at 96 dpi, from its point or pixel size. */
    function fontPixels(f) {
        return f.pointSize > 0 ? f.pointSize * 4 / 3 : f.pixelSize
    }

    /**
     * Japanese text (Kante 1.34, Kaiwa): the first installed family of japaneseFamilies, else
     * the default font's. Components that split Japanese into pieces use it (KanteRubyText per
     * character, KantePitchCurve per mora, KanteDiffText per part): a lone 来 or 。 gives Qt no
     * context, and under a non-Japanese locale its fallback took a Chinese face (other glyph
     * forms, a lower baseline, a centred 。). Whole lines in a Text keep the default font.
     */
    readonly property var japaneseFamilies: [
        "Noto Sans CJK JP", "Noto Sans JP", "Source Han Sans JP", "Source Han Sans",
        "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic UI", "Yu Gothic", "Meiryo UI",
        "Meiryo", "BIZ UDPGothic", "IPAexGothic", "IPAPGothic", "TakaoPGothic", "VL PGothic",
        "MS PGothic"
    ]
    readonly property string japaneseFamily: {
        var installed = Qt.fontFamilies()
        for (var i = 0; i < japaneseFamilies.length; i++) {
            if (installed.indexOf(japaneseFamilies[i]) >= 0) {
                return japaneseFamilies[i]
            }
        }
        return defaultFont.family
    }
    /** `base` (default: the default font) in the Japanese family, same size and weight. */
    function japaneseFont(base) {
        var b = base || defaultFont
        return b.pointSize > 0
            ? Qt.font({ family: japaneseFamily, pointSize: b.pointSize, bold: b.bold })
            : Qt.font({ family: japaneseFamily, pixelSize: b.pixelSize, bold: b.bold })
    }

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
    /**
     * Colour labels: a named colour that is the data itself (a colour tag on an input,
     * a darktable label), so "yellow" stays yellow in every kind; light or dark follows
     * the theme. Web: `data-label`. Never the only sign: name the label beside it.
     */
    readonly property var labels: ["red", "orange", "yellow", "green", "cyan", "blue", "purple"]
    function labelColor(name) {
        switch (name) {
        case "red": return palette.labelRed
        case "orange": return palette.labelOrange
        case "yellow": return palette.labelYellow
        case "green": return palette.labelGreen
        case "cyan": return palette.labelCyan
        case "blue": return palette.labelBlue
        case "purple": return palette.labelPurple
        }
        return "transparent"
    }
    // Warnings below "neutral" (e.g. stale dates, dead links); the platform has no own role, so neutral.
    readonly property color warningColor: themed ? palette.warning : Kirigami.Theme.neutralTextColor
    /** Focus ring, brackets, data lines (cyan; the platform's focus color otherwise). */
    readonly property color focusColor: themed ? palette.focus : Kirigami.Theme.focusColor
    /** Ground of a selected row or a focused field (cyan-tint; a tint of the highlight otherwise). */
    readonly property color selectionColor: themed ? palette.selection : tint(Kirigami.Theme.highlightColor, 0.16)
    /** Primary fill on hover (one step lighter) and pressed. */
    readonly property color accentHoverColor: themed ? palette.accentHover : Qt.lighter(Kirigami.Theme.highlightColor, 1.12)
    readonly property color accentPressedColor: themed ? palette.accentPressed : Qt.darker(Kirigami.Theme.highlightColor, 1.12)
    /**
     * The primary action (KanteButton.Emphasis.Primary, 1.27). Kante: the accent as before.
     * Kante Light and System: the platform highlight moved in lightness (hue kept) until its
     * label, the highlighted text colour, reads at 4.5:1 on it; Breeze's #3daee9 with white
     * is only 2.4:1. Hover and pressed go one and two steps further from the label.
     */
    readonly property color primaryColor: themed ? palette.accent : readable(Kirigami.Theme.highlightColor, Kirigami.Theme.highlightedTextColor)
    readonly property color primaryHoverColor: themed ? palette.accentHover : awayFrom(primaryColor, primaryTextColor, 0.05)
    readonly property color primaryPressedColor: themed ? palette.accentPressed : awayFrom(primaryColor, primaryTextColor, 0.1)
    /** Label on primaryColor. */
    readonly property color primaryTextColor: themed ? palette.accentForeground : Kirigami.Theme.highlightedTextColor
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
    // Practice roles (Kante 1.23: KanteTabLane, KanteTabStaff, KanteBassStaff, KanteNoteMark).
    // The state of a played note. Colour is never the only sign: KanteNoteMark draws
    // a shape for each (check, cross, hollow dashed square, arrow left / right, wave).
    /** Every note state that draws a sign, in legend order (pending draws none). */
    readonly property var noteStates: ["hit", "offpitch", "wrong", "missed", "early", "late"]
    /**
     * Colour of a note state: "hit", "wrong", "missed", "early", "late", "offpitch" (1.27:
     * the right note, its pitch off by more than the app's cents limit); anything else
     * (pending) the text colour. offpitch shares the warning colour with early and late
     * (right note, not quite right) and is told apart from them by its sign, a wave.
     */
    function noteStateColor(state) {
        switch (state) {
        case "hit": return positiveTextColor
        case "wrong": return negativeTextColor
        case "missed": return mutedTextColor
        case "early":
        case "late":
        case "offpitch": return warningColor
        default: return textColor
        }
    }
    /** Words for the note states (screen readers, legends); an app sets its translations once. */
    property var noteStateNames: ({
        pending: "Offen", hit: "Getroffen", wrong: "Falscher Ton",
        missed: "Verpasst", early: "Zu früh", late: "Zu spät", offpitch: "Unsauber"
    })
    /** Unit after a cents value ("+32 ct"); an app may translate it. */
    property string centsUnit: "ct"
    /** A deviation in cents as text: "+32 ct", "−18 ct" (true minus), "0 ct"; "" when not a number. */
    function centsText(cents) {
        var c = Number(cents)
        if (cents === undefined || cents === null || cents === "" || !isFinite(c)) {
            return ""
        }
        var r = Math.round(c)
        return (r < 0 ? "\u2212" : r > 0 ? "+" : "") + Math.abs(r) + " " + centsUnit
    }
    function noteStateName(state) {
        var n = noteStateNames && noteStateNames[state]
        return n !== undefined ? String(n) : String(noteStateNames && noteStateNames.pending || "")
    }
    /**
     * Words for playing techniques (Kante 1.31, KanteTechniqueMark): keys slide, hammer, pull,
     * slap, pop, ghost, dead (1.32, a dead note). An app sets its translations once, like
     * noteStateNames.
     */
    property var techniqueNames: ({
        slide: "Slide", hammer: "Hammer-on", pull: "Pull-off", slap: "Slap", pop: "Pop", ghost: "Ghost Note",
        dead: "Dead Note"
    })
    /** Name of a technique key; "" for an unknown key. */
    function techniqueName(key) {
        var n = techniqueNames && techniqueNames[key]
        return n !== undefined ? String(n) : ""
    }
    /** Words for how a technique was played (1.31): played, other, unheard. */
    property var techniqueResultNames: ({
        played: "Technik gespielt", other: "Andere Technik", unheard: "Technik nicht gehört"
    })
    /** Name of a technique result; "" for none or an unknown one. */
    function techniqueResultName(r) {
        var n = techniqueResultNames && techniqueResultNames[r]
        return n !== undefined ? String(n) : ""
    }
    /**
     * Screen-reader text of technique results (1.31): "Technik gespielt 3, Andere Technik 1"
     * from counts by result; "" when there are none.
     */
    function techniqueCountsText(counts) {
        var parts = []
        ;["played", "other", "unheard"].forEach(function (r) {
            if (counts && counts[r]) {
                parts.push(techniqueResultName(r) + " " + counts[r])
            }
        })
        return parts.join(", ")
    }
    /**
     * Rehearsal marks (Kante 1.50): the part names of one bar as one label. A name or a list
     * of names; blanks and repeats are left out, the rest joined with " · ":
     *   "Intro"                 "Intro"
     *   ["Refrain", "B"]        "Refrain · B"
     *   undefined, [], [""]     ""
     */
    function rehearsalText(names) {
        if (names === undefined || names === null) {
            return ""
        }
        // A list from QML or C++ is not always a JS Array: test for a length.
        const list = typeof names === "string" || names.length === undefined ? [names] : names
        const out = []
        for (let i = 0; i < list.length; i++) {
            const n = list[i] === undefined || list[i] === null ? "" : String(list[i]).trim()
            if (n !== "" && out.indexOf(n) < 0) {
                out.push(n)
            }
        }
        return out.join(" \u00b7 ")
    }
    /** A rehearsal mark for screen readers (1.50), %1 the label: "Teil Refrain · B". An app translates it once. */
    property string partText: "Teil %1"
    /**
     * String colours (Kante 1.28), one per string, string 0 = the lowest, kept apart from the
     * note state colours. Presets (`stringPalettes`): "kante" six roles that differ in hue
     * (purple, cyan, yellow, strong text, muted, info), "mono" every string in the strong
     * text colour, "bright" the strong signal colours (orange, info, yellow, purple, cyan,
     * strong text). `stringPalette` is the app's choice, set once; KanteTabLane, KanteTabStaff
     * and KanteFretboard follow it where their `stringColors` leave a string out. Colour is
     * never the only sign: strings keep their names and rows.
     *
     * "kante" in Kante and Kante Light (1.51) comes from the palette (string0..string5): on a
     * light ground raspberry, blue, ochre, strong text, muted, cyan, at least 4.5:1 (the fret
     * digits are drawn in it) and the four bass strings apart under deuteranopia; the platform
     * roles gave the A string 1.7:1 at a beamer, and purple and cyan look alike with
     * deuteranopia. Dark Kante keeps its colours; Kante Light on a dark system takes the dark
     * palette's (before: the platform roles). Kante Light moves a colour that reads below
     * 4.5:1 on an unusual platform ground (hue kept). System keeps the platform roles.
     */
    readonly property var stringPalettes: ["kante", "mono", "bright"]
    property string stringPalette: "kante"
    /** Colour of string s (0 = lowest) in `preset` (default `stringPalette`); repeats after six. */
    function stringColor(s, preset) {
        var p = preset !== undefined && preset !== null && preset !== "" ? String(preset) : stringPalette
        var list = p === "mono" ? [strongTextColor]
            : p === "bright" ? [warningColor, infoColor, accentTextColor, tagColor, focusColor, strongTextColor]
            : kanteStrings
        var i = Math.max(0, Math.floor(Number(s) || 0))
        return list[i % list.length]
    }
    /** The "kante" preset, worked out once per theme, not per note. */
    readonly property var kanteStrings: {
        if (!active) {
            return [tagColor, focusColor, accentTextColor, strongTextColor, mutedTextColor, infoColor]
        }
        const p = palette
        const list = [p.string0, p.string1, p.string2, p.string3, p.string4, p.string5]
        if (themed) {
            return list
        }
        const ground = Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, 1)
        return list.map(function (c) { return readable(c, ground) })
    }
    /** The colours of `count` strings (default 6) in `preset`, e.g. for `stringColors`. */
    function stringColors(count, preset) {
        var out = []
        var n = count === undefined ? 6 : Math.max(0, Number(count) || 0)
        for (var s = 0; s < n; s++) {
            out.push(stringColor(s, preset))
        }
        return out
    }
    /** Text colour for a label on a filled `fill`: the ground or the strong text, whichever reads better. */
    function inkOn(fill) {
        var a = Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, 1)
        var b = Qt.rgba(strongTextColor.r, strongTextColor.g, strongTextColor.b, 1)
        var f = Qt.rgba(fill.r, fill.g, fill.b, 1)
        return contrastOf(a, f) >= contrastOf(b, f) ? a : b
    }
    /** Text on a filled state color (danger button, counter). */
    readonly property color onStateColor: themed ? palette.onState : Kirigami.Theme.highlightedTextColor
    readonly property color cardColor: themed ? palette.card : tint(Kirigami.Theme.textColor, 0.04)
    readonly property color sunkenColor: themed ? palette.sunken : tint(Kirigami.Theme.textColor, 0.06)
    readonly property color frameColor: themed ? palette.frame : tint(Kirigami.Theme.textColor, 0.12)
    readonly property color ruleColor: themed ? palette.rule : tint(Kirigami.Theme.textColor, 0.12)
    readonly property color dialogColor: themed ? palette.dialog : Kirigami.Theme.backgroundColor
    /**
     * Ground of picture areas (monitors, video previews, image stages): dark in every kind and
     * scheme, Leinen and a light platform theme included, because colour is judged there and a
     * beige or white ground misleads (web: `.stage`). Opaque; the platform has no such role.
     */
    readonly property color stageColor: palette.stage
    /** Text and marks on stageColor (a "No signal" label, a safe-area frame). */
    readonly property color stageTextColor: palette.stageText

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

    // ── Lines, markers and tints (Kante 1.56) ─────────────────────────────
    // In every style, so a view drawn by hand (a time grid, a board) needs no sizes of its own.
    // Weights, dash, levels and opacities come from tokens/palette.json (shape.lines, levels).
    /** Borders and grid lines (web: 1 px borders). */
    readonly property int borderWidth: KantePalette.lineBorder
    /** Lines that mark: today, the picked day, the now line, an underline (web: 2 px lines). */
    readonly property int lineWidth: KantePalette.lineMark
    /** The colour edge of an entry: a calendar's or a project's colour on its left side. */
    readonly property int edgeWidth: KantePalette.lineEdge
    /** Its corners: square in the Kante style, slightly round elsewhere. */
    readonly property int edgeRadius: themed ? 0 : 1
    /** Small markers (day dots, legend keys): square in the Kante style, round elsewhere. */
    readonly property int markerSize: Math.max(4, Math.round(Kirigami.Units.gridUnit / 4))
    readonly property int markerRadius: themed ? 0 : Math.floor(markerSize / 2)
    /** A thin meter (a day's load, progress inside a row). */
    readonly property int meterHeight: Math.max(3, Math.round(Kirigami.Units.gridUnit / 5))
    readonly property int meterRadius: themed ? 0 : Math.floor(meterHeight / 2)
    /** Narrowest combo box in the Kante style (KanteFieldSkin), 120 px at a grid unit of 18. */
    readonly property int comboMinimumWidth: unit(120)
    /** A colour swatch in a legend or a menu. */
    readonly property int swatchSize: Math.round(Kirigami.Units.gridUnit * 0.7)
    /** Dash pattern of an edge that runs past its room (ShapePath.dashPattern, in line widths). */
    readonly property var dashPattern: KantePalette.dash
    /**
     * Tint levels of a colour over the ground, for tint(c, level): wash (a tray, a quiet
     * area), fill (free time, a draft), strongFill (a planned block), edge (the border of
     * such an area).
     */
    readonly property real washLevel: KantePalette.levelWash
    readonly property real fillLevel: KantePalette.levelFill
    readonly property real strongFillLevel: KantePalette.levelStrongFill
    readonly property real edgeLevel: KantePalette.levelEdge
    /** Opacity of something done (a completed task). */
    readonly property real doneOpacity: KantePalette.levelDone
    /** Opacity of something out of range or minor: a day of another month, half-hour lines. */
    readonly property real dimOpacity: KantePalette.levelDim
    /** Height of one minute in an hour grid (an hour is 1.5 grid units). */
    readonly property real minuteHeight: Kirigami.Units.gridUnit / 40
    /** Height of one entry line in a month cell. */
    readonly property real calendarEntryHeight: Kirigami.Units.gridUnit * 1.1

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
    /** c moved by `step` in lightness away from `from` (darker next to a light label, else lighter). */
    function awayFrom(c, from, step) {
        var l = relLum(from) > 0.5 ? Math.max(0, c.hslLightness - step) : Math.min(1, c.hslLightness + step)
        return Qt.hsla(Math.max(0, c.hslHue), c.hslSaturation, l, 1)
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
