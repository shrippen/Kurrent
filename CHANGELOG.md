# Changelog

## Unreleased

### Added

#### Styles: Plasma by default, Kante and Kante Light opt-in
- **Settings › Appearance › Style** with three preview cards: **Plasma (default)** follows the Plasma colour scheme like any KDE app; **Kante** applies the Kante palette (Gruvbox dark, or Leinen on a light colour scheme) with square controls, cut corners, Rajdhani titles and mono figures; **Kante Light** keeps Plasma's colours and controls and adds only Kante shapes and type.
- Built on the **Kante** QML module from shrippen.github.io (vendored under `contents/ui/Kante` and `contents/ui/KantePlasma`, fonts under SIL OFL): `KanteScope` for the widget, skins for menus, popups, dialogs, inline messages and check boxes, `KanteHeading` for view titles and Kanban columns, `KanteCard` for cards and the full editor.
- **Translucency in every style**: Kurrent never paints its own background, so a translucent / blurred Plasma background always shows through; Kante surfaces are tints on top. Only the panel flyout with blur off is opaque.
- **Accent switches** for project/label colours and priority colours.
- **Narrow layout**: below sidebar width + 24 grid units, views become tabs above the task pane with counters, and the sidebar opens on demand. The panel flyout now opens narrow by default (30 × 36 grid units).
- **Overdue notice** (inline message) in other views with "Move all to today" and "Show overdue"; can be turned off.
- Sidebar and tab **counters are badges** (red for overdue); Kanban column headers show the card count.
- **Panel badge** is a filled counter like Plasma's notification badge (negative colour for overdue).
- Quick Add tokens render as **tinted pills**.

#### Tiles and inspector (redesign direction B)
- **Tiles** above the task pane (wide layout): Overdue, Today, Tomorrow, Scheduled, Completed with counts and tone bars; a click switches the view. Per view: the heatmap shows its figures (total, per day, best day, overdue) in the tiles instead of a second row. Setting: Appearance › Wide layout.
- **Inspector** beside the task pane (wide layout): a click on a task in the list, Kanban or Swimlanes shows project/labels, status, properties, subtasks with progress and notes, with Done / Tomorrow / Next week / Editor actions. Double click still opens the full editor. It follows edits live and closes when the task disappears. Setting: Appearance › Wide layout.
- Backend: `taskSnapshotById()` and `childTasks()`; task snapshots now include all-day, recurrence preset and reminder, so the full editor opens correctly from Kanban cards and the inspector.

#### Redesign details (all styles unless noted)
- Task rows show label names (Plasma: tinted pills; Kante / Kante Light: `#name` in mono) and the project name next to its icon. Kante: the open check box carries the priority band in its frame.
- Header: "N open · M overdue" next to the view title (wide layout); active filters are chips with × that clear just that filter.
- Sidebar: sync status line ("Synced" / "Syncing…" / "Akonadi offline"); Kante and Kante Light add the brand head.
- List group headers: section label with a rule in Kante and Kante Light.
- Quick Add: primary button (highlighted in Plasma, accent square in Kante).
- Kanban: Plasma columns are tinted lanes; Kante / Kante Light columns get a colour bar (status, priority or overdue).
- Heatmap: facts row (total, per day, best day) for the shown period.

