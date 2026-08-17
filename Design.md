# Kurrent — Design

Prosa-Referenz für UI- und UX-Entscheidungen. Laufzeit-Tokens: `plasmoid/com.github.shrippen.kurrent/contents/ui/Design.qml`. Akzente: `contents/ui/colors.js`.

Diese Datei ist die **menschliche Quelle** für das Warum. `Design.qml` ist die **maschinelle Quelle** für Maße. Beides bei jeder neuen visuellen Entscheidung im selben Change aktualisieren (Cursor-Regel `.cursor/rules/kurrent-ui.mdc`). Es gibt keinen Datei-Watcher — „automatisch“ heißt: jeder Agent-Change an der UI muss diese Datei mitziehen.

---

## Produkt

- Name: **Kurrent**. Plasmoid-ID `com.github.shrippen.kurrent`.
- Plasma 6, Akonadi/CalDAV, kein eigenes Login.
- Panel: kompaktes Masken-Icon (`Kirigami.Icon { isMask: true; color: textColor }`), Breeze `ColorScheme-Text` / `currentColor`.
- Desktop: volle Ansicht, frei skalierbar.

## Layout

- Links Sidebar (Projekte, Labels, Prioritäten, Views), 1px-Separator, rechts Aufgabenfläche.
- Sidebar-Breite: `Design.sidebarWidth` (10 Grid-Units), fest.
- Desktop-`fullRepresentation`: Default `52×40` Grid-Units. `Layout.maximumWidth/Height: Infinity`.
- Inhalt bleibt **innerhalb** der Plasma-FrameSvg-Margins. Ränder nicht mit `collapseMarginsHint` kollabieren.
- **Nicht** `width`/`height` am `PlasmoidItem` binden. **Nicht** `Layout.maximumWidth: Infinity` am Plasmoid-Root.
- Listen und Sidebar, die die Höhe füllen: `implicitHeight: 0`, `Layout.preferredHeight: 0`. `ListView.contentHeight` darf nie die maximale Desktop-Widget-Höhe werden.
- Extra Höhe der Sidebar gleichmäßig auf alle Abschnitte verteilen (nicht bei „alles ohne Scrollbar sichtbar“ stoppen).

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

- Projekte/Labels: deterministisches HSL aus dem Schlüssel (`colors.js` / `colorForKey`), Sättigung 0,62, Helligkeit 0,46.
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

- Mutationen (anlegen, erledigen, speichern, verschieben, löschen) sofort in der Liste; bis Akonadi bestätigt: `syncing` / `pendingDelete`.
- Visuell: blasser, `BusyIndicator`, Zeile nicht erneut klickbar. Bei Fehler: Snapshot zurück.
- Neue Aufgaben: temporäre negative Item-ID, nach Create durch die echte ersetzen.

## Schreibbare Kalender

- Anzeigen: Todo-MIME, auch schreibgeschützt (z. B. Feiertags-ICS), wenn Aufgaben da sind.
- Schreiben (anlegen, verschieben, Projekt-Dialog, Default-Projekt): nur `CanCreateItem` plus Todo-MIME. Reine Ordner (`inode/directory`, z. B. DAV-Elternordner) nicht als Projekt führen.

## Drag & Drop

- MIME: `application/x-kurrent-task`.
- Drop auf Projekt nur wenn writable; auf Label = Kategorie setzen; auf Aufgabe = Unteraufgabe.

## Konfiguration

- Alle KCM-Einstellungen (Ansicht, erledigte Aufgaben, Unschärfe, Projekte, Labels, Sidebar-Zeilenhöhe, neue Aufgaben) gelten **gemeinsam** für Desktop-Widget und Panel-Flyout.
- Quelle: `~/.config/com.github.shrippen.kurrent/kurrentrc` (Gruppe `General`), im Prozess ein Singleton `SharedSettings`. Instanz-Config in `appletsrc` ist nur ein Cache. Ältere `~/.config/plasma_com.github.shrippen.kurrentrc` wird einmalig dorthin verschoben.
- Transienter UI-Zustand (aktuelle View, Suche, Selektion) bleibt pro Instanz.

## i18n

- QML-Strings über `i18n`. Nach neuen UI-Texten `python3 po/generate_po.py`.
---
