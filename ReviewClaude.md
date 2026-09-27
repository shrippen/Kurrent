# Kurrent — Review (Claude)

Stand: Branch `1.0`, Review-Datum 2026-09-15. Fokus laut Auftrag: Design und Features der Ansichten **Swimlanes** und **Projektplan**, plus allgemeiner Scan über Code, Design, Features, Performance, QoL und visuelles Aussehen.

Methodik: QML-Views (`FullView.qml`, `MainPaneHost.qml`, `SwimlaneView.qml`, `PlanView.qml`, `KanbanView.qml`, `HeatmapView.qml`), Backend (`tasklogic.cpp`, `taskcontroller.cpp/.h`), Config (`configViews.qml`) und die Projektdokumente (`Design.md`, `ROADMAP.md`, `to-test.md`) gelesen und gegeneinander abgeglichen. Alle unten als „Bug“ markierten Punkte sind im Code nachvollzogen, nicht nur vermutet — Zeilen sind referenziert.

Kurzfazit vorweg: Liste, Kanban, Heatmap und Kalender+Aufgaben sind spürbar ausgereift (Drag&Drop mit Gap-Indikator, Wheel-Handling, Tooltips, Jahres-/Monatsansicht, Undo). **Swimlanes und Projektplan liegen technisch und gestalterisch klar dahinter** — das deckt sich mit `to-test.md`, wo praktisch jede Swimlane-/Plan-Checkbox noch unangehakt ist. Das ist also kein subjektiver Eindruck, sondern lässt sich an zwei echten Funktionsfehlern und mehreren Konsistenzlücken festmachen.

---

## 1. Swimlanes — Befunde

**Datei:** `plasmoid/com.github.shrippen.kurrent/contents/ui/views/SwimlaneView.qml`

### 1.1 Bug: Klick auf eine Zelle tut nicht, was er soll

```qml
onClicked: {
    if (taskIds.length > 0 && controller) {
        controller.currentView = "list"
    }
}
```

`currentView` ist die **Sidebar-View** (Inbox/Today/Tomorrow/…), nicht der Hauptansichtsmodus (`mainPaneMode`). Das bestätigt `taskcontroller.h:51` (`Q_PROPERTY(QString currentView …)`) im Vergleich zu `mainPaneMode`. In `tasklogic.cpp::matchesView()` (Zeile 59–104) wird jede der bekannten View-IDs geprüft; keine davon heißt `"list"`. Der Code fällt durch alle `if`s durch und landet auf `return true;` (Zeile 104) — das ist exakt das Verhalten von **Inbox** (alles anzeigen).

Konkret passiert beim Klick auf eine Swimlane-Zelle also:
- Der Hauptansichtsmodus bleibt Swimlane (kein Wechsel zur Liste).
- Der bisherige Sidebar-Filter (z. B. „Today“, ein Projekt, ein Smart View) wird **stillschweigend auf „alles anzeigen“ zurückgesetzt** — unabhängig davon, welche Zelle angeklickt wurde.
- Es gibt **keine Filterung auf die angeklickte Spur/Zeit** — der Zellinhalt (`taskIds`) wird nirgends verwendet außer für die Sichtbarkeitsprüfung `taskIds.length > 0`.

Das ist ein Drilldown, der nicht drilldownt — er ist im Effekt fast eine Reset-Aktion, versteckt hinter einem Klick, der wie eine Detailansicht aussieht (Cursor wird zu `PointingHandCursor`, Tooltip zeigt Taskanzahl). Nutzer:innen erwarten an dieser Stelle exakt das Verhalten der Projektplan-Ansicht (siehe unten): Klick → gefilterte Liste dieser Zelle.

**Vergleich Projektplan** (`PlanView.qml:138`): `onClicked: controller.setPlanPreviewFilter(projectId, weekKey)` — das ist der korrekte Ansatz (projekt- und zeitgenau). Die Swimlane-Implementierung wurde offensichtlich nicht auf denselben Stand gebracht.

**Empfehlung:** Analog zu `setPlanPreviewFilter`/`clearPlanPreviewFilter` einen `setSwimlanePreviewFilter(laneKey, timeKey)` im Backend ergänzen (gleiches Muster wie `planPreviewWeek`/`planPreviewProject` in `tasklogic.cpp:408–420`), und beim Klick den Hauptansichtsmodus auf Liste umschalten (`controller.mainPaneMode = Design.viewModeList`), nicht nur den Filter setzen. Sonst bleibt der Nutzer in der Matrix und sieht keine Wirkung.

