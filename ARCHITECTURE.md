# Architecture

How this repository is meant to be built. Where the code differs today is listed under
"Known deviations". Change this file in the PR that changes the structure.

## What it does

Kurrent is a task manager for KDE Plasma: a widget that shows the tasks from Akonadi
(KDE's store for calendars and tasks) as list, board, matrix, agenda and more, with
quick entry, filters, an editor and undo. Beside the widget there are a terminal
program on the same core and a KRunner plug-in that reaches the widget over D-Bus.

## Building blocks

`ui/` stands for `plasmoid/io.github.shrippen.Kurrent/contents/ui/`.

| Path | Its one task |
|---|---|
| `plugin/taskstore.h`, `akonaditaskstore.*`, `memorytaskstore.*` | The storage boundary: create, change and delete a task. One store talks to Akonadi, one keeps tasks in memory for tests. |
| `plugin/tasklogic.*`, `agendalogic.*`, `quickadd.cpp`, `taskcalendar.*` | The rules, as pure functions with tests: sorting, filtering, counting for the sidebar, board and matrix; the agenda's day; parsing the quick entry; recurrence and dates of a task. |
| `plugin/tasklistmodel.*`, `collectionlistmodel.*` | The lists the views show: tasks, and the task lists of Akonadi. |
| `plugin/akonadiitems.*` | What a fetched Akonadi item is, for loading: a task or not by its MIME type, and the tasks among fetched headers (no jobs, no parsing). |
| `plugin/sharedsettings.*` | The settings shared by widget and terminal program (`kurrentrc`), with name and default. |
| `plugin/taskcontroller.*` | What QML and the terminal program call. In the target a thin front: it holds the state of the session and hands each call to the class for its topic (settings bridge, undo, merge conflicts, board and matrix moves, agenda). |
| `plugin/kurrentdbus.*`, `kurrentlogging.*`, `demodata.*`, `kurrentplugin.cpp` | The D-Bus interface of the widget; logging; the demo world; the registration as QML module. |
| `ui/main.qml`, `FullView.qml`, `Plugin*.qml` | The widget: panel item and popup; loading the plug-in and the hint when it is missing. |
| `ui/views/` | One file per view (list, board, swimlanes, plan, heatmap, agenda day, week, month), the sidebar, the editor, the inspector, the management of projects and labels. |
| `ui/components/` | Parts several views share: rows, cards, pickers, bars, the parts of the settings pages. |
| `ui/Design.qml` | The sizes and tokens of the interface at run time. |
| `ui/*.js` | Logic of the user interface without QML, with tests in `tests/qml/`: dates and their input mask, colours and priority names, the editor's recurrence choice, the sidebar's height distribution, agenda helpers, focus, taps. |
| `ui/config*.qml`, `contents/config/` | The settings pages and the description of the widget's settings with their defaults (`main.xml`). |
| `ui/Kante/`, `ui/KantePlasma/` | Synced copies of the design system. Never edited here. |
| `ui/SmokeTest.qml`, `ScreenshotRunner.qml` | The walk through every view for the smoke test and the screenshots. |
| `tui/` | `kurrent-tui`: screens as text and the terminal, on the same controller and rules. |
| `krunner/` | The KRunner plug-in; it knows the widget only through D-Bus. |
| `tests/` | Unit tests of rules, models, stores and controller; QML tests; smoke, screenshot and benchmark scripts. |
| `install.sh`, `install-linux.sh`, `uninstall.sh`, `scripts/`, `po/`, `docs/`, `demo/`, `tools/` | Build and install; packaging and release notes; translations; landing page; demo world and its start; the structure check (synced copy). |

## Layers

```
 ui/views, ui/components (QML) ─► ui/*.js        tui/ (terminal)      krunner/
        │                         (pure UI logic)     │                   │ D-Bus
        ▼                                             ▼                   ▼
 plugin/taskcontroller ◄──────────────────────────────┴──────── plugin/kurrentdbus
   and the classes it hands to; models; shared settings
        │                                    │
        ▼                                    ▼
 plugin/ rules: tasklogic, agendalogic,   plugin/taskstore (writes) ─► Akonadi store
 quickadd, taskcalendar                      │                      │ memory store (tests)
 (pure, know no store; tui/ calls            │  the loader reads and watches
 them too)                                   ▼
                                          Akonadi
```

- QML reaches tasks only through the controller and the models. It reads settings
  from `Plasmoid.configuration`, which the controller keeps equal to `kurrentrc`, and
  never touches `SharedSettings`. It holds layout, wiring and what is only about the
  look.
- A rule about tasks (what a filter matches, how a list is sorted, what a quick
  entry means) stands in the rules of `plugin/` and has a C++ test. Logic that is only
  about the user interface (sizes, input masks, names for display) stands in `ui/*.js`
  and has a QML test. Nothing stands in both, and no code exists only for a test.
- Every write of a task goes through the storage boundary, whichever way it starts:
  quick entry, editor, drag, D-Bus. So every write runs in tests against the memory
  store. Reading and watching Akonadi is the task of one class behind the controller.
  Nothing outside `plugin/` talks to Akonadi.
- One class has one topic. The controller hands on; it does not grow by a function
  per feature.
- A part of the interface that repeats is one component, used several times.
- A setting's default stands in `contents/config/main.xml`. The settings pages take it
  from there; the list in `plugin/sharedsettings.*`, which the terminal program needs,
  is held equal to it by a test.
- A helper exists once: dates and times in `ui/datetime.js`, shared parts of settings
  pages in `ui/components/`.
- One thing has one name: the controller is called `controller` everywhere in QML.
- Smoke test, screenshot mode and demo world hook in at one place each and stay out
  of the classes and views that do the work.
- `tui/` uses the controller and the rules of `plugin/`, `krunner/` only D-Bus;
  neither has rules of its own.

## Where new things go

| Change | Touch |
|---|---|
| A new filter, sort order or count | `plugin/tasklogic.*`, a test in `tests/tasklogic_test.cpp`; the sidebar or toolbar that offers it |
| A new field of a task | `plugin/tasklistmodel.*`, the function that sets a task's fields, `plugin/taskcalendar.*` if it concerns dates; editor, inspector and row in `ui/`; quick entry in `plugin/quickadd.cpp` if it can be typed |
| A new view | A file in `ui/views/`, its loader in `ui/components/MainPaneHost.qml`, its id in `plugin/tasklogic.h` and `ui/Design.qml`, the list of views in `ui/FullView.qml` and `ui/configViews.qml`; steps in `ui/SmokeTest.qml` and the screenshot plan |
| A new action on tasks | The class for its topic behind the controller, through the storage boundary; a test with the memory store |
| A new setting | `contents/config/main.xml` (name and default), `plugin/sharedsettings.*` if the terminal program needs it, its page in `ui/config*.qml` |
| Logic only the interface needs | A function in `ui/*.js` with a test in `tests/qml/` |
| A part several views need | `ui/components/` |
| A design element that is missing | Kante, then `scripts/sync-kante.sh`; never the copies here |
| A text | In place with `i18n`; then `po/` |
| A command for other programs | `plugin/kurrentdbus.*`; `krunner/` if KRunner offers it |

## Known deviations

- `ui/taskmeta.js` computes the progress bands a second time, without a test
  (`AUDIT.md`, finding 1). The drag limits of popups (`ui/FullView.qml`) are
  interface logic in a view, without a test (not in `AUDIT.md`).
- The sidebar consists of seven nearly equal sections of about 230 lines each
  (`AUDIT.md`, finding 3).
- The controller does nearly everything in one class of 7031 lines, including
  reading and watching Akonadi, smoke test, screenshot mode and demo mode
  (`AUDIT.md`, finding 4). Views branch on the smoke test too and carry helpers for
  the screenshot runner (`MainPaneHost`, `SwimlaneView`, `main.qml`, three views; not
  in `AUDIT.md`).
- `tui/tuiapp.cpp` has a filter and a sort order of its own for open tasks (not in
  `AUDIT.md`).
- The order of the sidebar's sections and views is still written out as a default in
  `ui/configSidebar.qml` and `ui/views/SidebarView.qml`, besides `main.xml` (`AUDIT.md`,
  finding 5).
- Small date and selection helpers are copied into many views and settings pages
  (`AUDIT.md`, finding 6).
- `plugin/tasklogic.cpp` holds all rules in one file of 3330 lines
  (`AUDIT.md`, finding 8).
