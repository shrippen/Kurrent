import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Spin box (Kante 1.28, from Kontra): a QtQuick.Controls SpinBox with KanteFieldSkin, so a
 * number field does not stay light on a dark Kante page.
 *   System       the platform's spin box (unchanged).
 *   Kante        square sunken box with a 2 px bottom edge (cyan on focus, red when
 *                `invalid`), the value in the Kante text colour, + and − drawn in mono
 *                (muted, the accent while pressed, faded at a limit).
 *                40 px high like a text field.
 *   Kante Light  the platform's spin box, as every control there.
 * Same API as QQC2.SpinBox: from, to, stepSize, value, editable, textFromValue,
 * valueFromText, validator, valueModified(); keys Up / Down (and Page Up / Down where the
 * style has them); set Accessible.name, e.g. "Tempo".
 *
 *   KanteSpinBox {
 *       from: 40; to: 200; stepSize: 5; value: 90; editable: true
 *       textFromValue: function (v) { return v + " BPM" }
 *       valueFromText: function (t) { return parseInt(t) }
 *       Accessible.name: "Tempo"
 *   }
 */
QQC2.SpinBox {
    id: spin

    /** Kante: mark the value as invalid (red bottom edge). */
    property bool invalid: false

    KanteFieldSkin {
        control: spin
        invalid: spin.invalid
    }

    Binding {
        target: spin
        property: "implicitHeight"
        value: Math.max(KanteStyle.heightMedium, spin.implicitContentHeight + spin.topPadding + spin.bottomPadding)
        when: KanteStyle.themed
        restoreMode: Binding.RestoreBindingOrValue
    }
}
