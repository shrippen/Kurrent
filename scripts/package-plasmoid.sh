#!/usr/bin/env bash
# Build a KPackage .plasmoid zip for KDE Store / Get New Widgets / kpackagetool6.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
META="${ROOT}/plasmoid/com.github.shrippen.kurrent/metadata.json"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Version"])' "${META}")"
ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Id"])' "${META}")"

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
PKG="${STAGE}/${ID}"
mkdir -p "${PKG}"

cp "${META}" "${PKG}/metadata.json"
cp -a "${ROOT}/plasmoid/com.github.shrippen.kurrent/contents" "${PKG}/contents"
cp "${ROOT}/LICENSE" "${PKG}/LICENSE"

if command -v msgfmt >/dev/null 2>&1; then
    shopt -s nullglob
    for po in "${ROOT}/po/"*.po; do
        lang="$(basename "${po}" .po)"
        dest="${PKG}/contents/locale/${lang}/LC_MESSAGES"
        mkdir -p "${dest}"
        msgfmt -o "${dest}/plasma_applet_${ID}.mo" "${po}"
    done
    shopt -u nullglob
fi

mkdir -p "${ROOT}/dist"
OUT="${ROOT}/dist/${ID}-${VERSION}.plasmoid"
rm -f "${OUT}"
(
    cd "${PKG}"
    zip -qr "${OUT}" metadata.json contents LICENSE
)

echo "${OUT}"
