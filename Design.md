# Kurrent — Design

Prosa-Referenz für UI- und UX-Entscheidungen. Laufzeit-Tokens: `plasmoid/com.github.shrippen.kurrent/contents/ui/Design.qml`. Akzente: `contents/ui/colors.js`.

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
- Passt die **natürliche** Höhe aller sichtbaren Abschnitte (Zeilenanzahl × Zeilenhöhe, inkl. touchfreundlich) **nicht** in die Sidebar, bleibt die Gesamthöhe begrenzt und jeder Abschnitt scrollt intern (`ThinScrollBar`, Gutter nur bei Bedarf). Die Verteilung nutzt dann nur eine Mindesthöhe (Kopfzeile + eine Zeile), nicht die volle Inhaltshöhe.

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
- Labels: `tag` in derselben Farbfunktion.

## Scrollbars

- Dünner Balken rechts, volle Viewport-Höhe: `ThinScrollBar`, `scrollBarExtent` 6px, Overlay-Optik (Textfarbe, Opacity 0,28/0,40/0,55).
- Mehrzeilige Felder: `ScrollableTextArea` (`Flickable`), **nicht** `QQC2.ScrollView` (reserviert Breite rechts, zeichnet den Balken links und zu kurz, kann das Widget schmaler machen).
- `implicitWidth: 0` an scrollbaren Feldern, damit der Balken die Widget-Breite nicht treibt.
- Gutter (`scrollGutter`) nur wenn wirklich gescrollt wird, Text nicht unter dem Balken.
- `Design.applyWheel(flick, event)` für Rad-Deltas in Flickables; Hover über einem Feld mit Scrollbar konsumiert das Rad immer.

## Full-Editor

- Immer ein `FocusScope` **im** Plasmoid, nie `QQC2.Dialog` und nie ein extra Fenster (`popupType: Item` reicht bei Dialogen nicht).
- Abdunklung (`overlayDim` 0,4) über das **gesamte sichtbare Widget**, inklusive Sidebar, Separator, Aufgabenfläche und Plasma-FrameSvg-Ränder/Ecken. Das Dim wird auf den `AppletContainer` umgehängt und färbt den Chrome, **ohne** den Inhalt in die Ränder zu ziehen (`collapseMarginsHint` bleibt aus). Die normalen Plasma-Margins um Sidebar und Liste bleiben.
- Karte: abgerundet (`windowRadius`), Rahmen, leichter Schatten, `overlayInset` Abstand zur Inhaltsfläche (plus Container-Padding, wenn das Overlay auf dem Chrome sitzt).
  - Schmal: Karte über dem ganzen Widget (weiterhin eingerückt).
  - Breit: Karte auf der Aufgabenfläche, Sidebar bleibt in der Abdunklung sichtbar darunter.
- Escape und Klick auf die Abdunklung schließen. Datums-Popups bleiben im Widget.
- Mausrad über der Editorkarte: nur die Karte (bzw. das Beschreibungsfeld) scrollt, nie Aufgabenliste oder Sidebar. Auch am Ende des Scrollbereichs kein Durchreichen.
- Footer: Titel | Löschen | Speichern | Abbrechen. Löschen links neben Speichern, ohne Extra-Bestätigung (wie in der Zeile).

## Widget-Hintergrund

- An: Desktop-Widget → `StandardBackground` (`DefaultBackground`). Plasma zeichnet `widgets/background` mit Prefix `blurred` und blurrt das Wallpaper im `AppletContainer`. Panel-Flyout → zusätzlich `AppletPopup.StandardBackground` am Popup-Fenster.
- Aus: Desktop → `TranslucentBackground` (durchscheinend, ohne Container-Blur). Panel-Flyout → `AppletPopup.SolidBackground`.
- Einstellungen gemeinsam in `~/.config/com.github.shrippen.kurrent/kurrentrc`.
- Kein eigenes Blur-Shader im Plasmoid.

## Inline-Editor

