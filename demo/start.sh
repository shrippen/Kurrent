#!/usr/bin/env bash
# Opens Kurrent in plasmoidviewer with the Studio Weber demo tasks (the shrippen demo world)
# instead of Akonadi. Uses the working tree and the plugin from ./build (cmake --build build).
#   demo/start.sh [de|en]
# Nothing is written to Akonadi; edits live in memory until the viewer closes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPLET_ID="com.github.shrippen.kurrent"
PLUGIN="${ROOT}/build/qml/com/github/shrippen/kurrent/libkurrentplugin.so"
[[ -f "${PLUGIN}" ]] || { echo "Plugin not built: ${PLUGIN} (cmake --build build)"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/kurrent-demo-XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/qml/com/github/shrippen/kurrent" "${WORK}/config"
cp "${PLUGIN}" "${WORK}/qml/com/github/shrippen/kurrent/"
printf 'module com.github.shrippen.kurrent\nplugin kurrentplugin\nclassname KurrentPlugin\n' \
    > "${WORK}/qml/com/github/shrippen/kurrent/qmldir"
# Own config home (the real settings could hide the demo projects); keep the colour scheme.
cp -p "${XDG_CONFIG_HOME:-${HOME}/.config}/kdeglobals" "${WORK}/config/" 2>/dev/null || true

LANG_="${1:-${DEMO_LANG:-de}}"
XDG_CONFIG_HOME="${WORK}/config" KURRENT_DEMO="${LANG_}" LANGUAGE="${LANG_}" \
QML_IMPORT_PATH="${WORK}/qml" QML2_IMPORT_PATH="${WORK}/qml" \
    plasmoidviewer -a "${ROOT}/plasmoid/${APPLET_ID}" -f horizontal -l bottomedge -s 900x60