### 1.2 Kein horizontales Limit auf der Zeitachse (Performance + Layout)

`buildSwimlaneMatrix()` (`tasklogic.cpp:2790–2834`) sammelt **jeden** in den sichtbaren Tasks vorkommenden Zeit-Bucket-Wert ohne Obergrenze. Zum Vergleich: `buildPlanMatrixGrid()` hat einen `horizon`-Parameter (Default 8 Wochen, `taskcontroller.h:596`) und clippt explizit (`tasklogic.cpp:2852–2875`). Für Swimlanes existiert dieser Mechanismus nicht.

Der Default-Zeitbucket für Swimlanes ist **„day“** (`taskcontroller.h:594`: `m_swimlaneTimeBucket = "day"`). In der Praxis heißt das: Ein Nutzer mit ein paar alten überfälligen Aufgaben (z. B. seit 3 Monaten) und ein paar weit in der Zukunft geplanten Aufgaben (z. B. in 6 Monaten) bekommt eine Matrix mit potenziell **hunderten Tagesspalten**, gerendert über verschachtelte `Repeater`s in einem `RowLayout`/`ColumnLayout` innerhalb eines `QQC2.ScrollView` (`SwimlaneView.qml:69–166`) — ohne Virtualisierung (kein `ListView`, keine `reuseItems`). Das ist ein reales Performance- und Usability-Risiko, nicht nur theoretisch: gerade Vielnutzer mit „Aufschieberitis“ (viele überfällige Tasks) oder Projektplanern mit weit gestreuten Fälligkeiten sind die Zielgruppe, die diese Ansicht am ehesten öffnen würde.

**Empfehlung:** Denselben `horizon`-Mechanismus wie bei Plan wiederverwenden (KCM-Feld „Swimlane horizon“ analog zu „Planning horizon“), plus serverseitiges Hardcap (z. B. max. 60 Spalten, Rest in „Older“/„Later“-Sammelspalten wie bei Plan `"overdue"`/`"undated"`).

### 1.3 Spaltenbreite ist für den Inhalt viel zu breit

Jede Zeitspalte ist `Design.kanbanColumnMinWidth` breit (`SwimlaneView.qml:84–93, 111–127`) — das ist `Kirigami.Units.gridUnit * 14` (`Design.qml:156`), ein Wert, der für Kanban-Karten mit Titel, Chips und Beschreibung gedacht ist. In der Swimlane-Zelle steht darin nur eine zentrierte Zahl (`SwimlaneView.qml:140–145`). Bei „day“-Granularität (Default!) verschwendet das enorm Platz: Eine Woche Zeitspalten braucht schon 7×14 = 98 Grid-Units Breite, bevor überhaupt gescrollt werden muss. Es gibt mit `Design.heatmapCellSize` bereits ein passendes, kompaktes Token für genau diesen Zweck (dichte, zahlenbasierte Zellen) — das wird hier nicht verwendet.

**Empfehlung:** Eigenes, deutlich schmaleres Spaltenbreiten-Token für Swimlane-Zeitspalten (orientiert an `heatmapCellSize` bzw. ähnlich wie `PlanView.colWidth`, das schon bucket-abhängig 5/7/9 Grid-Units nutzt statt der Kanban-Breite).

### 1.4 Zeit-/Spur-Beschriftungen sind nicht übersetzbar und nicht nutzerfreundlich formatiert

`swimlaneLaneLabel()` und `swimlaneTimeLabel()` (`tasklogic.cpp:2979–3014`) geben rohe `QStringLiteral`-Strings zurück (`"No label"`, `"High"`, `"Medium"`, `"Low"`, `"None"`, `"Inbox"`, `"Unscheduled"`) — **ohne `tr()`**. Die Namespace-Funktionen in `TaskLogic` haben keine `Q_DECLARE_TR_FUNCTIONS`-Infrastruktur; im Gegensatz dazu läuft die gesamte übrige UI konsequent über `i18n()` in QML (siehe `Design.md`: „QML-Strings über `i18n`“). Das bedeutet: **Diese Beschriftungen fehlen komplett im Übersetzungskatalog** (de/es/fr/ja/zh_CN), obwohl das Projekt aktiv mehrsprachig ist.

