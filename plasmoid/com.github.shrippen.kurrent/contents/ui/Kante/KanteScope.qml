import QtQuick
import org.kde.kirigami as Kirigami
import "."

/**
 * Hands the Kante colors to `target`'s Kirigami.Theme, so Plasma and
 * Kirigami controls below it (labels, check boxes, spin boxes, combo
 * boxes, icons) follow Kante too. Does nothing in the System style: when
 * Kante is switched off the colors are reset and the target inherits again.
 *
 * Place one inside the popup root and inside each popup/dialog (popups do
 * not inherit the theme of the item that opens them).
 */
Item {
    id: scope

    required property Item target
    readonly property var theme: target ? target.Kirigami.Theme : null

    visible: false

    // Theme property -> KanteStyle role.
    readonly property var roles: ({
        textColor: "textColor",
        disabledTextColor: "disabledTextColor",
        backgroundColor: "dialogColor",
        alternateBackgroundColor: "cardColor",
        highlightColor: "accentColor",
        highlightedTextColor: "accentForegroundColor",
        focusColor: "accentColor",
        hoverColor: "accentColor",
        linkColor: "infoColor",
        positiveTextColor: "positiveTextColor",
        neutralTextColor: "neutralTextColor",
        negativeTextColor: "negativeTextColor"
    })

    // Kante: bind the roles. Otherwise bind each color live to the parent's theme, which
    // behaves like inheriting and follows later platform theme changes (a Binding restore
    // would freeze the old colors). Not a reset: under the Plasma theme, assigning undefined
    // stores an invalid custom color (#00000000) and all text below turns invisible.
    // The target is never detached (inherit stays true): a detached theme leaves the
    // children on its own colour table, which the reset left empty.
    function apply() {
        if (!theme || KanteStyle.materialStyle || KanteStyle.themed === applied) {
            return
        }
        for (var prop in roles) {
            theme[prop] = Qt.binding(KanteStyle.themed ? roleBinding(roles[prop]) : parentBinding(prop))
        }
        applied = KanteStyle.themed
    }

    /** The colors are set by this scope (System never touches the target). */
    property bool applied: false

    function roleBinding(role) {
        return function() { return KanteStyle[role] }
    }

    /** The parent's live theme color (what the target would inherit). */
    function parentBinding(prop) {
        return function() {
            var p = scope.target ? scope.target.parent : null
            return p ? p.Kirigami.Theme[prop] : Kirigami.Theme[prop]
        }
    }

    onThemeChanged: {
        applied = false
        apply()
    }
    Component.onCompleted: apply()

    Connections {
        target: KanteStyle
        function onThemedChanged() { scope.apply() }
    }
}
