# Code-Audit Kurrent, 17.11.2026, Stand b28b14a

## Urteil
Das Repo lässt sich weiterhin nur mit Mühe warten, und seit dem letzten Audit ist im Code kaum etwas besser geworden. Neu ist `ARCHITECTURE.md`, die beschreibt, wie das Repo gebaut sein soll, und die alten Funde als bekannte Abweichungen festhält. Behoben ist aber keiner der acht Funde. Die Steuerzentrale ist um 74 Zeilen gewachsen: Das neue Laden aus Akonadi kam in sie hinein und nicht in die eigene Ladeklasse, die `ARCHITECTURE.md` dafür vorsieht. Neu gefunden habe ich zwei Mängel: Fehlermeldungen erreichen den Nutzer meist gar nicht, und Daten, die alle Widgets teilen, werden von Hand in jedes Widget kopiert.

## Kennzahlen
| | letztes Audit | jetzt |
|---|---|---|
| Quelldateien | 156 | 165 |
| Einträge in der Bestandsliste | 75 | 75 |
| größte Datei (Zeilen) | 7031 | 7105 |
| längste Funktion (Zeilen) | 210 | 210 |

## Funde

### 1. Die Logikbibliothek enthält Kopien von Oberflächenlogik, die nur die Tests aufrufen, und umgekehrt stehen Regeln in der Oberfläche
Die Oberfläche des Widgets ist in QML geschrieben, einer Beschreibungssprache für Oberflächen mit eingebettetem JavaScript. Viele ihrer Rechenwege stehen zusätzlich als C++-Funktionen in der Logikbibliothek. Das Programm ruft diese Funktionen nie auf, nur die Tests tun es. Betroffen sind die Höhenverteilung der Seitenleiste, die Wiederholungsauswahl im Editor, Prioritätsnamen und Prioritätsindex, die Eingabemaske für Datum und Uhrzeit, das Symbol einer Ansicht, die Suche eines Werts in einer Liste, die Grenzen für Popups und die Größe des Mauszeigers. Bei der Seitenleiste rechnet die Kopie schon anders als die laufende Fassung. Zwei weitere Funktionen ruft gar nichts auf, nicht einmal ein Test. Auch der umgekehrte Fall kommt vor: Die Einteilung des Fortschritts in Viertel ist eine Regel über Aufgaben. Der Seitenleisten-Filter nimmt sie aus C++, das Symbol in der Aufgabenzeile aus einer ungetesteten JavaScript-Kopie. Und das Terminalprogramm hat eine eigene, ungetestete Sortierung. Wer eine dieser Stellen ändert, muss zwei Orte finden und weiß nicht, welcher zählt. Die grünen Tests prüfen oft die Kopie, die gar nicht läuft.
Vorschlag: Die ungenutzten C++-Kopien und ihre Tests löschen. Wo die laufende QML-Fassung noch keinen Test hat (Seitenleiste, Wiederholung), einen QML-Test schreiben. Die Einteilung des Fortschritts und die Sortierung des Terminalprogramms in die Logikbibliothek ziehen.
Aufwand mittel (zwei PRs), Risiko gering: Die gelöschten Funktionen haben keinen Aufrufer, und für Prioritäten und Datumsmaske gibt es schon QML-Tests.
Beleg: `plugin/tasklogic.cpp:2089` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/SidebarView.qml:323`, `plugin/tasklogic.cpp:2213` und `:2230` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/TaskEditorSheet.qml:96`, `plugin/tasklogic.cpp:2246`–`:2275` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/colors.js:113`, `plugin/tasklogic.cpp:2339` und `:2416` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/datetime.js:61` und `:325`, ohne Aufrufer im Programm `plugin/tasklogic.cpp:2131`, `:2172`, `:2177`, `:2289`, `:2297`, `:2306`, ohne jeden Aufrufer `plugin/tasklogic.cpp:227` und `:1896`; Fortschritt `plugin/tasklogic.cpp:604` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/taskmeta.js:5`; Sortierung `tui/tuiapp.cpp:236`.

### 2. Fehlermeldungen erreichen den Nutzer meist nicht
Wenn das Speichern, Löschen oder Verschieben einer Aufgabe scheitert, macht die Steuerzentrale zweierlei. Sie sendet an 23 Stellen ein Fehlersignal, aber im ganzen Programm hört niemand darauf, nur ein Test. Außerdem legt sie einen Fehlertext ab. Diesen Text zeigt nur die Listenansicht, und auch nur, wenn gerade keine Aufgabe sichtbar ist. Scheitert also das Speichern, während Aufgaben in der Liste stehen, oder in einer anderen Ansicht, sieht der Nutzer nichts. Jede neue Aktion muss sich zwischen zwei halben Wegen entscheiden, und keiner von beiden führt sicher zum Nutzer.
Vorschlag: Einen Weg festlegen, etwa eine kurze Meldung im Widget, die auf das Fehlersignal hört. Den Fehlertext nur noch für den Zustand „Laden gescheitert“ verwenden.
Aufwand klein, Risiko gering: Die Steuerzentrale hat einen Test, der das Fehlersignal schon abfragt.
Beleg: `plugin/taskcontroller.h:627`, `plugin/taskcontroller.cpp:4002`, `plugin/taskcontroller.cpp:4844`, `plugin/taskcontroller.cpp:5557`, `plugin/tasklogic.cpp:1265`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/TaskListView.qml:239`, einziger Empfänger `tests/taskcontroller_store_test.cpp:140`.

