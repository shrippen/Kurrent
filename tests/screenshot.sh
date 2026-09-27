#!/usr/bin/env bash
# Render the widget offscreen and save PNG screenshots — nothing appears on the desktop.
#
#   tests/screenshot.sh [OUT_DIR]
#
# Uses the working tree (QML) and the plugin from ./build (run `cmake --build build` first),
# never the installed copy in ~/.local. Data comes from the running Akonadi.
#
# Environment:
#   KURRENT_SCREENSHOT_PLAN  "styles=plasma,kante,kanteLight;modes=list,kanban,swimlane,plan,heatmap,calendar;widths=30,60,80;editor=1;inspector=1;transition=0"
#                            (any part may be left out; empty = everything)
#   KURRENT_SCREENSHOT_TIMEOUT  seconds before giving up (default 240)
#   KURRENT_SCREENSHOT_ONSCREEN=1  render on the real platform instead (a viewer window shows
#                            briefly; still only the widget is grabbed). For checking colour-theme
#                            behaviour, which the offscreen platform only partly provides.
#
# How it works: plasmoidviewer runs with QT_QPA_PLATFORM=offscreen and the KDE platform theme
# (without it QQC2 falls back to Qt's default palette: black text). Only the panel form factor
# gives the widget a real window (the flyout), so the widget sits in a panel and expands itself.
# ScreenshotRunner.qml walks the plan and grabs each state with grabToImage.
# kurrentrc and plasmoidviewer's applet config are backed up and restored, because switching
# view modes persists like a user click.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-${ROOT}/build/screenshots}"
TIMEOUT_SEC="${KURRENT_SCREENSHOT_TIMEOUT:-240}"
APPLET_ID="com.github.shrippen.kurrent"

command -v plasmoidviewer >/dev/null 2>&1 || { echo "plasmoidviewer not found (install plasma-sdk)"; exit 77; }
PLUGIN="${KURRENT_SCREENSHOT_PLUGIN:-${ROOT}/build/qml/com/github/shrippen/kurrent/libkurrentplugin.so}"
[[ -f "${PLUGIN}" ]] || { echo "Plugin not built: ${PLUGIN}"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/kurrent-shots-XXXXXX")"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
RC="${CONFIG_HOME}/${APPLET_ID}/kurrentrc"
VIEWER_RC="${CONFIG_HOME}/plasmoidviewer-appletsrc"

backup() { [[ -f "$1" ]] && cp -p "$1" "${WORK}/$(basename "$1").bak" || true; }
restore() {
    local bak="${WORK}/$(basename "$1").bak"
    if [[ -f "${bak}" ]]; then cp -p "${bak}" "$1"; else rm -f "$1"; fi
}
cleanup() {
    restore "${RC}"
    restore "${VIEWER_RC}"
    rm -rf "${WORK}"
}
backup "${RC}"
backup "${VIEWER_RC}"
trap cleanup EXIT

# Stage the package (plus the generated dev marker) and an import dir with the fresh plugin.
mkdir -p "${WORK}/pkg" "${WORK}/qml/com/github/shrippen/kurrent"
cp -a "${ROOT}/plasmoid/${APPLET_ID}" "${WORK}/pkg/"
if [[ -f "${ROOT}/build/DevBuildMarker.qml" ]]; then
    cp "${ROOT}/build/DevBuildMarker.qml" "${WORK}/pkg/${APPLET_ID}/contents/config/"
fi
cp "${PLUGIN}" "${WORK}/qml/com/github/shrippen/kurrent/"
printf 'module com.github.shrippen.kurrent\nplugin kurrentplugin\nclassname KurrentPlugin\n' \
    > "${WORK}/qml/com/github/shrippen/kurrent/qmldir"

# Offscreen screen large enough for wide layouts (the flyout is clamped to the screen).
cat > "${WORK}/screens.json" <<'JSON'
{ "screens": [ { "name": "shot", "x": 0, "y": 0, "width": 1920, "height": 1200,
                 "logicalDpi": 96, "logicalBaseDpi": 96, "dpr": 1 } ] }
JSON

mkdir -p "${OUT}"
rm -f "${OUT}"/*.png
LOG="${WORK}/viewer.log"

echo "Rendering screenshots offscreen into ${OUT} …"
rc=0
QML_IMPORT_PATH="${WORK}/qml" QML2_IMPORT_PATH="${WORK}/qml" \
QPA_ENV=(QT_QPA_PLATFORM="offscreen:configfile=${WORK}/screens.json" QT_QPA_PLATFORMTHEME=kde)
if [[ "${KURRENT_SCREENSHOT_ONSCREEN:-0}" == "1" ]]; then
    QPA_ENV=()
fi
env "${QPA_ENV[@]}" \
QT_LOGGING_TO_CONSOLE=1 QT_FORCE_STDERR_LOGGING=1 \
KURRENT_SCREENSHOT_DIR="${OUT}" KURRENT_SCREENSHOT_PLAN="${KURRENT_SCREENSHOT_PLAN:-}" \
timeout --signal=TERM --kill-after=3 "${TIMEOUT_SEC}s" \
    plasmoidviewer -a "${WORK}/pkg/${APPLET_ID}" -f horizontal -l bottomedge -s 900x60 \
    >"${LOG}" 2>&1 || rc=$?

grep -E "KURRENT_SCREENSHOT" "${LOG}" | sed 's/^.*KURRENT_/KURRENT_/' || true
errors="$(grep -F "${APPLET_ID}/contents" "${LOG}" | grep -Ei 'TypeError|ReferenceError|is not a type|Cannot assign|Binding loop|Unable to assign|Error loading' || true)"
if [[ -n "${errors}" ]]; then
    echo "QML errors:"
    printf '%s\n' "${errors}"
fi
if ! grep -q "KURRENT_SCREENSHOT_DONE" "${LOG}"; then
    echo "Screenshot run did not finish (exit ${rc}). Log:"
    tail -40 "${LOG}"
    exit 1
fi
ls -1 "${OUT}"/*.png | wc -l | xargs echo "PNG files:"
