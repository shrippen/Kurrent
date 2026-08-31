#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${KURRENT_PREFIX:-${PREFIX:-${HOME}/.local}}"
APPLET="${KURRENT_APPLET:-com.github.shrippen.kurrent}"
TIMEOUT_SEC="${KURRENT_VIEWER_TIMEOUT:-30}"

if [[ "${SKIP_PLASMOIDVIEWER:-0}" == "1" ]]; then
    echo "Skipping plasmoidviewer smoke tests (SKIP_PLASMOIDVIEWER=1)."
    exit 0
fi

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo "SKIP: no DISPLAY/WAYLAND_DISPLAY for plasmoidviewer"
    exit 77
fi

if ! command -v plasmoidviewer >/dev/null 2>&1; then
    echo "SKIP: plasmoidviewer not found (install plasma-sdk)"
    exit 77
fi

if ! command -v timeout >/dev/null 2>&1; then
    echo "SKIP: GNU timeout not found"
    exit 77
fi

# Prefer lib64 (Fedora/CMake) then lib, then share/qt6 mirror.
export QML_IMPORT_PATH="${PREFIX}/lib64/qml:${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml${QML_IMPORT_PATH:+:${QML_IMPORT_PATH}}"
export QML2_IMPORT_PATH="${PREFIX}/lib64/qml:${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"
export KURRENT_SMOKE=1
export QT_FORCE_STDERR_LOGGING=1
export QT_LOGGING_TO_CONSOLE=1
export QT_ASSUME_STDERR_HAS_CONSOLE=1
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-qt.qml.connections.warning=true;qml=true}"

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kurrent-viewer-XXXXXX")"
cleanup() {
    pkill -f "plasmoidviewer -a ${APPLET}" 2>/dev/null || true
}
# Ensure no leftover viewer from a previous run races this one.
cleanup
sleep 0.2
trap cleanup EXIT

strip_ansi() {
    sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

scan_log() {
    local log="$1"
    local plain
    plain="$(strip_ansi < "${log}")"

    local hits
    hits="$(printf '%s\n' "${plain}" | grep -F 'com.github.shrippen.kurrent' | grep -Ei \
        -e 'TypeError' \
        -e 'ReferenceError' \
        -e 'SyntaxError' \
        -e 'is not a type' \
        -e 'is not installed' \
        -e 'Cannot assign' \
        -e 'Cannot read property' \
        -e 'Cannot call method' \
        -e 'is not a function' \
        -e 'Unable to assign' \
        -e 'Error loading QML' \
        -e 'Binding loop' \
        -e 'Invalid argument passed to formatDate' \
        -e 'Invalid argument passed to formatTime' \
        -e ': Error:' \
        || true)"

    local fatal
    fatal="$(printf '%s\n' "${plain}" | grep -Ei \
        -e 'Could not create applet' \
        -e 'plugin cannot be loaded' \
        -e 'Segmentation fault' \
        -e 'signal 11' \
        -e 'ASSERT:' \
        -e 'QFatal' \
        || true)"

    if [[ -n "${hits}${fatal}" ]]; then
        echo "QML/Plasma errors detected:"
        printf '%s\n' "${hits}"
        printf '%s\n' "${fatal}"
        return 1
    fi

    if ! printf '%s\n' "${plain}" | grep -q 'KURRENT_SMOKE_START'; then
        echo "Plasmoid did not start the smoke sequence. Log:"
        printf '%s\n' "${plain}"
        return 1
    fi

    if ! printf '%s\n' "${plain}" | grep -q 'KURRENT_SMOKE_DONE'; then
        echo "Smoke sequence did not finish. Log:"
        printf '%s\n' "${plain}"
        return 1
    fi

    return 0
}

run_scenario() {
    local name="$1"
    local formfactor="$2"
    local location="$3"
    local size="$4"
    local log="${LOG_DIR}/${name}.log"

    echo "plasmoidviewer smoke: ${name} (${formfactor}/${location}, ${size})"
    export KURRENT_SMOKE_LOG="${LOG_DIR}/${name}.trace"
    : > "${KURRENT_SMOKE_LOG}"

    local rc=0
    timeout --signal=TERM --kill-after=3 "${TIMEOUT_SEC}s" \
        plasmoidviewer \
            -a "${APPLET}" \
            -f "${formfactor}" \
            -l "${location}" \
            -s "${size}" \
            -x 80 -y 80 \
        >"${log}" 2>&1 || rc=$?

    # 124 = timeout: viewer was still running, which is expected.
    # 137/143 = killed by TERM/KILL after timeout.
    if [[ "${rc}" -ne 0 && "${rc}" -ne 124 && "${rc}" -ne 137 && "${rc}" -ne 143 ]]; then
        echo "plasmoidviewer exited with ${rc} (${name})"
        strip_ansi < "${log}"
        return 1
    fi

    local combined="${LOG_DIR}/${name}.combined"
    cat "${log}" "${KURRENT_SMOKE_LOG}" > "${combined}" 2>/dev/null || cp "${log}" "${combined}"

    if ! scan_log "${combined}"; then
        echo "--- full ${name} log ---"
        strip_ansi < "${combined}"
        return 1
    fi

    echo "OK: ${name}"
}

run_scenario desktop planar desktop 900x600
run_scenario panel horizontal bottomedge 800x80

echo "plasmoidviewer smoke tests passed"
rm -rf "${LOG_DIR}"
trap - EXIT
cleanup
