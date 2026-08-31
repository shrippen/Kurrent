# Kurrent 1.0 — Manuelle Testliste

Stand: Branch `1.0`, uncommitted, **Build 10** (Sidebar „Build 10“ bei Dev-Install).  
Version in `metadata.json`: **1.0.0**.

Nach `./install.sh`: plasmashell neu starten oder Widget neu laden.  
Desktop- und Panel-Flyout getrennt durchgehen, wo sinnvoll.

---

## Vorbereitung

- [ ] `./install.sh` lief ohne Fehler (Unit-Tests + plasmoidviewer smoke).
- [ ] Sidebar zeigt **Build 10** (nur bei Dev-Build).
- [ ] Akonadi läuft; mindestens ein beschreibbares Todo-Kalender/Projekt aktiv.
- [ ] Configure Kurrent öffnet alle KCM-Seiten ohne QML-Fehler.

---

## Hauptfläche — Ansichtsmodi (FullView-Kopfzeile)

Ansichtsmodus-Button (Gitternetz-Icon) neben Sort / Undo.

- [ ] **List** — bisheriges Verhalten (Suche, Inline-Editor, DnD, Unteraufgaben).
- [ ] **Kanban** — Spalten + Karten (siehe Kanban-Abschnitt).
- [ ] **Swimlanes** — Matrix Spur × Zeit (siehe Swimlanes).
- [ ] **Project plan** — Projekt × Woche-Grid (siehe Plan).
- [ ] **Heatmap** — Tageszellen nach Due/Completions umschaltbar.
- [ ] **Calendar + tasks** — Event-Chips + Tasks für gewählten Tag.
- [ ] Moduswechsel **List ↔ Kanban** ohne Absturz (Smoke-Test-Schritte 23–24).
- [ ] Letzter Modus global gespeichert (`mainPaneMode`): z. B. Kanban wählen → Sidebar-View wechseln → Modus bleibt Kanban; nach Neustart/plasmashell wiederhergestellt.
- [ ] Smart-View-Default-Modus im KCM (falls noch gespeichert) ändert den globalen `mainPaneMode` beim Sidebar-Wechsel **nicht**.

---

## Kopfzeile — Undo, Status, Banner

- [ ] **Undo**-Button sichtbar in **allen** Ansichtsmodi (nicht nur List), wenn `canUndo`.
- [ ] Undo nach Complete / Reschedule / Move / Delete in List; Tooltip zeigt Art („Undo complete“ …).
- [ ] **Ctrl+Z** / Standard-Undo funktioniert weiterhin.
- [ ] **„Akonadi offline“** (rot), wenn Server down; **„Syncing…“**, wenn Jobs pending.
- [ ] **Version-Mismatch-Banner**, wenn Store-Widget ≠ installiertes Plugin (falls reproduzierbar).
- [ ] **Konflikt-Banner**: bei Server-Konflikt (z. B. parallel in Merkuro editieren) → „Reload“ lädt Item neu, „Dismiss“ schließt Hinweis.

---

## Smart Views

### Sidebar

- [ ] Block **Smart Views** mit angelegten Views sichtbar.
- [ ] Klick wechselt Filter + ggf. Default-Ansichtsmodus.
- [ ] Smart View zählt in Sidebar-Counts mit.

### KCM — Views

- [ ] **Neue Smart View** anlegen (Dialog).
- [ ] **Bearbeiten**: Name, Icon, Default-Modus (List/Kanban/…), Sort-Override.
- [ ] **Filterregeln**: Text, Label, Status, Due-Fenster, Priorität, „Recurring only“, `KURRENT/LIST`, `KURRENT/COLUMN`.
- [ ] **Built-in duplizieren** (Combo „Duplicate built-in view…“) — z. B. Today als Vorlage.
- [ ] Smart View **löschen** (Papierkorb).
- [ ] **Kanban — Default column source** (Status, Project, Due, …).
- [ ] **Kanban writes**: Standard-Felder / nur `KURRENT/COLUMN` / Beides.
- [ ] **Swimlanes**: Lane-Achse (Project, Label, Priority, Parent), Zeit-Achse (Day, Week, Month).
- [ ] Reset-Seite Views setzt Defaults zurück.

---

## Kanban

Voraussetzung: Ansichtsmodus Kanban, Spaltenquelle in KCM Views oder Tasks.

