# Changelog

## [Unreleased]

## [0.5.0] — 2026-10-30

### English

Kurrent learns to plan your days: the Agenda shows a day as an hour grid next to your appointments, a week as a board and a month at a glance, and you drag tasks into free time. The widget gets a new look with tiles, an inspector and the optional Kante style, and there is now a terminal client.

#### New
- Agenda, Day: 14 days as hour grids (07–22, longer when something is earlier or later) with your appointments, tasks with a time as blocks and free gaps in green. Drop a task on a day and it lands in the next free time long enough for it; drag a block's edges to change its time. Suggestions for the picked day say why each task fits (overdue, due soon, high priority, fits the largest gap).
- Agenda, Week: one column per day with appointments, open tasks as cards and a load bar against your workday (8 hours by default, Settings › Views › Agenda). Overdue tasks wait in a tray above the week, and "All to today" moves them to today with their times. Done and overdue tasks of a day fold away and open with a click. Drop a card on another day to move it; its time stays. Recurring tasks are not moved here yet, neither by dragging nor by "All to today"; move them in the editor.
- Agenda, Month: six weeks tinted by how full each day is, with a panel for the picked day. Day | Week | Month share one date; keys T, W and M switch the view, ← → step, H jumps to today.
- Add tasks in the Agenda with the same Quick Add as the list. In the day view, click free time and type: the task is planned in that hour.
- Appointments in week and month show a stripe in their calendar's colour and a time column, so they read differently from tasks.
- Tiles above the task pane (Overdue, Today, Tomorrow, Scheduled, Completed) and an inspector beside it that shows a task's details and quick actions without opening the editor (wide layout).
- Styles: Plasma (default), Kante and Kante Light, picked with preview cards in Settings › Appearance.
- `kurrent-tui`: Kurrent in a terminal, installed by source builds (`install.sh`, or the installer with `--from-source`).
- A narrow layout with view tabs, used by default in the panel popup.

#### Improved
- Settings are eight pages instead of twelve, with labels left of the fields and "Reset this page" on every page.
- Swimlanes hold task cards you can drag between cells, have a horizon with Overdue, Later and No date columns, and stay fast with many tasks.
- A click on a Swimlanes or Project plan cell opens the list filtered to it.
- The sidebar gives the views their full height and can use dense rows.
- The Kante style is up to date (Kante 1.56): combo boxes fit their longest entry, disabled controls and menus follow Kante, and in Kante Light the main button of a place (add, Done, Save, Copy command) is filled in the accent so it stands out. Return presses a focused Kante button.
- Dates follow the system locale everywhere, and 120 more strings are translated in all five languages.

#### Fixed
- The heatmap's average per day was off in a month with a clock change.
- Overdue means the same everywhere: an open task due before today.
- Tasks completed in Kurrent had no completion date, so the heatmap did not count them.
- Several settings switched the wrong option ("Ask before deleting a task", "Only with Shift or Ctrl held", "Reduced motion").
- Week keys around New Year, the "today" drop in Kanban, and the refresh of Swimlanes and the Project plan after changes.

#### Note
- The Agenda reads appointments from your Akonadi calendars; pick which ones in the Agenda's calendar menu.
- Drag and drop and the keys in the Agenda are covered by tests but were checked by hand only briefly so far.

All changes: https://github.com/shrippen/Kurrent/compare/v0.4.0...v0.5.0

### Deutsch

Kurrent plant jetzt deine Tage mit: Die Agenda zeigt einen Tag als Stundenraster neben deinen Terminen, eine Woche als Brett und einen Monat im Überblick, und Aufgaben ziehst du in freie Zeit. Das Widget bekommt ein neues Aussehen mit Kacheln, einem Inspektor und dem wählbaren Kante-Stil, und es gibt einen Terminal-Client.

