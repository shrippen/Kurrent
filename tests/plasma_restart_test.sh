#!/usr/bin/env bash
# Checks the plasma-restart block of install-linux.sh against a fake plasmashell: the new shell
# starts only once the old one is gone (a slow quit, as after a Qt update, left no shell).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

BLOCK="${WORK}/block.sh"
sed -n '/^# BEGIN plasma-restart/,/^# END plasma-restart/p' "${ROOT}/install-linux.sh" >"$BLOCK"
if [[ ! -s "$BLOCK" ]]; then
    fail "no plasma-restart block in install-linux.sh"
    exit 1
fi

# Fake desktop. FAKE_STATE/running exists while a plasmashell runs; FAKE_STATE/log records
# each start, and "clash" when one starts while the old one still runs (it then exits).
mkdir -p "${WORK}/bin"
fake() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"${WORK}/bin/$1"
    chmod +x "${WORK}/bin/$1"
}
fake pgrep '[[ -e "${FAKE_STATE}/running" ]]'
fake kquitapp6 '[[ -n "${FAKE_QUIT_HANG:-}" ]] && exit 0
( sleep "${FAKE_QUIT_DELAY:-0}"; rm -f "${FAKE_STATE}/running" ) >/dev/null 2>&1 &'
fake pkill '[[ "$1" != -KILL && -n "${FAKE_TERM_IGNORED:-}" ]] && exit 0
rm -f "${FAKE_STATE}/running"'
fake plasmashell 'if [[ -e "${FAKE_STATE}/running" ]]; then echo clash >>"${FAKE_STATE}/log"; exit 1; fi
touch "${FAKE_STATE}/running"
echo "started ${QML_IMPORT_PATH:-}" >>"${FAKE_STATE}/log"'
# systemd user manager: only with FAKE_SYSTEMD; FAKE_STATE/env is its environment.
fake systemctl '[[ -z "${FAKE_SYSTEMD:-}" ]] && exit 1
shift
case "$1" in
    cat|is-active) exit 0 ;;
    stop) rm -f "${FAKE_STATE}/running" ;;
    show-environment) cat "${FAKE_STATE}/env" 2>/dev/null ;;
    set-environment) shift; for kv in "$@"; do sed -i "/^${kv%%=*}=/d" "${FAKE_STATE}/env"; echo "$kv" >>"${FAKE_STATE}/env"; done ;;
    start)
        if [[ -e "${FAKE_STATE}/running" ]]; then echo clash >>"${FAKE_STATE}/log"; exit 1; fi
        touch "${FAKE_STATE}/running"
        echo "started unit $(grep "^QML_IMPORT_PATH=" "${FAKE_STATE}/env")" >>"${FAKE_STATE}/log" ;;
esac'
for tool in bash cat env grep id mkdir nohup rm sed sleep touch; do
    ln -s "$(command -v "$tool")" "${WORK}/bin/${tool}"
done

# Runs the restart in a fresh fake desktop named $1, with plasmashell running unless told not.
run_restart() {
    export FAKE_STATE="${WORK}/$1"
    mkdir -p "$FAKE_STATE"
    touch "${FAKE_STATE}/env"
    if [[ -z "${FAKE_NOT_RUNNING:-}" ]]; then
        touch "${FAKE_STATE}/running"
    fi
    (
        PATH="${WORK}/bin"
        # shellcheck source=/dev/null
        source "$BLOCK"
        PLASMA_QUIT_SECONDS=2
        restart_plasma "${WORK}/prefix"
    ) >/dev/null 2>&1 || true

    # A shell started in the background may still be writing its line.
    local i
    for ((i = 0; i < 20; ++i)); do
        [[ -s "${FAKE_STATE}/log" ]] && break
        sleep 0.1
    done
}

log_of() {
    cat "${WORK}/$1/log" 2>/dev/null || true
}

# The old shell takes longer to quit than the restart used to wait.
FAKE_QUIT_DELAY=1.5 run_restart slow
grep -q clash <<<"$(log_of slow)" && fail "new plasmashell started while the old one still quit"
grep -q "^started .*${WORK}/prefix/lib/qml" <<<"$(log_of slow)" || fail "no plasmashell with the QML path after a slow quit: $(log_of slow)"

# The old shell ignores the quit request and SIGTERM: it is killed, then a new one starts.
FAKE_QUIT_HANG=1 FAKE_TERM_IGNORED=1 run_restart hung
grep -q clash <<<"$(log_of hung)" && fail "new plasmashell started next to a hung one"
grep -q "^started" <<<"$(log_of hung)" || fail "no plasmashell after a hung one: $(log_of hung)"

# Under systemd the unit restarts it, with the QML path in the manager's environment and
# entries already there kept.
mkdir -p "${WORK}/unit"
echo "QML_IMPORT_PATH=/other/qml" >"${WORK}/unit/env"
FAKE_SYSTEMD=1 FAKE_QUIT_HANG=1 run_restart unit
grep -q "^started unit QML_IMPORT_PATH=${WORK}/prefix/lib64/qml:.*:/other/qml$" <<<"$(log_of unit)" ||
    fail "unit not started with the merged QML path: $(log_of unit)"

# A second install does not add the path twice.
mkdir -p "${WORK}/again"
echo "QML_IMPORT_PATH=${WORK}/prefix/lib64/qml:${WORK}/prefix/lib/qml:${WORK}/prefix/share/qt6/qml" >"${WORK}/again/env"
FAKE_SYSTEMD=1 run_restart again
grep -q "^started unit QML_IMPORT_PATH=${WORK}/prefix/lib64/qml:${WORK}/prefix/lib/qml:${WORK}/prefix/share/qt6/qml$" <<<"$(log_of again)" ||
    fail "QML path doubled on a second install: $(log_of again)"

# No plasmashell running: none is started.
FAKE_NOT_RUNNING=1 run_restart idle
[[ -z "$(log_of idle)" ]] || fail "plasmashell started although none ran: $(log_of idle)"

if [[ "$failures" -gt 0 ]]; then
    exit 1
fi
echo "plasma restart: all checks passed"
