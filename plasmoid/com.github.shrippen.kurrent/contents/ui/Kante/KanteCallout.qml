import QtQuick
import QtQuick.Layouts
import "."

/**
 * Callout: a note with a 4 px bar in its kind's color, the cut corner and a
 * sign in front (i, tick, !, cross). Sizes to its width; `title` is optional.
 * `actions` takes buttons under the text; `dismissible` adds a cross, `dismissed`
 * fires and the callout hides itself (`autoHide`).
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
    property bool dismissible: false
    property bool autoHide: true
    default property alias actions: actionRow.data
    /** At least one action is visible (the action row takes room). */
    readonly property bool hasActions: actionRow.shown
    signal dismissed()

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
            // Stays visible, so each action's own `visible` counts: with no action shown it
            // takes no room (height 0, the column spacing cancelled).
            RowLayout {
                id: actionRow
                readonly property bool shown: implicitHeight > 0
                Layout.topMargin: shown ? KanteStyle.unit(4) : -parent.spacing
                Layout.preferredHeight: shown ? implicitHeight : 0
                spacing: KanteStyle.unit(8)
            }
        }
        Text {
            visible: callout.dismissible
            Layout.alignment: Qt.AlignTop
            text: "×"
            color: closeHover.hovered ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 1.2, true)
            HoverHandler { id: closeHover }
            TapHandler {
                onTapped: {
                    callout.dismissed()
                    if (callout.autoHide) {
                        callout.visible = false
                    }
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: "×"
        }
    }
}
