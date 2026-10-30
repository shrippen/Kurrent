import QtQuick
import "."

/**
 * Steps of a process (a wizard): `model` is a list of labels, `current` the active index.
 * Every state has a shape besides its colour (Kante 1.27, WCAG 1.4.1), as `.steps` on the web:
 *
 *   done      green bar, a filled square with a check mark instead of the number
 *   current   thick accent bar, the number on a filled primary square, the step framed
 *             with a 2 px outline, its label in the strong text colour
 *   upcoming  thin bar, the number in a hollow square, muted label
 *   skipped   a passed step in `skipped` (1.49): muted 4 px bar, a dash in a hollow square,
 *             so a step the user left out never shows the done check (Kontra: latency)
 *
 * Screen readers hear each step as "Schritt 2 von 4: Erkennen, aktuell"; the words come
 * from `stepText` and `stateNames`, an app sets its translations once.
 *
 * Narrower than all labels need (a width set by a layout, e.g. half a laptop screen): only
 * the current step keeps its label, the others show their sign (Kante 1.39, `compact`).
 *
 *   ┌──────────────┬────┬────┬────┐
 *   │ ■01          │ □02│ □03│ □04│     compact: the current step named, the rest by number
 *   │ INSTRUMENT   │    │    │    │
 */
Item {
    id: steps

    property var model: []
    property int current: 0
    /** Words of a step for screen readers; %1 its number, %2 the count. */
    property string stepText: "Schritt %1 von %2"
    property var stateNames: ({ done: "erledigt", current: "aktuell", upcoming: "offen", skipped: "übersprungen" })
    /** Indexes of passed steps the user skipped (1.49). */
    property var skipped: []

    property alias spacing: row.spacing

    /** Width all steps need with their labels: the sum of each step's named width, taken
     *  from its label (laid out whether shown or not), so it follows font changes. It sums
     *  the delegates made so far (the Repeater's `built`): created asynchronously (a Loader,
     *  a view's cache), they come after the count, and itemAt() alone does not notify. */
    readonly property real fullWidth: {
        let w = 0
        const made = Math.min(steps.count, repeater.built)
        for (let i = 0; i < made; i++) {
            const it = repeater.itemAt(i)
            w += it ? it.namedWidth : 0
        }
        return w + spacing * Math.max(0, steps.count - 1)
    }
    /** Too narrow for every label: only the current step keeps its label. The steps' own
     *  size is fullWidth, whatever they show (1.39), so only a width set from outside (a
     *  layout) makes them compact, and they leave it again when that width grows. */
    readonly property bool compact: width > 0 && width < fullWidth - 0.5
    readonly property alias count: repeater.count

    implicitWidth: fullWidth
    implicitHeight: row.implicitHeight

    Accessible.role: Accessible.List

    Row {
        id: row
        spacing: 2

        Repeater {
            id: repeater
            model: steps.model
            /** Delegates made so far, for fullWidth. */
            property int built: 0
            onItemAdded: built++
            onItemRemoved: built--
            delegate: Item {
                id: step
                required property int index
                required property var modelData
                readonly property bool passed: index < steps.current
                readonly property bool skippedStep: passed && (steps.skipped || []).indexOf(index) >= 0
                readonly property bool done: passed && !skippedStep
                readonly property bool now: index === steps.current
                readonly property string stateKey: skippedStep ? "skipped" : (done ? "done" : (now ? "current" : "upcoming"))
                readonly property real signSize: Math.max(KanteStyle.unit(20), number.implicitHeight + KanteStyle.unit(4))
                readonly property bool named: !steps.compact || now
                /** Width with the label shown. */
                readonly property real namedWidth: Math.max(KanteStyle.unit(110), label.implicitWidth + KanteStyle.unit(24))
                width: named ? namedWidth : signSize + KanteStyle.unit(20)
                height: Math.max(KanteStyle.unit(60), label.y + label.implicitHeight + KanteStyle.unit(8))

                Accessible.role: Accessible.ListItem
                Accessible.name: steps.stepText.arg(index + 1).arg(steps.model ? steps.model.length : 0) + ": " + modelData
                                 + ", " + (steps.stateNames && steps.stateNames[stateKey] !== undefined ? steps.stateNames[stateKey] : stateKey)

                Rectangle { anchors.fill: parent; color: KanteStyle.cardColor }
                // The current step: a 2 px outline around the whole step.
                Rectangle {
                    anchors.fill: parent
                    visible: step.now
                    color: "transparent"
                    border.width: 2
                    border.color: KanteStyle.accentTextColor
                }
                // Bar: 4 px done or skipped, 6 px current, 2 px upcoming.
                Rectangle {
                    width: parent.width
                    height: KanteStyle.unit(step.now ? 6 : (step.passed ? 4 : 2))
                    color: step.done ? KanteStyle.positiveTextColor
                         : (step.now ? KanteStyle.accentColor : (step.skippedStep ? KanteStyle.mutedTextColor : KanteStyle.frameColor))
                }
                // Sign: check on a filled square (done), number on a filled square (current),
                // number in a hollow square (upcoming).
                Rectangle {
                    id: sign
                    x: KanteStyle.unit(10)
                    y: KanteStyle.unit(12)
                    width: step.signSize
                    height: step.signSize
                    color: step.done ? KanteStyle.positiveTextColor : (step.now ? KanteStyle.primaryColor : "transparent")
                    border.width: step.done || step.now ? 0 : 1
                    border.color: KanteStyle.mutedTextColor
                    KanteTick {
                        visible: step.done
                        anchors.centerIn: parent
                        width: parent.width - KanteStyle.unit(6)
                        height: width
                        checked: true
                        color: KanteStyle.inkOn(KanteStyle.positiveTextColor)
                    }
                    Text {
                        id: number
                        visible: !step.done
                        anchors.centerIn: parent
                        text: step.skippedStep ? "–" : (step.index + 1 < 10 ? "0" : "") + (step.index + 1)
                        color: step.now ? KanteStyle.primaryTextColor : KanteStyle.mutedTextColor
                        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, step.now)
                    }
                }
                Text {
                    id: label
                    visible: step.named
                    x: KanteStyle.unit(10)
                    y: sign.y + sign.height + KanteStyle.unit(2)
                    text: step.modelData
                    color: step.now ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
                    font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize)
                }
            }
        }
    }
}
