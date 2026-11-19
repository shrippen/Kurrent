#!/usr/bin/env bash
# Measure the widget's startup, first open and search offscreen, with the data in Akonadi.
#
#   tests/ui_perf.sh [RUNS]
#
# Prints, per run and phase, the wall time and the main thread's CPU time (from /proc). CPU time
# is what to compare: the machine is often busy, wall times swing. For a before/after comparison
# run both builds alternately; the first run after a change compiles the QML (cold). Nothing
# appears on the desktop.
#
# Environment:
#   KURRENT_PERF_PLUGIN  plugin to load (default: ./build/qml/io/github/shrippen/Kurrent/libkurrentplugin.so)
#   KURRENT_PERF_STYLE   uiStyle for the run (plasma, kante, kanteLight); default: as configured
#
# How it works: like tests/screenshot.sh it stages the package and the plugin, then adds
# tests/ui_perf/PerfRunner.qml to FullView and exposes the search field. plasmoidviewer runs
# with QT_QPA_PLATFORM=offscreen in a panel (the only layout with a flyout). kurrentrc and the
# viewer's config are backed up and restored. plasmoidviewer ignores Qt.quit(), so the script
# ends it once the probe logs "PERF done".
#
# Lesson (2026-11-17): the probe's QML timers cannot measure a stall offscreen; the CPU time
# from /proc can.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS="${1:-1}"
APPLET_ID="io.github.shrippen.Kurrent"
PLUGIN="${KURRENT_PERF_PLUGIN:-${ROOT}/build/qml/io/github/shrippen/Kurrent/libkurrentplugin.so}"
TIMEOUT_SEC=180

command -v plasmoidviewer >/dev/null 2>&1 || { echo "plasmoidviewer not found (install plasma-sdk)"; exit 77; }
[[ -f "${PLUGIN}" ]] || { echo "Plugin not built: ${PLUGIN}"; exit 1; }

# A fixed place: the QML cache keys on the path, so only the first run starts cold.
WORK="${TMPDIR:-/tmp}/kurrent-perf-stage"
rm -rf "${WORK}"
mkdir -p "${WORK}"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
RC="${CONFIG_HOME}/${APPLET_ID}/kurrentrc"
VIEWER_RC="${CONFIG_HOME}/plasmoidviewer-appletsrc"
VIEWER_PID=""

backup() { [[ -f "$1" ]] && cp -p "$1" "${WORK}/$(basename "$1").bak" || true; }
restore() {
    local bak="${WORK}/$(basename "$1").bak"
    if [[ -f "${bak}" ]]; then cp -p "${bak}" "$1"; else rm -f "$1"; fi
}
cleanup() {
    [[ -n "${VIEWER_PID}" ]] && kill "${VIEWER_PID}" 2>/dev/null || true
    restore "${RC}"
    restore "${VIEWER_RC}"
    rm -rf "${WORK}"
}
backup "${RC}"
backup "${VIEWER_RC}"
trap cleanup EXIT

# Stage the package with the probe, and an import dir with the plugin.
UI="${WORK}/pkg/${APPLET_ID}/contents/ui"
mkdir -p "${WORK}/pkg" "${WORK}/qml/io/github/shrippen/Kurrent"
cp -a "${ROOT}/plasmoid/${APPLET_ID}" "${WORK}/pkg/"
if [[ -f "${ROOT}/build/DevBuildMarker.qml" ]]; then
    cp "${ROOT}/build/DevBuildMarker.qml" "${WORK}/pkg/${APPLET_ID}/contents/config/"
fi
cp "${ROOT}/tests/ui_perf/PerfRunner.qml" "${UI}/"
python3 - "${UI}" <<'PY'
import pathlib, sys
ui = pathlib.Path(sys.argv[1])
def patch(name, old, new):
    path = ui / name
    text = path.read_text()
    if old not in text:
        sys.exit(f"ui_perf: hook not found in {name}")
    path.write_text(text.replace(old, new, 1))