- [ ] Spalten je nach Quelle: Status, Open/Done, Project, Due-Buckets, Priority, Label, Day section, Custom (`KURRENT/COLUMN`).
- [ ] Karten zeigen Titel, Projekt, optional **% complete** (1–99).
- [ ] Karten **nur in passender Spalte** (keine leeren Platzhalter-Höhen in falscher Spalte).
- [ ] **Drag** Karte in andere Spalte → Feld wird geschrieben (Status, Due, Collection, Label, … je nach Spaltenquelle).
- [ ] **Undo** nach Kanban-Drag (ein Schritt).
- [ ] Sortierung innerhalb Spalte: `X-APPLE-SORT-ORDER` / `KURRENT/COLUMN-ORDER` (Round-Trip in anderem Client optional prüfen).
- [ ] Schreibmodus **custom**: Drag ändert nur `KURRENT/COLUMN`.
- [ ] Schreibmodus **both**: Standardfeld + `KURRENT/COLUMN`.
- [ ] Horizontal scrollen bei vielen Spalten.

---

## Swimlanes

- [ ] Matrix: Zeilen = Spur (Project/Label/Priority/Parent laut KCM), Spalten = Zeit-Buckets.
- [ ] Zell-Inhalt: Anzahl Tasks; Tooltip/Hover.
- [ ] **Busy days**-Streifen oben; Tipp → Sidebar Today (oder ähnlicher Sprung).
- [ ] Achse **Week/Month** in KCM ändern → Spalten-Labels passen sich an.
- [ ] Leere View: sinnvoller leerer Zustand.

---

## Project plan

- [ ] Grid: Zeilen = Projekte/Inbox, Spalten = ISO-Wochen.
- [ ] Zellen mit Count > 0 klickbar → **Zellenfilter** (nur Tasks dieser Woche + Projekt).
- [ ] **Clear cell filter** hebt Filter wieder auf.
- [ ] Leerer Hinweis, wenn keine datierten offenen Tasks.

---

## Heatmap

- [ ] Modus **Due dates** vs **Completions** umschalten.
- [ ] Intensität/Farbe skaliert mit Count.
- [ ] Tooltip zeigt Datum + Anzahl.

---

## Calendar + tasks (Day agenda)

- [ ] Busy-**Event-Chips** für gewählten Tag (wenn Event-Kalender in Notifications/Busy konfiguriert).
- [ ] **Tasks due this day** darunter (gefiltert auf Datum).
- [ ] Tag ohne Events: „No busy events for this day.“

---

## Mehrfachauswahl & Bulk

KCM Tasks: **Enable multi-select** aktivieren.

- [ ] **Ctrl+Klick** toggelt Auswahl; Auswahl bleibt über Scroll.
- [ ] **BulkActionBar** in Hauptfläche (alle Modi, nicht nur List), wenn ≥1 Task selected.
- [ ] **Complete** — alle ausgewählten erledigen.
- [ ] **Delete** — alle löschen (ggf. Confirm-Delete aus General).
- [ ] **Tomorrow** — Reschedule morgen.
- [ ] **+1 day** — Due +1 Tag.
- [ ] **Move to project** — Untermenü mit Projekten.
- [ ] **Add label** — Label aus Liste hinzufügen.
- [ ] **Set priority** — High / Medium / Low / None.
- [ ] **Copy UIDs** — Zwischenablage (z. B. in Editor einfügen).
- [ ] **Clear selection** — Auswahl aufheben.
- [ ] **Undo nach Bulk**: erwartetes Verhalten — Bulk belegt Undo-Stapel **nicht**; nur letzte Einzelaktion undo-bar (siehe Design.md).

---

## List-View (Regression + Shortcuts)

- [ ] `/` und **Ctrl+F** → Suche fokussieren.
- [ ] **Ctrl+N** → neue Aufgabe.
- [ ] **1–5** → Sidebar-Views wechseln.
- [ ] **E** → Full editor für Auswahl.
- [ ] **X** → Complete; **T** → Tomorrow; **Delete** → Löschen.
- [ ] Catch-up „Still open“ in Today (wenn in General aktiv).
- [ ] Join-Button bei http(s)-URL in Beschreibung/Location.

---

## Editor & Kollaboration

- [ ] Full editor: **Assignees** read-only, wenn Server `ATTENDEE` liefert.
- [ ] **Open map**, wenn VTODO **GEO** gesetzt (Link zu OpenStreetMap).
- [ ] **Percent complete** Slider speichern und in List/Kanban sichtbar.
- [ ] `KURRENT/LIST` (Section) im Editor → Day-section-Kanban-Spalte.

---

## Diagnostics (KCM)

- [ ] Seite **Diagnostics** öffnet.
- [ ] Akonadi-Status (online/offline), Plugin-/Release-Version, Widget-Version.
- [ ] Todo-Collections-Count, Pending jobs.
- [ ] **Copy debug bundle** → Zwischenablage mit redigierter Config + Log-Hinweis.
- [ ] Hinweis auf `KURRENT_SMOKE=1` und Log-Pfad `~/.cache/kurrent-smoke/`.

