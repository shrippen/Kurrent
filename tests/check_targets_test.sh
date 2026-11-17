#!/usr/bin/env bash
# Every test whose command is a built target must be in _kurrent_test_targets,
# so kurrent-check builds it before ctest runs (else ctest: "Not Run").
set -euo pipefail
CML="$(dirname "$0")/CMakeLists.txt"

listed=$(sed -n '/^set(_kurrent_test_targets/,/^)/p' "${CML}")
listed+=$'\n'$(grep -o 'list(APPEND _kurrent_test_targets [^)]*' "${CML}" || true)

missing=0
for target in $(grep -oE 'add_test\(NAME [^ ]+ COMMAND kurrent-[a-z0-9-]+-test' "${CML}" | awk '{print $4}'); do
    if ! grep -qw -- "${target}" <<<"${listed}"; then
        echo "missing in _kurrent_test_targets: ${target}"
        missing=1
    fi
done
exit "${missing}"
