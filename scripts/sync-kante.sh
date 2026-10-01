#!/usr/bin/env bash
# Copies the Kante QML module from the design system repo into the plasmoid.
#
#   plasmoid/com.github.shrippen.kurrent/contents/ui/Kante        KanteStyle, wrappers, skins, fonts
#   plasmoid/com.github.shrippen.kurrent/contents/ui/KantePlasma  the PlasmaComponents3 wrappers
#
# Source: KANTE_DS, default ../Kante (https://github.com/shrippen/Kante).
# The copies are not edited here; change the design system and sync again.
set -euo pipefail
cd "$(dirname "$0")/.."

DS="${KANTE_DS:-../Kante}"
if [ ! -f "$DS/qml/Kante/qmldir" ]; then
    echo "sync-kante: no Kante module in $DS/qml (set KANTE_DS)" >&2
    exit 1
fi

UI=plasmoid/com.github.shrippen.kurrent/contents/ui
for module in Kante KantePlasma; do
    rm -rf "$UI/$module"
    cp -r "$DS/qml/$module" "$UI/$module"
done

echo "sync-kante: $(git -C "$DS" describe --always --dirty 2>/dev/null || echo unknown) -> $UI/Kante, KantePlasma"
