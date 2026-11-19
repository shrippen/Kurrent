# Code-Audit Kurrent, 14.11.2026, Stand 73176b0

## Urteil
Das Repo lässt sich nur mit Mühe warten. Die Kernlogik zum Sortieren, Filtern und für die Schnelleingabe von Aufgaben steckt in reinen Rechenfunktionen, und viele davon haben Tests. Drei Stellen machen aber fast jede Änderung teuer: Eine einzige Klasse, die Steuerzentrale des Widgets, erledigt beinahe alles. Die Seitenleiste ist siebenmal von Hand kopiert. Und ein Teil der Logik steht doppelt, einmal in C++ und einmal in der Oberfläche, wobei die Tests die Kopie prüfen, die gar nicht läuft. Dies ist das erste Audit, deshalb gibt es keinen Vergleich mit früher.

## Kennzahlen
| | letztes Audit | jetzt |
|---|---|---|
| Quelldateien | – | 156 |
| Einträge in der Bestandsliste | – | 75 |
| größte Datei (Zeilen) | – | 7031 |
| längste Funktion (Zeilen) | – | 210 |

## Funde

### 1. Tests prüfen C++-Kopien von Oberflächenlogik, die nichts aufruft, während die laufende Fassung in der Oberfläche ungetestet bleibt oder anders rechnet
Die Oberfläche des Widgets ist in QML geschrieben, einer Beschreibungssprache für Oberflächen mit eingebettetem JavaScript. Mehrere ihrer Rechenwege stehen zusätzlich als C++-Funktionen in der Logikbibliothek: die Höhenverteilung der Abschnitte in der Seitenleiste, die Prioritätsnamen, die Wiederholungsauswahl im Editor und die Eingabemaske für Datum und Uhrzeit. Keine dieser C++-Funktionen wird vom Programm aufgerufen, nur von den Tests. Bei der Seitenleiste hat sich die Kopie schon entfernt: Die laufende Fassung verteilt den Platz nach Mindest- und Wunschhöhe, die C++-Fassung nur nach Mindesthöhe. Der grüne Test sagt also nichts über das, was der Nutzer sieht. Zwei weitere Funktionen dort ruft gar nichts auf, nicht einmal ein Test. Jede Änderung an diesen Stellen muss man heute an zwei Orten machen, und man weiß nicht, welcher zählt.
Vorschlag: Die C++-Kopien und ihre Tests löschen. Wo die laufende QML-Fassung noch keinen Test hat (Seitenleiste, Wiederholung), einen QML-Test schreiben, wie es ihn für Prioritäten und Datumsmaske schon gibt. Das löscht rund 450 Zeilen und zwei Einträge aus der Bestandsliste.
Aufwand klein bis mittel, Risiko gering: Für die gelöschten Funktionen gibt es keinen Aufrufer, und für Prioritäten und Datumsmaske gibt es schon QML-Tests.
Beleg: `plugin/tasklogic.cpp:2084` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/SidebarView.qml:323`, `plugin/tasklogic.cpp:2241` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/colors.js:113`, `plugin/tasklogic.cpp:2208` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/TaskEditorSheet.qml:96`, `plugin/tasklogic.cpp:2334` und `:2411` gegen `plasmoid/io.github.shrippen.Kurrent/contents/ui/datetime.js:61` und `:325`, `tests/tasklogic_test.cpp:1112`, ohne jeden Aufrufer `plugin/tasklogic.cpp:227` (`listGroupAlphaLabel`) und `plugin/tasklogic.cpp:1896` (`defaultViewIds`).

### 2. Aufgaben aus dem Editor entstehen auf einem zweiten, kopierten Weg, der die Speicherschicht umgeht
Neue Aufgaben aus der Schnelleingabe gehen über die Speicherschicht. Diese Schicht kapselt den Zugriff auf Akonadi, den Datendienst von KDE für Kalender und Aufgaben, und lässt sich in Tests durch einen Speicher im Arbeitsspeicher ersetzen. Aufgaben aus dem großen Editor schickt die Steuerzentrale dagegen direkt an Akonadi. Die Funktion übernimmt dazu den Block, der alle Felder setzt, als Kopie aus der Bearbeitungsfunktion. Der Kommentar dort sagt selbst, dass er es „genauso wie“ die Bearbeitung macht. Ein neues Feld, etwa ein weiteres Aufgabenattribut, muss man darum an zwei Stellen einbauen. Der Editor-Weg hat außerdem keinen Test, weil er am austauschbaren Speicher vorbeiläuft.
Vorschlag: Das Setzen der Felder in eine gemeinsame Funktion ziehen und das Anlegen über denselben Speicherweg schicken wie die Schnelleingabe.
Aufwand mittel. Risiko mittel: Die Schnelleingabe ist über den Speicher getestet, der Editor-Weg nicht. Ein Test dafür kommt zuerst.
Beleg: `plugin/taskcontroller.cpp:4731`, `plugin/taskcontroller.cpp:4754`, `plugin/taskcontroller.cpp:4825`, `plugin/taskcontroller.cpp:4603`, `plugin/taskcontroller.cpp:3812`, `plugin/taskstore.h:10`.

### 3. Die Seitenleiste besteht aus sieben fast gleichen Abschnitten von je rund 230 Zeilen
Die Abschnitte Projekte, Labels, Prioritäten, Fortschritt, Status, Vertraulichkeit und Ort der Seitenleiste sind jeweils eine eigene Kopie desselben Bausteins: Liste, Kopfzeile, Eintrag „Alle“, Hinweis für gesperrte Filter, Markierung der Auswahl. Sie unterscheiden sich fast nur in Namen und in der Einstellung, die sie lesen. So kommt die Datei auf 2847 Zeilen. Wer am Verhalten eines Abschnitts etwas ändert, etwa am Hinweis oder an der Markierung, muss es siebenmal tun und darf keinen vergessen.
Vorschlag: Einen Baustein „Abschnitt der Seitenleiste“ anlegen, der Liste, Titel und gewählten Wert als Eingaben bekommt, und ihn siebenmal verwenden.
Aufwand mittel. Risiko mittel: Für die Seitenleiste gibt es keinen eigenen Test, nur den Rauchtest (ein automatischer Durchlauf, der prüft, ob das Widget startet und die Ansichten öffnet) und die Bildschirmfotos zum Vergleich.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/SidebarView.qml:1153`, `:1395`, `:1629`, `:1877`, `:2108`, `:2339`, `:2570`.

