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
    readonly property color accentTextColor: themed ? palette.accentText : Kirigami.Theme.highlightColor
    readonly property color accentForegroundColor: themed ? palette.accentForeground : Kirigami.Theme.highlightedTextColor
    readonly property color infoColor: themed ? palette.info : Kirigami.Theme.linkColor
    readonly property color cardColor: themed ? palette.card : tint(Kirigami.Theme.textColor, 0.04)
    readonly property color sunkenColor: themed ? palette.sunken : tint(Kirigami.Theme.textColor, 0.06)
    readonly property color frameColor: themed ? palette.frame : tint(Kirigami.Theme.textColor, 0.12)
    readonly property color ruleColor: themed ? palette.rule : tint(Kirigami.Theme.textColor, 0.12)
    readonly property color dialogColor: themed ? palette.dialog : Kirigami.Theme.backgroundColor

    /** Top-right corner cut of cards (px), scaled with the grid unit; 0 in System. */
    readonly property int chamfer: active ? Math.round(KantePalette.chamfer * Kirigami.Units.gridUnit / 18) : 0
    readonly property int chamferSmall: active ? Math.round(KantePalette.chamferSmall * Kirigami.Units.gridUnit / 18) : 0

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
        if (!active) {
            return Qt.font({ family: "monospace", pointSize: pointSize, bold: !!bold })
        }
        return Qt.font({
            family: (bold ? monoMediumFace : monoFace).font.family,
            pointSize: pointSize,
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
