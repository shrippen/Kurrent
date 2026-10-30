# Changelog

## [Unreleased]

## [0.5.0] — 2026-10-30

### English

Kurrent learns to plan your days: the Agenda shows a day as an hour grid next to your appointments, a week as a board and a month at a glance, and you drag tasks into free time. The widget gets a new look with tiles, an inspector, a narrow layout and the optional Kante style, Swimlanes and the Project plan are reworked, the settings are new, and there is now a terminal client.

#### New
- Agenda, Day: 14 days from the picked date, each as an hour grid (07–22, longer on a day with something earlier or later) with your appointments, tasks with a time as blocks and free gaps of 30 minutes and more in green; today starts at the now line, which moves with the clock. Days with nothing on them fold into one line. A month calendar with dots for appointments, tasks and overdue tasks picks the first day.
- Plan by dragging: drop a task on a day and it lands in the next free time long enough for it (a block keeps its length, otherwise 60, 45 or 30 minutes by priority). Drop it under "No time", or use a suggestion's arrow button, to keep it on the day without a time. Click a block to get grips at its edges; they move its time in 15-minute steps and stop at the next appointment or task. Everything can be undone.
- Suggestions for the picked day (click a day's header to pick it) in three tiers, First, Then and If time allows: overdue tasks and tasks due within a week rank highest, undated tasks come later, and high priority and fitting the largest free gap count too. Each suggestion says why it is there.
- Agenda, Week: one column per day with appointments, open tasks as cards and a load bar against your workday (8 hours by default, Settings › Views › Agenda), orange when the day is full. Done tasks fold into "✓ N done", empty days say "free", and + adds a task for the day. Overdue tasks wait in a tray above the week, and "All to today" moves them to today with their times. Drop a card on another day to move it; its time stays. Recurring tasks are not moved here yet, neither by dragging nor by "All to today"; move them in the editor.
- Agenda, Month: six weeks tinted by how full each day is, up to three entries per day and "+n more", overdue in red. Click a day for a panel with its appointments, tasks and a field to add one; drop a task on a day to move it.
- Day | Week | Month share one date and remember the last view; "Open day →", a weekday in the week or a day number in the month opens that day. Keys T, W and M switch the view, ← → step, H jumps to today.
- Add tasks in the Agenda with the same Quick Add as the list. In the day view, click free time and type: the task is planned in that hour. In the week and the month the task lands on the day unless the text names a date.
- Appointments in week and month show a stripe in their calendar's colour and a time column, so they read differently from tasks.
- Tiles above the task pane: Overdue, Today, Tomorrow, Scheduled and Completed with their counts; a click opens the view. The overdue tile offers "Move all to today", and the heatmap shows its figures (total, per day, best day) in the tiles.
- Inspector beside the task pane: a click on a task in the list, Kanban, Swimlanes, the Agenda or the heatmap's day list shows its project, labels, status, dates, subtasks with progress and notes without opening the editor. Values with a picker (due date, priority, project, status, progress, secrecy) open a menu, "Edit here" edits title, description and location in place, and Done, Tomorrow, Next week and Editor are one click away. Double click still opens the full editor. Tiles and inspector can be turned off in Settings › Appearance › Wide layout.
- Narrow layout: when the widget is narrow, the views become tabs with counters above the tasks (arrows at the edges when more tabs exist), and the sidebar opens on demand. The panel popup opens narrow by default.
- Styles: Plasma (default) follows your Plasma colour scheme like any KDE app; Kante brings its own palette (Gruvbox, or Leinen on a light colour scheme) with square controls, cut corners and condensed titles; Kante Light keeps Plasma's colours and adds only Kante's shapes and type. Pick one with preview cards in Settings › Appearance. A translucent or blurred Plasma background shows through in every style.
- Accent switches: show project and label colours or priority colours as accents, or keep the widget calm.
- Overdue tasks in other views: a notice with "Move all to today" and "Show overdue" (a compact chip in the narrow layout); it can be turned off.
- Header: "N open · M overdue" next to the view title, and active filters as chips whose × clears just that filter.
- Sidebar: the views (Inbox, Today, Overdue …) always get their full height, and projects, labels and the other sections share the rest. Optional dense rows (Settings › Sidebar › Row size), a sync line ("Synced", "Syncing…", "Akonadi offline") with "Sync now", and a note when a view hides a section.
- Counters are badges (red for overdue), Kanban column headers count their cards, and the panel badge looks like Plasma's notification badge.
- `kurrent-tui`: Kurrent in a terminal, installed by source builds (`install.sh`, or the installer with `--from-source`). Now, Soon and Someday as one list; `x` done, `t` today, `m` tomorrow, `d` someday, `a` adds with Quick Add, `/` searches, and `g` goes through overdue tasks one at a time. Its texts are English only for now.

#### Improved
- Swimlanes hold task cards. Drag a card to another cell to change its project, label, priority or parent and move its due date into that period, as one undo step. Columns are weeks by default.
- Swimlanes have a horizon (Settings › Views › Look ahead, automatic by default) with Overdue, Later and No date columns; empty periods stay as drop targets. The Project plan gets the same Later column instead of leaving far-off tasks out.
- Swimlanes and the Project plan share one grid: row and column headers stay in place, scrolling works like in Kanban (wheel, thin bars, middle-click to pan), the current period is highlighted with a button to jump to it, and column headers name the period, such as the calendar week with its dates, or "Today". A button in the header sets rows, columns and look ahead without the settings dialog.
- A click on a Swimlanes or Project plan cell, row or column header opens the list filtered to it, with a chip in the header to go back.
- Swimlanes stay fast with many tasks: a cell shows up to eight cards and "+N more tasks".
- Project plan cells show how busy they are compared with the busiest cell, a red dot for overdue tasks, a flag for high priority and a split bar by priority; tooltips work, a legend explains the colours, and projects are sorted by name.
- Heatmap: square month cells with the count inside, the legend below, and the picked day's tasks beside or below the grid (a click opens the inspector or the editor). Month, year and mode sit in the navigation row.
- Kanban: a click on a card opens the inspector or the editor, empty columns fold into a narrow strip, and the Canceled column can be hidden (Settings › Views).
- Task rows show label names and the project name, the priority flag sits right before the due date, and the edit buttons appear only on hover.
- Editor: title and status at the top, "All day" hides the time fields, and the editor opens correctly from Kanban cards and the inspector.
- Quick Add shows the recognised parts as tinted pills.
- Return presses a focused button in the widget like Space, in every style.
- Settings are now seven pages: General, Appearance, Tasks, Sidebar, Views, Panel & notifications and Organize. Labels sit left of the fields, and every page has "Reset this page". General shows whether Akonadi is connected, with a button that opens your task app; Tasks shows a live preview of a task row; Panel & notifications previews the panel badge and can send a test notification; Organize keeps projects, labels and locations in one list each (colour, rename, delete, default project). Relative dates are on by default.
- The widget's icon in the widget picker is now in colour; the panel icon stays monochrome.
- Dates follow the system locale everywhere (day and month names were always English), Kanban column names are translated, and about 250 more strings are translated in all five languages.

#### Fixed
- The settings dialog showed only Plasma's own pages: Kurrent's pages did not load at all.
- Overdue means the same everywhere: an open task due before today. Completed tasks no longer show their due date in red.
- Tasks completed in Kurrent had no completion date, so the heatmap did not count them; completions after midnight UTC landed on the previous day.
- Translations were partly missing: the catalogs were stale, and texts with quotation marks never matched.
- The Project plan put the days around New Year into the wrong week; also fixed: the "today" drop in Kanban, and the refresh of Swimlanes and the Project plan after changes.
- A click on a Swimlanes cell reset the sidebar view, a click on a Project plan cell filtered the plan itself, and the plan's tooltips never appeared.
- A click on a heatmap day was undone right away.

#### Note
- The Agenda reads appointments from your Akonadi calendars; pick which ones in the Agenda's calendar menu.
- The Agenda's day and week are rebuilt, the month is new, and the switch between days side by side and stacked is gone.
- The Project plan options are now shared by all Kurrent widgets, like every other setting.
- Drag and drop and the keys in the Agenda are covered by tests but were checked by hand only briefly so far.

All changes: https://github.com/shrippen/Kurrent/compare/v0.4.0...v0.5.0

### Deutsch

Kurrent plant jetzt deine Tage mit: Die Agenda zeigt einen Tag als Stundenraster neben deinen Terminen, eine Woche als Brett und einen Monat im Überblick, und Aufgaben ziehst du in freie Zeit. Das Widget bekommt ein neues Aussehen mit Kacheln, einem Inspektor, einem schmalen Layout und dem wählbaren Kante-Stil, Swimlanes und Projektplan sind überarbeitet, die Einstellungen neu gestaltet, und es gibt einen Terminal-Client.

#### Neu
- Agenda, Tag: 14 Tage ab dem gewählten Datum, jeder als Stundenraster (07–22 Uhr, länger, wenn etwas früher oder später liegt) mit deinen Terminen, Aufgaben mit Uhrzeit als Blöcke und freien Lücken ab 30 Minuten in Grün; heute beginnt an der Jetzt-Linie, die mit der Uhr wandert. Tage ohne Einträge klappen zu einer Zeile zusammen. Ein Monatskalender mit Punkten für Termine, Aufgaben und Überfälliges wählt den ersten Tag.
- Planen per Ziehen: Eine abgelegte Aufgabe landet in der nächsten freien Zeit, die lang genug ist (ein Block behält seine Länge, sonst 60, 45 oder 30 Minuten nach Priorität). Unter „Ohne Uhrzeit“ abgelegt oder mit dem Pfeilknopf eines Vorschlags bleibt sie ohne Uhrzeit auf dem Tag. Ein Klick auf einen Block zeigt Griffe an seinen Kanten; sie verschieben seine Zeit in 15-Minuten-Schritten und halten am nächsten Termin oder an der nächsten Aufgabe. Alles lässt sich rückgängig machen.
- Vorschläge für den gewählten Tag (ein Klick auf den Tageskopf wählt ihn) in drei Stufen, Zuerst, Danach und Wenn Zeit bleibt: Überfällige und innerhalb einer Woche fällige Aufgaben stehen am höchsten, Aufgaben ohne Datum später, und hohe Priorität und das Passen in die größte freie Lücke zählen mit. Jeder Vorschlag sagt, warum er dasteht.
- Agenda, Woche: eine Spalte je Tag mit Terminen, offenen Aufgaben als Karten und einem Auslastungsbalken gegen deinen Arbeitstag (Standard 8 Stunden, Einstellungen › Ansichten › Agenda), orange, wenn der Tag voll ist. Erledigte Aufgaben klappen zu „✓ N erledigt“ ein, leere Tage zeigen „frei“, und + legt eine Aufgabe für den Tag an. Überfällige Aufgaben warten in einem Fach über der Woche, und „Alle auf heute“ legt sie mit ihren Uhrzeiten auf heute. Eine Karte auf einem anderen Tag ablegen verschiebt sie; die Uhrzeit bleibt. Wiederkehrende Aufgaben werden hier noch nicht verschoben, weder per Ziehen noch mit „Alle auf heute“; verschiebe sie im Editor.
- Agenda, Monat: sechs Wochen, je Tag nach Auslastung getönt, bis zu drei Einträge je Tag und „+n weitere“, Überfälliges in Rot. Ein Klick auf einen Tag öffnet eine Leiste mit seinen Terminen, Aufgaben und einem Feld zum Anlegen; eine Aufgabe auf einem Tag ablegen verschiebt sie.
- Tag | Woche | Monat teilen sich ein Datum und merken sich die letzte Ansicht; „Tag öffnen →“, ein Wochentag in der Woche oder eine Tageszahl im Monat öffnet diesen Tag. Die Tasten T, W und M wechseln die Ansicht, ← → blättern, H springt auf heute.
- Aufgaben in der Agenda mit derselben Schnelleingabe wie in der Liste anlegen. In der Tagesansicht auf freie Zeit klicken und tippen: Die Aufgabe wird in dieser Stunde geplant. In Woche und Monat landet sie auf dem Tag, außer der Text nennt ein Datum.
- Termine in Woche und Monat zeigen einen Streifen in der Farbe ihres Kalenders und eine Zeitspalte, so unterscheiden sie sich von Aufgaben.
- Kacheln über der Aufgabenliste: Überfällig, Heute, Morgen, Geplant und Erledigt mit ihren Zahlen; ein Klick öffnet die Ansicht. Die Kachel Überfällig bietet „Alle auf heute“, und die Heatmap zeigt ihre Kennzahlen (gesamt, je Tag, bester Tag) in den Kacheln.
- Inspektor neben der Aufgabenliste: Ein Klick auf eine Aufgabe in Liste, Kanban, Swimlanes, der Agenda oder der Tagesliste der Heatmap zeigt Projekt, Labels, Status, Daten, Unteraufgaben mit Fortschritt und Notizen, ohne den Editor zu öffnen. Werte mit Auswahl (Fälligkeit, Priorität, Projekt, Status, Fortschritt, Vertraulichkeit) öffnen ein Menü, „Hier bearbeiten“ ändert Titel, Beschreibung und Ort direkt, und Erledigt, Morgen, Nächste Woche und Editor sind einen Klick entfernt. Ein Doppelklick öffnet weiter den vollen Editor. Kacheln und Inspektor lassen sich unter Einstellungen › Erscheinungsbild › Breites Layout abschalten.
- Schmales Layout: Ist das Widget schmal, werden die Ansichten zu Tabs mit Zählern über den Aufgaben (mit Pfeilen an den Rändern, wenn mehr Tabs da sind), und die Seitenleiste öffnet sich bei Bedarf. Das Panel-Popup öffnet sich standardmäßig schmal.
- Stile: Plasma (Standard) folgt deinem Plasma-Farbschema wie jede KDE-App; Kante bringt eine eigene Palette (Gruvbox, oder Leinen bei hellem Farbschema) mit eckigen Bedienelementen, abgeschnittenen Ecken und schmalen Titeln; Kante Light behält die Farben von Plasma und ergänzt nur Formen und Schrift von Kante. Gewählt mit Vorschaukarten unter Einstellungen › Erscheinungsbild. Ein durchscheinender oder unscharfer Plasma-Hintergrund bleibt in jedem Stil sichtbar.
- Akzent-Schalter: Projekt- und Labelfarben oder Prioritätsfarben als Akzente zeigen, oder das Widget ruhig lassen.
- Überfällige Aufgaben in anderen Ansichten: ein Hinweis mit „Alle auf heute“ und „Überfällige zeigen“ (im schmalen Layout ein kompakter Chip); lässt sich abschalten.
- Kopfzeile: „N offen · M überfällig“ neben dem Titel der Ansicht, und aktive Filter als Chips, deren × nur diesen Filter entfernt.
- Seitenleiste: Die Ansichten (Posteingang, Heute, Überfällig …) bekommen immer ihre volle Höhe, Projekte, Labels und die übrigen Bereiche teilen sich den Rest. Wählbar dichte Zeilen (Einstellungen › Seitenleiste › Zeilenhöhe), eine Sync-Zeile („Synchronisiert“, „Synchronisiere …“, „Akonadi offline“) mit „Jetzt synchronisieren“ und ein Hinweis, wenn eine Ansicht einen Bereich ausblendet.
- Zähler sind Plaketten (rot für Überfälliges), Kanban-Spalten zählen ihre Karten, und die Plakette im Panel sieht aus wie die Benachrichtigungs-Plakette von Plasma.
- `kurrent-tui`: Kurrent im Terminal, wird bei Quellbuilds mitinstalliert (`install.sh` oder der Installer mit `--from-source`). Now, Soon und Someday als eine Liste; `x` erledigt, `t` heute, `m` morgen, `d` irgendwann, `a` legt per Schnelleingabe an, `/` sucht, und `g` geht überfällige Aufgaben einzeln durch. Seine Texte sind vorerst nur Englisch.

#### Verbessert
- Swimlanes enthalten Aufgabenkarten. Eine Karte in eine andere Zelle ziehen ändert Projekt, Label, Priorität oder Elternaufgabe und legt die Fälligkeit in diesen Zeitraum, als ein Rückgängig-Schritt. Spalten sind standardmäßig Wochen.
- Swimlanes haben einen Horizont (Einstellungen › Ansichten › Vorausschau, standardmäßig automatisch) mit Spalten für Überfällig, Später und Kein Datum; leere Zeiträume bleiben als Ablageziel. Der Projektplan bekommt dieselbe Spalte Später, statt ferne Aufgaben wegzulassen.
- Swimlanes und Projektplan teilen sich ein Raster: Zeilen- und Spaltenköpfe bleiben stehen, Scrollen geht wie im Kanban (Mausrad, schmale Leisten, Mittelklick zum Verschieben), der aktuelle Zeitraum ist hervorgehoben mit einem Knopf, der zu ihm springt, und Spaltenköpfe nennen den Zeitraum, etwa die Kalenderwoche mit ihren Daten, oder „Heute“. Ein Knopf in der Kopfzeile stellt Zeilen, Spalten und Vorausschau ein, ohne den Einstellungsdialog.
- Ein Klick auf eine Zelle, einen Zeilen- oder Spaltenkopf in Swimlanes oder Projektplan öffnet die Liste, gefiltert darauf, mit einem Chip in der Kopfzeile für den Weg zurück.
- Swimlanes bleiben auch mit vielen Aufgaben schnell: Eine Zelle zeigt bis zu acht Karten und „+N weitere Aufgaben“.
- Zellen im Projektplan zeigen ihre Auslastung im Vergleich zur vollsten Zelle, einen roten Punkt für Überfälliges, eine Flagge für hohe Priorität und einen Balken nach Priorität; Tooltips funktionieren, eine Legende erklärt die Farben, und Projekte sind nach Namen sortiert.
- Heatmap: quadratische Monatszellen mit der Zahl darin, die Legende darunter und die Aufgaben des gewählten Tages neben oder unter dem Raster (ein Klick öffnet Inspektor oder Editor). Monat, Jahr und Modus stehen in der Navigationszeile.
- Kanban: Ein Klick auf eine Karte öffnet Inspektor oder Editor, leere Spalten klappen zu einem schmalen Streifen ein, und die Spalte Abgebrochen lässt sich ausblenden (Einstellungen › Ansichten).
- Aufgabenzeilen zeigen Labelnamen und den Projektnamen, die Prioritätsflagge steht direkt vor der Fälligkeit, und die Bearbeiten-Knöpfe erscheinen nur beim Überfahren.
- Editor: Titel und Status oben, „Ganztägig“ blendet die Zeitfelder aus, und der Editor öffnet sich auch aus Kanban-Karten und dem Inspektor richtig.
- Die Schnelleingabe zeigt die erkannten Teile als getönte Pillen.
- Enter drückt einen fokussierten Knopf im Widget wie die Leertaste, in jedem Stil.
- Die Einstellungen haben jetzt sieben Seiten: Allgemein, Erscheinungsbild, Aufgaben, Seitenleiste, Ansichten, Panel & Hinweise und Organisieren. Beschriftungen stehen links neben den Feldern, und jede Seite hat „Diese Seite zurücksetzen“. Allgemein zeigt, ob Akonadi verbunden ist, mit einem Knopf, der deine Aufgaben-App öffnet; Aufgaben zeigt eine Live-Vorschau einer Aufgabenzeile; Panel & Hinweise zeigt die Panel-Plakette als Vorschau und kann eine Test-Benachrichtigung senden; Organisieren führt Projekte, Labels und Orte in je einer Liste (Farbe, Umbenennen, Löschen, Standardprojekt). Relative Datumsangaben sind standardmäßig an.
- Das Symbol des Widgets in der Widget-Auswahl ist jetzt farbig; das Panel-Symbol bleibt einfarbig.
- Datumsangaben folgen überall der Systemsprache (Tages- und Monatsnamen waren immer Englisch), Kanban-Spaltennamen sind übersetzt, und rund 250 weitere Texte sind in allen fünf Sprachen übersetzt.

#### Behoben
- Der Einstellungsdialog zeigte nur die eigenen Seiten von Plasma: Die Seiten von Kurrent luden gar nicht.
- Überfällig heißt überall dasselbe: eine offene Aufgabe, die vor heute fällig war. Erledigte Aufgaben zeigen ihre Fälligkeit nicht mehr in Rot.
- In Kurrent erledigte Aufgaben hatten kein Erledigungsdatum, darum zählte die Heatmap sie nicht; Erledigungen nach Mitternacht UTC landeten auf dem Vortag.
- Übersetzungen fehlten teilweise: Die Kataloge waren veraltet, und Texte mit Anführungszeichen wurden nie gefunden.
- Der Projektplan legte die Tage um Neujahr in die falsche Woche; außerdem behoben: das Ablegen in der Kanban-Spalte „Heute“ und das Auffrischen von Swimlanes und Projektplan nach Änderungen.
- Ein Klick auf eine Swimlanes-Zelle setzte die Ansicht in der Seitenleiste zurück, ein Klick auf eine Projektplan-Zelle filterte den Plan selbst, und die Tooltips des Plans erschienen nie.
- Ein Klick auf einen Tag der Heatmap wurde sofort wieder zurückgenommen.

#### Hinweis
- Die Agenda liest Termine aus deinen Akonadi-Kalendern; welche, wählst du im Kalendermenü der Agenda.
- Tag und Woche der Agenda sind neu gebaut, der Monat ist neu, und der Schalter zwischen Tagen nebeneinander und untereinander entfällt.
- Die Optionen des Projektplans gelten jetzt für alle Kurrent-Widgets, wie jede andere Einstellung.
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