### 3. Die Standardwerte der Einstellungen stehen an drei Stellen
Jede Einstellung hat ihren Standardwert in der Einstellungsbeschreibung des Widgets und in der Liste der gemeinsam genutzten Einstellungen in C++. Für die Schaltfläche „Diese Seite zurücksetzen“ steht er auf sechs Einstellungsseiten noch einmal. Die Reihenfolge der Seitenleiste steht sogar ein viertes Mal. Kein Test vergleicht diese Stellen. Plasma liefert jeder Einstellungsseite den Standardwert aus der Beschreibung schon mit, die eigenen Listen auf den Seiten braucht es also nicht. Wer einen Standardwert ändert, muss drei oder vier Dateien finden.
Vorschlag: Die Schaltfläche zum Zurücksetzen auf die von Plasma gelieferten Standardwerte umstellen. Dazu einen Test schreiben, der die C++-Liste mit der Beschreibung vergleicht.
Aufwand klein, Risiko gering: Der Vergleichstest fängt Abweichungen selbst ab.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/config/main.xml:189`, `plugin/sharedsettings.cpp:84`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configSidebar.qml:11`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configAppearance.qml:351`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/ConfigResetButton.qml:17`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/ConfigPageBase.qml:4`.

### 4. Kleine Helfer sind in viele Ansichten und Auswahlfelder kopiert
Einige Hilfsfunktionen stehen mehrfach im Code. „Minuten als Uhrzeit schreiben“ gibt es fünfmal, „heute“ viermal und „Tage addieren“ dreimal. Die Funktion, die einen Wert in einer Auswahlliste markiert, steht auf fünf Einstellungsseiten. Neu aufgefallen ist mir: Die drei Auswahlfelder für Labels, Orte und übergeordnete Aufgabe haben je eine wörtlich gleiche Kopie des Codes, der ihre Liste über dem Eingabefeld platziert und öffnet. Für Datumshilfen gibt es bereits eine gemeinsame, getestete Datei. Eine Änderung, etwa eine 12-Stunden-Anzeige oder eine andere Lage der Auswahlliste, muss man in jeder Kopie nachziehen.
Vorschlag: Die Datumshelfer in die vorhandene Datumsdatei ziehen, die Auswahlhilfe in den gemeinsamen Baustein der Einstellungsseiten und die Platzierung der Liste in einen gemeinsamen Baustein der drei Auswahlfelder.
Aufwand klein. Risiko gering, wenn die Helfer dort einen QML-Test bekommen.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/AgendaEventRow.qml:29`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/AgendaCard.qml:38`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/AgendaDayView.qml:40` und `:59`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/AgendaMonthView.qml:33`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/CalendarAgendaView.qml:113`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/HeatmapView.qml:73`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configGeneral.qml:12`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configPanel.qml:79`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/LabelPicker.qml:56`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/LocationPicker.qml:45`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/ParentPicker.qml:93`.

