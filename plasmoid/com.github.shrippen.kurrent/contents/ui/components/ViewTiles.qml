import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../Kante"

// Direction B: key views as tiles above the task pane (wide layout). Each tile shows the
// count with a tone bar on top; a click switches to that view, the current one is marked.
// A view can hand in its own figures (`facts`, e.g. the heatmap); those tiles replace the view
// tiles, only entries with a viewId stay clickable.
// Plasma: soft rounded tile, highlight frame when current. Kante / Kante Light: KanteCard with
// the cut corner, figures in Rajdhani.
RowLayout {
    id: tiles

    required property var controller

    // [{ label, value, tone, viewId? }] from the current view; null = the view tiles.
    property var facts: null

    signal viewPicked(string viewId)

    spacing: Design.spaceSmall

    function countFor(viewId) {
        return controller && controller.viewTaskCounts ? (controller.viewTaskCounts[viewId] || 0) : 0
    }

    readonly property var viewEntries: [
        { viewId: "overdue", label: i18n("Overdue"), tone: KanteStyle.negativeTextColor, value: String(countFor("overdue")) },
        { viewId: "today", label: i18n("Today"), tone: KanteStyle.accentColor, value: String(countFor("today")) },
        { viewId: "tomorrow", label: i18n("Tomorrow"), tone: KanteStyle.infoColor, value: String(countFor("tomorrow")) },
        { viewId: "scheduled", label: i18n("Scheduled"), tone: KanteStyle.neutralTextColor, value: String(countFor("scheduled")) },
        { viewId: "completed", label: i18n("Completed"), tone: KanteStyle.positiveTextColor, value: String(countFor("completed")) }
    ]
    readonly property var entries: facts && facts.length > 0 ? facts : viewEntries

    Repeater {
        model: tiles.entries

        delegate: QQC2.AbstractButton {
            id: tile
            required property var modelData
            readonly property bool clickable: !!modelData.viewId
            readonly property bool current: clickable && !tiles.facts && tiles.controller
                    && tiles.controller.currentView === modelData.viewId
            // Overdue with tasks reads as an alarm: figure in the negative colour.
            readonly property bool alarm: modelData.viewId === "overdue" && modelData.value !== "0"

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            hoverEnabled: clickable
            enabled: true
            padding: Design.spaceSmall
            topPadding: Design.spaceSmall + 3
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label + ": " + modelData.value
            onClicked: {
                if (clickable) {
                    tiles.viewPicked(modelData.viewId)
                }
            }

            background: Item {
                Rectangle {
                    anchors.fill: parent
                    visible: !KanteStyle.active
                    radius: Kirigami.Units.cornerRadius
                    color: tile.current ? KanteStyle.tint(Kirigami.Theme.highlightColor, 0.14)
                         : (tile.hovered ? KanteStyle.tint(Kirigami.Theme.textColor, 0.08)
                                         : KanteStyle.tint(Kirigami.Theme.textColor, 0.045))
                    border.width: tile.current || tile.visualFocus ? 1 : 0
                    border.color: Kirigami.Theme.highlightColor

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: parent.radius
                        anchors.topMargin: 0
                        height: 3
                        radius: 1.5
                        color: tile.modelData.tone
                    }
                }

                KanteCard {
                    anchors.fill: parent
                    visible: KanteStyle.active
                    chamfer: KanteStyle.chamferSmall
                    color: tile.current ? KanteStyle.sunkenColor
                         : (tile.hovered ? KanteStyle.tint(KanteStyle.textColor, 0.08) : KanteStyle.cardColor)
                    borderColor: tile.current || tile.visualFocus ? KanteStyle.accentColor : "transparent"
                    barColor: tile.modelData.tone
                }
            }

            contentItem: ColumnLayout {
                spacing: 2

                QQC2.Label {
                    Layout.fillWidth: true
                    text: tile.modelData.label
                    elide: Text.ElideRight
                    font: KanteStyle.active ? KanteStyle.labelFont() : Kirigami.Theme.smallFont
                    color: KanteStyle.mutedTextColor
                }

                QQC2.Label {
                    text: tile.modelData.value
                    font: KanteStyle.active
                          ? KanteStyle.titleFont(Kirigami.Theme.defaultFont.pointSize * 2)
                          : Qt.font({ family: Kirigami.Theme.defaultFont.family,
                                      pointSize: Kirigami.Theme.defaultFont.pointSize * 1.7, bold: true })
                    color: tile.alarm ? KanteStyle.negativeTextColor : KanteStyle.strongTextColor
                }
            }
        }
    }
}
