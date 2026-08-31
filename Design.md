# Kurrent — Design

Prosa-Referenz für UI- und UX-Entscheidungen. Laufzeit-Tokens: `plasmoid/com.github.shrippen.kurrent/contents/ui/Design.qml`. Akzente: `contents/ui/colors.js`. Projektübergreifende Designsprache (Farbpalette, Typografie, Icon-Stil, Landing-Page-Template): **[DesignDefault](https://github.com/shrippen/DesignDefault)**.

Diese Datei ist die **menschliche Quelle** für das Warum. `Design.qml` ist die **maschinelle Quelle** für Maße. Beides bei jeder neuen visuellen Entscheidung im selben Change aktualisieren (Cursor-Regel `.cursor/rules/kurrent-ui.mdc`). Es gibt keinen Datei-Watcher — „automatisch“ heißt: jeder Agent-Change an der UI muss diese Datei mitziehen.

---

## Produkt

- Name: **Kurrent**. Plasmoid-ID `com.github.shrippen.kurrent`.
- Autor: shrippen. Website und Issues: GitHub-Repo `https://github.com/shrippen/Kurrent` (About-Dialog im Widget).
- Plasma 6, Akonadi/CalDAV, kein eigenes Login.
- Panel: kompaktes Masken-Icon (`Kirigami.Icon { isMask: true; color: textColor }`), Breeze `ColorScheme-Text` / `currentColor`. Badge unten rechts: Zahl oder Punkt (`panelBadgeStyle`). Quelle (`panelBadge`): off, open roots, today, overdue, tomorrow, high (`viewCounts.high`). Overdue-Farbe (`panelBadgeOverdueColor`): Accent oder Negative — bei Modus overdue immer; bei Modus today nur wenn overdue &gt; 0. Tooltip (`panelTooltip`): open, today, today+overdue, overdue, high, all views (Zeilen pro View mit count &gt; 0), off.
- Desktop: volle Ansicht, frei skalierbar.

## Layout

- Links Sidebar (Projekte, Labels, Prioritäten, Views), 1px-Separator, rechts Aufgabenfläche.
- Sidebar-Breite: `Design.sidebarWidth` aus `sidebarWidthUnits` (6–20 Grid-Units, Default 10), gemeinsam in `kurrentrc`.
- Dichte: `Design.density` (`auto` / `compact` / `comfortable`) steuert `taskRowPad` für Aufgabenzeilen. Sidebar-Zeilen extra über `sidebarRowSize`.
- Overlay-Dim in drei Stufen (`overlayDimStep` 0/1/2 → 0,25 / 0,40 / 0,55).
- Reduced motion: kein Sync-Spinner, kein Hover-Flash auf Aufgabenzeilen.
- Sidebar-Abschnitte (Views, Projekte, Labels, Prioritäten, Fortschritt, Status, Vertraulichkeit, Ort) und einzelne Views: Reihenfolge und Sichtbarkeit aus `kurrentrc`. Alle Abschnitte können gleichzeitig aktiv sein; Extra-Höhe wird gleichmäßig auf die **sichtbaren** Abschnitte verteilt (natürliche Höhe + Squeeze wie bisher, nicht fest 4 Viertel). Default sichtbar: Views, Projekte, Labels, Prioritäten; Fortschritt/Status/Vertraulichkeit/Ort standardmäßig ausgeblendet (`hiddenSidebarSections`). **Views:** Alltags-Views (Inbox, Today, …) plus Zeile **Maintenance** (Ordner); Klick blendet Alltags-Views per **gerichteter ListView-Transition** aus und zeigt **Back** oben plus Wartungs-Views (Recurring, Unlabeled, Has reminder, Has no location, No priority, No status). Die Transition nutzt dieselbe Dauer (`Design.mainPaneTransitionDuration`) und dasselbe Easing (`OutCubic`) wie der Hauptflächen-Moduswechsel: beim Öffnen des Ordners gleiten Alltags-Views nach links heraus / Wartungs-Views von rechts herein; beim Zurückkehren umgekehrt. Aktive Wartungs-View öffnet den Ordner automatisch. Smart Views unter den Alltags-Views. Prioritäten/Status ohne „None“-Zeile — Filter über Wartungs-Views (`nopriority`, `nostatus`).
- Desktop-`fullRepresentation`: Default `52×40` Grid-Units. `Layout.maximumWidth/Height: Infinity`.
- Inhalt bleibt **innerhalb** der Plasma-FrameSvg-Margins. Ränder nicht mit `collapseMarginsHint` kollabieren.
- **Nicht** `width`/`height` am `PlasmoidItem` binden. **Nicht** `Layout.maximumWidth: Infinity` am Plasmoid-Root.
- Listen und Sidebar, die die Höhe füllen: `implicitHeight: 0`, `Layout.preferredHeight: 0`. `ListView.contentHeight` darf nie die maximale Desktop-Widget-Höhe werden.
- Extra Höhe der Sidebar gleichmäßig auf alle Abschnitte verteilen (nicht bei „alles ohne Scrollbar sichtbar“ stoppen).
- Passt die **natürliche** Höhe aller sichtbaren Abschnitte (Zeilenanzahl × Zeilenhöhe, inkl. touchfreundlich) **nicht** in die Sidebar: Anteile proportional zur natürlichen Höhe (nicht gleiche Viertel), jeder Abschnitt scrollt intern (`ThinScrollBar`). Bis die erste Verteilung gelaufen ist (`sectionsAllocated`), gleiche Startanteile — danach nie wieder `Alloc == -1` als „noch nicht berechnet“ missverstehen (`-1` war früher der Sentinel und wirkte wie Equal-Split bei knapper Höhe).
- **Near-fit (eine Zeile):** Fehlt einem Abschnitt höchstens eine Zeilenhöhe (+ Gap) zur Natural-Höhe, bekommt er die volle Natural-Höhe (Pixel von Abschnitten, die sowieso mehr als eine Zeile Overflow haben). Größerer Shortfall → Squeeze + Scrollbar. `listNeedsScroll`: `contentHeight > height + 1`.
- Sidebar-Scrollbar: bei Overflow sichtbar (`AlwaysOn` + hide wenn fit), Breite passt in die **feste** `rightMargin` (`Design.spaceSmall`) — Margin wächst/schrumpft nicht mit der Scrollbar.
- Sidebar-Breite per Ziehen am Separator (`SplitHCursor`), 6–20 Grid-Units, speichert `sidebarWidthUnits`.

## Datenmodell

- **Akonadi ist Source of Truth.** Alle Task-Mutationen laufen als Akonadi-Jobs über `AkonadiTaskStore`; das Plasmoid hält einen optimistischen Cache (`syncing`, `pendingDelete`, Revert bei Fehler). Weitere Edits während eines Jobs (z. B. Label per DnD entfernen, dann wieder setzen) werden **zusammengeführt** und erst nach der Bestätigung mit aktueller Revision geschrieben. Monitor-/Fetch-Updates mit **älterer Item-Revision** dürfen den Cache nicht überschreiben — sonst kommen Labels nach dem zweiten Entfernen wieder. Keine parallele Task-Datenbank im Widget. Akonadi-Logs unter `com.github.shrippen.kurrent.akonadi` (KCM Diagnostics: **Info journal** / **Verbose journal** in `kurrentrc`, Default Info an / Verbose aus).
- Unbekannte **`X-*`- und fremde Vendor-Properties** auf VTODO beim Lesen/Schreiben **durchreichen** (nicht verwerfen), damit andere CalDAV-Clients Metadaten erhalten.

## Hauptfläche

- Rechts der Sidebar liegt **eine** Hauptfläche (`mainPane` in `FullView`). Sidebar-Einträge (Built-in-Views und **Smart Views**) liefern nur **Filter + Sort**; die Darstellung wählt der **Ansichtsmodus**.
- **Kopfzeile** (Titel, aktive Filter, dann Controls), gelesen links→rechts: **Undo** (nur bei `canUndo`) · **Ansichtsmodus** (`ViewModeToolbar`) · **Group** (nur Liste) · **Kanban-Spalten** (nur Kanban) · **Sort** · Status. Header-Tool-Größe `Design.mainPaneHeaderToolSize`: **2 Grid-Units** (Desktop) bzw. **2,25 GU** (Touch). Titelbereich (`Layout.fillWidth`) kürzt sich; `headerTools` rechts (`Layout.minimumWidth: implicitWidth`) behält alle Buttons sichtbar. `ViewModeToolbar` setzt `implicitWidth`, `Layout.preferredWidth` und `Layout.minimumWidth` explizit: schmal exakt ein Button, breit exakt der gerahmte Sechser-Streifen; verschachtelte Layouts dürfen sie nicht auf Breite 0 reduzieren. `ViewModeToolbar` bekommt `backend: fullRoot.backend` übergeben (nicht das bare `backend`): die gleichnamige Komponenten-Property würde den Bezeichner sonst selbst verschatten und die Toolbar dauerhaft als „unsichtbar“ (`!!backend === false`) festsetzen. **Group** ist ein eigener `ToolButton` **neben** der View-Toolbar (identisch in schmaler und breiter Ansicht). **Aktive Filter** stehen **rechts neben dem Ansichtstitel**, getrennt durch ein `|`-Zeichen; jeder Filter zeigt farbiges Icon (wie Sidebar) + Text. Der Filtertext kürzt sich (`availableFilterTextWidth`) bei schmaler MainPane bis auf **nur das Icon** (`Layout.maximumWidth: 0` → Text unsichtbar); erst danach kollabiert die `ViewModeToolbar` in den Single-Button. **Breite MainPane** (`mainPane.width` ≥ `mainPaneHeaderTitleMinWidth` + `filterIconOnlyWidth` + `filterSeparatorWidth` + `mainPaneHeaderToolsExpandedWidth`): die Ansichtsmodi werden in einzelne Buttons aufgeklappt, in gerahmtem Chrome als Gruppe erkennbar; sonst ein kompakter Button mit Menü. Der Schwellwert berücksichtigt die **icon-only Filter** (nicht Text), so dass die Toolbar erst kollabiert wenn Titel + Filter-Icons + Tools passen — der Filtertext darf die Toolbar nicht verdecken. **Group** (`listGroupMode` in `kurrentrc`): Abschnitts-Header wie Today (Morning/Afternoon/Evening) — Projekt, Label, Priorität, Progress, Status, Secrecy, Ort; „None“ = view-native Buckets (Today-Zeitabschnitte). Jeder Abschnitts-Header zeigt links dasselbe Icon wie die Sidebar-Zeile (`taskmeta.js` · `Design.listSectionIconSize`). Bei aktiver Gruppierung: **Subtask-Bäume bleiben unter dem Root-Task**; Gruppenzugehörigkeit nur am Root. Gruppen **in Sidebar-Reihenfolge** (Projekte/Labels/Orte wie sichtbare Sidebar-Zeilen; Priorität/Progress/Secrecy wie der jeweilige Sidebar-Abschnitt; **Status** = VTODO-`STATUS`-Enum 4/6/3/5 wie Sidebar-Zeilen, **0/Keine** am Ende). Gruppen-Schlüssel, die in der Sidebar **nicht** vorkommen (z. B. „No location“, Inbox, unlabeled), **ans Ende**, dort locale A–Z. Passende Sortieroption ausgeblendet. **Sort**-Popup: drei Spalten nebeneinander (First/Second/Third sort) nur wenn die verfügbare Breite **alle Optionstexte** ohne Kürzung trägt (`sortMenuWideMinWidth` einmal beim Start aus dem vollen Label-Satz via `TextMetrics`, inkl. Label-Breiten-Map); Optionen locale A–Z in `sortOptionsAlphabetical` vorsortiert — beim Öffnen nur filtern, nicht neu sortieren; sonst gestapelt in einer Spalte. Statische Menü-Lookups (Sort-/Kanban-/Modus-/Gruppen-Labels, Smart-Views, Sidebar-View-Map, `colors.js`-Hash) werden gecacht und nur bei Config-/Override-Wechsel neu aufgebaut.
- **Sort** gilt in **Liste** und für Karten-Reihenfolge **innerhalb** einer Kanban-Spalte. Die **Spaltenreihenfolge** folgt der Spaltenquelle (nicht dem Sort). Kanban/Swimlanes/Plan/Heatmap/Kalender nutzen eigene Layout-Regeln, respektieren aber denselben **Task-Filter** der aktiven Sidebar-View.
- Letzter Modus **global** in `kurrentrc` (`mainPaneMode`), Default `Design.viewModeList`. Sidebar-View-Wechsel ändert den Modus nicht.
- Modus-Wechsel lädt dieselbe gefilterte Task-Menge; kein zweites Datenmodell pro Ansicht.
- **Hauptflächen-Laden (`MainPaneHost`):** Filter/Sort/Gruppieren **asynchron**; UI reagiert **sofort** (Slide bzw. Zahnrad). **Geschätzte Dauer** → `rebuildPerfProfile` in `kurrentrc` (wöchentliche Kalibrierung). Bei Schätzung ≥ `Design.mainPaneBlurMinEstimateMs`: **`MainPaneWidgetChrome`** über die **gesamte MainPane** (Kopfzeile, Bulk-Leiste, Aufgabenfläche; **Sidebar bleibt hell**) — **Editor-Dim** (`overlayDim`) wenn Tasks sichtbar (`taskModel.count > 0`); sonst **nur Zahnrad** zentriert. Sort: Dim+Zahnrad sofort. `reducedMotion`: kein Slide/Chrome.

### Liste

- Bestehende `TaskListView` / Delegates; unveränderte Zeilen-, Editor- und DnD-Regeln.

### Kanban

- **Phase A (1.0):** Spalten **berechnet** — Quelle wählbar in Views-KCM **oder** Kopfzeilen-Button (`view-file-columns`, nur im Kanban-Modus): Status, Offen/Erledigt, Projekt, Fälligkeits-Buckets (überfällig/heute/morgen/Woche/später/ohne Datum), Priorität, Label, Tagesabschnitt (`KURRENT/LIST`), Secrecy (Public/Private/Confidential), Custom-Spalte. Mehrfach-Label: Aufgabe erscheint in der Spalte der **ersten** Kategorie; Label-Spaltenliste = **alle** bekannten Labels (`availableLabels`) plus „None“ wenn unlabelled Tasks existieren (nicht nur Labels, die gerade als erste Kategorie vorkommen).
- **Feste Spaltenvokabulare** (Status, Completion, Priorität, Due-Buckets, Tagesabschnitt, Secrecy): **immer alle** Spalten anzeigen — auch leer — damit Karten dorthin gezogen werden können. Variable Quellen (Label, Projekt, Custom) bleiben datengetrieben.
- **Status-Spalten** nutzen dasselbe VTODO-**`STATUS`**-Enum wie Sidebar-Zähler und Listen-Gruppierung (`0` Keine, `4` Needs action, `6` In process, `3` Completed, `5` Canceled). Spaltenzuordnung liest nur `STATUS` (nicht das Erledigt-Flag allein). Drop in eine Status-Spalte schreibt denselben Enum wie Sidebar-DnD auf Status-Zeilen (Status `3` → erledigt + 100 %, sonst `completed` zurück).
- **Spaltenreihenfolge** (unabhängig vom Karten-Sort): Label/Projekt alphabetisch (Inbox zuerst, „none“ zuletzt); Status 4 → 6 → 3 → 5 → 0; Completion open → done; Priorität none → low → medium → high; Due overdue → today → tomorrow → this-week → later → no-date; Tagesabschnitt morning → afternoon → evening → unspecified → unscheduled; Secrecy public → private → confidential.
- **Karten:** `Kirigami.AbstractCard` (`KanbanCard.qml`) — Chips (Label/Priorität/Recurring/Fälligkeit), Titel, Beschreibungsvorschau, **Edit** (Full-Editor), **Join** (URL). Drag bewegt die **Karte selbst** nach Überschreiten eines Bewegungs-Schwellenwerts (Klick ohne Ziehen ändert die Sortierung nicht); während des Zugs bleibt ein Höhen-Platzhalter in der Quellspalte (keine Überlappung). Drop-Ziel zeigt eine **Lücken-Linie** (Gap) oberhalb/unterhalb der Zielkarte. Drop auf Spalte schreibt das Quellfeld (wie Sidebar-DnD). Reorder in der Spalte setzt Sort auf **Custom (manual)** und speichert die ID-Liste lokal in `kurrentrc` (`kanbanManualOrder`, Key `view|columnSource`) — **kein** `KURRENT/COLUMN-ORDER` auf dem VTODO. Unveränderte Reihenfolge → kein Custom-Switch.
- **Sort im Kanban:** **Custom (manual)** steht oben im Sort-Menü. Sort-Optionen, die dieselbe Dimension wie die Spaltenquelle sind (z. B. Priorität bei Prioritäts-Spalten), entfallen im Sort-Menü. Custom erscheint nur im Kanban.
- **Phase B (optional):** persistierte Spalte **`KURRENT/COLUMN`** (Slug, z. B. `doing`). Drag zwischen Spalten schreibt Standard-VTODO-Felder (Status, Due, Collection, …) und/oder `KURRENT/COLUMN` — Einstellung „Kanban schreibt: Felder / Custom-Spalte / beides“. Ein Schritt Undo wie in der Liste.
- Spaltenbreite mindestens `Design.kanbanColumnMinWidth`; Kartenabstand `Design.kanbanCardGap`. Zwischen Spalten eine **1px-Trennlinie** (Textfarbe ~12 % Opacity) plus `spaceSmall` Abstand — leere Spalten bleiben als Lane lesbar. Horizontal: `QQC2.ScrollBar` (wie die Aufgabenliste, nicht `ThinScrollBar`). Mittelklick-Ziehen pans die Spaltenleiste. Horizontales Scrollen: äußere Leiste nur über **`Kirigami.WheelHandler`** (kein zweites Custom-Delta — sonst doppelte Schritte/Sprünge). Über Kartenspalten: nur bei dominantem Horizontal-Delta (`pixelDelta.x` / `angleDelta.x`, Notch = `/120` wie Kirigami) an die Spalten-`contentX` weiterreichen. Drop-Lücke: Index aus **Karten-Mittelpunkten** (nicht Delegate-Höhe inkl. Gap-Chrome), damit „unten Karte N“ und „oben Karte N+1“ dieselbe Slot-Position sind.
- Kein Deck/Planix-Board-Sync — Spalten sind Kurrent-eigen oder abgeleitet.

### Swimlanes

- **Zeilen** = Achse (Projekt, Label, Priorität oder Wurzel-Parent); **Spalten** = Zeit (Tag/Woche/Monat) aus `DTSTART`/`DUE`.
- Kompakter **Busy-Day-Streifen** in der Kopfzeile; Tipp auf Datum → Sidebar **Today** (oder Smart View) mit Datumsfilter.
- Gleiche Task-Karten/Delegates wie Kanban, enger.

### Projektplan

- Matrix: Zeilen = Projekte (Kalender), Spalten = ISO-Wochen (oder Monat). Zelle = Anzahl offener Tasks in der Woche (optional später Summe `DURATION` / `KURRENT/ESTIMATE`).
- Klick auf Zelle → gefilterte Liste (temporär oder Smart-View-Vorschau).
- **Icon:** `view-pim-tasks` (KDE-Standard-Icon für PIM-Aufgaben); Ansichtsmodus-Liste in `FullView.viewModeOptions`.

### Heatmap

- Monats- oder Jahresgitter; Zellengröße mindestens `Design.heatmapCellSize`.
- Modus umschaltbar: offene Fälligkeiten pro Tag vs. Erledigungen pro Tag (aus STATUS/`COMPLETED`, nicht gespeicherter „Streak“-Zähler).

### Kalender + Aufgaben

- **Tages-Ansicht:** Event-Streifen (bestehender Event-Cache, opaque/busy wie Notifications) plus VTODO-Liste für denselben Tag — **kein** Zusammenführen von VEVENT und VTODO in 1.0.
- „Block time“ (Task → verknüpftes VEVENT) bewusst **nach 1.0**.

### Smart Views

- Eigener Sidebar-Block **Smart Views** (neben Built-in Views); Reihenfolge in Sidebar-KCM.
- Definition in KCM **Views**: Name, Icon, Filterregeln (Projekt, Labels, Priorität, Text, Due-Fenster, Status, recurring, `KURRENT/LIST`, optional `KURRENT/COLUMN`), optional Sort-Override, Default-**Hauptansichtsmodus**.
- JSON in `kurrentrc` (`smartViews`); Filter materialisiert Tasks nicht in VTODO, außer der User ändert Felder manuell.

### Mehrfachauswahl und Bulk

- Shift/Ctrl+Klick, optional Rubberband in der Liste; Checkbox-Spalte optional (Tasks-KCM).
- Bulk-Toolbar in der **Hauptfläche** (alle Ansichtsmodi): erledigen, löschen, morgen/+1 Tag, Projekt, Label, Priorität, UIDs kopieren — dieselben Akonadi-Jobs wie Einzelaktionen.
- **Undo:** die **letzte Einzelaktion** ist rückgängig machbar (ein Schritt, kein Stapel in 1.0). Das gilt für **alle** nutzerinitiierten Mutationen: erledigen, verschieben (Projekt), löschen, verschieben/verschieben (Due), Editor/Inline-Speichern, Label/Priorität/Status/Secrecy/Location, Kanban-Spalten-Drop (VTODO-Felder) und **lokale** Kanban-Anpassungen (`kanbanManualOrder` + Sort **Custom** in `kurrentrc`, kein VTODO). Bulk-Aktionen belegen den Undo-Slot nicht.

### Undo (Kopfzeile)

- Sichtbarer **`QQC2.ToolButton` Undo** (`edit-undo`) **direkt links** neben dem Ansichtsmodus-Button, in **allen** Hauptansichtsmodi, wenn `backend.canUndo`. Tooltip nennt `undoKind` (`complete`, `reschedule`, `move`, `delete`, `edit`, `kanban`). Standard-Shortcut (Strg+Z / Ctrl+Z) unverändert.
- **Kanban:** ein Drop (Spaltenwechsel + Reorder) = **ein** Undo-Schritt (Aufgabenfelder + manuelle Kartenreihenfolge + ggf. Sort-Modus Custom werden zusammen zurückgesetzt).
- Ergänzt Toolbar/Shortcut in Zeilen/Editoren, ersetzt sie nicht.

### Offline und Pending

- Akonadi down: bestehendes „Akonadi offline“ + Retry; **`controller.loading`**: Placeholder/Boot-Loader.
- Zeilen **`syncing` / pending** in jeder Ansicht; keine lokale Queue über Prozessende hinaus — Fehler → Meldung + Retry. Details unter **Diagnostics**.

### Diagnostics

- KCM **Diagnostics**: Server-Status, Plugin-/Build-Version, Pending/Syncing-Jobs, `debugInfo`-Text (via `PluginController` wie andere KCMs), „Debug kopieren“ (`plasmoid.copyToClipboard`). **Info journal** (`infoJournalLogging`, Default an) und **Verbose journal** (`verboseJournalLogging`, Default aus) in `kurrentrc` → `KurrentLogging::info` / `::verbose` unter `com.github.shrippen.kurrent.akonadi`. Kein `PluginBackend`/`Plasmoid.configuration` in der KCM-Seite — das verhindert den Load. Multiline: `ScrollableTextArea`, nicht `ScrollView`.

### Kollaboration (CalDAV)

- Geteilte Kalender = Projekte; Schreibregeln wie heute.
- **ATTENDEE / ORGANIZER:** read-only anzeigen wenn im VTODO; Editor nur wenn Server schreibt.
- **COMMENT:** anzeigen/anhängen wenn Roundtrip; sonst **DESCRIPTION**.
- **CLASS**, **PERCENT-COMPLETE**, **URL/LOCATION/GEO** wie Editor/Join; Konflikt bei Job-Fehler → Item neu laden, kein 3-Wege-Merge in 1.0.
- Anhänge, volles Kommentar-Threading, Einladungs-Workflow **nach 1.0**.

### Custom Properties (Kanban)

- Bereits **`KURRENT/LIST`** (Tagesabschnitt) via `Todo::setCustomProperty("KURRENT", "LIST", …)`.
- Geplant **`KURRENT/COLUMN`**, optional **`KURRENT/COLUMN-ORDER`**; Interop: **`X-APPLE-SORT-ORDER`** (Tasks.org, Nextcloud Tasks) bevorzugt für Sortierung innerhalb Spalte. Fremde `X-*` nie löschen. Siehe `ROADMAP.md` Recherche-Tabelle.

## Abstände

Nur diese Stufen, keine ad-hoc `smallSpacing`/`largeSpacing`-Mischung:

| Token | Rolle |
| --- | --- |
| `spaceTiny` | Icon-zu-Text, kompakte Sidebar-Zeilen |
| `spaceSmall` | Standard-Innenabstand, Aufgabenzeilen, Control-Reihen |
| `spaceMedium` | Paneel-Lücken, Editor-Formular, Abschnittsumbrüche |
| `spaceLarge` | Große Luft (selten direkt) |
| `panelGap` | Sidebar ↔ Hauptfläche |
| `padInner` | Listen, kompakte Editoren |
| `padEditor` | Full-Editor Formular + Footer |
| `overlayInset` | Sichtbarer Rand um die Full-Editor-Karte (`gridUnit + spaceSmall`) |

## Farbe

- Projekte/Labels/**Locations**: deterministisches HSL aus dem Schlüssel (`colors.js` / `colorForKey`), Sättigung 0,62, Helligkeit 0,46. Optional Hex-Override pro Projekt-ID, Label-Name und Location (`projectColors` / `labelColors` / `locationColors` in `kurrentrc`); leer = Hash. Locations nutzen `kind: "location"`.
- Priorität (KCalendarCore 1–9): 1–3 rot, 4–6 gelb/amber, 7–9 blau; innerhalb der Bandstärke abgestuft (`colorForPriority`).
- Keine zweite Palette in QML hardcoden.

## Icons

- Projektordner überall gleich: `Kirigami.Icon { source: "folder"; color: colorForKey(id) }` mit expliziter Icon-Größe. Nicht `QQC2` `icon.name` + `icon.color` (färbt Breeze-Icons unzuverlässig).
- Projekt-Radios (`ProjectPicker`, wenige Projekte): Radio-Indikator, Ordner-Icon und Name als **Geschwister** in einer `RowLayout` — kein `RadioButton.contentItem`-Override (Plasma legt das Icon sonst unter den Kreis). Priorität darf `icon.name` nutzen (Flaggen); Projekte nicht.
- Labels: `tag` in derselben Farbfunktion.
- Locations: `mark-location` mit `colorForKey(…, "location")` (KCM **Locations** wie Labels: Farben, Sichtbarkeit, Anlegen/Umbenennen/Löschen). Full-Editor: **`LocationPicker`** — **ein** Ort in der Suchzeile (kein Chip darunter); Clear rechts (`edit-clear` wie Start/Due). Klick ohne Ort: Popup + Suche; Klick mit Ort: Text bleibt, Popup zum Wechseln (Filter erst nach Tippen). Vorschläge **nach oben** (`boundsItem`, wie ParentPicker). Label- und Location-Popups: `ThinScrollBar` bei Overflow (`rightMargin` = `Design.spaceSmall`).
- Full-Editor **Section**: schreibt `KURRENT/LIST` (Tagesabschnitt für Today-View / Kanban-Quelle „Day section“) — nicht die Sidebar-Abschnitts-Reihenfolge.
- Sidebar Progress (Balken-Metapher via Battery): `0–25%` → `battery-000`, `26–50%` → `battery-040`, `51–75%` → `battery-060`, `76–100%` → `battery-100`.
- Sidebar Status: Needs action → `view-task`, In process → `media-playback-start`, Completed → `task-complete`, Canceled → `dialog-cancel` (keine „None“-Zeile — View **No status**).
- Sidebar Secrecy: Public → `unlock`, Private → `lock`, Confidential → `security-high`.
- Sidebar-DnD: Fortschritt/Status/Secrecy/Location setzen die jeweiligen VTODO-Felder wie Projekte/Labels/Prioritäten (Location: erneutes Drop auf denselben Ort leert LOCATION).

## Scrollbars

- Dünner Balken rechts, volle Viewport-Höhe: `ThinScrollBar`, `scrollBarExtent` 6px (Sidebar: Breite = `spaceSmall`, in die Margin), Overlay-Optik (Textfarbe, Opacity 0,28/0,40/0,55). Bei Overflow immer sichtbar (kein Fade auf 0).
- Mehrzeilige Felder: `ScrollableTextArea` (`Flickable`), **nicht** `QQC2.ScrollView` (reserviert Breite rechts, zeichnet den Balken links und zu kurz, kann das Widget schmaler machen). Die `TextArea` füllt mindestens die sichtbare Rahmenhöhe (`height: max(implicitHeight, flick.height)`), damit leerer Raum unter dem Text klick-/fokusierbar bleibt — nicht nur die erste Textzeile.
- `implicitWidth: 0` an scrollbaren Feldern, damit der Balken die Widget-Breite nicht treibt.
- Aufgabenliste: feste `scrollGutter`; Sidebar-Abschnitte: feste `spaceSmall`-Margin.
- Aufgabenliste, Sort-Popup: `Kirigami.WheelHandler` wie in Kirigami-Apps (`angleDelta` × `verticalStepSize`, Smooth-Scroll, kein Custom-Coast; Touchpad-Events werden akzeptiert). `filterMouseEvents: true` — Maus flickt nicht, Touch schon. `boundsBehavior: OvershootBounds` plus `returnToBounds()` nach Wheel/Flick/`contentHeight`-Änderung. `ThinScrollBar.stepSize` an den WheelHandler gekoppelt (vertikale Listen). Kanban-Spaltenleiste: gleicher WheelHandler, horizontale Leiste ist `QQC2.ScrollBar`; Mittelklick-Drag pans `contentX`. `Design.applyWheel` nur für Felder, die das Rad schlucken müssen.

## Full-Editor

- Immer ein `FocusScope` **im** Plasmoid, nie `QQC2.Dialog` und nie ein extra Fenster (`popupType: Item` reicht bei Dialogen nicht).
- Abdunklung (`overlayDim` 0,4) über das **gesamte sichtbare Widget**, inklusive Sidebar, Separator, Aufgabenfläche und Plasma-FrameSvg-Ränder/Ecken. Das Dim wird auf den `AppletContainer` umgehängt und färbt den Chrome, **ohne** den Inhalt in die Ränder zu ziehen (`collapseMarginsHint` bleibt aus). Die normalen Plasma-Margins um Sidebar und Liste bleiben.
- Solange der Full-Editor offen ist: **kein Hover-Highlight** auf Sidebar und Hauptfläche (Liste, Kanban, …) unter dem Dim — `interactionsSuspended` von `taskFullEditor.visible`; Dim-`MouseArea` mit `hoverEnabled` fängt Hover ab. Editor-eigene Controls behalten Hover. Die Karte selbst hat **keine vollflächige `MouseArea` über ihren Controls**; Dim und Editor sind getrennte z-gestapelte Geschwister, daher ist kein zusätzlicher Klickfänger nötig. Speichern/Abbrechen/Löschen müssen ihren Pointer-Grab direkt erhalten.
- Karte: abgerundet (`windowRadius`), Rahmen, leichter Schatten, `overlayInset` Abstand zur Inhaltsfläche (plus Container-Padding, wenn das Overlay auf dem Chrome sitzt).
  - Schmal: Karte über dem ganzen Widget (weiterhin eingerückt), wenn die Widget-Breite unter `sidebarWidth + 48×gridUnit + panelGap` liegt.
  - Breit: Karte auf der Aufgabenfläche, Sidebar bleibt in der Abdunklung sichtbar darunter.
- Escape und Klick auf die Abdunklung schließen. Datums-Popups bleiben im Widget.
- Mausrad über der Editorkarte: nur die Karte (bzw. das Beschreibungsfeld) scrollt, nie Aufgabenliste oder Sidebar. Auch am Ende des Scrollbereichs kein Durchreichen.
- Footer: Titel | Löschen | Speichern | Abbrechen. Löschen links neben Speichern, ohne Extra-Bestätigung (wie in der Zeile). Speichern parsed Fällig-/Startdatum über `datetime.js` → `resolveDateFields` (leer = löschen, ungültig = kein Speichern).
- Formular-Labels (`FieldLabel`): **ohne** trailing „:“ (wie Inline-Editor). Standard `AlignVCenter` zur Feldzeile; nur mehrzeilige Beschreibung `AlignTop`. Fortschritt: Label zur **Slider-Zeile** zentrieren, Skalen-Ticks in der nächsten Zeile nur in der Wertspalte.
- Parent: beliebige andere Aufgabe **im gleichen Projekt** als Übergeordnete (`ParentPicker` als Suchfeld wie Labels); keine Selbst-/Nachfahren-Auswahl; Speichern schreibt `RELATED-TO` (wie DnD-Subtask).
  - Suchfeld behält den Fokus zum Tippen (Popup `focus: false`, kein Focus-Steal auf die Liste; kein `TapHandler` über dem Feld). Label „Parent“ vertikal zentriert zur Feldzeile (`AlignVCenter`, nicht `AlignTop`).
  - Vorschläge öffnen **nach oben**; `maxHeight` = Abstand Feldoberkante → Widget-/Overlay-Oberkante (`boundsItem`). Zeile: Prioritäts-Flag und Tag-Chips **vor** dem Aufgabennamen (Farben wie TaskDelegate / `colors.js`).

## Widget-Hintergrund

- An: Desktop-Widget → `StandardBackground` (`DefaultBackground`). Plasma zeichnet `widgets/background` mit Prefix `blurred` und blurrt das Wallpaper im `AppletContainer`. Panel-Flyout → zusätzlich `AppletPopup.StandardBackground` am Popup-Fenster.
- Aus: Desktop → `TranslucentBackground` (durchscheinend, ohne Container-Blur). Panel-Flyout → `AppletPopup.SolidBackground`.
- Einstellungen gemeinsam in `~/.config/com.github.shrippen.kurrent/kurrentrc`.
- Kein eigenes Blur-Shader im Plasmoid.

## Inline-Editor

- Kein extra Fenster. Hover-Fläche dauerhaft mit `highlightColor` bei Opacity 0,12.
- Hintergrund und Breite: volle Delegate-Breite (gleiche linke/rechte Kante wie Zeilen-Hover), **ohne** Hierarchie-Einrückung.
- Öffnen: kurze Aufklappanimation (`openReveal` 0→1, `shortDuration`, OutCubic); bei Reduced Motion sofort voll.
- Schließen (sofort, ohne Speicher): View-/Filter-/Such-/Sortierwechsel, Management-View, DnD-Start, Aufgabe verschwindet aus der gefilterten Liste, Speichern/Abbrechen/Full-Editor.
- Beschreibung über `ScrollableTextArea`.
- Hat das Beschreibungsfeld eine Scrollbar und die Maus steht darüber: nur dieses Feld scrollt, nicht die Aufgabenliste und nicht der Full-Editor-Körper. Ohne Scrollbar darf das Rad nach außen.
- Zeilenhöhe nur über `implicitHeight` der Delegate (keine `height ↔ implicitHeight`-Schleife).

## Popups

- `QQC2.Popup`/`Dialog`: nicht `anchors.fill`. `popupType: Item`, damit nichts als Fenster ausbricht.
- Bestätigungsdialoge (z. B. Label von Aufgabe entfernen) **an den Text anpassen**: Breite = `min(Parent − 2×overlayInset, Inhalt)`, Text `WordWrap`. Feste `gridUnit * N`-Breite ohne Wrap schneidet Übersetzungen ab. Aktionen, die nach DnD bestätigt werden, merken `itemId`/Payload **beim Drop**, nicht erst beim Yes — der Drag ist dann schon beendet.

## Aufgaben-Zustand

- Mutationen (anlegen, erledigen, speichern, verschieben, löschen, **reschedule**, Label add/remove) sofort in der Liste; bis Akonadi bestätigt: `syncing` / `pendingDelete`. Wiederholtes Label-DnD (hinzufügen/entfernen) darf den Chip nicht nach einem kurzen Verschwinden wieder einblenden.
- Ein Schritt **Undo** (Complete / Reschedule / Move / Delete / Edit / Kanban-Layout): **Undo-Button** links neben Ansichtsmodus (alle Modi) plus Toolbar/Shortcut — siehe § Hauptfläche · Undo.
- Unteraufgaben: Pfeil klappt den Teilbaum ein (`flattenTree` lässt Kinder weg).
- Akonadi aus / keine Kalender / leere View: `Kirigami.PlaceholderMessage`, kein nackter Fehlerstring.
- **KDE Store / `.plasmoid`:** nur Widget-UI. Das Akonadi-Backend ist ein kompiliertes QML-Modul (`com.github.shrippen.kurrent`). `main.qml` importiert es nicht statisch — fehlt das Plugin, bleibt das Widget stehen und zeigt `PluginMissingView` statt „module is not installed“: Placeholder, danach der Release-Einzeiler `https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh` in einem wählbaren Feld (`padInner`, `inputRadius`, Rahmen wie Editor-Felder) plus **Copy command** und GitHub. Vollständig: One-Liner (Binary aus dem Release) oder `./install.sh`.
- **Versions-Mismatch:** Widget (`metadata.json` major.minor) und Backend (`TaskController.pluginVersion`, CMake `KURRENT_RELEASE_VERSION`) vergleichen. Bei Abweichung (oder leerem/legacy Backend) zeigt `VersionMismatchBanner` oben in `FullView` und in **General**-KCM ein kompaktes `Kirigami.InlineMessage` (Warning) mit Widget-/Backend-Version (Backend leer → „unknown“), Reinstall-Hinweis und denselben **Copy command** / GitHub-Aktionen wie `PluginMissingView`. Nicht anzeigen wenn das Plugin fehlt (`PluginMissingView` übernimmt).
- Widget-Load darf Akonadi nicht blockieren: Icon und Chrome zuerst, dann D-Bus/Shortcuts (`QTimer::singleShot(0)`), dann `refresh()` (`Qt.callLater`). `ServerManager::start()` ist async, nie `Control::start()`. Cache darf Badge/Liste sofort füllen. Solange der Server startet: Placeholder `loading`; wenn er down bleibt: `offline` plus 5s-Retry. Erst nach `Running` Monitor + Fetch.
- Panel: `preloadFullRepresentation: true` — Plasma lädt die Flyout-Shell beim Applet-Start; `FullView.qml` startet asynchron sobald `PluginBackend` ready ist (nicht erst beim ersten Klick). `pluginLoader` und `fullLoader` bleiben async; Akonadi-Connect blockiert plasmashell nicht.
- **Startup / Flyout:** `PluginBackend.qml` mit `Loader.asynchronous: true`. Flyout-Shell öffnet sofort mit Boot-Loader (rotierendes Breeze-Zahnrad `boot-gear.svg`, abgeleitet von `process-working-symbolic`, + „Connecting to Akonadi…“ / „Loading tasks…“; bei `reducedMotion` statisch); `FullView` lädt asynchron nach (Smoke-Test weiter synchron). Während `controller.loading`: Leiste oben in der Aufgabenliste + Placeholder wenn noch keine Tasks.
- Zeile: Klick öffnet Inline- oder Full-Editor (KCM); Chips für Label/Priorität/Recurring/Progress/Status/Secrecy/Location/Join abschaltbar (Tasks-KCM). **Liste und Kanban** nutzen dieselben Toggles. Progress/Status/Secrecy/Location als Icon-Chips (Tooltips: Prozent, Statusname, Secrecy, Ortsname); Location-Farbe wie Sidebar (`colorForKey(…, "location")`). **Label-Chips** zeigen **immer alle** Kategorien der Aufgabe — auch wenn die Sidebar nach Label filtert (kein Ausblenden des aktiven Tags). Fälligkeit in der Chip-Zeile **ganz rechts** als Text in Akzentfarbe (`highlightColor`; überfällig: `negativeTextColor`), inkl. optionaler relativer Labels und Uhrzeit — kein Hintergrund-Pill; nur über `datetime.js` (`isValidDate`, `formatDueRowLabel`, `isDueBeforeToday`), nie rohes `Qt.formatDate` auf `dueDate`-Rollen.
- Sortierung: gemeinsames Optionen-Set ohne „Standard“; Default **Priorität › Fälligkeit › A–Z** (`priority,due,title`). Zusätzliche Keys: **Projekt**, **Label**, **Priorität**, **Progress**, **Status**, **Secrecy**, **Ort** (jeweils mit Desc-Variante wo sinnvoll), plus Due/Start/Reminder/Recurring/Title/Open first; Kanban **Custom (manual)**. Menü: drei Stufen Radios; breit = drei Spalten. **Gruppierung (Liste):** optional per Group-Button; nutzt `bucket` + Section-Delegate wie Today (`TaskListView`). **Gruppenzugehörigkeit nur am Root-Task** (`applyListGroupTreeBuckets`); Subtasks erben den Bucket und bleiben unter dem Parent (`sortFlatForListGroup` sortiert Wurzel-Bäume, nicht einzelne Zeilen). Gruppen **in Sidebar-Reihenfolge** (unbekannte Schlüssel ans Ende, dort A–Z); innerhalb einer Gruppe Sortierung nur auf Root-Tasks. Passende Sortieroption ausgeblendet. Shared `kurrentrc` über `SharedSettings`. **Sort-Popup:** Optionen pro Stufe **A–Z nach Label** (`localeCompare`, UI-Sprache); Wide/Narrow-Schwellen **einmal beim Start** (`recomputeSortMenuWidthThresholds`); Spalten oben ausgerichtet (`Layout.alignment: AlignTop`). **Große Listen und jede Sort-/Gruppier-Änderung:** Rebuild asynchron (`listReorganizing`); Feedback über `MainPaneHost` / `MainPaneWidgetChrome` (Dim + Zahnrad), nicht mehr als Banner in der Liste.
- Subtasks: beliebige Nesting-Tiefe; Collapse hält den Parent fest. Eingeklappte Nachfahren fehlen in der flachen Liste (`flattenTree` lässt sie weg) — Scrollbar/`contentHeight` nur sichtbare Zeilen. Zeilenlayout: Hierarchie-Einrückung (`taskIndentUnit`), dann reservierte Collapse-Spalte (`taskCollapseCol`), dann Checkbox (Pfeil verschiebt die Checkbox nicht). `reuseItems: true`, `cacheBuffer` ≈ 2 Viewports. Während Wheel-Scroll: kein Hover (`wheelScrolling`). ListView-`spacing` in der Delegate-Höhe.
- Suche / Sidebar-Filter (Projekt, Label, Priorität): Treffer ziehen den **ganzen offenen** Baum der Wurzel mit (Vorfahren + nicht erledigte Nachfahren). Erledigte Subtasks erscheinen dort nicht. **Erledigt-Ansicht:** nur erledigte Aufgaben plus ihre Parent-Kette (auch wenn Parents noch offen sind); offene Geschwister bleiben aus. Während Hierarchie-Filtern ist Collapse ausgesetzt.
- **Filter-Kompatibilität (Sidebar):** Wenn eine Sidebar-Filter-Dimension bereits durch den **Hauptansichtsmodus** oder dessen Optionen materialisiert ist, **verschwindet** der zugehörige Abschnitt bzw. die View (nicht nur ausgegraut). Beispiele: Kanban mit Label-Spalten → Labels-Abschnitt und „Unlabeled“-View; Kanban mit Projekt-Spalten → Projekte; Swimlanes mit Projekt-Zeilen → Projekte; Plan → Projekte. Regel in `main.qml` (`isSidebarFilterEnabled`), Sidebar filtert `visibleSectionIdList` / `visibleViewItems`. Höhen neu über `sectionContentKey` (inkl. Counts/Modus); **Abschnitt-Reparent/`applySectionOrder` nur über `sectionLayoutKey`** (Order/Visibility/Modus) — nicht bei jedem Count-Refresh, sonst bleiben untere Abschnitte (Progress/Status/…) leer trotz allokierter Höhe.
- Sidebar-Counts: Standard zählt auch eingeklappte Subtasks. Option „Exclude collapsed subtasks from counts“ in Sidebar-Einstellungen.
- Erinnerung: VALARM im Full-Editor; Plasma-Benachrichtigung mit Snooze (15 min / 1 h / morgen, schreibt nur den Alarm). Quiet Hours unterdrücken Popups. Optional: Erinnerungen während laufender Kalendertermine unterdrücken (KCM Notifications → „During events“); nur **opaque** (busy) Events zählen, transparente Termine werden ignoriert. Kalenderauswahl wie bei Projekten (CSV `busyCalendarIds`, leer = alle Event-Kalender). Event-Cache wird alle 5 Minuten aus Akonadi neu geladen (±1 Tag Fenster).
- Tastatur im fokussierten Widget: Suche, Neu, Undo, Complete, Delete, Full-Editor, Reschedule, Views 1–5. Global: Meta+Shift+K zeigt das Flyout, Meta+Shift+N legt an (Plasma-Shortcuts, D-Bus `org.github.shrippen.Kurrent`).
- Wiederkehrende Aufgaben: Abhaken schiebt DTSTART/DUE auf die nächste Instanz und lässt die RRULE stehen.
- Today: nur Aufgaben mit Fälligkeit **heute**, gruppiert nach Morning/Afternoon/Evening (`Design` + Stunden im KCM). Überfällige Aufgaben erscheinen **nicht** in Today — dafür ist die Sidebar-View **Overdue** zuständig.
- Meeting-URL in Beschreibung/Ort: kompakter Join-Knopf als **erstes** Element in der Chip-Zeile (vor Labels/Priorität/Recurring; Datum rechts; `internet-services`).
- Rechtsklick: Reschedule (15 min / 1 h / 4 h / morgen / nächste Woche).
- Quick Add im Anlegefeld: Natural Language auf **Englisch plus der UI-Sprache**. Bare Datums-Wörter (`tomorrow` / `morgen`, `next week` / `nächste woche`, Wochentage), Uhrzeit (`18:00`, `6pm`, `18 Uhr`), Präfixe `!priority`, `#label`, `@projekt`.
- Quick Add ist ein **mehrzeiliges** Feld (`TextArea` + `Flickable`, nicht einzeiliges `TextField`): Text wrappt, die Höhe wächst mit (`textLinePx` × Zeilen) bis `quickAddMaxLines` (5), danach interner Scroll mit `ThinScrollBar` / `Design.applyWheel` wie `ScrollableTextArea`. Enter legt an (bzw. übernimmt Vorschlag); Shift+Enter fügt eine Soft-Zeile ein.
- Erkannte Schlüsselwörter werden im Feld farbig und fett hervorgehoben — sie gehören nicht zum Aufgabentitel. Vorschläge (unvollständige oder vertippten Tokens) per ↑/↓, Tab übernimmt, Enter übernimmt wenn der Token noch nicht vollständig ist, sonst legt an. Escape schließt die Liste.
- Fuzzy nur dort, wo klar ein Schlüsselwort gemeint ist: Tippfehler (`tommorow`, `!hihg`) mit Damerau-Distanz, Prefix-Tokens (`!` `#` `@`) schon ab 3 Zeichen. Bare Wörter wie `high` in „The high road“ bleiben Titel. `@` matched Projektnamen (schreibbare, nicht versteckte Kalender).
- Visuell: blasser, `BusyIndicator`, Zeile nicht erneut klickbar. Bei Fehler: Snapshot zurück.
- Neue Aufgaben: temporäre negative Item-ID, nach Create durch die echte ersetzen.
- Persistenz: `TaskController` macht Optimistic UI (Cache, inflight, revert); CRUD-Jobs laufen über `AbstractTaskStore` (`AkonadiTaskStore` live, `MemoryTaskStore` in Unit-Tests ohne Akonadi-Server).

## Schreibbare Kalender

- Anzeigen: Todo-MIME, auch schreibgeschützt (z. B. Feiertags-ICS), wenn Aufgaben da sind.
- Schreiben (anlegen, verschieben, Projekt-Dialog, Default-Projekt): nur `CanCreateItem` plus Todo-MIME. Reine Ordner (`inode/directory`, z. B. DAV-Elternordner) nicht als Projekt führen.

## Drag & Drop

- MIME: `application/x-kurrent-task`.
- Drop auf Projekt nur wenn writable; auf Label = Kategorie **hinzufügen**; hat die Aufgabe das Label schon → Bestätigungsdialog, dann **entfernen**; auf Aufgabe = Unteraufgabe.

## Konfiguration

- Alle KCM-Seiten (General, Appearance, Sidebar, **Views**, Tasks, Editor, Panel, Notifications, Projects, Labels, **Locations**, **Diagnostics**) gelten **gemeinsam** für Desktop-Widget und Panel-Flyout. Jede Seite hat „Reset this page“. Widget-Tastenkürzel und globale Shortcuts werden in Plasma System Settings konfiguriert, nicht in einer eigenen KCM-Seite.
- **Views:** Smart Views anlegen/bearbeiten (Filter, Default-Hauptansichtsmodus, Icon). **Tasks:** Kanban-Spaltenquelle, Multi-Select-Defaults. **Diagnostics:** siehe § Hauptfläche.
- KCM-Kategorie-Icons in `contents/config/config.qml` müssen existierende Breeze-Namen sein (z. B. Panel → `plasmashell`, nicht `panel`).
- Panel-Flyout-Größe: Plasma merkt sich Resize per Drag; keine KCM-Spinboxen für Breite/Höhe. Startgröße über `implicitWidth`/`implicitHeight` der FullView-Hülle.
- Formularseiten nutzen `ConfigFormShell`: zentrierte Spalte, begrenzte Breite. Root = `ConfigPageBase` (deklariert alle `cfg_*` aus `main.xml`, inkl. `*Default`; Plasma 6 setzt sonst „does not have property cfg_…“ auf jeder Seite). Plugin-Zugriff in KCMs: unsichtbarer `ConfigControllerLoader` (0×0), nicht als sichtbares Scroll-Kind. `SimpleKCM` scrollt selbst — keine innere `Flickable`. Schmale Fenster stapeln Labels/Steuerelemente über `Kirigami.FormLayout`. Listen-artige Optionen (Dichte, Vorschauzeilen, Stunden) als Dropdown, nicht SpinBox mit Pfeilen.
- Sidebar-Reihenfolge (Sektionen/Views) in der Sidebar-KCM per Drag-and-drop (`ConfigOrderList` + `Kirigami.ListItemDragHandle`); Mehrfachschritte in einem Griff — Persistenz erst beim Drop.
- Quelle: `~/.config/com.github.shrippen.kurrent/kurrentrc` (Gruppe `General`), im Prozess ein Singleton `SharedSettings`. Instanz-Config in `appletsrc` ist nur ein Cache. Ältere `~/.config/plasma_com.github.shrippen.kurrentrc` wird einmalig dorthin verschoben.
- `Design.qml` liest Sidebar-Breite, Dichte, Overlay-Dim und Reduced Motion aus dieser Config (über `main.qml`).
- Transienter UI-Zustand (aktuelle View sofern nicht „remember last“, Suche, Selektion, eingeklappte Bäume) bleibt pro Instanz.

## i18n

- QML-Strings über `i18n`. Nach neuen UI-Texten `python3 po/generate_po.py`.
---