Zusätzlich: Für Wochen-/Monats-Buckets wird der rohe interne Key durchgereicht (`swimlaneTimeLabel`, Zeile 3005–3014 — für alles außer `"unscheduled"` wird einfach `key` zurückgegeben). Nutzer sehen also Spaltenköpfe wie `2026-W37` oder `2026-09` statt „8.–14. Sep“ oder „September 2026“. Das ist technisch korrekt, aber für ein poliertes 1.0-Feature spürbar roh — besonders im Kontrast zur Heatmap-Ansicht, die für Monatsnamen sauber `Qt.formatDate(mon, "MMM")` nutzt (`HeatmapView.qml:78`).

**Empfehlung:** (a) `swimlaneLaneLabel`/`swimlaneTimeLabel` in die QML-Schicht verlagern oder mit `tr()`/`i18n()`-fähiger Infrastruktur versehen; (b) Wochen-Keys in ein lesbares Format wie „8.–14. Sep“ übersetzen (dieselbe Woche-zu-Datumsspanne-Logik ließe sich mit Plan teilen).

### 1.5 Kein Drag & Drop — Bruch mit dem etablierten Interaktionsmuster

Kanban erlaubt es, eine Karte zwischen Spalten zu ziehen und schreibt dabei das Backing-Feld (Status/Projekt/Fälligkeit/Label je nach Spaltenquelle) — inklusive Gap-Indikator, Platzhalter, Undo (`KanbanView.qml`, komplett). Swimlanes zeigen exakt dieselbe Grundidee (Spur × Zeit als 2D-Raster), bekommen aber gar keinen `dragHost` übergeben (`MainPaneHost.qml:326–329`: `SwimlaneView { controller: …; interactionsSuspended: … }` — kein `dragHost`). Eine Aufgabe von einer Spur/Zeit in eine andere zu ziehen (z. B. Priorität ändern, auf einen anderen Tag verschieben) ist nicht möglich, obwohl die Datenstruktur (Zelle mit `taskIds`) dafür geradezu einlädt.

Das ist kein Bug, sondern eine bewusste Lücke laut `ROADMAP.md` (0.5c ist als „Swimlanes, Project plan, Heatmap“ vermerkt, ohne DnD-Anspruch) — aber aus Nutzersicht ist es die auffälligste Inkonsistenz: Zwei fast identische Matrix-Metaphern (Kanban-Spalten vs. Swimlane-Zellen) verhalten sich fundamental unterschiedlich interaktiv.

**Empfehlung (Feature, größerer Aufwand):** Drag von einer Zelle in eine andere schreibt je nach Lane-Achse das entsprechende Feld (Projekt/Label/Priorität/Parent) UND verschiebt die Fälligkeit gemäß Zielzeit-Bucket — mit Bestätigungsdialog wenn beide Achsen gleichzeitig geändert würden (analog zum bestehenden Label-Wechsel-Bestätigungsdialog aus `Design.md` § Popups).

### 1.6 Zelle zeigt nur eine Zahl — keine Vorschau, keine Priorität, kein Warnsignal

Die Zelle rendert ausschließlich `String(taskIds.length)` (`SwimlaneView.qml:143`). Es gibt keine Kennzeichnung für überfällige Aufgaben in der Zelle (anders als Projektplan, das `isOverdue` extra rot einfärbt, `PlanView.qml:120–127`), keine Kennzeichnung für hohe Priorität, keinen Mini-Chip für den ersten/wichtigsten Task. Für eine Übersichtsansicht, deren Zweck „auf einen Blick sehen, wo es brennt“ ist, ist reine Mengenangabe zu wenig Information.

**Empfehlung:** Farbintensität zusätzlich nach höchster enthaltener Priorität modulieren (nicht nur nach Anzahl), plus optional eine feine rote Umrandung wenn mindestens ein Task in der Zelle überfällig ist — dieselbe Farbsemantik, die Projektplan schon für `isOverdue` nutzt, ließe sich auf Zellenebene wiederverwenden.

### 1.7 Kein leerer Zustand

Wenn `lanes.length === 0` (z. B. aktiver Filter liefert keine Tasks mit Datum), zeigt `SwimlaneView.qml` schlicht eine leere Fläche — kein `Kirigami.PlaceholderMessage`, wie es `Design.md` als generelle Regel vorschreibt („Akonadi aus / keine Kalender / leere View: `Kirigami.PlaceholderMessage`, kein nackter Fehlerstring“). Projektplan hat immerhin einen Hinweistext (`PlanView.qml:51–55`: „No dated open tasks in this view.“), Swimlane nicht.

