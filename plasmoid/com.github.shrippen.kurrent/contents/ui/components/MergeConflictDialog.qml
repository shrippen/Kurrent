import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3

Item {
    id: root

    property var controller: null
    property var fields: []
    property var resolution: ({})
    property Item overlayHost: null

    signal accepted(var resolution)
    signal dismissed()
    signal editRequested()

    visible: false
    z: 2000
    parent: overlayHost || null
    anchors.fill: parent

    function openDialog(conflictFields) {
        fields = conflictFields || []
        resolution = {}
        for (var i = 0; i < fields.length; i++)
            resolution[fields[i].key] = "server"
        visible = true
    }

    function closeDialog() {
        visible = false
        fields = []
        resolution = {}
    }

    function selectAll(choice) {
        var r = {}
        for (var i = 0; i < fields.length; i++)
            r[fields[i].key] = choice
        resolution = r
    }

    function fmtVal(key, value) {
        if (value === undefined || value === null || value === "")
            return "(empty)"
        if (key === "priority") {
            var p = parseInt(value)
            if (p === 1) return "1 (Highest)"
            if (p === 5) return "5 (Normal)"
            if (p === 9) return "9 (Lowest)"
            return "" + p
        }
        return value.toString()
    }

    // Dim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        z: -1
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.closeDialog() }
    }

    // Card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 600)
        height: Math.min(parent.height * 0.9, scrollCol.implicitHeight + 40)
        radius: 12
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        border.width: 1
        z: 1

        ColumnLayout {
            id: scrollCol
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 12
                Kirigami.Icon {
                    source: "dialog-warning"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    color: Qt.rgba(1, 0.8, 0, 1)
                }
                PlasmaExtras.Heading {
                    level: 2
                    text: "Merge Conflict"
                    Layout.fillWidth: true
                }
                PC3.ToolButton {
                    icon.name: "dialog-close"
                    onClicked: root.closeDialog()
                }
            }

            PC3.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 16
                wrapMode: Text.Wrap
                text: "The task was modified on the server while you were editing."
                color: Kirigami.Theme.disabledTextColor
            }

            // Scrollable conflict fields
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(root.height * 0.65, fieldCol.implicitHeight + 10)
                contentHeight: fieldCol.implicitHeight
                clip: true
                PC3.ScrollBar.vertical: PC3.ScrollBar { policy: PC3.ScrollBar.AsNeeded }

                ColumnLayout {
                    id: fieldCol
                    width: parent.width
                    spacing: 20

                    Repeater {
                        model: root.fields
                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0

                            // Original state (top of tree)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: origContent.implicitHeight + 20
                                radius: 8
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                                border.width: 1

                                ColumnLayout {
                                    id: origContent
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 2
                                    PC3.Label {
                                        text: modelData.label
                                        font.bold: true
                                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
                                        color: Kirigami.Theme.disabledTextColor
                                    }
                                    PC3.Label {
                                        Layout.fillWidth: true
                                        text: root.fmtVal(modelData.key, modelData.baseValue)
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Arrows
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30

                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.3)
                                        ctx.lineWidth = 2
                                        ctx.setLineDash([4, 3])
                                        var cx = width / 2
                                        var topY = 0
                                        var botY = height
                                        var leftX = width * 0.28
                                        var rightX = width * 0.72
                                        // Left arrow
                                        ctx.beginPath()
                                        ctx.moveTo(cx, topY)
                                        ctx.lineTo(leftX, botY)
                                        ctx.stroke()
                                        // Right arrow
                                        ctx.beginPath()
                                        ctx.moveTo(cx, topY)
                                        ctx.lineTo(rightX, botY)
                                        ctx.stroke()
                                        // Arrowheads
                                        ctx.setLineDash([])
                                        ctx.fillStyle = Qt.alpha(Kirigami.Theme.textColor, 0.3)
                                        // Left head
                                        ctx.beginPath()
                                        ctx.moveTo(leftX, botY)
                                        ctx.lineTo(leftX + 6, botY - 8)
                                        ctx.lineTo(leftX - 6, botY - 8)
                                        ctx.closePath()
                                        ctx.fill()
                                        // Right head
                                        ctx.beginPath()
                                        ctx.moveTo(rightX, botY)
                                        ctx.lineTo(rightX + 6, botY - 8)
                                        ctx.lineTo(rightX - 6, botY - 8)
                                        ctx.closePath()
                                        ctx.fill()
                                    }
                                }
                            }

                            // Two branches side by side
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                // Left: User change
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(60, leftCol.implicitHeight + 20)
                                    radius: 8
                                    color: root.resolution[modelData.key] === "user"
                                           ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1)
                                           : "transparent"
                                    border.color: root.resolution[modelData.key] === "user"
                                                  ? Kirigami.Theme.highlightColor
                                                  : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                                    border.width: 1

                                    ColumnLayout {
                                        id: leftCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 2
                                        PC3.Label {
                                            text: "Widget"
                                            font.bold: true
                                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                                            color: Kirigami.Theme.highlightColor
                                        }
                                        PC3.Label {
                                            Layout.fillWidth: true
                                            text: root.fmtVal(modelData.key, modelData.userValue)
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }

                                // Right: Server change
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(60, rightCol.implicitHeight + 20)
                                    radius: 8
                                    color: root.resolution[modelData.key] === "server"
                                           ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1)
                                           : "transparent"
                                    border.color: root.resolution[modelData.key] === "server"
                                                  ? Kirigami.Theme.highlightColor
                                                  : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                                    border.width: 1

                                    ColumnLayout {
                                        id: rightCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 2
                                        PC3.Label {
                                            text: "Akonadi"
                                            font.bold: true
                                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                                            color: Qt.rgba(0.6, 0.8, 1, 1)
                                        }
                                        PC3.Label {
                                            Layout.fillWidth: true
                                            text: root.fmtVal(modelData.key, modelData.serverValue)
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }

                            // Question + buttons
                            PC3.Label {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                text: "Which version do you want to keep?"
                                color: Kirigami.Theme.disabledTextColor
                                font.italic: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 8
                                PC3.Button {
                                    text: "My version"
                                    icon.name: "edit-undo"
                                    highlighted: root.resolution[modelData.key] === "user"
                                    onClicked: root.setField(modelData.key, "user")
                                    Layout.fillWidth: true
                                }
                                PC3.Button {
                                    text: "Akonadi"
                                    icon.name: "view-refresh"
                                    highlighted: root.resolution[modelData.key] === "server"
                                    onClicked: root.setField(modelData.key, "server")
                                    Layout.fillWidth: true
                                }
                                PC3.Button {
                                    text: "New"
                                    icon.name: "document-edit"
                                    highlighted: root.resolution[modelData.key] === "edit"
                                    onClicked: root.setField(modelData.key, "edit")
                                    Layout.fillWidth: true
                                }
                            }

                            Kirigami.Separator {
                                Layout.fillWidth: true
                                Layout.topMargin: 12
                                visible: index < root.fields.length - 1
                            }
                        }
                    }
                }
            }

            // Bottom bar
            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: 8 }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8
                PC3.Button {
                    text: "All: Mine"
                    onClicked: root.selectAll("user")
                }
                PC3.Button {
                    text: "All: Akonadi"
                    onClicked: root.selectAll("server")
                }
                Item { Layout.fillWidth: true }
                PC3.Button {
                    text: "Apply"
                    icon.name: "dialog-ok-apply"
                    highlighted: true
                    enabled: Object.keys(root.resolution).length > 0
                    onClicked: {
                        root.accepted(root.resolution)
                        root.closeDialog()
                    }
                }
            }
        }
    }

    function setField(key, val) {
        var r = resolution
        r[key] = val
        resolution = r
    }
}
