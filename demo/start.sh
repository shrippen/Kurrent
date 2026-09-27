#!/usr/bin/env bash
# Opens Kurrent in plasmoidviewer with the Studio Weber demo tasks (internal, for screenshots).
#   demo/start.sh [de|en]
# Nothing is written to Akonadi; edits live in memory until the viewer closes.
set -euo pipefail
source "$(dirname "$0")/common.sh"
APPLET_ID="com.github.shrippen.kurrent"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kurrent-demo-XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/qml/com/github/shrippen/kurrent"
cp "${DEMO_PLUGIN}" "${WORK}/qml/com/github/shrippen/kurrent/"
printf 'module com.github.shrippen.kurrent\nplugin kurrentplugin\nclassname KurrentPlugin\n' \
    > "${WORK}/qml/com/github/shrippen/kurrent/qmldir"
demo_config "${WORK}/config"
LANG_="${1:-${DEMO_LANG:-de}}"
XDG_CONFIG_HOME="${WORK}/config" KURRENT_DEMO="${LANG_}" KURRENT_DEMO_WORLD="${ROOT}/demo/world.json" LANGUAGE="${LANG_}" \
QML_IMPORT_PATH="${WORK}/qml" QML2_IMPORT_PATH="${WORK}/qml" \
    plasmoidviewer -a "${ROOT}/plasmoid/${APPLET_ID}" -f horizontal -l bottomedge -s 900x60