**Empfehlung:** Placeholder ergänzen, konsistent mit Plan.

### 1.8 Kein Schnellzugriff in der Kopfzeile

Kanban hat einen eigenen Kopfzeilen-Button „Kanban-Spalten“ (`FullView.qml:1212–1221`, `kanbanColumnsButton`), über den die Spaltenquelle direkt im Hauptbereich gewechselt werden kann, ohne die KCM zu öffnen. Für Swimlane-Achse (Lane-Axis) und Zeit-Bucket sowie für Plan-Zeit-Bucket/-Horizon gibt es **kein Äquivalent** — beides ist ausschließlich über `configViews.qml` (KCM „Views“) erreichbar. Gerade bei einer explorativen Ansicht wie Swimlanes will man aber typischerweise mehrfach pro Sitzung die Achse wechseln („zeig mir das mal nach Priorität statt nach Projekt“) — der Umweg über die Einstellungen bremst genau diesen Anwendungsfall.

**Empfehlung:** Analog zu `kanbanColumnsButton` einen kleinen Kopfzeilen-Button für Swimlane (Lane-Achse + Zeit-Bucket) und einen für Plan (Zeit-Bucket + Horizon) ergänzen.

---

## 2. Projektplan — Befunde

**Datei:** `plasmoid/com.github.shrippen.kurrent/contents/ui/views/PlanView.qml`

### 2.1 Bug: Zellklick kollabiert die Matrix selbst, statt in die Liste zu wechseln

`setPlanPreviewFilter(projectId, weekKey)` (`PlanView.qml:138`) setzt `m_planPreviewProject`/`m_planPreviewWeek` im Backend. In `computeTaskRebuild()` (`tasklogic.cpp:396–423`) wird dieser Filter **direkt auf `out.tasks` angewendet** (Zeile 408–420) — und genau dieses `out.tasks` landet über `applyRebuildOutput()` in `m_taskModel` (`taskcontroller.cpp:4490–4494`, `m_taskModel.setTasks(output.tasks)`). `m_taskModel` ist aber dieselbe Datenquelle, die `planMatrixGridForVisibleTasks()` für den **nächsten** Matrix-Rebuild wieder ausliest (`taskcontroller.cpp:1538–1546`).

Konkreter Ablauf: Nutzer klickt auf Zelle „Projekt X, KW 37“ → Backend filtert das komplette Taskmodell auf genau diese Kombination → beim nächsten Reactive-Rebuild zeigt die Projektplan-Matrix **nur noch eine Zeile mit einer Spalte** (weil nur noch Tasks übrig sind, die exakt in diese eine Zelle fallen) → die Gesamtübersicht ist weg, ohne dass der Hauptansichtsmodus gewechselt hätte. Der einzige Ausweg ist der Button „Clear cell filter“ (`PlanView.qml:153–156`).

Das widerspricht dem in `Design.md` und `ROADMAP.md` beschriebenen Zweck („Klick auf Zelle → gefilterte **Liste** (temporär oder Smart-View-Vorschau)“) — gemeint ist offensichtlich ein Drilldown in die Listenansicht, nicht eine Selbstverstümmelung der Matrixansicht. So wie es jetzt implementiert ist, wirkt ein Klick auf eine belegte Zelle wie ein Fehler („warum ist plötzlich fast alles weg?“), nicht wie eine Detailansicht.

**Empfehlung:** Beim Setzen des Preview-Filters den Hauptansichtsmodus auf Liste wechseln (`controller.mainPaneMode = Design.viewModeList`), damit die Matrix selbst unverändert bleibt und der Nutzer stattdessen die gefilterte Liste sieht. `clearPlanPreviewFilter()` müsste dann beim Verlassen der Liste (oder über einen sichtbaren „Zurück zum Plan“-Pfad) aufgerufen werden.

### 2.2 „Clear cell filter“-Button ignoriert den tatsächlichen Filterzustand

```qml
RowLayout {
    Layout.fillWidth: true
    visible: projects.length > 0
    QQC2.Button { text: i18n("Clear cell filter"); onClicked: controller.clearPlanPreviewFilter() }
}
```

