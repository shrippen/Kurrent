import QtQuick
import QtQuick.Layouts
import "."

/**
 * Callout: a note with a 4 px bar in its kind's color, the cut corner and a
 * sign in front (i, tick, !, cross). Sizes to its width; `title` is optional.
 */
Item {
    id: callout

    enum Kind {
        Info,
        Ok,
        Warn,
        Danger
    }

    property int kind: KanteCallout.Kind.Info
    property string title: ""
    property string text: ""

    readonly property color tone: {
        switch (kind) {
        case KanteCallout.Kind.Ok: return KanteStyle.positiveTextColor
        case KanteCallout.Kind.Warn: return KanteStyle.warningColor
        case KanteCallout.Kind.Danger: return KanteStyle.negativeTextColor
        default: return KanteStyle.infoColor
        }
    }
    readonly property string sign: kind === KanteCallout.Kind.Ok ? "✓" : (kind === KanteCallout.Kind.Warn ? "!" : (kind === KanteCallout.Kind.Danger ? "✕" : "i"))

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: content.implicitHeight + KanteStyle.unit(28)

    KanteCard {
        anchors.fill: parent
        color: KanteStyle.cardColor
        barColor: callout.tone
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: KanteStyle.unit(14)
        anchors.topMargin: KanteStyle.unit(16)
        spacing: KanteStyle.unit(10)

        Text {
            Layout.alignment: Qt.AlignTop
            text: callout.sign
            color: callout.tone
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                visible: callout.title.length > 0
                Layout.fillWidth: true
                text: callout.title
                color: KanteStyle.strongTextColor
                font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 1.05)
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: callout.text
                color: KanteStyle.textColor
                font: KanteStyle.defaultFont
                wrapMode: Text.WordWrap
            }
        }
    }
}