### 5. Dieselbe Steuerzentrale heißt in der Oberfläche einmal „backend“ und einmal „controller“
In fünf Dateien heißt die Steuerzentrale „backend“, darunter in der Hauptansicht mit 155 Vorkommen, in 41 Dateien heißt sie „controller“. Wer sucht, wo die Oberfläche eine Funktion der Steuerzentrale aufruft, muss nach beiden Namen suchen und übersieht leicht eine Stelle.
Vorschlag: Überall „controller“ verwenden.
Aufwand klein, Risiko gering: Es ist eine reine Umbenennung, und der Rauchtest (ein automatischer Durchlauf durch alle Ansichten) deckt die betroffenen Dateien ab.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/ui/main.qml:93`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/FullView.qml:18`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/ScreenshotRunner.qml:15`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/SmokeTest.qml:7`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/ViewModeToolbar.qml:42`.

### 6. Aufgaben aus dem Editor entstehen auf einem zweiten, kopierten Weg, der die Speicherschicht umgeht
Neue Aufgaben aus der Schnelleingabe gehen über die Speicherschicht. Diese Schicht kapselt den Zugriff auf Akonadi, den Datendienst von KDE für Kalender und Aufgaben, und lässt sich in Tests durch einen Speicher im Arbeitsspeicher ersetzen. Aufgaben aus dem großen Editor schickt die Steuerzentrale dagegen direkt an Akonadi. Den Block, der alle Felder setzt, hat sie dafür aus der Bearbeitungsfunktion kopiert, wie ihr eigener Kommentar sagt. Ein neues Aufgabenfeld muss man darum an zwei Stellen einbauen. Der Editor-Weg hat keinen Test, weil er am austauschbaren Speicher vorbeiläuft.
Vorschlag: Das Setzen der Felder in eine gemeinsame Funktion ziehen und das Anlegen über denselben Speicherweg schicken wie die Schnelleingabe.
Aufwand mittel. Risiko mittel: Der Editor-Weg hat keinen Test, der muss zuerst kommen.
Beleg: `plugin/taskcontroller.cpp:4746`, `plugin/taskcontroller.cpp:4769`, `plugin/taskcontroller.cpp:4840`, `plugin/taskcontroller.cpp:4618`, `plugin/taskcontroller.cpp:3834`, `plugin/taskstore.h:24`.

### 7. Daten, die alle Widgets teilen, liegen doppelt vor und werden von Hand abgeglichen
Stehen mehrere Kurrent-Widgets auf dem Bildschirm, teilen sie sich Aufgaben, Aufgabenlisten und belegte Termine aus dem Kalender. Ein Teil davon liegt einmal für alle vor, ein anderer Teil in jedem Widget als eigene Kopie. Die Kopien gleichen Schleifen über alle Widgets von Hand ab. Die Namen der Aufgabenlisten gibt es zweimal, einmal gemeinsam und einmal je Widget, und sie werden an fünf Stellen hin und her kopiert. Die belegten Termine liegen je Widget vor, aber der Vermerk, ob sie neu geholt werden müssen, gilt seit dem letzten PR für alle Widgets gemeinsam. Insgesamt laufen zwölf solcher Schleifen über alle Widgets. Wer neue geteilte Daten einführt, muss jede Kopierstelle kennen. Vergisst er eine, zeigen zwei Widgets verschiedene Stände.
Vorschlag: Die geteilten Daten in eine eigene Klasse ziehen, die es einmal gibt und die die Widgets bei Änderungen benachrichtigt. Diese Klasse ist zugleich die Ladeklasse, die `ARCHITECTURE.md` für das Lesen aus Akonadi vorsieht.
Aufwand mittel. Risiko mittel: Kein Test prüft mehrere Widgets gleichzeitig.
Beleg: `plugin/taskcontroller.h:917`, `plugin/taskcontroller.h:918`, `plugin/taskcontroller.h:933`–`:939`, `plugin/taskcontroller.cpp:481`, `plugin/taskcontroller.cpp:5815`, `plugin/taskcontroller.cpp:5820`, `plugin/taskcontroller.cpp:6552`, `plugin/taskcontroller.cpp:6569`, `plugin/taskcontroller.cpp:6951`, `plugin/taskcontroller.cpp:7000`.

### 8. Die Seitenleiste besteht aus sieben fast gleichen Abschnitten von je rund 230 Zeilen
Die Abschnitte Projekte, Labels, Prioritäten, Fortschritt, Status, Vertraulichkeit und Ort sind jeweils eine eigene Kopie desselben Bausteins. Jeder besteht aus Liste, Kopfzeile, Eintrag „Alle“, Hinweis für gesperrte Filter und Markierung der Auswahl. Die Kopien unterscheiden sich fast nur in Namen und in der Einstellung, die sie lesen. Die Datei hat dadurch 2847 Zeilen. Wer am Hinweis oder an der Markierung etwas ändert, muss es siebenmal tun.
Vorschlag: Einen Baustein „Abschnitt der Seitenleiste“ anlegen, der Liste, Titel und gewählten Wert als Eingaben bekommt, und ihn siebenmal verwenden.
Aufwand mittel. Risiko mittel: Für die Seitenleiste gibt es keinen eigenen Test, nur den Rauchtest und die Bildschirmfotos zum Vergleich.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/SidebarView.qml:1153`, `:1395`, `:1629`, `:1877`, `:2108`, `:2339`, `:2570`.