(`PlanView.qml:149–157`) Der Button ist sichtbar, sobald irgendwelche Projekte in der Matrix existieren — unabhängig davon, ob überhaupt ein Zellfilter aktiv ist. Es gibt **keinerlei visuelle Rückmeldung**, ob gerade ein Filter aktiv ist (kein Highlight der angeklickten Zelle, kein Text wie „Filtered: Project X, KW 37“). In Kombination mit 2.1 heißt das: Der einzige Hinweis, dass gerade eine Filterung aktiv ist, ist die veränderte (kollabierte) Matrix selbst — für Erstnutzer kaum selbsterklärend.

**Empfehlung:** Button nur sichtbar/aktiv wenn `controller.planPreviewActive` (neue Property nötig), plus Label das die aktive Zelle benennt; angeklickte Zelle selbst mit Rahmen/Highlight markieren, solange der Filter aktiv ist.

### 2.3 Bug: Tooltip auf Plan-Zellen erscheint praktisch nie

```qml
MouseArea {
    anchors.fill: parent
    enabled: count > 0
    onClicked: controller.setPlanPreviewFilter(projectId, weekKey)
    QQC2.ToolTip.text: i18n("Show %1 tasks", count)
    QQC2.ToolTip.visible: containsMouse
}
```

(`PlanView.qml:135–141`) `hoverEnabled` wird hier **nicht gesetzt**. Der QtQuick-Default für `MouseArea.hoverEnabled` ist `false`; ohne aktiviertes Hover-Tracking wird `containsMouse` bei reiner Mausbewegung (ohne gedrückte Taste) nicht aktualisiert. Der Tooltip „Show N tasks“ erscheint dadurch beim normalen Drüberfahren mit der Maus **nicht** — ein für Endnutzer unsichtbarer, aber klar nachweisbarer Bug. Zum Vergleich: Swimlane setzt korrekt `hoverEnabled: !root.interactionsSuspended` (`SwimlaneView.qml:153`).

**Empfehlung:** `hoverEnabled: true` (bzw. `!root.interactionsSuspended`, siehe 2.4) ergänzen.

### 2.4 `interactionsSuspended` fehlt komplett in PlanView

`PlanView.qml` deklariert die Property `interactionsSuspended` gar nicht, und `MainPaneHost.qml:343–350` übergibt sie auch nicht (`PlanView { controller: host.controller }` — sonst nichts). Bei SwimlaneView, KanbanView und HeatmapView ist sie jeweils vorhanden und verdrahtet. Das ist die im Design-Dokument explizit festgehaltene Regel: „Solange der Full-Editor offen ist: kein Hover-Highlight auf Sidebar und Hauptfläche … unter dem Dim“ — für Projektplan ist diese Regel schlicht nicht umgesetzt. In der Praxis dürfte der übergreifende Dim-`MouseArea` Klicks trotzdem abfangen, aber Hover-Zustand/Cursor-Wechsel auf den Zellen bleibt unter dem abgedunkelten Editor aktiv, was optisch inkonsistent zum Rest der App ist.

**Empfehlung:** Property ergänzen und wie bei den anderen Views durchreichen.

### 2.5 „KCURRENT“ statt „KURRENT“ — Tippfehler in fünf sichtbaren Strings

In `configViews.qml` taucht wiederholt der Property-Namespace **„KCURRENT“** statt „KURRENT“ auf:

- Zeile 236: `i18n("Custom column (KCURRENT/COLUMN)")`
- Zeile 252: `i18n("KCURRENT/COLUMN only")`
- Zeile 635: `i18n("Filter by KCURRENT/LIST day section. …")`
- Zeile 643: `i18n("KCURRENT/COLUMN value…")`
- Zeile 644: `i18n("Filter by a custom KCURRENT/COLUMN value. …")`

Der tatsächliche VTODO-Custom-Property-Namespace ist **`KURRENT`** (siehe `Design.md`: „Bereits `KURRENT/LIST`… via `Todo::setCustomProperty("KURRENT", "LIST", …)`“, sowie `tasklogic.h:499`: `inline const QString Swimlane = QStringLiteral("swimlane")` im selben Header, in dem an anderer Stelle der reale `KURRENT`-Namespace verwendet wird). Das ist zwar formal „nur“ ein Tippfehler in KCM-Beschriftungen, aber gerade hier sicherheitsrelevant für die Bedienbarkeit: Ein technisch versierter Nutzer, der versucht, `KURRENT/COLUMN` manuell auf einem VTODO zu setzen (z. B. über einen anderen CalDAV-Client) und sich an der KCM-Beschriftung orientiert, würde den falschen Property-Namen verwenden und wundern, warum nichts funktioniert.

