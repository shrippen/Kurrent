#!/bin/sh
# Release notes from CHANGELOG.md, shared by all projects (rule: shrippen.github.io/overview/PROJECTS.md,
# "Changelog on every landing page"). Source: tools/release-notes.sh in Kante, tested by
# tools/release-notes.test.sh. Projects carry an unchanged copy as scripts/release-notes.sh, made by
# Kante's tools/sync-release-notes.sh: change it only in Kante, then sync, never in a copy.
#
#   release-notes.sh 1.2.0 [CHANGELOG.md]   print the section of 1.2.0 (the release notes);
#                                            exit 1 if it is missing or empty
#   release-notes.sh --check [CHANGELOG.md]  check every heading; run it in CI on every push, so a
#                                            wrong heading shows up before the tag, not after it
#
# Format: one section per release, newest first, `## [1.2.0] — 2026-10-29` (an em dash), optionally
# `## [Unreleased]` on top. The section ends at the next `## ` heading; `###` and `####` stay inside.
# Other `## ` headings are allowed if they do not look like a version (e.g. "## Upstream history").
set -eu

if [ "${1:-}" = "--check" ]; then
    file="${2:-CHANGELOG.md}"
    [ -f "$file" ] || { echo "error: $file not found" >&2; exit 1; }
    awk -v file="$file" '
        function fail(msg) { printf "error: %s:%d: %s\n", file, NR, msg > "/dev/stderr"; bad = 1 }

        # The section before this heading must have text
        function close_section() {
            if (cur != "" && !text) { fail("section " cur " is empty") }
            cur = ""; text = 0
        }

        /^## / {
            close_section()
            h = substr($0, 4)
            if (h == "[Unreleased]") {
                if (versions) { fail("[Unreleased] must be the first section") }
                next
            }
            # A release: [1.2.0] — 2026-10-29
            if (match(h, /^\[[0-9][0-9A-Za-z.-]*\] — [0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]$/)) {
                v = substr(h, 2, index(h, "]") - 2)
                if (v in seen) { fail("version " v " twice") }
                seen[v] = 1; versions++; cur = v
                next
            }
            # Looks like a version but is not the format: "1.2.0", "v1.2", "[1.2.0](link)", "[1.2.0] 2026-…"
            if (h ~ /^\[?v?[0-9]/) { fail("heading \"" $0 "\" is not \"## [X.Y.Z] — YYYY-MM-DD\"") }
            next
        }
        cur != "" && /[^[:space:]]/ { text = 1 }
        END {
            close_section()
            if (!versions && !bad) { printf "%s: no release yet\n", file }
            else if (!bad) { printf "%s: %d release%s ok\n", file, versions, versions == 1 ? "" : "s" }
            exit bad
        }
    ' "$file"
    exit
fi

version="${1:?usage: release-notes.sh VERSION [CHANGELOG.md] | --check [CHANGELOG.md]}"
file="${2:-CHANGELOG.md}"
[ -f "$file" ] || { echo "error: $file not found" >&2; exit 1; }

# Exact match of "## [VERSION]" (index(), not a regex: "1.3" must not match "1.30" or "1.3.1"),
# blank lines at the start and end dropped
notes="$(awk -v head="## [$version]" '
    /^## / { if (on) { exit } if (index($0, head) == 1) { on = 1; next } }
    on
' "$file" | sed -e '/./,$!d')"

if [ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]; then
    echo "error: no notes for $version in $file (heading \"## [$version] — YYYY-MM-DD\")" >&2
    exit 1
fi
printf '%s\n' "$notes"