### 9. Eine Klasse, die Steuerzentrale, erledigt fast alles, und sie wächst weiter
Die Steuerzentrale hat jetzt 7105 Zeilen und bietet der Oberfläche 129 aufrufbare Funktionen und 100 Eigenschaften. Sie lädt und beobachtet Akonadi, gleicht die Einstellungen ab und verwaltet Rückgängig und Konflikte. Außerdem verschiebt sie Karten auf dem Kanban-Brett (einer Spaltenansicht der Aufgaben) und in der Matrix, rechnet die Agenda und enthält Haken für Rauchtest, Bildschirmfotos und Demomodus. Sie wurde in 71 von 354 Commits geändert, öfter als jede andere Quelldatei. Der letzte PR hat ihr das zweistufige Laden der Aufgaben und das Beobachten der Kalendertermine hinzugefügt. Nach `ARCHITECTURE.md` gehört beides in eine eigene Ladeklasse. Die neue Datei dafür enthält nur die Unterscheidung, ob ein Eintrag eine Aufgabe ist. Auch in der Oberfläche fragen sieben Dateien nach, ob gerade der Rauchtest oder die Bildschirmfotos laufen, statt dass diese an einer Stelle einhaken.
Vorschlag: In mehreren Schritten an den vorhandenen Nähten aufteilen. Zuerst Laden und Beobachten von Akonadi zusammen mit Fund 7, dann Einstellungsbrücke, Rückgängig und Konfliktlösung, dann Kanban- und Matrixbewegungen sowie die Test- und Demohaken. Jeder Teil kommt in eine eigene Klasse, auf die die Steuerzentrale nur noch verweist.
Aufwand groß, Risiko mittel: Es gibt einen Testsatz mit austauschbarem Speicher, er deckt aber nicht jede Naht ab, das Laden aus Akonadi gar nicht.
Beleg: `plugin/taskcontroller.h:449`, `plugin/taskcontroller.h:529`, `plugin/taskcontroller.h:535`, `plugin/taskcontroller.h:551`, `plugin/taskcontroller.cpp:1355`, `plugin/taskcontroller.cpp:3455`, `plugin/taskcontroller.cpp:5898`, `plugin/taskcontroller.cpp:6909`, `plugin/akonadiitems.h:13`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/MainPaneHost.qml:1`.

### 10. Bestandsliste: was sich teilen lässt und was bleiben darf
Die Bestandsliste nennt, was heute über den Grenzen der Strukturprüfung liegt. Sie hat wie beim letzten Audit 75 Einträge. Die Steuerzentrale ist darin gewachsen, die Aufgabenzeile ist geschrumpft. Zu den größten Einträgen:

- Die Steuerzentrale (Fund 9) und die Seitenleiste (Fund 8) lassen sich an natürlichen Nähten teilen.
- Die Logikbibliothek mit 3783 Zeilen schrumpft schon durch Fund 1. Danach lässt sie sich in drei Teile trennen: Sortieren und Filtern, Matrix und Kanban, Zählen für die Seitenleiste.
- Die Vergleichsfunktion für die Sortierung ist eine lange Kette mit einem Zweig je Sortierfeld. Ein kleiner Vergleich je Feld wäre eine saubere Naht.
- Die Hauptansicht mit 2082 Zeilen ist groß, aber ohne klare Naht. Sie sollte erst nach den Funden 5 und 8 angegangen werden.
- In Ordnung, wie sie sind: das Installationsskript mit 1111 Zeilen, das als eine einzige Datei über das Netz geladen wird. Ebenso die Schrittfolgen von Rauchtest und Bildschirmfotos, die flache Abläufe von Schritten sind.

Aufwand und Risiko stehen bei den Funden 1, 8 und 9.
Beleg: `plugin/tasklogic.cpp:664`, `plugin/tasklogic.cpp:851`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/FullView.qml:1`, `install-linux.sh:1`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/SmokeTest.qml:31`.

## Seit dem letzten Audit
Keiner der acht Funde vom 14.11.2026 ist behoben. Abgelehnte Funde hat der Eigentümer keine vermerkt.

- Fund 1 (C++-Kopien von Oberflächenlogik): offen, jetzt Fund 1. Er ist größer als damals gemeldet: Sechs weitere Funktionen ohne Aufrufer im Programm kamen dazu, außerdem die Fortschrittsviertel und die Sortierung des Terminalprogramms.
- Fund 2 (Editor umgeht die Speicherschicht): offen, jetzt Fund 6.
- Fund 3 (sieben Abschnitte der Seitenleiste): offen, jetzt Fund 8.
- Fund 4 (Steuerzentrale erledigt fast alles): offen, jetzt Fund 9. Die Klasse ist von 7031 auf 7105 Zeilen gewachsen.
- Fund 5 (Standardwerte an drei Stellen): offen, jetzt Fund 3.
- Fund 6 (kopierte Helfer): offen, jetzt Fund 4, ergänzt um die Platzierung der Auswahllisten.
- Fund 7 („backend“ und „controller“): offen, jetzt Fund 5.
- Fund 8 (Bestandsliste): unverändert 75 Einträge, jetzt Fund 10.

Neu sind Fund 2 (Fehlermeldungen) und Fund 7 (geteilte Daten mehrerer Widgets).