**Empfehlung:** Fünf `i18n()`-Strings korrigieren, danach `python3 po/generate_po.py` erneut laufen lassen (Design.md-Pflicht bei Textänderungen).

### 2.6 Zeilenbeschriftung nicht responsiv / harte Breite

Die Projektnamen-Spalte hat eine feste Breite `Kirigami.Units.gridUnit * 12` (`PlanView.qml:72, 99`), unabhängig von der tatsächlichen Fensterbreite. Bei langen Projektnamen wird zwar elidiert (`elide: Text.ElideRight`, Zeile 104), aber bei schmalen Panel-Flyouts (Kurrent läuft auch als Panel-Popup, siehe `Design.md` „Panel: kompaktes Masken-Icon“) nimmt diese feste Spalte einen unverhältnismäßig großen Anteil der verfügbaren Breite ein, bevor überhaupt eine Wochenspalte sichtbar wird. Swimlane hat dasselbe Problem mit `Design.kanbanColumnMinWidth` für die Lane-Spalte (`SwimlaneView.qml:84–86, 111–112`).

**Empfehlung:** Beide Row-Header-Spalten an die tatsächlich benötigte Textbreite koppeln (z. B. `TextMetrics`-basiertes Maximum über alle sichtbaren Zeilenbeschriftungen, mit sinnvoller Ober-/Untergrenze), statt fixer Grid-Unit-Werte.

### 2.7 Reine Mengen-Farbcodierung ohne Kapazitätsbezug

Zellfarbe/-opazität skaliert linear mit `count` (`PlanView.qml:120–124`: `opacity: count > 0 ? Math.min(0.9, 0.25 + count * 0.1) : 0.3`). Das sagt „hier sind mehr Aufgaben“, aber nichts über Kapazität oder Überlastung — 8 triviale 5-Minuten-Aufgaben in einer Woche sehen optisch „schlimmer“ aus als 2 mehrtägige Aufgaben, obwohl Letzteres ggf. die kritischere Woche ist. Das ist im Rahmen von 1.0 (reine Zählung, kein `DURATION`/`KURRENT/ESTIMATE`, siehe `ROADMAP.md` §Project plan) bewusst so vereinfacht — für den User als Person, die *planen* will (Kernzweck dieser Ansicht), ist die reine Taskzahl aber ein schwacher Indikator für Auslastung.

**Empfehlung (post-1.0, wie in ROADMAP schon vermerkt):** Optional Summe aus `DURATION` einbeziehen, sobald verfügbar — bis dahin zumindest die Faustregel dokumentieren/im Tooltip klarstellen, dass die Zahl reine Taskanzahl ist, keine Auslastung.

---

## 3. Warum Swimlanes/Plan hinter Kanban/Heatmap zurückbleiben — Reifegradvergleich

| Merkmal | Kanban | Heatmap | Swimlanes | Projektplan |
|---|---|---|---|---|
| Drag & Drop | ✅ vollständig (Gap-Indikator, Undo) | – (nicht sinnvoll) | ❌ fehlt | – (nicht sinnvoll) |
| Klick → sinnvolle Aktion | ✅ (Karte öffnen/Editor) | ✅ (Tag → Agenda) | ❌ Bug (1.1) | ❌ Bug (2.1) |
| Hover-Tooltip | ✅ | ✅ | ✅ | ❌ Bug (2.3) |
| `interactionsSuspended` verdrahtet | ✅ | ✅ | ✅ | ❌ fehlt (2.4) |
| Leerer Zustand | ✅ | ✅ (implizit leeres Grid) | ❌ fehlt (1.7) | ✅ vorhanden |
| Kopfzeilen-Schnellzugriff | ✅ (Spaltenquelle) | ✅ (Month/Year, Mode) | ❌ nur KCM | ❌ nur KCM |
| Übersetzbare Beschriftungen | ✅ | ✅ | ❌ (1.4) | ✅ |
| In `to-test.md` abgehakt | größtenteils ✅ | größtenteils ✅ | fast nichts | fast nichts |