#### Review round
- Heatmap: compact square month cells with the count inside, legend below the grid, and a list of the selected day's tasks beside or below it (click opens the inspector or editor). Month / year and mode moved into the navigation row.
- Calendar: own tile figures (events, tasks due, next event, overdue); an empty day offers "Add task for this day"; "Today" is a text button.
- Overdue is shown once: with tiles the overdue tile carries "Move all to today" and the header drops its overdue count; the narrow layout shows a compact "N overdue" chip with both actions instead of the banner.
- Tile tones carry meaning only (overdue, today, completed; everything else muted). Zero counters are dimmed.
- Kante: the brand moves from the sidebar into the wide header.
- Sidebar: when a view hides sections (e.g. projects are the swimlane rows), a note at the bottom says why.
- List: edit buttons only on hover, gone while the inspector is shown; "Sync now" moved to the sync line in the sidebar; batch delete uses a select icon.
- Inspector: short due date with "in 3 days"; priority as flag plus plain text; label column fits the longest label; values with a picker (due, priority, project, status, progress, secrecy) open a menu; "Edit here" edits title, description and location in place; actions are "Done" plus icon buttons.
- Kanban: no edit button on cards (click → inspector or editor, double click → editor); empty columns fold into a narrow strip; option to hide the Canceled column; Kante shows priority only as the card bar; thin horizontal scroll bar on hover.
- Editor: title and status (segmented) at the top; "All day" hides the time fields; progress without scale; Kante radio buttons are diamonds; placeholders "Date" / "Time"; title field starts at the beginning.
- Swimlanes: cards per cell adapt so several lanes fit; Plan: legend right below the table, taller cells with a priority split bar.
- Narrow layout: arrows at the tab bar edges when more tabs exist.
- Settings: eight pages instead of twelve. General (Akonadi status with task app button, new-task defaults incl. reminder, behaviour), Appearance, Tasks (click action, live row preview, two-column chips, description preview), Sidebar, Views (Smart Views, Today day sections, Kanban, Swimlanes, Plan, Advanced), Panel & notifications (badge preview, test notification, quiet hours in one line), Organize (projects, labels, locations as tabs with one compact list: colour picker, inline rename, delete with count, default-project star), Diagnostics (widget and plugin version side by side).
- Settings layout: labels sit left of the fields on every page; left-aligned section heads; "Reset this page" on every page at the bottom left; consistent terms (Priorities, built-in view); relative dates on by default.
- Dates follow the system locale everywhere (day and month names were English); Kanban column names are translated; 120 missing strings translated in all five languages.
- Full editor (Kante): accent bar in the task's priority colour.
- Backend-missing page: Kante install card (title, cut corner, accent bar, primary copy button).

#### Screenshots for self-testing
- `tests/screenshot.sh` renders the widget offscreen into PNGs (every style × view × width, plus the full editor) — nothing appears on the desktop. `ScreenshotRunner.qml` is only active with `KURRENT_SCREENSHOT_DIR`.
- Kante skins and wrappers on every widget control (buttons, tool buttons, text fields, combo boxes, check boxes, radio buttons, slider), so Kante reaches into the editor and pickers; settings pages stay native.

### Changed
- Priority flag in task rows sits right before the due date.
- Kanban cards: Plasma style uses the Kirigami card look with a hover tint; Kante and Kante Light use a Kante card with the priority bar on top.
- View-mode toolbar: the active mode shows a highlight tint with a hairline border (Plasma) or an accent fill (Kante).

#### Swimlanes and Project plan — polish pass
- **Shared matrix grid**: pinned column and row headers (both axes), Kanban-style scrolling (wheel, thin bars, middle-click pan), current period highlighted, "jump to current period" button, columns use spare width.
- **Swimlanes hold task cards** (compact Kanban cards) and support **drag & drop**: dropping a card on another cell writes the lane field (project / label / priority / parent) and moves the due date into the target period, as a single undo step. Default column axis is now **Week**.
- **Horizon** for Swimlanes (new KCM option "Swimlane horizon", automatic by default) with **Overdue** and **Later** collector columns and a **No date** column; empty periods stay as drop targets. Project plan gets the same **Later** column instead of silently dropping far-future tasks.
- **Drill-down opens the list**: clicking a cell, row header or column header shows the list filtered to it with a filter chip in the header (click = back to the matrix, ✕ = clear). The matrix itself is no longer collapsed by the filter.
- **Header options** for both views (`view-grid` button): row axis, column bucket, look-ahead, and undated/completed for the plan — no more detour through the settings dialog.
- **Project plan cells**: heat relative to the busiest cell, red dot for overdue tasks, flag for high priority, richer tooltip, legend, projects sorted by name.
- Readable period headers ("Week 38 · 14.–20. Sep", "Today", month names), localized lane labels (no more raw keys or parent UIDs), empty states with `PlaceholderMessage`.

