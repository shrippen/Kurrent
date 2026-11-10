import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * In-place help (Kante 1.28, from Kontra): a "?" tool button next to a technical term. The
 * text shows on hover, on keyboard focus and on a click or tap (it stays until a second click,
 * Esc or leaving focus), and is the button's description for screen readers. The web twin is
 * `details.help` (1.11).
 *   term            the word it explains, e.g. "Latenz"
 *   info            the explanation, shown as tooltip and read as description
 *   accessibleName  the button's name for screen readers; default "Hilfe zu <term>". Plain
 *                   text: an app with its own translations sets it, e.g. "Help on latency"
 * A question mark, not an icon: it shows with every icon theme. System: the platform tool
 * button; Kante: KanteToolButton (square, sunken on hover, accent while open).
 */
KanteToolButton {
    id: tip

    property string term: ""
    property string info: ""
    property string accessibleName: term.length > 0 ? "Hilfe zu " + term : "Hilfe"

    display: QQC2.AbstractButton.TextOnly
    text: "?"
    checkable: true
    Accessible.name: tip.accessibleName
    Accessible.description: tip.info
    QQC2.ToolTip.text: tip.info
    QQC2.ToolTip.visible: tip.info.length > 0 && (hovered || activeFocus || checked)
    QQC2.ToolTip.delay: hovered && !checked ? 300 : 0

    // Esc closes an open tip; leaving the button closes it too.
    Keys.onEscapePressed: function (event) {
        event.accepted = tip.checked
        tip.checked = false
    }
    onActiveFocusChanged: {
        if (!activeFocus) {
            checked = false
        }
    }
}
