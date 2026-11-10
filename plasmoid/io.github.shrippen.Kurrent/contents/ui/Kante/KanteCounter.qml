import QtQuick
import "."

/** Small count badge (tabs, lists): accent fill, or info / danger. */
Rectangle {
    id: counter

    enum Kind {
        Normal,
        Info,
        Error
    }

    property int kind: KanteCounter.Kind.Normal
    property string text: ""

    implicitHeight: KanteStyle.unit(20)
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + KanteStyle.unit(10))
    color: kind === KanteCounter.Kind.Info ? KanteStyle.infoColor
        : (kind === KanteCounter.Kind.Error ? KanteStyle.negativeTextColor : KanteStyle.accentColor)

    Text {
        id: label
        anchors.centerIn: parent
        text: counter.text
        color: counter.kind === KanteCounter.Kind.Normal ? KanteStyle.accentForegroundColor : KanteStyle.onStateColor
        font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
    }
}
