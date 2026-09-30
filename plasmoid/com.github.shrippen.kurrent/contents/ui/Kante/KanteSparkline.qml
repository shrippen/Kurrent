import QtQuick
import "."

/** A small line without axes: one series and a square mark at its end. Aqua by default (data colour 4). */
KanteLineChart {
    property var values: []
    series: [values]
    compact: true
    colorIndex: 3
}