Das Muster ist eindeutig: Swimlanes und Plan wurden nach demselben Bauplan wie Kanban/Heatmap begonnen, aber nicht mit derselben Sorgfalt zu Ende gebracht — vermutlich weil sie zuletzt in der Umsetzungsreihenfolge (0.5c laut `ROADMAP.md`) drankamen. Das ist genau der Bereich, in dem sich am meisten mit überschaubarem Aufwand herausholen lässt, weil die Infrastruktur (Backend-Matrixfunktionen, Grid-Rendering) schon da ist — es fehlt der letzte Politur-Durchgang, den Kanban/Heatmap schon hatten.

---

## 4. Persona-Durchspielungen

**A. Freiberufler mit 3 Kundenprojekten, will Wochenauslastung sehen.**
Öffnet Projektplan → sieht Matrix, klickt auf eine Zelle um Details zu sehen → Matrix kollabiert unerwartet auf eine Zeile (Bug 2.1) → verwirrt, klickt „Clear cell filter“ → zurück zur vollen Matrix, aber jetzt misstrauisch gegenüber der Ansicht. Der Tooltip, der eigentlich vorab Klarheit geschaffen hätte („Show 4 tasks“), erscheint nicht (Bug 2.3) — der einzige Weg, die Zellzahl zu verstehen, ist der sichtbare Zahlenwert selbst.

**B. Studierende:in mit vielen Deadlines, nutzt Swimlanes um nach Priorität zu sortieren.**
Stellt in der KCM „Row axis: Priority“ ein (Umweg über Einstellungen, da kein Kopfzeilen-Schnellzugriff, Befund 1.8). Sieht die Matrix mit Tages-Spalten (Default) — bei mehreren Monaten Vorlauf entstehen sehr viele schmale Spalten (Befund 1.2/1.3), die Ansicht wird unübersichtlich breit und muss weit gescrollt werden. Klickt auf eine hochprioritäre Zelle in der Hoffnung, direkt die Aufgaben zu sehen — landet stattdessen wieder in der (jetzt ungefilterten) Liste (Bug 1.1).

**C. Nutzer mit vielen überfälligen Aufgaben („Aufschieberitis“).**
Swimlanes zeigt wegen fehlendem Horizon-Limit (1.2) unter Umständen dutzende alte Tagesspalten von vor Monaten, bevor überhaupt die aktuelle Woche sichtbar wird — im Gegensatz zu Projektplan, das überfällige Aufgaben sauber in eine einzige „Overdue“-Sammelspalte packt (`buildPlanMatrixGrid`, Zeile 2899–2916). Swimlanes fehlt dieses Konsolidierungsmuster komplett; genau diese Zielgruppe (viele Altlasten) trifft das Problem am härtesten.

**D. Team mit geteiltem Nextcloud-Kalender, mehrere Bearbeiter:innen.**
Projektplan-Zeilen sind Projekte/Kalender — funktioniert grundsätzlich gut für „wer hat wie viel in welchem Kalender diese Woche offen“. Aber: Es gibt keine Möglichkeit, nach Bearbeiter (ATTENDEE) zu gruppieren — das ist laut `ROADMAP.md` bewusst post-1.0 (Collaboration-Bereich), also kein Fehlschlag, aber eine spürbare Grenze für genau dieses Szenario.

---

## 5. Konkrete Feature-Vorschläge (über Bugfixes hinaus)

**Swimlanes**
1. Zeilen-„None“/Sammel-Lanes optisch von echten Lanes absetzen (dezente Trennlinie oder andere Hintergrundfarbe für „No label“/„Inbox“), damit die Struktur (echte Projekte/Labels vs. Restgruppe) auf einen Blick erkennbar ist.
2. Kompaktmodus: Bei Zeit-Bucket „day“ automatisch auf „week“ vorschlagen, sobald mehr als N Spalten entstehen würden (verhindert Befund 1.2/1.3 in der Praxis, ohne die Einstellung zu erzwingen).
3. Busy-Day-Streifen (`SwimlaneView.qml:37–67`) und die Matrix selbst zeigen teils redundante Information (beide leiten aus denselben Fälligkeiten ab) — evtl. den Streifen nur zeigen, wenn Zeit-Bucket „day“ aktiv ist, da er bei „week“/„month“-Bucket weniger Mehrwert bietet.