### 4. Eine Klasse, die Steuerzentrale, erledigt fast alles
Die Steuerzentrale hat 7031 Zeilen und bietet der Oberfläche 129 aufrufbare Funktionen und 100 Eigenschaften. Sie lädt Daten aus Akonadi, gleicht die Einstellungen ab, verwaltet Rückgängig und Konflikte beim Zusammenführen, verschiebt Karten auf dem Kanban-Brett (einer Spaltenansicht der Aufgaben) und in der Matrix, rechnet die Agenda und enthält dazu noch Rauchtest, Bildschirmfotomodus und Demomodus. In der Geschichte des Repos wurde sie in 61 von 336 Commits geändert, öfter als jede andere Quelldatei. Fast jede neue Funktion berührt sie, und wer eine Stelle ändert, muss sich durch eine riesige Datei arbeiten. 20 ihrer Funktionen stehen in der Bestandsliste.
Vorschlag: In mehreren Schritten an den vorhandenen Nähten aufteilen, zuerst Einstellungsbrücke, Rückgängig und Konfliktlösung, dann Kanban- und Matrixbewegungen sowie Test- und Demohaken, jeweils in eine eigene Klasse, auf die die Steuerzentrale nur noch verweist.
Aufwand groß, Risiko mittel: Für die Steuerzentrale gibt es einen Testsatz mit austauschbarem Speicher, er deckt aber nicht jede Naht ab.
Beleg: `plugin/taskcontroller.h:42`, `plugin/taskcontroller.h:449`, `plugin/taskcontroller.h:529`, `plugin/taskcontroller.h:551`, `plugin/taskcontroller.cpp:1340`, `plugin/taskcontroller.cpp:3440`, `plugin/taskcontroller.cpp:4376`, `plugin/taskcontroller.cpp:5161`.

