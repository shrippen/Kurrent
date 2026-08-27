# Kurrent — Design

Prosa-Referenz für UI- und UX-Entscheidungen. Laufzeit-Tokens: `plasmoid/com.github.shrippen.kurrent/contents/ui/Design.qml`. Akzente: `contents/ui/colors.js`. Projektübergreifende Designsprache (Farbpalette, Typografie, Icon-Stil, Landing-Page-Template): **[DesignDefault](https://github.com/shrippen/DesignDefault)**.

Diese Datei ist die **menschliche Quelle** für das Warum. `Design.qml` ist die **maschinelle Quelle** für Maße. Beides bei jeder neuen visuellen Entscheidung im selben Change aktualisieren (Cursor-Regel `.cursor/rules/kurrent-ui.mdc`). Es gibt keinen Datei-Watcher — „automatisch“ heißt: jeder Agent-Change an der UI muss diese Datei mitziehen.

---

## Produkt

- Name: **Kurrent**. Plasmoid-ID `com.github.shrippen.kurrent`.
- Autor: shrippen. Website und Issues: GitHub-Repo `https://github.com/shrippen/Kurrent` (About-Dialog im Widget).
- Plasma 6, Akonadi/CalDAV, kein eigenes Login.
- Panel: kompaktes Masken-Icon (`Kirigami.Icon { isMask: true; color: textColor }`), Breeze `ColorScheme-Text` / `currentColor`.
- Desktop: volle Ansicht, frei skalierbar.

## Layout

- Links Sidebar (Projekte, Labels, Prioritäten, Views), 1px-Separator, rechts Aufgabenfläche.
- Sidebar-Breite: `Design.sidebarWidth` aus `sidebarWidthUnits` (6–20 Grid-Units, Default 10), gemeinsam in `kurrentrc`.
- Dichte: `Design.density` (`auto` / `compact` / `comfortable`) steuert `taskRowPad` für Aufgabenzeilen. Sidebar-Zeilen extra über `sidebarRowSize`.
- Overlay-Dim in drei Stufen (`overlayDimStep` 0/1/2 → 0,25 / 0,40 / 0,55).
- Reduced motion: kein Sync-Spinner, kein Hover-Flash auf Aufgabenzeilen.
- Sidebar-Abschnitte (Views/Projekte/Labels/Prioritäten) und einzelne Views: Reihenfolge und Sichtbarkeit aus `kurrentrc`.
- Desktop-`fullRepresentation`: Default `52×40` Grid-Units. `Layout.maximumWidth/Height: Infinity`.
- Inhalt bleibt **innerhalb** der Plasma-FrameSvg-Margins. Ränder nicht mit `collapseMarginsHint` kollabieren.
- **Nicht** `width`/`height` am `PlasmoidItem` binden. **Nicht** `Layout.maximumWidth: Infinity` am Plasmoid-Root.
- Listen und Sidebar, die die Höhe füllen: `implicitHeight: 0`, `Layout.preferredHeight: 0`. `ListView.contentHeight` darf nie die maximale Desktop-Widget-Höhe werden.
- Extra Höhe der Sidebar gleichmäßig auf alle Abschnitte verteilen (nicht bei „alles ohne Scrollbar sichtbar“ stoppen).
- Passt die **natürliche** Höhe aller sichtbaren Abschnitte (Zeilenanzahl × Zeilenhöhe, inkl. touchfreundlich) **nicht** in die Sidebar: Anteile proportional zur natürlichen Höhe (nicht gleiche Viertel), jeder Abschnitt scrollt intern (`ThinScrollBar`). Bis die erste Verteilung gelaufen ist (`sectionsAllocated`), gleiche Startanteile — danach nie wieder `Alloc == -1` als „noch nicht berechnet“ missverstehen (`-1` war früher der Sentinel und wirkte wie Equal-Split bei knapper Höhe).
- **Near-fit (eine Zeile):** Fehlt einem Abschnitt höchstens eine Zeilenhöhe (+ Gap) zur Natural-Höhe, bekommt er die volle Natural-Höhe (Pixel von Abschnitten, die sowieso mehr als eine Zeile Overflow haben). Größerer Shortfall → Squeeze + Scrollbar. `listNeedsScroll`: `contentHeight > height + 1`.
- Sidebar-Scrollbar: bei Overflow sichtbar (`AlwaysOn` + hide wenn fit), Breite passt in die **feste** `rightMargin` (`Design.spaceSmall`) — Margin wächst/schrumpft nicht mit der Scrollbar.
- Sidebar-Breite per Ziehen am Separator (`SplitHCursor`), 6–20 Grid-Units, speichert `sidebarWidthUnits`.

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

- Projekte/Labels: deterministisches HSL aus dem Schlüssel (`colors.js` / `colorForKey`), Sättigung 0,62, Helligkeit 0,46. Optional Hex-Override pro Projekt-ID und Label-Name (`projectColors` / `labelColors` in `kurrentrc`); leer = Hash.
- Priorität (KCalendarCore 1–9): 1–3 rot, 4–6 gelb/amber, 7–9 blau; innerhalb der Bandstärke abgestuft (`colorForPriority`).
- Keine zweite Palette in QML hardcoden.

## Icons

- Projektordner überall gleich: `Kirigami.Icon { source: "folder"; color: colorForKey(id) }` mit expliziter Icon-Größe. Nicht `QQC2` `icon.name` + `icon.color` (färbt Breeze-Icons unzuverlässig).
- Projekt-Radios (`ProjectPicker`, wenige Projekte): Radio-Indikator, Ordner-Icon und Name als **Geschwister** in einer `RowLayout` — kein `RadioButton.contentItem`-Override (Plasma legt das Icon sonst unter den Kreis). Priorität darf `icon.name` nutzen (Flaggen); Projekte nicht.
- Labels: `tag` in derselben Farbfunktion.

## Scrollbars

- Dünner Balken rechts, volle Viewport-Höhe: `ThinScrollBar`, `scrollBarExtent` 6px (Sidebar: Breite = `spaceSmall`, in die Margin), Overlay-Optik (Textfarbe, Opacity 0,28/0,40/0,55). Bei Overflow immer sichtbar (kein Fade auf 0).
- Mehrzeilige Felder: `ScrollableTextArea` (`Flickable`), **nicht** `QQC2.ScrollView` (reserviert Breite rechts, zeichnet den Balken links und zu kurz, kann das Widget schmaler machen).
- `implicitWidth: 0` an scrollbaren Feldern, damit der Balken die Widget-Breite nicht treibt.
- Aufgabenliste: feste `scrollGutter`; Sidebar-Abschnitte: feste `spaceSmall`-Margin.
- Aufgabenliste und Sort-Popup: `Kirigami.WheelHandler` wie in Kirigami-Apps (`angleDelta` × `verticalStepSize`, Smooth-Scroll, kein Custom-Coast; Touchpad-Events werden akzeptiert). `filterMouseEvents: true` — Maus flickt nicht, Touch schon. `boundsBehavior: OvershootBounds` plus `returnToBounds()` nach Wheel/Flick/`contentHeight`-Änderung, damit schneller Touchpad-Scroll am Rand zurückfedert statt hängen zu bleiben. `ThinScrollBar.stepSize` an den WheelHandler gekoppelt. `Design.applyWheel` nur für Felder, die das Rad schlucken müssen.

## Full-Editor

- Immer ein `FocusScope` **im** Plasmoid, nie `QQC2.Dialog` und nie ein extra Fenster (`popupType: Item` reicht bei Dialogen nicht).
- Abdunklung (`overlayDim` 0,4) über das **gesamte sichtbare Widget**, inklusive Sidebar, Separator, Aufgabenfläche und Plasma-FrameSvg-Ränder/Ecken. Das Dim wird auf den `AppletContainer` umgehängt und färbt den Chrome, **ohne** den Inhalt in die Ränder zu ziehen (`collapseMarginsHint` bleibt aus). Die normalen Plasma-Margins um Sidebar und Liste bleiben.
- Karte: abgerundet (`windowRadius`), Rahmen, leichter Schatten, `overlayInset` Abstand zur Inhaltsfläche (plus Container-Padding, wenn das Overlay auf dem Chrome sitzt).
  - Schmal: Karte über dem ganzen Widget (weiterhin eingerückt).
  - Breit: Karte auf der Aufgabenfläche, Sidebar bleibt in der Abdunklung sichtbar darunter.
- Escape und Klick auf die Abdunklung schließen. Datums-Popups bleiben im Widget.
- Mausrad über der Editorkarte: nur die Karte (bzw. das Beschreibungsfeld) scrollt, nie Aufgabenliste oder Sidebar. Auch am Ende des Scrollbereichs kein Durchreichen.
- Footer: Titel | Löschen | Speichern | Abbrechen. Löschen links neben Speichern, ohne Extra-Bestätigung (wie in der Zeile).
- Parent: beliebige andere Aufgabe **im gleichen Projekt** als Übergeordnete (`ParentPicker` als Suchfeld wie Labels); keine Selbst-/Nachfahren-Auswahl; Speichern schreibt `RELATED-TO` (wie DnD-Subtask).
  - Suchfeld behält den Fokus zum Tippen (Popup `focus: false`, kein Focus-Steal auf die Liste; kein `TapHandler` über dem Feld). Label „Parent:“ vertikal zentriert zur Feldzeile (`AlignVCenter`, nicht `AlignTop`).
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

## Aufgaben-Zustand

- Mutationen (anlegen, erledigen, speichern, verschieben, löschen, **reschedule**) sofort in der Liste; bis Akonadi bestätigt: `syncing` / `pendingDelete`.
- Ein Schritt **Undo** (Complete / Reschedule / Move / Delete) in der Toolbar und per Standard-Undo-Shortcut.
- Unteraufgaben: Pfeil klappt den Teilbaum ein (`flattenTree` lässt Kinder weg).
- Akonadi aus / keine Kalender / leere View: `Kirigami.PlaceholderMessage`, kein nackter Fehlerstring.
- **KDE Store / `.plasmoid`:** nur Widget-UI. Das Akonadi-Backend ist ein kompiliertes QML-Modul (`com.github.shrippen.kurrent`). `main.qml` importiert es nicht statisch — fehlt das Plugin, bleibt das Widget stehen und zeigt `PluginMissingView` statt „module is not installed“: Placeholder, danach der Release-Einzeiler `https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh` in einem wählbaren Feld (`padInner`, `inputRadius`, Rahmen wie Editor-Felder) plus **Copy command** und GitHub. Vollständig: One-Liner (Binary aus dem Release) oder `./install.sh`.
- Widget-Load darf Akonadi nicht blockieren: Icon und Chrome zuerst, dann D-Bus/Shortcuts (`QTimer::singleShot(0)`), dann `refresh()` (`Qt.callLater`). `ServerManager::start()` ist async, nie `Control::start()`. Cache darf Badge/Liste sofort füllen. Solange der Server startet: Placeholder `loading`; wenn er down bleibt: `offline` plus 5s-Retry. Erst nach `Running` Monitor + Fetch.
- Panel: `preloadFullRepresentation: false`, `preferredRepresentation` ist das Compact-Icon. Plasma delayed-preloadet nur eine leere Größen-Hülle; `FullView.qml` (Sidebar, Liste, Editor) wird erst beim ersten Öffnen des Flyouts geladen.
- **Startup / Flyout:** `PluginBackend.qml` mit `Loader.asynchronous: true`. Flyout-Shell öffnet sofort mit Boot-Loader („Connecting to Akonadi…“ / „Loading tasks…“ + indeterminate `ProgressBar`); `FullView` lädt asynchron nach (Smoke-Test weiter synchron). Während `controller.loading`: Leiste oben in der Aufgabenliste + Placeholder wenn noch keine Tasks.
- Zeile: Klick öffnet Inline- oder Full-Editor (KCM); Chips für Label/Priorität/Recurring/Join abschaltbar. Fälligkeit in der Chip-Zeile **ganz rechts** als Text in Akzentfarbe (`highlightColor`; überfällig: `negativeTextColor`), inkl. optionaler relativer Labels und Uhrzeit — kein Hintergrund-Pill.
- Sortierung: gemeinsames Optionen-Set ohne „Standard“; Default **Priorität › Fälligkeit › A–Z**. Menü als Popup (bleibt nach Klick offen) mit drei Stufen Radios; Scrollbereich wie die Aufgabenliste (`Kirigami.WheelHandler`, `OvershootBounds`, `ThinScrollBar`). Gegenläufige Paare desselben Felds (A–Z/Z–A, Fälligkeit auf/ab, Erinnerung/Wiederkehrend zuerst/zuletzt, Fortschritt niedrig/hoch) sind über Stufen hinweg exklusiv; Kollision setzt tiefere Stufe auf „Keine“. Weitere Keys: Startdatum, Open first. Sort ist **nur session-weit** (`backend.sortMode`); kein KCM-/Shared-Setting, kein Persist in `kurrentrc` / `Plasmoid.configuration` — jeder Start setzt `priority,due,title`.
- Subtasks: beliebige Nesting-Tiefe; Collapse hält den Parent fest. Eingeklappte Nachfahren fehlen in der flachen Liste (`flattenTree` lässt sie weg) — Scrollbar/`contentHeight` nur sichtbare Zeilen. Zeilenlayout: Hierarchie-Einrückung (`taskIndentUnit`), dann reservierte Collapse-Spalte (`taskCollapseCol`), dann Checkbox (Pfeil verschiebt die Checkbox nicht). `reuseItems: true`, `cacheBuffer` ≈ 2 Viewports. Während Wheel-Scroll: kein Hover (`wheelScrolling`). ListView-`spacing` in der Delegate-Höhe.
- Suche / Sidebar-Filter (Projekt, Label, Priorität): Treffer ziehen den **ganzen offenen** Baum der Wurzel mit (Vorfahren + nicht erledigte Nachfahren). Erledigte Subtasks erscheinen dort nicht. **Erledigt-Ansicht:** nur erledigte Aufgaben plus ihre Parent-Kette (auch wenn Parents noch offen sind); offene Geschwister bleiben aus. Während Hierarchie-Filtern ist Collapse ausgesetzt.
- Sidebar-Counts: Standard zählt auch eingeklappte Subtasks. Option „Exclude collapsed subtasks from counts“ in Sidebar-Einstellungen.
- Erinnerung: VALARM im Full-Editor; Plasma-Benachrichtigung mit Snooze (15 min / 1 h / morgen, schreibt nur den Alarm). Quiet Hours unterdrücken Popups.
- Tastatur im fokussierten Widget: Suche, Neu, Undo, Complete, Delete, Full-Editor, Reschedule, Views 1–5. Global: Meta+Shift+K zeigt das Flyout, Meta+Shift+N legt an (Plasma-Shortcuts, D-Bus `org.github.shrippen.Kurrent`).
- Wiederkehrende Aufgaben: Abhaken schiebt DTSTART/DUE auf die nächste Instanz und lässt die RRULE stehen.
- Today: fällig heute, gruppiert nach Morning/Afternoon/Evening (`Design` + Stunden im KCM). Unerledigte überfällige Aufgaben (dieselbe Menge wie die Overdue-View) erscheinen oben als **Still open** (Catch-up), wenn Catch-up an ist — kein N-Tage-Lookback, kein Auto-Rollover. Overdue bleibt eine eigene Sidebar-View.
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
- Drop auf Projekt nur wenn writable; auf Label = Kategorie setzen; auf Aufgabe = Unteraufgabe.

## Konfiguration

- Alle KCM-Seiten (General, Appearance, Sidebar, Tasks, Editor, Panel, Notifications, Projects, Labels) gelten **gemeinsam** für Desktop-Widget und Panel-Flyout. Jede Seite hat „Reset this page“. Widget-Tastenkürzel und globale Shortcuts werden in Plasma System Settings konfiguriert, nicht in einer eigenen KCM-Seite.
- Formularseiten nutzen `ConfigFormShell`: zentrierte Spalte, begrenzte Breite. `SimpleKCM` scrollt selbst — keine innere `Flickable`. Schmale Fenster stapeln Labels/Steuerelemente über `Kirigami.FormLayout`. Listen-artige Optionen (Dichte, Vorschauzeilen, Stunden) als Dropdown, nicht SpinBox mit Pfeilen.
- Sidebar-Reihenfolge (Sektionen/Views) in der Sidebar-KCM per Drag-and-drop (`ConfigOrderList` + `Kirigami.ListItemDragHandle`); Mehrfachschritte in einem Griff — Persistenz erst beim Drop.
- Quelle: `~/.config/com.github.shrippen.kurrent/kurrentrc` (Gruppe `General`), im Prozess ein Singleton `SharedSettings`. Instanz-Config in `appletsrc` ist nur ein Cache. Ältere `~/.config/plasma_com.github.shrippen.kurrentrc` wird einmalig dorthin verschoben.
- `Design.qml` liest Sidebar-Breite, Dichte, Overlay-Dim und Reduced Motion aus dieser Config (über `main.qml`).
- Transienter UI-Zustand (aktuelle View sofern nicht „remember last“, Suche, Selektion, eingeklappte Bäume) bleibt pro Instanz.

## i18n

- QML-Strings über `i18n`. Nach neuen UI-Texten `python3 po/generate_po.py`.
---