- Kein extra Fenster. Hover-Fläche dauerhaft mit `highlightColor` bei Opacity 0,12.
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
- Zeile: Klick öffnet Inline- oder Full-Editor (KCM); Chips für Datum/Label/Priorität/Recurring/Join abschaltbar. Fälligkeitschip: optionale relative Labels (Heute/Morgen/Gestern) und Uhrzeit.
- Erinnerung: VALARM im Full-Editor; Plasma-Benachrichtigung mit Snooze (15 min / 1 h / morgen, schreibt nur den Alarm). Quiet Hours unterdrücken Popups.
- Tastatur im fokussierten Widget: Suche, Neu, Undo, Complete, Delete, Full-Editor, Reschedule, Views 1–5. Global: Meta+Shift+K zeigt das Flyout, Meta+Shift+N legt an (Plasma-Shortcuts, D-Bus `org.github.shrippen.Kurrent`).
- Wiederkehrende Aufgaben: Abhaken schiebt DTSTART/DUE auf die nächste Instanz und lässt die RRULE stehen.
- Today: fällig heute, gruppiert nach Morning/Afternoon/Evening (`Design` + Stunden im KCM). Unerledigtes der letzten N Tage als Abschnitt **Still open** (Catch-up), kein Auto-Rollover. Overdue ist eine eigene Sidebar-View.
- Meeting-URL in Beschreibung/Ort: kompakter Join-Knopf in der Zeile (`internet-services`).
- Rechtsklick: Reschedule (15 min / 1 h / 4 h / morgen / nächste Woche).
- Quick Add im Anlegefeld: `tomorrow 18:00`, `heute`, `!high`, `#label`.
- Visuell: blasser, `BusyIndicator`, Zeile nicht erneut klickbar. Bei Fehler: Snapshot zurück.
- Neue Aufgaben: temporäre negative Item-ID, nach Create durch die echte ersetzen.

## Schreibbare Kalender

- Anzeigen: Todo-MIME, auch schreibgeschützt (z. B. Feiertags-ICS), wenn Aufgaben da sind.
- Schreiben (anlegen, verschieben, Projekt-Dialog, Default-Projekt): nur `CanCreateItem` plus Todo-MIME. Reine Ordner (`inode/directory`, z. B. DAV-Elternordner) nicht als Projekt führen.

## Drag & Drop

- MIME: `application/x-kurrent-task`.
- Drop auf Projekt nur wenn writable; auf Label = Kategorie setzen; auf Aufgabe = Unteraufgabe.

## Konfiguration

- Alle KCM-Seiten (General, Appearance, Sidebar, Tasks, Editor, Panel, Notifications, Projects, Labels) gelten **gemeinsam** für Desktop-Widget und Panel-Flyout. Jede Seite hat „Reset this page“. Widget-Tastenkürzel und globale Shortcuts werden in Plasma System Settings konfiguriert, nicht in einer eigenen KCM-Seite.
- Formularseiten nutzen `ConfigFormShell`: zentrierte Spalte, begrenzte Breite, Scroll bei kleinem Fenster; schmale Fenster stapeln Labels/Steuerelemente über `Kirigami.FormLayout`. Listen-artige Optionen (Dichte, Vorschauzeilen, Stunden) als Dropdown, nicht SpinBox mit Pfeilen.
- Sidebar-Reihenfolge (Sektionen/Views) in der Sidebar-KCM per Drag-and-drop (`ConfigOrderList`), nicht als lose FormLayout-Repeater.
- Quelle: `~/.config/com.github.shrippen.kurrent/kurrentrc` (Gruppe `General`), im Prozess ein Singleton `SharedSettings`. Instanz-Config in `appletsrc` ist nur ein Cache. Ältere `~/.config/plasma_com.github.shrippen.kurrentrc` wird einmalig dorthin verschoben.
- `Design.qml` liest Sidebar-Breite, Dichte, Overlay-Dim und Reduced Motion aus dieser Config (über `main.qml`).
- Transienter UI-Zustand (aktuelle View sofern nicht „remember last“, Suche, Selektion, eingeklappte Bäume) bleibt pro Instanz.

## i18n

- QML-Strings über `i18n`. Nach neuen UI-Texten `python3 po/generate_po.py`.
---
