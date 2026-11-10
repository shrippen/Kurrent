import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Switch (Kante 1.27): a QtQuick.Controls Switch with KanteCheckSkin's switch shape, so an
 * app does not leave a light platform switch on a dark Kante page.
 *   System       the platform's switch (unchanged).
 *   Kante        a square track with a square knob that snaps to its end; on: accent
 *                track and the knob in the accent's ink, off: sunken track, knob in the
 *                text colour. On and off differ by the knob's side, not by colour alone.
 *                Focus is a cyan ring, the label takes the Kante text colour.
 *   Kante Light  the platform's switch, as every control there.
 * Same API as QQC2.Switch (text, checked, toggled()).
 */
QQC2.Switch {
    id: toggle

    KanteCheckSkin {
        control: toggle
        shape: KanteCheckSkin.Shape.Switch
    }
}
