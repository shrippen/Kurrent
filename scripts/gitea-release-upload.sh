#!/usr/bin/env bash
# Hängt Dateien an ein Gitea-Release (legt es an, falls es fehlt).
# Nutzung: gitea-release-upload.sh <tag> <datei>...
# Umgebung: GITEA_TOKEN, GITHUB_SERVER_URL, GITHUB_REPOSITORY (setzt der Runner).
set -euo pipefail

tag="$1"; shift
api="${GITHUB_SERVER_URL}/api/v1/repos/${GITHUB_REPOSITORY}"
auth=(-H "Authorization: token ${GITEA_TOKEN}")

json_field() { python3 -c "import sys,json; print(json.load(sys.stdin).get('$1',''))"; }

release_id="$(curl -fsS "${auth[@]}" "${api}/releases/tags/${tag}" 2>/dev/null | json_field id || true)"
if [ -z "${release_id}" ]; then
  release_id="$(curl -fsS "${auth[@]}" -H 'Content-Type: application/json' \
    -d "{\"tag_name\":\"${tag}\",\"name\":\"Kurrent ${tag#v}\"}" \
    "${api}/releases" | json_field id)"
fi

for f in "$@"; do
  name="$(basename "$f")"
  # vorhandenes Asset gleichen Namens ersetzen
  old="$(curl -fsS "${auth[@]}" "${api}/releases/${release_id}/assets" \
    | python3 -c "import sys,json; print(next((str(a['id']) for a in json.load(sys.stdin) if a['name']=='${name}'), ''))")"
  if [ -n "${old}" ]; then
    curl -fsS -X DELETE "${auth[@]}" "${api}/releases/${release_id}/assets/${old}"
  fi
  curl -fsS "${auth[@]}" -F "attachment=@${f}" \
    "${api}/releases/${release_id}/assets?name=${name}" >/dev/null
  echo "uploaded ${name} to ${tag}"
done
