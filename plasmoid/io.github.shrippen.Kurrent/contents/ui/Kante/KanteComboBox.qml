import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Combo box (Kante 1.27): a QtQuick.Controls ComboBox with KanteFieldSkin and a Kante list,
 * so neither the box nor its open list stays light on a dark Kante page.
 *   System       the platform's combo box; the rows are the style's ItemDelegate.
 *   Kante        square sunken box with a 2 px bottom edge (cyan on focus, red when
 *                `invalid`), the value in the Kante text colour and a drawn arrow; the
 *                list opens on a cut card with a cyan bar (KantePopupSkin), the row under
 *                the pointer or the keyboard on the cyan tint with a 3 px cyan edge (not
 *                colour alone), the chosen row in the strong text colour and medium
 *                weight. 40 px high like a text field.
 *   Kante Light  the platform's combo box, as every control there.
 * Same API as QQC2.ComboBox (model, textRole, currentIndex, activated()). Set your own
 * `delegate` and the rows are yours (the box and the card stay Kante).
 *
 * The rows are drawn over the style's ItemDelegate, not swapped in when Kante turns on:
 * a combo box deletes the delegate it replaces, so a swapped-out style delegate was gone
 * when System came back.
 */
QQC2.ComboBox {
    id: combo

    /** Kante: mark the value as invalid (red bottom edge). */
    property bool invalid: false

    KanteFieldSkin {
        control: combo
        invalid: combo.invalid
    }
    KantePopupSkin { popup: combo.popup }

    delegate: QQC2.ItemDelegate {
        id: row
        required property int index
        readonly property bool chosen: combo.currentIndex === index
        width: ListView.view ? ListView.view.width : implicitWidth
        text: combo.textAt(index)
        highlighted: combo.highlightedIndex === index
        hoverEnabled: combo.hoverEnabled

        Rectangle {
            z: -1
            anchors.fill: parent
            visible: KanteStyle.themed
            color: row.highlighted || row.down ? KanteStyle.selectionColor : (row.hovered ? KanteStyle.tint1Color : "transparent")
            Rectangle {
                visible: row.highlighted
                width: KanteStyle.unit(3)
                height: parent.height
                color: KanteStyle.focusColor
            }
        }
        Text {
            id: rowText
            visible: KanteStyle.themed
            x: Math.max(KanteStyle.unit(10), row.leftPadding)
            width: row.width - x - Math.max(KanteStyle.unit(10), row.rightPadding)
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            color: row.chosen ? KanteStyle.strongTextColor : KanteStyle.textColor
            font.family: combo.font.family
            font.pointSize: combo.font.pointSize > 0 ? combo.font.pointSize : KanteStyle.defaultFont.pointSize
            font.weight: row.chosen ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }
        Binding {
            target: row.background
            property: "opacity"
            value: 0
            when: KanteStyle.themed && row.background !== null
            restoreMode: Binding.RestoreBindingOrValue
        }
        Binding {
            target: row.contentItem
            property: "opacity"
            value: 0
            when: KanteStyle.themed && row.contentItem !== null
            restoreMode: Binding.RestoreBindingOrValue
        }
        Binding {
            target: row
            property: "implicitHeight"
            value: Math.max(KanteStyle.heightSmall, rowText.implicitHeight + KanteStyle.unit(12))
            when: KanteStyle.themed
            restoreMode: Binding.RestoreBindingOrValue
        }
    }

    Binding {
        target: combo
        property: "implicitHeight"
        value: Math.max(KanteStyle.heightMedium, combo.implicitContentHeight + combo.topPadding + combo.bottomPadding)
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
