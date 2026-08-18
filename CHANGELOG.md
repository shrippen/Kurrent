# Changelog

## Unreleased

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
- Compact panel icon first; `FullView.qml` (sidebar, list, editor) loads on first expand (`preloadFullRepresentation: false`)

## 0.1.0 — 2026-08-17

First public release of **Kurrent**, a KDE Plasma 6 task manager plasmoid.

- Inbox, Today, Tomorrow, Scheduled, Anytime, Recurring, Unlabeled, and Completed views
- Projects, labels, and priorities from Akonadi / Nextcloud CalDAV
- Create, edit, complete, delete, subtasks, and drag-and-drop
- Full editor overlay inside the widget and compact inline editor
- Shared settings between desktop widget and panel flyout (`~/.config/com.github.shrippen.kurrent/kurrentrc`)
- Optional Plasma wallpaper blur on desktop and panel popup
- German, Spanish, French, Japanese, and Simplified Chinese translations
