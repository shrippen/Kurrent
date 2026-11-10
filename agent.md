# Working rules for this repository

The rules for all shrippen repositories are in `RULES.md` (writing, code, commits, bug
fixes, repository, GUI). It is a synced copy from the rules repository; do not edit it
here. This file holds only what is particular to this repository. A Claude Code session on
the owner's machine has the rules through the global `CLAUDE.md` already and reads
`RULES.md` only for its GUI rule, before work on a user interface.

## Rules of this project

- After every code change, run `bash install.sh` (full build, unit tests, plasmoidviewer smoke tests, install, plasmashell restart). Do not proceed until all tests pass. The script takes ~2 minutes end-to-end; set command timeout accordingly.

- UI changes: check them visually with `tests/screenshot.sh [OUT_DIR]` (offscreen PNGs of every style × view × width, plus the editor; `KURRENT_SCREENSHOT_PLAN` narrows it). Never screenshot the desktop.

- Never push automatically. Always ask for permission before pushing to remote.

- Changelogs and release notes are written in English first, regardless of the conversation language, followed by the same notes in German (the landing page is bilingual).

## Release

Release steps: `RELEASE.md`. Before a release, load the skill `release-changelog`. A release
is published, so the owner confirms it in words.

## Repository (this project)

- CI runs on the GitHub mirror (`.github/workflows/tests.yml`, since 16.10.2026) and reports back to Gitea as the commit status `github / test`.
- The merge waits for: CI is green on the PR's latest commit: every CI check that runs on each push (such as `github / test` from the GitHub mirror) shows success there. No status there yet means wait, not merge; if it never comes, check the mirror or ask the owner. PR-Agent's status does not count here. Without CI, the local checks count.
- Everything else: `RULES.md` (Repository) and the skill `pr-review`.
