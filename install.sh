#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT}/build"
PREFIX="${PREFIX:-${HOME}/.local}"
BUILD_TESTING="${BUILD_TESTING:-ON}"
if [[ "${SKIP_TESTS:-0}" == "1" ]]; then
    BUILD_TESTING="OFF"
fi

restart_plasmashell() {
    if [[ "${SKIP_PLASMA_RESTART:-0}" == "1" ]]; then
        echo "Skipping plasmashell restart (SKIP_PLASMA_RESTART=1)."
        return 0
    fi

    if ! command -v plasmashell >/dev/null 2>&1; then
        echo "plasmashell not found; skipping restart."
        return 0
    fi

    if ! pgrep -x plasmashell >/dev/null 2>&1; then
        echo "plasmashell is not running; skipping restart."
        return 0
    fi

    export QML_IMPORT_PATH="${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml${QML_IMPORT_PATH:+:${QML_IMPORT_PATH}}"
    export QML2_IMPORT_PATH="${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"

    echo "Restarting plasmashell..."
    kquitapp6 plasmashell 2>/dev/null || true
    sleep 1
    nohup plasmashell --replace >/dev/null 2>&1 &
    disown >/dev/null 2>&1 || true
    echo "plasmashell restarted."
}

mkdir -p "${BUILD_DIR}"
cmake -S "${ROOT}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=OFF \
    -DKURRENT_DEV_BUILD="${KURRENT_DEV_BUILD:-ON}" \
    -DBUILD_TESTING="${BUILD_TESTING}"

cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
    echo "Running unit tests..."
    ctest --test-dir "${BUILD_DIR}" --output-on-failure -E kurrent-plasmoidviewer
fi
cmake --install "${BUILD_DIR}"

for _old_id in org.planify.plasmoid org.kde.kurrent; do
    kpackagetool6 -t Plasma/Applet -r "${_old_id}" 2>/dev/null || true
done
rm -rf \
    "${PREFIX}/lib/qml/org/planify" "${PREFIX}/share/qt6/qml/org/planify" \
    "${PREFIX}/share/plasma/plasmoids/org.planify.plasmoid" \
    "${PREFIX}/lib/qml/org/kde/kurrent" "${PREFIX}/share/qt6/qml/org/kde/kurrent" \
    "${PREFIX}/share/plasma/plasmoids/org.kde.kurrent" || true
rm -f "${HOME}/.config/plasma-workspace/env/planify-qml.sh"

kpackagetool6 -t Plasma/Applet -i "${ROOT}/plasmoid/com.github.shrippen.kurrent" || \
    kpackagetool6 -t Plasma/Applet -u "${ROOT}/plasmoid/com.github.shrippen.kurrent"

echo "Installed Kurrent plasmoid and QML plugin to ${PREFIX}"

if [[ "${SKIP_TESTS:-0}" != "1" && "${SKIP_PLASMOIDVIEWER:-0}" != "1" ]]; then
    echo "Running plasmoidviewer smoke tests..."
    PREFIX="${PREFIX}" "${ROOT}/tests/plasmoidviewer_smoke.sh"
fi

ENV_DIR="${HOME}/.config/plasma-workspace/env"
mkdir -p "${ENV_DIR}"
cat > "${ENV_DIR}/kurrent-qml.sh" <<EOF
export QML_IMPORT_PATH="${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="${PREFIX}/lib/qml:${PREFIX}/share/qt6/qml\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}"
EOF
echo "Wrote QML import path helper: ${ENV_DIR}/kurrent-qml.sh"

restart_plasmashell
