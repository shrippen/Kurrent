import QtQuick
import QtQuick.Layouts
import "."

/**
 * One message of a conversation (web: `.thread > .msg`). The other side sits left with an
 * info bar on the left edge, your own messages sit right with the accent bar on the right
 * edge and a light tint. A head line in small mono capitals carries who and when; items
 * put into `head` (chips, a button) wrap on a line under it, on the speaker's side.
 * Children go under the text (chips,
 * a row of versions). Place several in a ListView or ColumnLayout with the full width;
 * `ownIndent` keeps your messages off the left edge. `System` draws a centred line with
 * the time between rules, for events in the thread ("3 files got a new version"); its
 * children sit centred under the text.
 *
 *   KanteMessage { from: KanteMessage.From.Other; author: "AI"; time: "09:14"; text: "…" }
 */
Item {
    id: msg

    enum From {
        Other,
        Own,
        System
    }

    property int from: KanteMessage.From.Other
    property string author: ""
    property string time: ""
    property string text: ""
    property int textFormat: Text.PlainText
    /** Room on the left of your own messages, so the two sides read apart. */
    property real ownIndent: KanteStyle.unit(48)
    /** Items in the head line, between the author and the time (chips, a tool button). */
    property alias head: headExtra.data
    /** Items under the text. */
    default property alias extra: extraColumn.data

    readonly property bool own: from === KanteMessage.From.Own
    readonly property bool system: from === KanteMessage.From.System
    readonly property int barWidth: KanteStyle.unit(4)

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: system ? systemColumn.implicitHeight : box.implicitHeight

    // ── Speech: a surface with a bar on the speaker's side ──
    Item {
        id: box
        visible: !msg.system
        x: msg.own ? Math.min(msg.ownIndent, msg.width / 4) : 0
        width: msg.width - x
        implicitHeight: content.implicitHeight + KanteStyle.unit(22)
        height: implicitHeight

        Rectangle {
            anchors.fill: parent
            color: msg.own ? KanteStyle.tint1Color : KanteStyle.cardColor
            radius: KanteStyle.active ? 0 : KanteStyle.unit(4)
        }
        Rectangle {
            width: msg.barWidth
            height: parent.height
            anchors.left: msg.own ? undefined : parent.left
            anchors.right: msg.own ? parent.right : undefined
            color: msg.own ? KanteStyle.accentColor : KanteStyle.infoColor
            radius: KanteStyle.active ? 0 : msg.barWidth / 2
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: KanteStyle.unit(14) + (msg.own ? 0 : msg.barWidth)
            anchors.rightMargin: KanteStyle.unit(14) + (msg.own ? msg.barWidth : 0)
            anchors.topMargin: KanteStyle.unit(10)
            spacing: KanteStyle.unit(4)

            RowLayout {
                Layout.fillWidth: true
                spacing: KanteStyle.unit(8)
                layoutDirection: msg.own ? Qt.RightToLeft : Qt.LeftToRight
                Text {
                    visible: msg.author.length > 0
                    text: msg.author
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.labelFont()
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: msg.time.length > 0
                    text: msg.time
                    color: KanteStyle.mutedTextColor
                    font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
                }
            }
            // Head items (chips) on their own line: they wrap instead of pushing the time out.
            Flow {
                id: headExtra
                Layout.fillWidth: true
                visible: visibleChildren.length > 0
                spacing: KanteStyle.unit(6)
                layoutDirection: msg.own ? Qt.RightToLeft : Qt.LeftToRight
            }
            Text {
                visible: msg.text.length > 0
                Layout.fillWidth: true
                text: msg.text
                textFormat: msg.textFormat
                color: KanteStyle.textColor
                font: KanteStyle.defaultFont
                wrapMode: Text.Wrap
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
    }

    // ── System line: time between two rules, the text centred under it ──
    ColumnLayout {
        id: systemColumn
        visible: msg.system
        width: msg.width
        spacing: KanteStyle.unit(4)
        RowLayout {
            Layout.fillWidth: true
            spacing: KanteStyle.unit(8)
            Rectangle { Layout.fillWidth: true; height: 1; color: KanteStyle.ruleColor }
            Text {
                text: msg.time
                visible: msg.time.length > 0
                color: KanteStyle.mutedTextColor
                font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: KanteStyle.ruleColor }
        }
        Text {
            visible: msg.text.length > 0
            Layout.fillWidth: true
            text: msg.text
            textFormat: msg.textFormat
            color: KanteStyle.mutedTextColor
            font.family: KanteStyle.defaultFont.family
            font.pointSize: KanteStyle.defaultFont.pointSize * 0.9
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Children: under the text of a message, or under the system line. One column that moves.
    ColumnLayout {
        id: extraColumn
        parent: msg.system ? systemColumn : content
        Layout.fillWidth: true
        Layout.alignment: msg.system ? Qt.AlignHCenter : Qt.AlignLeft
        visible: children.length > 0
        spacing: KanteStyle.unit(6)
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: (author ? author + ", " : "") + (time ? time + ": " : "") + text
}