#### Swimlanes — performance
- Cells are virtualized: content is built only within a screen of the viewport, so switching the row axis or the time bucket no longer blocks the UI (measured on ~350 tasks: axis switch went from ~80 ms average / ~300 ms p90 stall to ~1 ms / ~5 ms).
- A cell shows at most 8 cards and collapses the rest into "+N more tasks"; the click still drills into the list.
- Viewport culling binds to a throttled scroll offset instead of the raw one, so scrolling no longer re-evaluates one binding per cell per pixel.
- Weekend columns are computed once per matrix instead of per cell.

### Fixed
- Settings › General: "Ask before deleting" toggled "Show completed tasks", and "Complete only with Shift or Ctrl" toggled "Ask before deleting".
- Settings showed no options: `config.qml` imported the generated dev-build marker as a directory, so the category list failed to load.
- Tasks completed in Kurrent had no completion date (COMPLETED), so the heatmap did not count them; completions after midnight UTC landed on the previous day.
- Translation catalogs were stale (the merge step failed on missing strings), and msgids with QML escapes (`\u201c`, `\"`) never matched at runtime.
- Switching away from Kante left invisible text (Kante module: after Kante the theme scope stays detached with colours bound live to the parent theme instead of resetting and re-attaching).
- View switches slid the leaving view under the sidebar (the task pane lost its clip when the inspector landed).
- Narrow layout: the view tab bar collapsed to 0 px (height binding loop).
- Kante: hovering the selected sidebar row turned the accent fill muddy brown; "All" chips had light text on the accent fill; priority flags vanished from the editor's priority options.
- The "today" reschedule preset (used when dropping a card into the Kanban "Today" column) left the due date unchanged.
- Settings › Appearance: the "Reduced motion" checkbox toggled the background blur setting instead.
- Swimlane cell click reset the sidebar view to "everything" instead of drilling down.
- Project plan cell click filtered the plan's own data down to one cell; the tooltip on plan cells never appeared (missing `hoverEnabled`); the plan ignored `interactionsSuspended`.
- Matrix views did not refresh after tasks changed (the matrix was computed once).
- ISO week keys used the calendar year, so days around New Year landed in the wrong week (e.g. 2027-01-01 is now `2026-W53`).
- Heatmap day click switched the main-pane mode in a way that was reset immediately.
- "KCURRENT" typo in five KCM strings (the property namespace is `KURRENT`).

## 0.4.0 — 2026-09-03

### Added

#### View modes
- **Swimlanes**: lane × time matrix with configurable axes (Project, Label, Priority, Parent task × Day/Week/Month)
- **Project plan**: project × time grid with configurable time bucket (Day/Week/Month), planning horizon (0–52), consolidated overdue column, undated tasks column, optional completed task display
- **Heatmap**: day cells toggled by due date / completions
- **Calendar + tasks**: event chips + tasks for selected day; Day/Week mode

#### Smart Views
- Filter bug fixed: `projectId` parsed to 0 instead of -1 when key was missing → smart views showed no results
- Smart views count correctly in sidebar badges (computed on load, not on click)
- Dedicated "Smart Views" folder in sidebar (below Maintenance) with badge and navigation
- Alphabetical sorting of smart views in sidebar and KCM
- KCM Views: section order corrected — Smart Views above Kanban

#### KCM Views — Swimlanes
- Row axis: Project / Label / Priority / Parent task
- Column axis: Day / Week / Month

#### KCM Views — Project plan
- Time grouping: Day / Week / Month
- Planning horizon: 0–52 periods (0 = unlimited)
- Show undated tasks (own column)
- Show completed tasks (optional)

#### Merge conflict dialog
- Wizard style: one field at a time, Kurrent/Akonadi columns, chip rendering
- Overlay card (like FullEditor), D-Bus `testMergeConflict` for testing
- Null guards, auto-resolve, stale echo guard

