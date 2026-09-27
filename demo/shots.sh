#!/usr/bin/env bash
# Landing-page screenshots from the demo tasks, for shrippen.github.io/tools/screenshots.py
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

XDG_CONFIG_HOME="${CONFIG}" KURRENT_DEMO="${LANG_}" LANGUAGE="${LANG_}" \
KURRENT_SCREENSHOT_PLAN="styles=kante;modes=list,kanban,plan,heatmap;widths=60;editor=1;inspector=1" \
    "${ROOT}/tests/screenshot.sh" "${RAW}"

mkdir -p "${OUT}"
for pair in list:tasks kanban:kanban plan:plan heatmap:heatmap editor:editor inspector:inspector; do
    cp "${RAW}/kante-60gu-${pair%%:*}.png" "${OUT}/${pair##*:}.png"
done