### 5. Die Standardwerte der Einstellungen stehen an drei Stellen
Jede Einstellung hat ihren Standardwert in der Einstellungsbeschreibung des Widgets, in der Liste der gemeinsam genutzten Einstellungen in C++ und, für die Schaltfläche „Diese Seite zurücksetzen“, noch einmal in einer Liste auf jeder Einstellungsseite. Heute stimmen alle drei überein, das habe ich für alle Werte verglichen. Kein Test prüft das aber. Wer einen Standardwert ändert, muss drei Dateien finden. Plasma liefert jeder Einstellungsseite den Standardwert aus der Beschreibung schon mit. Die eigenen Listen auf den Seiten braucht es also nicht.
Vorschlag: Die Schaltfläche zum Zurücksetzen auf die von Plasma gelieferten Standardwerte umstellen und einen Test ergänzen, der die C++-Liste mit der Beschreibung vergleicht.
Aufwand klein, Risiko gering: Der Vergleichstest fängt Abweichungen selbst ab.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/config/main.xml:86`, `plugin/sharedsettings.cpp:22`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configAppearance.qml:351`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/ConfigResetButton.qml:16`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/ConfigPageBase.qml:4`.

### 6. Kleine Datums- und Auswahlhelfer sind in viele Ansichten kopiert
Die Hilfsfunktionen „heute“, „Tage addieren“ und „Minuten als Stunden und Minuten schreiben“ stehen in den Agenda-Ansichten bis zu fünfmal. Die Hilfsfunktion, die einen Wert in einer Auswahlliste markiert, steht auf fünf Einstellungsseiten. Für Datumshilfen gibt es bereits gemeinsame, getestete Skriptdateien. Eine Änderung an der Zeitdarstellung, etwa eine 12-Stunden-Anzeige, müsste man in jeder Kopie nachziehen.
Vorschlag: Die Helfer in die vorhandene Datumsdatei und in den gemeinsamen Baustein der Einstellungsseiten ziehen.
Aufwand klein. Risiko gering, wenn die Helfer dort einen QML-Test bekommen.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/AgendaDayView.qml:59`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/AgendaMonthView.qml:33`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/AgendaWeekView.qml:44`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/CalendarAgendaView.qml:113`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/views/HeatmapView.qml:73`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/AgendaEventRow.qml:29`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/AgendaTimeline.qml:107`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configGeneral.qml:12`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/configTasks.qml:11`.

### 7. Dieselbe Steuerzentrale heißt in der Oberfläche einmal „backend“ und einmal „controller“
In fünf Dateien heißt die Steuerzentrale „backend“, in rund dreißig „controller“. Wer im Code sucht, wo die Oberfläche eine Funktion der Steuerzentrale aufruft, muss nach beiden Namen suchen und kann leicht eine Stelle übersehen.
Vorschlag: Überall „controller“ verwenden.
Aufwand klein, Risiko gering: Es ist eine reine Umbenennung, und der Rauchtest deckt die betroffenen Dateien ab.
Beleg: `plasmoid/io.github.shrippen.Kurrent/contents/ui/main.qml:405`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/FullView.qml:1677`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/components/TaskQuickAdd.qml:56`.

### 8. Bestandsliste: was sich teilen lässt und was bleiben darf
Die Bestandsliste nennt, was heute über den Grenzen der Strukturprüfung liegt. Zu ihren größten Einträgen:

- Die Steuerzentrale (Fund 4) und die Seitenleiste (Fund 3) lassen sich an natürlichen Nähten teilen.
- Die Logikbibliothek mit 3778 Zeilen schrumpft schon durch Fund 1. Danach lässt sie sich in Sortieren und Filtern, Matrix und Kanban sowie Zählen der Seitenleiste teilen.
- Die Vergleichsfunktion für die Sortierung ist eine lange Kette mit einem Zweig je Sortierfeld. Ein kleiner Vergleich je Feld wäre eine saubere Naht.
- Die Hauptansicht mit 2082 Zeilen ist groß, aber ohne klare Naht. Sie sollte erst nach Fund 3 angegangen werden.
- In Ordnung, wie sie sind: das Installationsskript mit 1111 Zeilen, das als eine einzige Datei über das Netz geladen wird und ganz bleiben muss, und die Schrittfolgen von Rauchtest und Bildschirmfotomodus, die flache Abläufe von Schritten sind.

Aufwand und Risiko stehen bei den Funden 1, 3 und 4.
Beleg: `plugin/tasklogic.cpp:664`, `plugin/tasklogic.cpp:851`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/FullView.qml:1`, `install-linux.sh:1`, `plasmoid/io.github.shrippen.Kurrent/contents/ui/SmokeTest.qml:31`.

## Seit dem letzten Audit
Dies ist das erste Audit.