#### Other
- Project chip in task delegate (visible when no project filter active)
- Diagnostics KCM visible in dev builds only (`DevBuildMarker.qml` generated via CMake)
- Auto-check allDay when date is entered without a time
- Quick-add: full editor opens when button is clicked with empty text

### Fixed

- Smart View editor: replaced free-text fields with dropdowns (Project, Label, Status, Due, Priority)
- `upsertTask`: reject revision-0 monitor updates when cache has a real revision
- `persistTodo`: refetch before modify when revision is 0
- `configViews.qml`: dialog content fills dialog space correctly (anchors.fill instead of Layout)
- Sidebar: smart view counts precomputed (not only on click)
- `computeCounts`: smart view badge count calculated correctly; `matchesViewFilter` delegates to smart rules

### Changed

- CalendarAgendaView: stable toolbar with fixed label width, icon-only Today button, animated Day/Week toggle
- Chunked model application for smoother animations
- Sidebar highlight animation, dimming removed
- Calendar event integration (opaque/busy events)
- Version 0.4.0 (CMakeLists.txt + metadata.json)

### Tests

- `planMatrixGridOverdueConsolidationAndHorizon`: overdue consolidation, horizon clipping, showCompleted, undated, day-bucket
- `smartViewFilterAppliesInComputeCounts`: smart view rules affect sidebar counts
- All 69 tests passing (100%)

### Not yet manually tested

> The following features are implemented and unit-tested but have not been manually verified in a live environment.

- **Merge conflict dialog**: wizard flow, DBus test, editor integration
- **Multi-select + bulk actions**: complete/delete/reschedule/move/copy UIDs
- **KRunner**: `task today`, `task <search>`, add task
- **Global shortcuts**: Meta+Shift+K/N, D-Bus show/addTask
- **Offline/syncing banner**: Akonadi offline (red), Syncing… (yellow)
- **i18n**: German strings for new swimlanes/plan options; fallback checks in de/es/fr/ja/zh_CN

## 0.3.1 — 2026-08-29

### Fixed

- i18n catalog completion: all 304 QML strings now translated for de, es, fr, ja, zh_CN (was ~166; ~158 fell back to English at runtime)
- `generate_po.py` auto-extracts msgids from QML and fails on missing per-locale translations

## 0.3 — 2026-08-29

### Added

- Search/sidebar filters keep the full *open* task tree; completed tasks only in Completed view (with open parents rescued)
- Sort popup stays open for multi-level edits; default Priority › Due › A–Z; opposite directions mutually exclusive; removed opaque “Default”
- Sort persistence: global or per-view scope (Tasks KCM); stored in `Plasmoid.configuration` / shared `kurrentrc`; default `priority,due,title` when unset
- Sort keys: due latest-first, start date, reminder/recurring first|last, progress % low|high
- Overdue view: `chronometer` icon (replaces missing `appointment-missed`); “Overdue” translated
- Due date/time in task row chip line: right-aligned accent text (overdue stays negative)
- Full editor: pick any same-project task as parent (`ParentPicker` search field like labels)
- Notifications KCM: optionally suppress reminders during ongoing calendar events; pick which Akonadi event calendars count (opaque/busy events only)
- Panel KCM: badge modes tomorrow and high priority; dot instead of number; overdue badge color (accent vs negative); configurable panel tooltip (open, today, today+overdue, overdue, high, all views)
- Panel flyout preloads at applet startup (`preloadFullRepresentation: true`; `FullView.qml` loads async once the plugin is ready)
- Boot loader: Breeze gear icon (`boot-gear.svg`, from `process-working-symbolic`) while plugin / FullView load
- Backend version mismatch banner: widget compares `metadata.json` to `TaskController.pluginVersion`; warning in FullView and General KCM with reinstall one-liner (KDE Store widget + outdated `~/.local` plugin)
- i18n catalog gap fill: ~129 UI/C++ strings (sort keys, ParentPicker, settings pages, notifications, parent errors) for de/es/fr/ja/zh_CN

### Fixed

