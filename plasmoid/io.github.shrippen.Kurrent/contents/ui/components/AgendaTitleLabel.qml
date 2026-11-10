import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import "../agenda.js" as Agenda

// A title for the Agenda's narrow columns. It breaks between words only and cuts a word too
// wide for the column with "…" (Agenda.fitWords): "Wochenplanung" → "Wochenpla…", not
// "Wochenplanun/g". Where fitWords cannot foresee Qt's line breaking (a Latin word glued to
// Thai or to CJK punctuation), a hidden probe sees the overflow and the label shows the whole
// title, broken anywhere.
QQC2.Label {
    id: label

    /** The whole title; `text` is what fits. */
    property string fullText
    /** A word was cut or lines were dropped: show the whole title as tooltip. */
    readonly property bool cut: truncated || text !== fullText

    readonly property string fitted: Agenda.fitWords(fullText, width, metrics)
    readonly property bool overflows: probe.contentWidth > width + 0.5

    text: overflows ? fullText : fitted
    wrapMode: overflows ? Text.Wrap : Text.WordWrap

    FontMetrics {
        id: metrics
        font: label.font
    }

    // Lays the fitted text out with WordWrap at the label's width; its widest line tells
    // overflow. It reads `fitted`, not `text`, so the switch cannot feed back.
    Text {
        id: probe
        visible: false
        width: label.width
        wrapMode: Text.WordWrap
        text: label.fitted
        font: label.font
    }
}
