# Review guide

Every PR is reviewed by a new Claude agent before it is merged (rule in
`agent.md`, owner 18.10.2026). The agent knows nothing of the session that
wrote the change: it gets the PR's intent, its diff and the repository, and
this file. The owner does not read code; this review is the second reader.

## What failure looks like here

Kurrent is a Plasma 6 widget over the user's Akonadi tasks, plus a
KRunner plugin (`krunner/`) and a terminal UI (`tui/`); the list applies
to all three. A bug that
matters is one the user loses data to or sees:

- **Loses data:** a write drops foreign `X-*` properties, the RRULE, a
  VALARM or a label; an older Akonadi revision brings a removed label
  back; completing a recurring task ends it instead of moving it on.
- **Blocks the desktop:** a synchronous Akonadi call or `Loader` on
  start, a plasmashell crash or hang, a missing plugin that shows "module
  is not installed" instead of `PluginMissingView`.
- **Shows the wrong tasks:** a view, filter, count or badge against
  `Design.md` (e.g. overdue tasks in Today), subtasks torn from a parent.
- **Looks broken:** an untranslated string, hover under the editor dim,
  an empty view without `Kirigami.PlaceholderMessage`, a broken narrow
  flyout; a `kurrentrc` key renamed or dropped, so settings are lost.
- **Lies:** `Design.md`, CHANGELOG, README or `to-test.md` vs. the code.

## What to check in particular

- Layers: QML calls `TaskController`, rules live in `TaskLogic`, writes go
  through `AbstractTaskStore`; QML never touches `SharedSettings`.
- Bug fixes: a test in `tests/` that fails without the fix; the cause
  removed, not hidden. CI only packages, it runs no unit tests: a PR that changes code (not only
  docs) names the result of `bash install.sh` on its latest commit;
  report a missing result.
- Kante GUI rule: no own colours, sizes or raw `#hex`; `ui/Kante*` only
  via `scripts/sync-kante.sh`. Visual changes update `Design.md` and
  `Design.qml`; new strings run `python3 po/generate_po.py`.
- `agent.md` code rules: braces always, early return, enums not bools,
  private by default (widening needs the owner's approval).
- `ReviewClaude.md` lists known findings in Swimlanes and Projektplan
  (15.09.2026); one of those is **Bestand** unless the PR touches it.

## What the owner confirms here

"What is published" (rule in `agent.md`) means here: a release (tag,
`.github/workflows/release.yml`), the packaging scripts
(`scripts/package-plasmoid.sh`, `scripts/package-linux-bin.sh`,
`install-linux.sh`) and the landing page `docs/index.html`.

## Skip

- `po/*.po` (generated); `ui/Kante/`, `ui/KantePlasma/` when synced.
- `docs/shots/`, `docs/social-preview.png`, `icons/`, `demo/world.json`.

## How to report

- Every finding names file and line and the concrete input or state that
  goes wrong. No guess without evidence; if unsure, say so.
- Each finding gets one label: **Wichtig** (a bug from the list above,
  must be fixed or answered before the merge), **Kleinigkeit** (optional,
  at most five) or **Bestand** (the bug was there before this PR; not
  blocking).
- The report starts with the count, e.g. "2 Wichtig, 1 Kleinigkeit" (the
  session puts the heading above it). The count of **Wichtig** holds every
  one still open, also from an earlier round, e.g. "1 Wichtig (offen aus
  Runde 1)". Only when none is open it says plainly: "Nichts zu beheben."
- In a later round: say for each open **Wichtig** of the last round whether
  it is fixed, or whether its answer is accepted, with the reason.
- Findings in German, code names as they are.
