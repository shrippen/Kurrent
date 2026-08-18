#!/usr/bin/env bash
# Build a relocatable plugin+plasmoid tree (lib/ + share/) for ~/.local.
# Output: dist/kurrent-<version>-linux-<arch>.tar.gz
#         dist/kurrent-linux-<arch>.tar.gz  (stable name for releases/latest/download)
set -euo pipefail

ROOT="$(cd "${KURRENT_SRC:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd)"
META="${ROOT}/plasmoid/com.github.shrippen.kurrent/metadata.json"
ARCH="$(uname -m)"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Version"])' "${META}")"

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
BUILD="${STAGE}/build"
DEST="${STAGE}/dest"

cmake -S "${ROOT}" -B "${BUILD}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${DEST}" \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=OFF \
    -DKURRENT_DEV_BUILD=OFF \
    -DBUILD_TESTING=OFF

cmake --build "${BUILD}" --parallel "$(nproc)"
cmake --install "${BUILD}"

if command -v strip >/dev/null 2>&1; then
    find "${DEST}" -type f -name 'libkurrentplugin.so' -exec strip --strip-unneeded {} +
fi

SO="$(find "${DEST}" -name 'libkurrentplugin.so' -print -quit)"
if [[ -z "${SO}" ]]; then
    echo "libkurrentplugin.so missing after install" >&2
    exit 1
fi

mkdir -p "${ROOT}/dist"
VERSIONED="${ROOT}/dist/kurrent-${VERSION}-linux-${ARCH}.tar.gz"
STABLE="${ROOT}/dist/kurrent-linux-${ARCH}.tar.gz"
rm -f "${VERSIONED}" "${STABLE}"

# Tarball root is lib/ and share/ so extracting into ~/.local overlays the prefix.
tar -C "${DEST}" -czf "${VERSIONED}" lib share
cp -a "${VERSIONED}" "${STABLE}"

echo "${VERSIONED}"
echo "${STABLE}"
