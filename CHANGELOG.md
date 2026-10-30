# Changelog

## [Unreleased]

### Added

#### Terminal client
- **`kurrent-tui`**: Kurrent in a terminal, installed next to the widget. Now, Soon and Someday as one list; `x` done, `t` today, `m` tomorrow, `d` someday, `a` adds with Quick Add, `/` searches, `g` goes through overdue tasks one at a time (↑ done, → today, ← tomorrow, ↓ someday). Same tasks through Akonadi as the widget; the widget keeps the D-Bus name and the global shortcuts.

#### Sidebar
- The views (Inbox, Today, Overdue, …, Maintenance) always get their full height; projects, labels and the other sections share the rest and scroll. Before, every section got an equal share and the last views were only reachable by scrolling.
- **Settings › Sidebar › Row size › Dense (more rows)**: Kante's dense list rows (24 px) for long sidebars, opt-in.

#### Styles: Plasma by default, Kante and Kante Light opt-in
- **Settings › Appearance › Style** with three preview cards: **Plasma (default)** follows the Plasma colour scheme like any KDE app; **Kante** applies the Kante palette (Gruvbox dark, or Leinen on a light colour scheme) with square controls, cut corners, Rajdhani titles and mono figures; **Kante Light** keeps Plasma's colours and controls and adds only Kante shapes and type.
- Built on the **Kante** QML module from shrippen.github.io (vendored under `contents/ui/Kante` and `contents/ui/KantePlasma`, fonts under SIL OFL): `KanteScope` for the widget, skins for menus, popups, dialogs, inline messages and check boxes, `KanteHeading` for view titles and Kanban columns, `KanteCard` for cards and the full editor.
- Kante 1.6: narrow-layout tabs (`KanteTabBar`), multi-select bar (`KanteBulkBar`), date picker (`KanteCalendarGrid`) and colour override swatches (`KanteSwatch`) come from the module.
- Kante 1.7: labels in task rows and picked labels in the editor (removable) are `KanteChip` in Kante and Kante Light.
- Kante 1.8: header filter chips are `KanteChip` with the filter icon (the name elides, then drops); Kanban cards and the agenda show labels as compact chips.
- Kante 1.9: the whole sidebar draws `KanteListRow`s (red Overdue count, chevron on folder rows); labels in the editor use `KanteTagPicker` (suggestions open above the field and stay in the window). Fix: Kanban card titles were near-black with Kante dark on a light desktop.
- Kante 1.56: the module is current again (it was on 1.13). In the Kante style combo boxes draw their arrow as a shape, set their value in from the frame and are wide enough for their longest entry (the editor's project picker keeps the full width); the heatmap's mode box gives way in a narrow popup. Leinen's positive green is a little darker, disabled controls take Kante's colours, and menus and inline messages draw their card behind the platform frame. In Kante Light the primary buttons (add at quick add, Done/Reopen and Save while editing in the inspector, Copy command when the plugin is missing, the chosen version in the conflict dialog) are filled in the accent with cut corners, so they stand out. Return presses a focused Kante button, not only Space.
- **Translucency in every style**: Kurrent never paints its own background, so a translucent / blurred Plasma background always shows through; Kante surfaces are tints on top. Only the panel flyout with blur off is opaque.
- **Accent switches** for project/label colours and priority colours.
- **Narrow layout**: below sidebar width + 24 grid units, views become tabs above the task pane with counters, and the sidebar opens on demand. The panel flyout now opens narrow by default (30 × 36 grid units).
- **Overdue notice** (inline message) in other views with "Move all to today" and "Show overdue"; can be turned off.
- Sidebar and tab **counters are badges** (red for overdue); Kanban column headers show the card count.
- **Panel badge** is a filled counter like Plasma's notification badge (negative colour for overdue).
- Quick Add tokens render as **tinted pills**.

#### Agenda: day view with hour grids
- **Calendar › Day** shows 14 days from the picked date, each as an hour grid (07–22, longer on a day with something earlier or later, such as a night shoot until midnight): appointments stay fixed, tasks with a start and end time on the same day are blocks, free gaps of 30 minutes and more until 18:00 show in green (today from now on, and the now line moves with the clock). Days with nothing on them fold into one line; dropping a task there puts it on the first of those days. A block that another app ends at midnight (00:00 the next day) stays on its day.
- **Plan by dragging**: drop a task on a day's grid and it lands in the next free stretch long enough for it (late in the evening, in the free time just before) (a block keeps its length; otherwise 60, 45 or 30 minutes by priority). Drop it under "No time" or use "→ day" to keep it on the day without a time. Click a block to get grips at its top and bottom edge; they move in 15-minute steps and stop at the neighbouring appointment or task. Everything can be undone.
- **Suggestions** for the target day (click a day's header to pick it), most relevant first in three tiers: overdue tasks (the longer, the higher), tasks due within a week after the day (the sooner, the higher), undated top-level tasks; high priority and "fits the largest gap" add to it. Each suggestion says why.
- A month calendar with dots for appointments, tasks and overdue tasks (with a legend, also in the Kante style) picks the first day. In a narrow widget, such as the panel flyout, the calendar and the suggestions are left out and a day's header picks nothing.

#### Agenda: week board, month and a view switcher
- **Day | Week | Month** at the front of the Agenda's date bar; ‹ › step by a day, a week or a month, the title names the calendar week, Today is off when you are on today. One date for all three views; the view and the weekend switch are remembered. Click a weekday in the week, a day number in the month or "Open day →" to open that day. Keys: T, W, M, ← →, H, while Kurrent has the focus (on the desktop they leave the folder view alone).
- **Week**: one column per day (weekend narrower) with appointments (no box: a stripe in the calendar's colour, start and end in a time column, the title in full text colour; the month and its day panel show them the same way), open tasks as dense cards and a load bar (appointments plus task time against the workday, orange when over; the workday is 8 hours unless set otherwise in Settings › Views › Agenda, in half-hour steps). Done tasks fold into "✓ N done", empty days say "free", + adds a task for the day. Overdue tasks wait in a tray above the week with "All to today", which moves them like a drop on today (times stay); past days only point there. Drop a card on a day to move it; its time stays.
- **Month**: six weeks, tinted by how full each day is, up to three entries per day and "+n more", overdue in red. Click a day for the detail panel with its appointments, tasks and a quick-add field; drop a task on a day to move it.
- **Add tasks** in the Agenda with the same Quick Add as the list (dates, !priority, #labels, @project, and the project choice when needed). In the day view, click free time: a task ghost opens there with Quick Add and Enter plans the task in that hour. In the week (+) and the month panel the task lands on the day unless the text names a date.
- The tiles above the pane and the overdue notice are gone from the Agenda; it shows overdue tasks itself.

#### Tiles and inspector (redesign direction B)
- **Tiles** above the task pane (wide layout): Overdue, Today, Tomorrow, Scheduled, Completed with counts and tone bars; a click switches the view. Per view: the heatmap shows its figures (total, per day, best day, overdue) in the tiles instead of a second row. Setting: Appearance › Wide layout.
- **Inspector** beside the task pane (wide layout): a click on a task in the list, Kanban or Swimlanes shows project/labels, status, properties, subtasks with progress and notes, with Done / Tomorrow / Next week / Editor actions. Double click still opens the full editor. It follows edits live and closes when the task disappears. Setting: Appearance › Wide layout.
- Backend: `taskSnapshotById()` and `childTasks()`; task snapshots now include all-day, recurrence preset and reminder, so the full editor opens correctly from Kanban cards and the inspector.

#### Redesign details (all styles unless noted)
- Task rows show label names (Plasma: tinted pills; Kante / Kante Light: `KanteChip`) and the project name next to its icon. Kante: the open check box carries the priority band in its frame.
- Header: "N open · M overdue" next to the view title (wide layout); active filters are chips with × that clear just that filter.
- Sidebar: sync status line ("Synced" / "Syncing…" / "Akonadi offline"); Kante and Kante Light add the brand head.
- List group headers: section label with a rule in Kante and Kante Light.
- Quick Add: primary button (highlighted in Plasma, accent square in Kante).
- Kanban: Plasma columns are tinted lanes; Kante / Kante Light columns get a colour bar (status, priority or overdue).
- Heatmap: facts row (total, per day, best day) for the shown period.

#### Review round
- Heatmap: compact square month cells with the count inside, legend below the grid, and a list of the selected day's tasks beside or below it (click opens the inspector or editor). Month / year and mode moved into the navigation row.
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
- Project plan options (columns, look ahead, undated and completed tasks) are shared by all Kurrent widgets, like every other setting. The first start keeps each widget's current values.

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
- Completing a recurring task after moving it to another day moves it on to its next occurrence on the series' usual day. Before, it stayed open on the moved day and the series could shift to that weekday.
- Overdue means the same everywhere: an open task due before today, as in the Overdue view. Task rows no longer show the due date of completed tasks in red, and the inspector no longer marks tasks due earlier today as overdue.
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

## [0.4.0] — 2026-09-03

### English

Four new ways to look at your tasks: Swimlanes, a Project plan, a Heatmap and Calendar with tasks. Smart Views finally show their results and counts, and edits that clash with a sync now ask you which version to keep.

#### New
- Swimlanes: tasks in a lane × time matrix; rows by project, label, priority or parent task, columns by day, week or month.
- Project plan: projects × time, with a planning horizon (0–52 periods), one column for overdue tasks, an optional column for undated tasks and optional completed tasks.
- Heatmap: one cell per day, counting tasks due or tasks completed.
- Calendar with tasks: the day's events as chips next to its tasks, in a day or week mode.
- Smart Views have their own folder in the sidebar, with a count badge, sorted by name.
- Merge conflict dialog: when a task was changed in Kurrent and elsewhere at the same time, Kurrent goes through the differing fields one at a time and lets you pick the Kurrent or the Akonadi value.
- Settings › Views: options for Swimlanes (row and column axis) and the Project plan (time grouping, horizon, undated and completed tasks).
- Task rows show their project when no project filter is active.

#### Improved
- The Smart View editor offers drop-downs for project, label, status, due date and priority instead of free-text fields.
- Entering a date without a time ticks "All day" automatically.
- Clicking the Quick Add button with an empty field opens the full editor.
- Calendar view: a steady toolbar, an icon-only Today button and an animated Day/Week switch.
- Smoother animations when the list changes; the sidebar highlight slides instead of dimming.

#### Fixed
- Smart Views showed no tasks when they had no project rule, and their sidebar counts only appeared after a click.
- A stale sync echo could overwrite a task you had just edited; Kurrent now ignores it and refetches before saving.
- The Views settings dialog did not fill its space.

#### Note
- The merge conflict dialog, multi-select bulk actions, KRunner, the global shortcuts and the offline/syncing banner are covered by tests but were not yet checked by hand in a live session.

All changes: https://github.com/shrippen/Kurrent/compare/v0.3.1...v0.4.0

### Deutsch

Vier neue Ansichten auf die Aufgaben: Swimlanes, ein Projektplan, eine Heatmap und Kalender mit Aufgaben. Intelligente Ansichten zeigen endlich ihre Treffer und Zähler, und Änderungen, die mit einer Synchronisation kollidieren, fragen jetzt, welche Fassung bleiben soll.

#### Neu
- Swimlanes: Aufgaben in einer Matrix aus Bahnen × Zeit; Zeilen nach Projekt, Label, Priorität oder übergeordneter Aufgabe, Spalten nach Tag, Woche oder Monat.
- Projektplan: Projekte × Zeit, mit Planungshorizont (0–52 Zeiträume), einer Spalte für Überfälliges, wahlweise einer Spalte für Aufgaben ohne Datum und erledigten Aufgaben.
- Heatmap: eine Zelle je Tag, gezählt nach fälligen oder erledigten Aufgaben.
- Kalender mit Aufgaben: die Termine des Tages als Chips neben seinen Aufgaben, als Tag oder Woche.
- Intelligente Ansichten haben einen eigenen Ordner in der Seitenleiste, mit Zähler und nach Namen sortiert.
- Dialog für Konflikte: Wurde eine Aufgabe zugleich in Kurrent und anderswo geändert, geht Kurrent die abweichenden Felder einzeln durch und lässt den Wert aus Kurrent oder aus Akonadi wählen.
- Einstellungen › Ansichten: Optionen für Swimlanes (Zeilen- und Spaltenachse) und den Projektplan (Zeiteinteilung, Horizont, Aufgaben ohne Datum und erledigte).
- Aufgabenzeilen zeigen ihr Projekt, solange kein Projektfilter aktiv ist.

#### Verbessert
- Der Editor für intelligente Ansichten bietet Auswahllisten für Projekt, Label, Status, Fälligkeit und Priorität statt Freitextfeldern.
- Ein Datum ohne Uhrzeit setzt „Ganztägig“ von selbst.
- Ein Klick auf den Schnelleingabe-Knopf bei leerem Feld öffnet den vollen Editor.
- Kalenderansicht: eine ruhige Werkzeugleiste, ein Heute-Knopf nur mit Symbol und ein animierter Tag/Woche-Schalter.
- Flüssigere Animationen, wenn sich die Liste ändert; die Markierung in der Seitenleiste gleitet, statt abzudunkeln.

#### Behoben
- Intelligente Ansichten ohne Projektregel zeigten keine Aufgaben, und ihre Zähler erschienen erst nach einem Klick.
- Ein veraltetes Echo der Synchronisation konnte eine gerade bearbeitete Aufgabe überschreiben; Kurrent ignoriert es jetzt und lädt vor dem Speichern neu.
- Der Einstellungsdialog für Ansichten füllte seinen Platz nicht aus.

#### Hinweis
- Konfliktdialog, Mehrfachauswahl mit Sammelaktionen, KRunner, die globalen Kürzel und das Offline-/Synchronisierungsbanner sind durch Tests abgedeckt, aber noch nicht von Hand in einer echten Sitzung geprüft.

## [0.3.1] — 2026-08-29

### English

A translation release: every string of the widget is now translated.

#### Fixed
- All 304 interface strings are translated into German, Spanish, French, Japanese and Simplified Chinese; before, about 158 of them fell back to English.

All changes: https://github.com/shrippen/Kurrent/compare/v0.3...v0.3.1

### Deutsch

Eine Übersetzungsversion: Jeder Text im Widget ist jetzt übersetzt.

#### Behoben
- Alle 304 Texte der Oberfläche sind ins Deutsche, Spanische, Französische, Japanische und vereinfachte Chinesisch übersetzt; vorher fielen etwa 158 davon auf Englisch zurück.

## [0.3] — 2026-08-29

### English

Sorting you can shape and keep, a faster panel start, and a long list of fixes from daily use. The installer now checks your system before it touches anything.

#### New
- Multi-level sorting (default Priority › Due › A–Z) that is kept globally or per view; new sort keys: due latest first, start date, reminder or recurring first/last, progress.
- Pick any task of the same project as the parent in the full editor.
- Reminders can stay quiet during ongoing calendar events, for the calendars you choose.
- More panel badge modes (tomorrow, high priority), a dot instead of a number, the overdue badge colour, and a configurable panel tooltip.
- A warning with a reinstall command when the widget and the installed backend have different versions.

#### Improved
- Search and sidebar filters keep the whole open task tree; completed tasks only appear in Completed.
- The panel icon and flyout appear at once and show a loading indicator while Akonadi connects; the badge no longer flashes empty.
- Today's "Still open" shows every overdue task, the same set as the Overdue view.
- Due date and time sit right-aligned in the task row; Quick Add wraps long text (Enter adds, Shift+Enter starts a new line).
- Scrolling in the task list and the sort menu works like in other Kirigami apps, with overshoot on touchpads; the scroll bar matches the visible rows when subtasks are collapsed.
- Sidebar sections share their height better and can be reordered across several positions by dragging.

#### Fixed
- Due dates were missing in the task row and the editor (#2).
- The sort menu stuck on "None" for the second and third level.
- The inline editor stayed open after changing the view, filter, search or sort.
- `install-linux.sh` asked for a wrong Kirigami package on Debian/Ubuntu (#1), could leave root-owned files in `~/.local`, and missed Akonadi runtime packages on Debian/Ubuntu and Fedora.

#### Note
- `install-linux.sh` now stops on systems without Plasma 6 / Qt 6 / KF6, asks before continuing on unknown distributions and explains the options on immutable systems (rpm-ostree, transactional-update, Toolbx/Distrobox).

All changes: https://github.com/shrippen/Kurrent/compare/v0.2.2...v0.3

### Deutsch

Sortierung, die sich formen und behalten lässt, ein schnellerer Start im Panel und eine lange Liste von Korrekturen aus dem Alltag. Das Installationsskript prüft jetzt das System, bevor es etwas anfasst.

#### Neu
- Mehrstufige Sortierung (Standard Priorität › Fälligkeit › A–Z), global oder je Ansicht gespeichert; neue Sortierschlüssel: späteste Fälligkeit zuerst, Startdatum, Erinnerung oder Wiederholung zuerst/zuletzt, Fortschritt.
- Im vollen Editor lässt sich jede Aufgabe desselben Projekts als übergeordnete wählen.
- Erinnerungen können während laufender Kalendertermine schweigen, für die gewählten Kalender.
- Mehr Modi für das Panel-Abzeichen (morgen, hohe Priorität), ein Punkt statt einer Zahl, die Farbe für Überfälliges und ein einstellbarer Panel-Tooltip.
- Eine Warnung mit Befehl zur Neuinstallation, wenn Widget und installiertes Backend verschiedene Versionen haben.

#### Verbessert
- Suche und Filter der Seitenleiste behalten den ganzen offenen Aufgabenbaum; erledigte Aufgaben erscheinen nur unter Erledigt.
- Panel-Symbol und Ausklappfenster erscheinen sofort und zeigen eine Ladeanzeige, solange Akonadi verbindet; das Abzeichen blinkt nicht mehr leer.
- „Noch offen“ unter Heute zeigt alle überfälligen Aufgaben, dieselben wie die Ansicht Überfällig.
- Fälligkeit und Uhrzeit stehen rechtsbündig in der Aufgabenzeile; die Schnelleingabe bricht lange Texte um (Enter fügt hinzu, Umschalt+Enter beginnt eine neue Zeile).
- Scrollen in der Aufgabenliste und im Sortiermenü verhält sich wie in anderen Kirigami-Apps, mit Nachfedern auf dem Touchpad; die Bildlaufleiste passt zu den sichtbaren Zeilen, wenn Unteraufgaben eingeklappt sind.
- Die Abschnitte der Seitenleiste teilen sich die Höhe besser und lassen sich per Ziehen über mehrere Positionen umsortieren.

#### Behoben
- Fälligkeiten fehlten in der Aufgabenzeile und im Editor (#2).
- Das Sortiermenü blieb für die zweite und dritte Stufe auf „Keine“ hängen.
- Der Inline-Editor blieb nach einem Wechsel von Ansicht, Filter, Suche oder Sortierung offen.
- `install-linux.sh` verlangte unter Debian/Ubuntu ein falsches Kirigami-Paket (#1), konnte Dateien in `~/.local` root gehörend hinterlassen und vergaß Akonadi-Laufzeitpakete unter Debian/Ubuntu und Fedora.

#### Hinweis
- `install-linux.sh` bricht jetzt auf Systemen ohne Plasma 6 / Qt 6 / KF6 ab, fragt bei unbekannten Distributionen nach und erklärt auf unveränderlichen Systemen die Wege (rpm-ostree, transactional-update, Toolbx/Distrobox).

## [0.2.2] — 2026-08-22

### English

An installer fix: updating no longer removes the widget.

#### Fixed
- Updating with `install-linux.sh` deleted the widget; updates now copy the files in place.
- Installing with `sudo bash` left files under `~/.local` owned by root.

All changes: https://github.com/shrippen/Kurrent/compare/v0.2.1...v0.2.2

### Deutsch

Eine Korrektur am Installationsskript: Ein Update entfernt das Widget nicht mehr.

#### Behoben
- Ein Update mit `install-linux.sh` löschte das Widget; Updates kopieren die Dateien jetzt an Ort und Stelle.
- Eine Installation mit `sudo bash` hinterließ Dateien unter `~/.local`, die root gehörten.

## [0.2.1] — 2026-08-19

### English

A bug-fix release for Quick Add.

#### Fixed
- The highlighting in Quick Add shifted left while typing.
- Selecting text in Quick Add (Ctrl+A) showed the text twice.

All changes: https://github.com/shrippen/Kurrent/compare/v0.2.0...v0.2.1

### Deutsch

Eine Fehlerkorrektur für die Schnelleingabe.

#### Behoben
- Die Hervorhebung in der Schnelleingabe verrutschte beim Tippen nach links.
- Markierter Text in der Schnelleingabe (Strg+A) erschien doppelt.

## [0.2.0] — 2026-08-18

### English

A planner-style task flow, a full settings dialog, reminders and a faster panel start.

#### New
- Today no longer mixes in overdue tasks; a "Still open" catch-up and an Overdue view in the sidebar take them.
- Reschedule from the task row (15 min, 1 h, 4 h, tomorrow, next week) and one-step undo for complete, reschedule, move and delete.
- Morning, afternoon and evening groups, and a list section field in the editor.
- Quick Add understands dates, priorities and labels (`tomorrow 18:00 !high #tag`); a Join button opens meeting links.
- Reminders (VALARM) in the editor and as Plasma notifications with snooze, with optional quiet hours.
- A settings dialog with pages for appearance, sidebar, tasks, editor, panel, notifications, projects and labels, each with its own reset; the sidebar order is set by dragging.
- Panel badge (open, today or overdue), a default due date, colours per project and label, renaming labels, collapsible subtask trees.
- Keyboard control in the widget, plus the global shortcuts Meta+Shift+K and Meta+Shift+N.
- Empty states when Akonadi is offline, no calendar exists or a view is empty.
- GitHub releases carry `kurrent-linux-x86_64.tar.gz` and `install-linux.sh`; the one-line installer puts the plugin into `~/.local` (`--from-source` builds it when the binary does not match the distribution).

#### Improved
- Completing a recurring task moves the series on and keeps its recurrence rule.
- The panel starts without waiting for Akonadi and fills the badge and list from the cache at once.

All changes: https://github.com/shrippen/Kurrent/compare/v0.1.0...v0.2.0

### Deutsch

Ein Aufgabenfluss wie in einem Planer, ein vollständiger Einstellungsdialog, Erinnerungen und ein schnellerer Start im Panel.

#### Neu
- Heute mischt keine überfälligen Aufgaben mehr hinein; dafür gibt es „Noch offen“ und eine Ansicht Überfällig in der Seitenleiste.
- Verschieben direkt aus der Aufgabenzeile (15 Min., 1 Std., 4 Std., morgen, nächste Woche) und Rückgängig in einem Schritt für Erledigen, Verschieben, Umhängen und Löschen.
- Gruppen für Morgen, Nachmittag und Abend sowie ein Feld für den Listenabschnitt im Editor.
- Die Schnelleingabe versteht Datum, Priorität und Labels (`tomorrow 18:00 !high #tag`); ein Beitreten-Knopf öffnet Meeting-Links.
- Erinnerungen (VALARM) im Editor und als Plasma-Benachrichtigungen mit Schlummern, wahlweise mit Ruhezeiten.
- Ein Einstellungsdialog mit Seiten für Darstellung, Seitenleiste, Aufgaben, Editor, Panel, Benachrichtigungen, Projekte und Labels, jede mit eigenem Zurücksetzen; die Reihenfolge der Seitenleiste wird per Ziehen festgelegt.
- Panel-Abzeichen (offen, heute oder überfällig), ein Standard-Fälligkeitsdatum, Farben je Projekt und Label, Labels umbenennen, einklappbare Unteraufgaben.
- Tastatursteuerung im Widget und die globalen Kürzel Meta+Umschalt+K und Meta+Umschalt+N.
- Hinweise, wenn Akonadi offline ist, kein Kalender existiert oder eine Ansicht leer ist.
- GitHub-Releases enthalten `kurrent-linux-x86_64.tar.gz` und `install-linux.sh`; der Einzeiler installiert das Plugin nach `~/.local` (`--from-source` baut es, wenn die Binärdatei nicht zur Distribution passt).

#### Verbessert
- Das Erledigen einer wiederkehrenden Aufgabe rückt die Serie weiter und behält ihre Wiederholungsregel.
- Das Panel startet, ohne auf Akonadi zu warten, und füllt Abzeichen und Liste sofort aus dem Zwischenspeicher.

## [0.1.0] — 2026-08-17

### English

The first public release of Kurrent, a task manager for KDE Plasma 6 on your Akonadi tasks.

#### New
- Inbox, Today, Tomorrow, Scheduled, Anytime, Recurring, Unlabeled and Completed views.
- Projects, labels and priorities from Akonadi, for example a Nextcloud CalDAV account.
- Create, edit, complete and delete tasks, with subtasks and drag and drop.
- A full editor inside the widget and a compact inline editor.
- The desktop widget and the panel flyout share their settings.
- Optional wallpaper blur behind the widget.
- Translations into German, Spanish, French, Japanese and Simplified Chinese.

### Deutsch

Die erste öffentliche Version von Kurrent, einer Aufgabenverwaltung für KDE Plasma 6 auf deinen Akonadi-Aufgaben.

#### Neu
- Ansichten Eingang, Heute, Morgen, Geplant, Jederzeit, Wiederkehrend, Ohne Label und Erledigt.
- Projekte, Labels und Prioritäten aus Akonadi, etwa aus einem Nextcloud-CalDAV-Konto.
- Aufgaben anlegen, bearbeiten, erledigen und löschen, mit Unteraufgaben und Ziehen und Ablegen.
- Ein voller Editor im Widget und ein kompakter Inline-Editor.
- Desktop-Widget und Panel-Ausklappfenster teilen sich ihre Einstellungen.
- Wahlweise unscharfer Hintergrundbild-Effekt hinter dem Widget.
- Übersetzungen ins Deutsche, Spanische, Französische, Japanische und vereinfachte Chinesisch.
