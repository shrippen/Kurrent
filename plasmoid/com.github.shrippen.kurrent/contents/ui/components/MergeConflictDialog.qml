import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3
import "../colors.js" as Colors

Item {
    id: root

    property var controller: null
    property var fields: []
    property int currentIndex: 0
    property var resolution: ({})
    property Item overlayHost: null
    property bool waitingForEditor: false

    signal accepted(var resolution)
    signal dismissed()
    signal editRequested()

    visible: false
    z: 2000
    parent: overlayHost || null
    anchors.fill: parent

    readonly property var currentField: fields.length > 0 && currentIndex < fields.length ? fields[currentIndex] : null
    readonly property int totalFields: fields.length
    readonly property bool hasMore: currentIndex < fields.length - 1

    function openDialog(conflictFields) {
        fields = conflictFields || []
        resolution = {}
        currentIndex = 0
        waitingForEditor = false
        visible = true
    }

    function closeDialog() {
        visible = false
        waitingForEditor = false
    }

    function advanceToNext() {
        if (currentIndex < fields.length - 1) {
            currentIndex++
        } else {
            accepted(resolution)
            closeDialog()
        }
    }

    function editorClosed() {
        waitingForEditor = false
        advanceToNext()
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
        width: Math.min(parent.width * 0.9, 550)
        height: Math.min(parent.height * 0.9, cardCol.implicitHeight + 40)
        radius: 12
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        border.width: 1
        z: 1

        ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
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

            // Progress
            PC3.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                text: "Conflict " + (root.currentIndex + 1) + " of " + root.totalFields
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
            }

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                Layout.bottomMargin: 16
                radius: 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
                Rectangle {
                    width: parent.width * ((root.currentIndex + 1) / Math.max(1, root.totalFields))
                    height: parent.height
                    radius: 2
                    color: Kirigami.Theme.highlightColor
                }
            }

            // Waiting overlay
            PC3.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 16
                visible: root.waitingForEditor
                text: "Editor is open. Close it to continue."
                color: Kirigami.Theme.disabledTextColor
                font.italic: true
                horizontalAlignment: Text.AlignHCenter
            }

            // Content (only when not waiting)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: !root.waitingForEditor && root.currentField

                // Original state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: origCol.implicitHeight + 20
                    radius: 8
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                    border.width: 1

                    ColumnLayout {
                        id: origCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        PC3.Label {
                            text: root.currentField ? root.currentField.label : ""
                            font.bold: true
                            color: Kirigami.Theme.disabledTextColor
                        }
                        Loader {
                            Layout.fillWidth: true
                            active: root.currentField !== null
                            sourceComponent: root.currentField ? valueDisplayComponent : null
                            property var field: root.currentField
                            property string mode: "original"
                        }
                    }
                }

                // Arrows
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2
                            var topY = 2
                            var botY = height - 2
                            var leftX = width * 0.28
                            var rightX = width * 0.72
                            ctx.strokeStyle = Qt.alpha(Kirigami.Theme.textColor, 0.3)
                            ctx.lineWidth = 2
                            ctx.setLineDash([4, 3])
                            ctx.beginPath(); ctx.moveTo(cx, topY); ctx.lineTo(leftX, botY); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(cx, topY); ctx.lineTo(rightX, botY); ctx.stroke()
                            ctx.setLineDash([])
                            ctx.fillStyle = Qt.alpha(Kirigami.Theme.textColor, 0.3)
                            ctx.beginPath(); ctx.moveTo(leftX, botY); ctx.lineTo(leftX + 6, botY - 8); ctx.lineTo(leftX - 6, botY - 8); ctx.closePath(); ctx.fill()
                            ctx.beginPath(); ctx.moveTo(rightX, botY); ctx.lineTo(rightX + 6, botY - 8); ctx.lineTo(rightX - 6, botY - 8); ctx.closePath(); ctx.fill()
                        }
                    }
                }

                // Two branches
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Kurrent (left)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(60, leftCol.implicitHeight + 20)
                        radius: 8
                        color: root.resolution[root.currentField.key] === "user"
                               ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                               : "transparent"
                        border.color: root.resolution[root.currentField.key] === "user"
                                      ? Kirigami.Theme.highlightColor
                                      : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                        border.width: 1

                        ColumnLayout {
                            id: leftCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4
                            PC3.Label {
                                text: "Kurrent"
                                font.bold: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                                color: Kirigami.Theme.highlightColor
                            }
                            Loader {
                                Layout.fillWidth: true
                                active: root.currentField !== null
                                sourceComponent: root.currentField ? valueDisplayComponent : null
                                property var field: root.currentField
                                property string mode: "user"
                            }
                        }
                    }

                    // Akonadi (right)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(60, rightCol.implicitHeight + 20)
                        radius: 8
                        color: root.resolution[root.currentField.key] === "server"
                               ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                               : "transparent"
                        border.color: root.resolution[root.currentField.key] === "server"
                                      ? Kirigami.Theme.highlightColor
                                      : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                        border.width: 1

                        ColumnLayout {
                            id: rightCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4
                            PC3.Label {
                                text: "Akonadi"
                                font.bold: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                                color: Qt.rgba(0.6, 0.8, 1, 1)
                            }
                            Loader {
                                Layout.fillWidth: true
                                active: root.currentField !== null
                                sourceComponent: root.currentField ? valueDisplayComponent : null
                                property var field: root.currentField
                                property string mode: "server"
                            }
                        }
                    }
                }

                // Buttons
                PC3.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    text: "Which version do you want to keep?"
                    color: Kirigami.Theme.disabledTextColor
                    font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    PC3.Button {
                        text: "Mine"
                        icon.name: "edit-undo"
                        highlighted: root.currentField && root.resolution[root.currentField.key] === "user"
                        onClicked: {
                            var r = root.resolution
                            r[root.currentField.key] = "user"
                            root.resolution = r
                            root.advanceToNext()
                        }
                        Layout.fillWidth: true
                    }
                    PC3.Button {
                        text: "Akonadi"
                        icon.name: "view-refresh"
                        highlighted: root.currentField && root.resolution[root.currentField.key] === "server"
                        onClicked: {
                            var r = root.resolution
                            r[root.currentField.key] = "server"
                            root.resolution = r
                            root.advanceToNext()
                        }
                        Layout.fillWidth: true
                    }
                    PC3.Button {
                        text: "New"
                        icon.name: "document-edit"
                        highlighted: root.currentField && root.resolution[root.currentField.key] === "edit"
                        onClicked: {
                            // Accept server value for current field, then open editor for manual changes
                            var r = root.resolution
                            r[root.currentField.key] = "edit"
                            root.resolution = r
                            root.waitingForEditor = true
                            root.editRequested()
                        }
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // Value display component with chip rendering
    Component {
        id: valueDisplayComponent
        Loader {
            Layout.fillWidth: true
            property var fld: field
            property string valMode: mode
            sourceComponent: {
                if (!fld) return null
                if (fld.key === "categories") return chipDisplay
                if (fld.key === "priority") return priorityDisplay
                return textDisplay
            }

            Component {
                id: textDisplay
                PC3.Label {
                    text: {
                        if (!fld) return ""
                        var val = valMode === "user" ? fld.userValue
                                : valMode === "server" ? fld.serverValue
                                : fld.baseValue
                        if (val === undefined || val === null || val === "") return "(empty)"
                        return val.toString()
                    }
                    wrapMode: Text.Wrap
                }
            }

            Component {
                id: chipDisplay
                Flow {
                    spacing: 4
                    Repeater {
                        model: {
                            if (!fld) return []
                            var val = valMode === "user" ? fld.userValue
                                    : valMode === "server" ? fld.serverValue
                                    : fld.baseValue
                            if (!val || val === "") return []
                            return val.toString().split(",")
                        }
                        Rectangle {
                            width: chipLabel.implicitWidth + 12
                            height: chipLabel.implicitHeight + 6
                            radius: height / 2
                            color: Qt.alpha(Colors.colorForKey(modelData, "label"), 0.15)
                            border.color: Colors.colorForKey(modelData, "label")
                            border.width: 1
                            PC3.Label {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                                color: Colors.colorForKey(modelData, "label")
                            }
                        }
                    }
                }
            }

            Component {
                id: priorityDisplay
                RowLayout {
                    spacing: 4
                    Kirigami.Icon {
                        source: "flag"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        property var fldRef: fld
                        property string priMode: valMode
                        color: Colors.colorForPriority(priMode === "user" ? fldRef.userValue : priMode === "server" ? fldRef.serverValue : fldRef.baseValue)
                    }
                    PC3.Label {
                        text: {
                            if (!fld) return ""
                            var val = valMode === "user" ? fld.userValue
                                    : valMode === "server" ? fld.serverValue
                                    : fld.baseValue
                            var p = parseInt(val)
                            if (p === 1) return "1 (Highest)"
                            if (p === 5) return "5 (Normal)"
                            if (p === 9) return "9 (Lowest)"
                            return "" + p
                        }
                    }
                }
            }
        }
    }
}