#### Neu
- Agenda, Tag: 14 Tage als Stundenraster (07–22 Uhr, länger, wenn etwas früher oder später liegt) mit deinen Terminen, Aufgaben mit Uhrzeit als Blöcke und freien Lücken in Grün. Eine abgelegte Aufgabe landet in der nächsten freien Zeit, die lang genug ist; an den Kanten eines Blocks ziehst du seine Zeit. Vorschläge für den gewählten Tag sagen, warum eine Aufgabe passt (überfällig, bald fällig, hohe Priorität, passt in die größte Lücke).
- Agenda, Woche: eine Spalte je Tag mit Terminen, offenen Aufgaben als Karten und einem Auslastungsbalken gegen deinen Arbeitstag (Standard 8 Stunden, Einstellungen › Ansichten › Agenda). Überfällige Aufgaben warten in einem Fach über der Woche, und „Alle auf heute“ legt sie mit ihren Uhrzeiten auf heute. Erledigte und überfällige Aufgaben eines Tages klappen sich ein und öffnen per Klick. Eine Karte auf einem anderen Tag ablegen verschiebt sie; die Uhrzeit bleibt. Wiederkehrende Aufgaben werden hier noch nicht verschoben, weder per Ziehen noch mit „Alle auf heute“; verschiebe sie im Editor.
- Agenda, Monat: sechs Wochen, je Tag nach Auslastung getönt, mit einer Leiste für den gewählten Tag. Tag | Woche | Monat teilen sich ein Datum; die Tasten T, W und M wechseln die Ansicht, ← → blättern, H springt auf heute.
- Aufgaben in der Agenda mit derselben Schnelleingabe wie in der Liste anlegen. In der Tagesansicht auf freie Zeit klicken und tippen: Die Aufgabe wird in dieser Stunde geplant.
- Termine in Woche und Monat zeigen einen Streifen in der Farbe ihres Kalenders und eine Zeitspalte, so unterscheiden sie sich von Aufgaben.
- Kacheln über der Aufgabenliste (Überfällig, Heute, Morgen, Geplant, Erledigt) und ein Inspektor daneben, der die Details einer Aufgabe und schnelle Aktionen zeigt, ohne den Editor zu öffnen (breites Layout).
- Stile: Plasma (Standard), Kante und Kante Light, gewählt mit Vorschaukarten unter Einstellungen › Erscheinungsbild.
- `kurrent-tui`: Kurrent im Terminal, wird bei Quellbuilds mitinstalliert (`install.sh` oder der Installer mit `--from-source`).
- Ein schmales Layout mit Ansichts-Tabs, im Panel-Popup als Standard.

#### Verbessert
- Die Einstellungen haben acht statt zwölf Seiten, mit Beschriftungen links neben den Feldern und „Diese Seite zurücksetzen“ auf jeder Seite.
- Swimlanes enthalten Aufgabenkarten, die sich zwischen Zellen ziehen lassen, haben einen Horizont mit Spalten für Überfällig, Später und Ohne Datum und bleiben auch mit vielen Aufgaben schnell.
- Ein Klick auf eine Zelle in Swimlanes oder Projektplan öffnet die Liste, gefiltert auf diese Zelle.
- Die Seitenleiste gibt den Ansichten ihre volle Höhe und kann dichte Zeilen nutzen.
- Der Kante-Stil ist auf dem neuen Stand (Kante 1.56): Auswahlfelder sind so breit wie ihr längster Eintrag, ausgegraute Elemente und Menüs folgen Kante, und in Kante Light ist der Hauptknopf einer Stelle (Hinzufügen, Erledigt, Speichern, Befehl kopieren) in der Akzentfarbe gefüllt und fällt so auf. Enter drückt einen fokussierten Kante-Knopf.
- Datumsangaben folgen überall der Systemsprache, und 120 weitere Texte sind in allen fünf Sprachen übersetzt.

#### Behoben
- Der Tagesschnitt der Heatmap stimmte in einem Monat mit Zeitumstellung nicht.
- Überfällig heißt überall dasselbe: eine offene Aufgabe, die vor heute fällig war.
- In Kurrent erledigte Aufgaben hatten kein Erledigungsdatum, darum zählte die Heatmap sie nicht.
- Mehrere Einstellungen schalteten die falsche Option („Vor dem Löschen einer Aufgabe nachfragen“, „Nur mit gedrückter Umschalt- oder Strg-Taste“, „Reduzierte Bewegung“).
- Kalenderwochen um Neujahr, das Ablegen in der Kanban-Spalte „Heute“ und das Auffrischen von Swimlanes und Projektplan nach Änderungen.

#### Hinweis
- Die Agenda liest Termine aus deinen Akonadi-Kalendern; welche, wählst du im Kalendermenü der Agenda.
- Ziehen und Ablegen und die Tasten in der Agenda sind durch Tests abgedeckt, von Hand aber bisher nur kurz geprüft.

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