**Projektplan**
1. Kapazitätsindikator (s. 2.7) mindestens als Tooltip-Zusatz „N Aufgaben, geschätzter Aufwand unbekannt“, um Erwartungen zu steuern.
2. Wenn `setPlanPreviewFilter` künftig in die Liste wechselt (Fix 2.1), einen sichtbaren „← Zurück zum Plan“-Link in der Listenkopfzeile ergänzen, solange ein Plan-Preview-Filter aktiv ist — sonst verliert man den Rückweg.
3. Legende analog zur Heatmap („Few … Many“, `HeatmapView.qml:422–441`) auch für Projektplan ergänzen — aktuell muss man die Opacity-Skala erraten.

---

## 6. Breiterer Scan — restliche Bereiche (kurz)

Da der Auftrag primär Swimlanes/Plan betraf, hier nur die auffälligsten Punkte aus dem übrigen Scan, ohne Anspruch auf Vollständigkeit:

- **Liste/Kanban/Heatmap/Kalender:** Solide, kein dringender Handlungsbedarf gefunden. Kanban-Drag-Code (`KanbanView.qml`) ist bemerkenswert sorgfältig (Gap-Index aus Karten-Mittelpunkten statt Delegate-Höhe, siehe Kommentar Zeile 253–254) — hoher Qualitätsstandard, an dem sich Swimlanes/Plan orientieren sollten.
- **Performance allgemein:** `TaskListView` nutzt `reuseItems: true` und `cacheBuffer` (laut Design.md), Swimlane/Plan-Grids tun das nicht (reine `Repeater`-Verschachtelung). Für die aktuellen Standardgrößen unkritisch, wird aber bei Punkt 1.2 zum echten Problem.
- **i18n-Konsistenz:** Bis auf die in 1.4 und 2.5 genannten Stellen wirkt die i18n-Abdeckung sehr konsequent (durchgängig `i18n()` in QML).
- **Visuelles Erscheinungsbild:** Kanban-Karten und Heatmap-Zellen nutzen durchgängig Theme-Farben (`Kirigami.Theme.*`) korrekt für Light/Dark — Swimlane/Plan tun das ebenfalls korrekt, insofern kein Farbschema-Problem, nur das oben genannte Fehlen von Kontext-/Kapazitätsfarbcodierung.
- **Config/KCM:** `configViews.qml` ist inhaltlich vollständig (Smart Views, Kanban, Swimlane-Achsen, Plan-Horizon) — der einzige Sachfehler ist der KCURRENT-Tippfehler (2.5).

---

## 7. Priorisierte To-Do-Liste

**Quick Wins (Minuten bis Stunden, hoher Nutzeffekt):**
1. `hoverEnabled: true` in `PlanView.qml:135` ergänzen (Tooltip-Bug 2.3).
2. `KCURRENT` → `KURRENT` in `configViews.qml` (5 Stellen, Befund 2.5) + `generate_po.py`.
3. `interactionsSuspended` in `PlanView.qml` ergänzen und in `MainPaneHost.qml` durchreichen (2.4).
4. Placeholder-Message für leere Swimlane-Matrix ergänzen (1.7).

**Mittlerer Aufwand (echte Bugfixes, kein neues Feature):**
5. Swimlane-Zellklick auf echten Drilldown umstellen (`setSwimlanePreviewFilter` + Moduswechsel zu Liste) — Fix für 1.1.
6. Plan-Zellklick so ändern, dass die Matrix selbst nicht kollabiert, sondern der Hauptmodus zur Liste wechselt — Fix für 2.1, inkl. Statusanzeige für 2.2.
7. Horizon-Limit für Swimlanes ergänzen, analog zu Plan (1.2).
8. Swimlane-Spaltenbreite von `kanbanColumnMinWidth` auf ein eigenes, schmaleres Token umstellen (1.3).

**Größere Arbeiten (echte Features):**
9. Übersetzbare, freundlich formatierte Lane-/Zeit-Labels für Swimlanes (1.4).
10. Kopfzeilen-Schnellzugriff für Swimlane-Achse/Zeit-Bucket und Plan-Zeit-Bucket/-Horizon (1.8).
11. Drag & Drop für Swimlane-Zellen (1.5) — größter Einzelaufwand, aber auch größter Wahrnehmungssprung Richtung „genauso ausgereift wie Kanban“.