patch("FullView.qml", "    SmokeTest {\n",
      "    PerfRunner { plasmoidRoot: fullRoot.plasmoidRoot; controller: fullRoot.controller; fullRoot: fullRoot }\n\n    SmokeTest {\n")
patch("views/TaskListView.qml", "    property var pendingDeleteId: -1\n",
      "    property var pendingDeleteId: -1\n    property alias perfSearchField: searchField\n")
PY
cp "${PLUGIN}" "${WORK}/qml/io/github/shrippen/Kurrent/"
printf 'module io.github.shrippen.Kurrent\nplugin kurrentplugin\nclassname KurrentPlugin\n' \
    > "${WORK}/qml/io/github/shrippen/Kurrent/qmldir"
cat > "${WORK}/screens.json" <<'JSON'
{ "screens": [ { "name": "perf", "x": 0, "y": 0, "width": 1920, "height": 1200,
                 "logicalDpi": 96, "logicalBaseDpi": 96, "dpr": 1 } ] }
JSON
if [[ -n "${KURRENT_PERF_STYLE:-}" && -f "${RC}" ]]; then
    sed -i "s/^uiStyle=.*/uiStyle=${KURRENT_PERF_STYLE}/" "${RC}"
fi

# One run: the viewer's log and, every 50 ms, the main thread's CPU ticks.
run_once() {
    local log="$1" cpu="$2"
    date +"PERF process_start at=%s%3N" > "${log}"
    QML_IMPORT_PATH="${WORK}/qml" QML2_IMPORT_PATH="${WORK}/qml" \
    QT_QPA_PLATFORM="offscreen:configfile=${WORK}/screens.json" QT_QPA_PLATFORMTHEME=kde \
    QT_LOGGING_TO_CONSOLE=1 QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="qml=true;js=true" \
        plasmoidviewer -a "${WORK}/pkg/${APPLET_ID}" -f horizontal -l bottomedge -s 900x60 >>"${log}" 2>&1 &
    VIEWER_PID=$!
    local waited=0
    : > "${cpu}"
    while kill -0 "${VIEWER_PID}" 2>/dev/null && ! grep -q "PERF done" "${log}"; do
        echo "$(date +%s%3N) $(cut -d' ' -f14,15 "/proc/${VIEWER_PID}/task/${VIEWER_PID}/stat" 2>/dev/null)" >> "${cpu}"
        sleep 0.05
        waited=$((waited + 1))
        (( waited < TIMEOUT_SEC * 20 )) || { echo "ui_perf: run did not finish"; break; }
    done
    kill "${VIEWER_PID}" 2>/dev/null || true
    wait "${VIEWER_PID}" 2>/dev/null || true
    VIEWER_PID=""
}

# Wall time and main-thread CPU per phase (clock ticks of 10 ms).
report() {
    python3 - "$1" "$2" <<'PY'
import re, sys
log, cpu = open(sys.argv[1], errors="replace").read(), open(sys.argv[2]).read().split("\n")
ticks = [(int(f[0]), int(f[1]) + int(f[2])) for f in (l.split() for l in cpu) if len(f) == 3]
def at(t):
    value = ticks[0][1] if ticks else 0
    for stamp, tick in ticks:
        if stamp <= t:
            value = tick
    return value * 10
start = int(re.search(r"process_start at=(\d+)", log).group(1))
for key in ("fullview_created", "data_ready"):
    m = re.search(key + r" at=(\d+)", log)
    if m:
        t = int(m.group(1))
        print(f"  {key:22} wall {t - start:6} ms  main CPU {at(t):6} ms (since start)")
for b, e in zip(re.finditer(r"PERF begin (.*?) at=(\d+)", log), re.finditer(r"PERF end at=(\d+) ", log)):
    t0, t1 = int(b.group(2)), int(e.group(1))
    print(f"  {b.group(1):22} wall {t1 - t0:6} ms  main CPU {at(t1) - at(t0):6} ms")
PY
}

for run in $(seq 1 "${RUNS}"); do
    echo "Run ${run}:"
    run_once "${WORK}/run.log" "${WORK}/run.cpu"
    report "${WORK}/run.log" "${WORK}/run.cpu"
done