---

## KRunner

Plugin installiert unter `~/.local/lib/qt6/plugins/kf6/krunner/` (nach `./install.sh`).

- [ ] **KRunner** öffnen (Alt+Space o.g.).
- [ ] `kurrent` → „Open Kurrent“ → Flyout öffnet.
- [ ] `task today` / `kurrent today` → View Today + Flyout.
- [ ] `task Rechnung` → „Search tasks for …“ → Flyout + Suchfeld mit Text.
- [ ] `task Rechnung` → „Add task …“ → neue Aufgabe mit Summary (oder Quick-Add-Fokus).

*(Falls Runner nicht erscheint: `kbuildsycoca6` oder Ab-/Anmeldung.)*

---

## Globale Shortcuts / D-Bus (Regression)

- [ ] **Meta+Shift+K** — Kurrent öffnen (wenn in System Settings konfiguriert).
- [ ] **Meta+Shift+N** — Add task.
- [ ] D-Bus: `qdbus org.github.shrippen.Kurrent /Kurrent org.github.shrippen.Kurrent.show`

---

## Einstellungen — Persistenz & Sync

- [ ] **Desktop-Widget** und **Panel-Flyout** teilen dieselben Werte (Sidebar-Breite, Smart Views, Kanban-Defaults, Multi-Select).
- [ ] Jede KCM-Seite: **Reset this page** funktioniert.
- [ ] `~/.config/com.github.shrippen.kurrent/kurrentrc`: neue Keys u. a. `mainPaneMode`, `smartViews`, `kanbanColumnSource`, `kanbanWriteMode`, `swimlaneLaneAxis`, `swimlaneTimeBucket`, `multiSelectEnabled`.

---

## i18n (Stichprobe)

Sprache in System Settings umstellen (de, es, fr, ja, zh_CN).

- [ ] Kopfzeile: View mode, Syncing…, Undo-Tooltips.
- [ ] KCM Views: Smart View Editor, Kanban writes, Swimlanes-Achsen.
- [ ] BulkActionBar: „Move to project“, „Copy UIDs“, „+1 day“.
- [ ] Konflikt-Banner: Reload / Dismiss.
- [ ] Keine offensichtlichen englischen Fallbacks in neuen 1.0-Strings (389 msgids im Katalog).

---

## Automatisierte Tests (Referenz)

Bereits grün in `./install.sh`:

- [ ] `kurrent-tasklogic`, `kurrent-sharedsettings`, `kurrent-models`, `kurrent-calendar`, `kurrent-taskstore`, `kurrent-qml`
- [ ] plasmoidviewer smoke: desktop + panel

Neue/erweiterte Unit-Tests u. a.: Kanban-Spalten-Mapping, Smart-View-JSON, Swimlane/Plan/Heatmap-Helper, `KURRENT/COLUMN`, Kanban-Sort-Order, X-`OC-HIDESUBTASKS`-Erhalt bei Modify.

---

## Bewusst nicht testen / nicht enthalten

- [ ] ~~AUR / COPR / `install-linux.sh` Easy Install~~ — nicht in diesem Changeset.
- [ ] ~~GitHub Release / Tag v1.0.0~~ — nur auf explizite Freigabe.
- [ ] Smart View **Materialisierung** als Label auf VTODO — nicht implementiert.
- [ ] Bulk-**Undo** für Sammelaktionen — bewusst nicht (Design.md).
- [ ] Deck/Planix-Spalten-Sync — dokumentierte Interop-Grenzen (ROADMAP).

---

## Bekannte Smoke-Hinweise (optional)

`plasmoidviewer`-Smoke schlägt fehl bei QML-Laufzeitfehlern in Kurrent-QML (u. a. `Invalid argument passed to formatDate` / `formatTime`, `TypeError`, `: Error:` in Plasmoid-Pfaden). Datums-Chips nutzen `datetime.js` (`isValidDate`, `formatDueRowLabel`).

---

## Kurz-Checkliste „Alles einmal durch“

1. Smart View anlegen (Filter + Kanban-Default) → Sidebar → Matrix sichtbar.  
2. Today → Kanban → Karte draggen → Undo.  
3. Swimlanes + Plan + Heatmap + Calendar je 30 s ansehen.  
4. Multi-Select → Bulk Move + Copy UIDs.  
5. KCM Diagnostics + Copy debug.  
6. KRunner `task morgen`.  
7. Panel-Flyout: gleicher Modus/Smart View wie Desktop.  
8. Sprache DE → neue Strings lesbar.

---

*Datei für manuelles QA — nach Release wieder entfernen oder ins Wiki übernehmen.*
