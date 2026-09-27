#!/usr/bin/env bash
# Landing-page screenshots from the demo tasks, for shrippen.github.io/demo/tools/screenshots.py
# (demo/shots.json). Writes <name>.png into $SHOT_DIR (default build/demo-shots).
# Language: $DEMO_LANG (de|en). Renders offscreen through tests/screenshot.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${SHOT_DIR:-${ROOT}/build/demo-shots}"
LANG_="${DEMO_LANG:-de}"
RAW="$(mktemp -d "${TMPDIR:-/tmp}/kurrent-demo-shots-XXXXXX")"
CONFIG="$(mktemp -d "${TMPDIR:-/tmp}/kurrent-demo-config-XXXXXX")"
trap 'rm -rf "${RAW}" "${CONFIG}"' EXIT
cp -p "${XDG_CONFIG_HOME:-${HOME}/.config}/kdeglobals" "${CONFIG}/" 2>/dev/null || true

XDG_CONFIG_HOME="${CONFIG}" KURRENT_DEMO="${LANG_}" KURRENT_DEMO_WORLD="${ROOT}/demo/world.json" LANGUAGE="${LANG_}" \
KURRENT_SCREENSHOT_PLAN="styles=kante;modes=list,kanban,plan,heatmap,calendar;widths=60;editor=1;inspector=1" \
    "${ROOT}/tests/screenshot.sh" "${RAW}"

mkdir -p "${OUT}"
for pair in list:tasks kanban:kanban plan:plan heatmap:heatmap calendar:agenda editor:editor inspector:inspector; do
    cp "${RAW}/kante-60gu-${pair%%:*}.png" "${OUT}/${pair##*:}.png"
done

# Detail crops of the list view (fractions of its size): sidebar, view switcher, quick add.
crop() {   # name x y w h
    local size w h
    size="$(magick identify -format '%w %h' "${OUT}/tasks.png")"
    w="${size% *}"; h="${size#* }"
    magick "${OUT}/tasks.png" -crop "$(python3 -c "print('%dx%d+%d+%d' % (${w}*$4, ${h}*$5, ${w}*$2, ${h}*$3))")" +repage "${OUT}/$1.png"
}
crop detail-sidebar 0 0 0.17 1
crop detail-views 0.72 0 0.28 0.056
crop detail-quickadd 0.17 0.944 0.83 0.056
