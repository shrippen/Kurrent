#!/usr/bin/env bash
# Checks the move from the old widget id (com.github.shrippen.kurrent, up to 0.7.0) to the new
# one: the id-move block of install-linux.sh against a fake plasmashell, and that the old id
# appears nowhere but in migration code.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_ID_TEXT="com.github.shrippen.kurrent"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

# Files allowed to name the old id: the migrations, their tests and the history.
ALLOWED=(
    CHANGELOG.md
    install-linux.sh
    uninstall.sh
    plugin/sharedsettings.cpp
    tests/sharedsettings_test.cpp
    tests/id_move_test.sh
)
while IFS= read -r file; do
    allowed=0
    for a in "${ALLOWED[@]}"; do
        if [[ "$file" == "$a" ]]; then
            allowed=1
        fi
    done
    if [[ "$allowed" == 0 ]]; then
        fail "old id in ${file}"
    fi
done < <(git -C "$ROOT" grep -il -e "$OLD_ID_TEXT" -e "com/github/shrippen" -- . ':!*.png' ':!*.webp' || true)

BLOCK="${WORK}/block.sh"
sed -n '/^# BEGIN id-move/,/^# END id-move/p' "${ROOT}/install-linux.sh" >"$BLOCK"
if [[ ! -s "$BLOCK" ]]; then
    fail "no id-move block in install-linux.sh"
    exit 1
fi

# A fake qdbus6 that answers every script with FAKE_REPLY.
mkdir -p "${WORK}/bin"
cat >"${WORK}/bin/qdbus6" <<'EOF'
#!/usr/bin/env bash
# Plasma's layout: FAKE_DESKTOPS containments (0 while plasmashell still starts).
if [[ "${!#}" == 'print(desktops().length)' ]]; then
    echo "${FAKE_DESKTOPS:-1}"
    exit 0
fi
if [[ "${!#}" == 'print("up")' ]]; then
    echo up
    exit 0
fi
echo "$FAKE_REPLY"
EOF
chmod +x "${WORK}/bin/qdbus6"

# Tools the block needs, without any qdbus: the real one would ask the running desktop.
mkdir -p "${WORK}/tools"
for tool in cat find rm rmdir sleep; do
    ln -s "$(command -v "$tool")" "${WORK}/tools/${tool}"
done
for tool in bash cat find rm rmdir sleep; do
    ln -s "$(command -v "$tool")" "${WORK}/bin/${tool}"
done

# Lays out an install of the old id under PREFIX.
old_install() {
    local prefix="$1"
    mkdir -p "${prefix}/share/plasma/plasmoids/${OLD_ID_TEXT}" \
        "${prefix}/lib/qml/com/github/shrippen/kurrent" \
        "${prefix}/share/locale/de/LC_MESSAGES"
    touch "${prefix}/share/locale/de/LC_MESSAGES/plasma_applet_${OLD_ID_TEXT}.mo"

    # An old widget still running after the restart writes its file again (seen on 0.7.0).
    mkdir -p "${prefix}/config/${OLD_ID_TEXT}" "${prefix}/config/io.github.shrippen.Kurrent"
    echo "[General]" >"${prefix}/config/${OLD_ID_TEXT}/kurrentrc"
    echo "[General]" >"${prefix}/config/io.github.shrippen.Kurrent/kurrentrc"
}

old_gone() {
    local prefix="$1"
    [[ ! -e "${prefix}/config/${OLD_ID_TEXT}" ]] &&
        [[ ! -e "${prefix}/share/plasma/plasmoids/${OLD_ID_TEXT}" ]] &&
        [[ ! -e "${prefix}/lib/qml/com" ]] &&
        [[ ! -e "${prefix}/share/locale/de/LC_MESSAGES/plasma_applet_${OLD_ID_TEXT}.mo" ]]
}

run_move() {
    local prefix="$1" path="$2"
    (
        PATH="$path"
        export XDG_CONFIG_HOME="${prefix}/config"
        # shellcheck source=/dev/null
        source "$BLOCK"
        PLASMA_WAIT_SECONDS=1
        move_old_widgets "$prefix"
    ) >/dev/null 2>&1
}

# Every widget moved: the old files go.
P="${WORK}/moved"
old_install "$P"
FAKE_REPLY="moved 2 left 0" run_move "$P" "${WORK}/bin"
old_gone "$P" || fail "old files kept after all widgets moved"

# A widget could not move: everything of the old id stays.
P="${WORK}/left"
old_install "$P"
FAKE_REPLY="moved 1 left 1" run_move "$P" "${WORK}/bin"
[[ -d "${P}/share/plasma/plasmoids/${OLD_ID_TEXT}" ]] || fail "old package removed while a widget still uses it"
[[ -d "${P}/lib/qml/com/github/shrippen/kurrent" ]] || fail "old QML module removed while a widget still uses it"
[[ -f "${P}/config/${OLD_ID_TEXT}/kurrentrc" ]] || fail "old config removed while a widget still uses it"

# Plasma answers but has not loaded its layout yet: everything stays.
P="${WORK}/starting"
old_install "$P"
FAKE_DESKTOPS=0 FAKE_REPLY="moved 0 left 0" run_move "$P" "${WORK}/bin"
[[ -d "${P}/share/plasma/plasmoids/${OLD_ID_TEXT}" ]] || fail "old package removed before Plasma loaded its layout"

# No Plasma to ask: everything stays.
P="${WORK}/noplasma"
old_install "$P"
FAKE_REPLY="" run_move "$P" "${WORK}/tools"
[[ -d "${P}/share/plasma/plasmoids/${OLD_ID_TEXT}" ]] || fail "old package removed without Plasma"

# Package gone already (removed by hand): leftovers of the old id go.
P="${WORK}/leftovers"
old_install "$P"
rm -rf "${P}/share/plasma/plasmoids/${OLD_ID_TEXT}"
FAKE_REPLY="" run_move "$P" "${WORK}/tools"
old_gone "$P" || fail "leftovers of the old id kept"

if [[ "$failures" -gt 0 ]]; then
    exit 1
fi
echo "id move: all checks passed"