- Panel startup: load `PluginBackend` asynchronously so the compact icon is not blocked on `libkurrentplugin.so`; keep task cache during Akonadi fetch (no empty badge flash)
- Flyout opens immediately with boot loader; FullView loads async; indeterminate progress while Akonadi connects / tasks load
- Today Catch-up (“Still open”) includes all overdue incomplete tasks (same set as the Overdue view), not only those within the former catch-up lookback window
- Sort menu radios no longer stick on “None” for levels 2–3
- Due dates missing in list chip and editor (#2): Qt 6 Date has no `isValid`; use `DateTime.isValidDate()` (`getTime()` / format fallback) instead of `task.dueDate.isValid === true`
- `install-linux.sh` Debian/Ubuntu build deps (#1): `libkirigami-dev` (not `libkf6kirigami-dev`)
- Panel KCM category icon: `plasmashell` (Breeze has no generic `panel` icon)
- Remove Panel KCM flyout width/height (Plasma persists popup size via drag-resize)
- Full editor project radios: folder icon sits beside the name (not under the radio circle)
- Quick Add: long text wraps and the field grows (capped at `quickAddMaxLines`); scrolls internally beyond that; Enter still adds, Shift+Enter inserts a newline
- Parent picker: TextField stays focusable for typing; label vertically centered; suggestions open upward (height clamped to space above); priority/tag chips before task name
- Sidebar KCM reorder: keep dragging across multiple positions; persist order on drop
- Inline editor: closes on view/filter/search/sort change, drag start, or when the task leaves the list
- Inline editor: full delegate width flush with row hover; short unfold animation on open
- Task list scroll: `Kirigami.WheelHandler` (same as Kirigami apps); removed custom `KineticScrollHandler`
- Sort popup scroll: same `Kirigami.WheelHandler` + `OvershootBounds` / `returnToBounds` as the task list
- Join button: first chip in the status row (before date/labels/priority); tooltip „Open / Join“ (+ translations)
- Task list: touchpad overshoot rebounds (`OvershootBounds` + `returnToBounds` after wheel/flick)
- Collapse: omit descendants from flat list so scrollbar matches visible rows; reserved collapse-arrow column + indent hierarchy
- Task list: `reuseItems`, larger `cacheBuffer`; hover suppressed via `wheelScrolling`
- Smoke test: process-wide step/leader so recreated FullView continues; faster ticks; 30s timeout; lib64 QML path
- Sidebar near-fit: grant full natural height when shortfall is at most one row; steal from sections that overflow more
- Sidebar scrollbars visible on overflow; bar fits in fixed `spaceSmall` margin
- Sidebar section heights: proportional when short; `sectionsAllocated` instead of `-1` sentinel
- Sidebar task counts stable when collapsing (default); optional “Exclude collapsed subtasks from counts”

### Architecture

- `AbstractTaskStore` boundary for task CRUD: `AkonadiTaskStore` (live) and `MemoryTaskStore` (unit tests, no Akonadi server). Optimistic UI + rollback stay in `TaskController` (cache, inflight, revertTodo)
- Unit test `kurrent-taskstore` covers create/modify/move/delete and forced failure

### Code quality (agent.md)

- View ids, reschedule presets, priority bands as named constants; DaySpan/CursorKind/LoadState enums instead of bool params in TaskLogic
- `TaskListModel::dataDiffRoles` always uses braces
- QML spacing uses `Design.space*` / pads instead of raw `Kirigami.Units.*Spacing`

### Installer

- `install-linux.sh`: chown `~/.local` before copy; drop `kpackagetool6` for plasmoid install/update; legacy cleanup via `rm -rf`; verify file ownership after install; warn when not run via `sudo`; clearer fallback messages for incompatible prebuilt plugins
- `install-linux.sh`: hard Plasma 6 / Qt 6 / KF6 gate (`check_plasma6_env`) before deps or binary install; unknown distros warn and ask to continue (`confirm_unknown_distro`; auto-continues when non-interactive)
- `install-linux.sh`: immutable/atomic distro detection (`warn_immutable_distro`) with rpm-ostree, transactional-update, and Toolbx/Distrobox guidance; interactive continue prompt (auto-continues when non-interactive)
- `install-linux.sh`: Debian/Ubuntu Akonadi runtime packages; Fedora `akonadi-server`/`akonadi-calendar` without silent failure; `lib64/qml` in QML env (Fedora/RHEL source installs)
- `install.sh`: same plasmoid install path as the release installer (cmake install + verify, no `kpackagetool6`); `lib64/qml` in QML env helper

## 0.2.2 — 2026-08-22

Installer fix release.

- Fix `install-linux.sh` updates deleting the plasmoid (`kpackagetool6 -u` on the install path removed the widget; updates now copy files in place)
- Fix root-owned files under `~/.local` when installing via `sudo bash` (`cp --no-preserve=ownership` + `chown`)

## 0.2.1 — 2026-08-19

Bug-fix release.

- Fix QuickAdd highlight overlay shifting left when typing
- Fix double-text ghost layer when selecting text in QuickAdd (Ctrl+A)
- Fix smoke test never starting (QML scope shadowing made backend null)
- Fix smoke test skipping the first post-view step (off-by-one in switch cases)
- Landing page: Rajdhani heading font
- Design.md: reference shared DesignDefault repo

## 0.2.0 — 2026-08-18

Catch-up on the 1.0 branch: planner-style task flow, a full settings dialog, notifications, and a faster panel startup.

- GitHub Releases attach `kurrent-linux-x86_64.tar.gz` and `install-linux.sh` next to the `.plasmoid`; the one-liner installs the plugin into `~/.local` (`--from-source` if the `.so` does not match the distro)

- Today no longer mixes overdue into “due today”; Catch-up (“Still open”) and an Overdue sidebar view
- Reschedule from the task row (15m / 1h / 4h / tomorrow / next week)
- Morning / afternoon / evening grouping and a list section field in the editor
- Join button for http(s) links; quick add (`tomorrow 18:00 !high #tag`)
- Completing a recurring task advances the series without dropping the RRULE
- Sort mode, catch-up, day-part hours, and Join persist in shared settings
- Settings shell: Appearance, Sidebar, Tasks, Editor, Panel, Notifications, Projects, and Labels pages; per-page reset; density and sidebar width tokens
- Settings forms use `ConfigFormShell` (centered, width-capped). `SimpleKCM` scrolls; no nested Flickable
- Shortcuts live in Plasma System Settings (no dedicated KCM); sync is manual (interval setting removed)
- Sidebar section/view order in settings via drag-and-drop
- Empty states for Akonadi offline, no calendars, and empty views
- One-step undo (complete / reschedule / move / delete), collapse subtask trees
- Panel badge (open / today / overdue) and flyout size; default due date; confirm row delete
- VALARM reminders in the editor, Plasma notifications with snooze, optional quiet hours
- Rename labels; complete parent can complete children; per-project and per-label color overrides
- Keyboard in the widget plus global Meta+Shift+K / Meta+Shift+N (D-Bus `org.github.shrippen.Kurrent`)
- Relative due chips
- Panel startup: non-blocking Akonadi start (`ServerManager::start()`, never `Control::start()`); cache can fill the badge/list immediately
- Panel flyout preloads at applet startup (`preloadFullRepresentation: true`; `FullView.qml` loads async once the plugin is ready, not on first click)

## 0.1.0 — 2026-08-17

First public release of **Kurrent**, a KDE Plasma 6 task manager plasmoid.

- Inbox, Today, Tomorrow, Scheduled, Anytime, Recurring, Unlabeled, and Completed views
- Projects, labels, and priorities from Akonadi / Nextcloud CalDAV
- Create, edit, complete, delete, subtasks, and drag-and-drop
- Full editor overlay inside the widget and compact inline editor
- Shared settings between desktop widget and panel flyout (`~/.config/com.github.shrippen.kurrent/kurrentrc`)
- Optional Plasma wallpaper blur on desktop and panel popup
- German, Spanish, French, Japanese, and Simplified Chinese translations
