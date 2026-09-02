import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3

PlasmaExtras.PlasmoidHeading {
    id: root

    property var controller: null
    property var fields: []
    property var resolution: ({})

    signal accepted(var resolution)
    signal dismissed()

    visible: controller && controller.conflictItemId >= 0 && fields.length > 0

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

    function setField(key, val) {
        var r = resolution
        r[key] = val
        resolution = r
    }

    function fmtVal(key, value) {
        if (value === undefined || value === null || value === "")
            return qsTr("(empty)")
        if (key === "priority") {
            var p = parseInt(value)
            if (p === 1) return "1 (Highest)"
            if (p === 5) return "5 (Normal)"
            if (p === 9) return "9 (Lowest)"
            return "" + p
        }
        return value.toString()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
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
            wrapMode: Text.Wrap
            text: "The task was modified on the server while you were editing."
            color: Kirigami.Theme.disabledTextColor
        }

        Repeater {
            model: root.fields
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                Kirigami.Separator { Layout.fillWidth: true }

                PC3.Label {
                    text: modelData.label
                    font.bold: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 6
                        color: root.resolution[modelData.key] === "user"
                               ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
                               : "transparent"
                        border.color: root.resolution[modelData.key] === "user"
                                      ? Kirigami.Theme.highlightColor
                                      : Qt.alpha(Kirigami.Theme.textColor, 0.2)
                        border.width: 1
                        PC3.Label {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: root.fmtVal(modelData.key, modelData.userValue)
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setField(modelData.key, "user")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 6
                        color: root.resolution[modelData.key] === "server"
                               ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
                               : "transparent"
                        border.color: root.resolution[modelData.key] === "server"
                                      ? Kirigami.Theme.highlightColor
                                      : Qt.alpha(Kirigami.Theme.textColor, 0.2)
                        border.width: 1
                        PC3.Label {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: root.fmtVal(modelData.key, modelData.serverValue)
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setField(modelData.key, "server")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PC3.Button {
                        text: "A: Your change"
                        icon.name: "edit-undo"
                        background: Rectangle { radius: 4; color: root.resolution[modelData.key] === "user" ? Kirigami.Theme.highlightColor : "transparent" }
                        onClicked: root.setField(modelData.key, "user")
                        Layout.fillWidth: true
                    }
                    PC3.Button {
                        text: "B: Server"
                        icon.name: "view-refresh"
                        background: Rectangle { radius: 4; color: root.resolution[modelData.key] === "server" ? Kirigami.Theme.highlightColor : "transparent" }
                        onClicked: root.setField(modelData.key, "server")
                        Layout.fillWidth: true
                    }
                    PC3.Button {
                        text: "C: Edit"
                        icon.name: "document-edit"
                        background: Rectangle { radius: 4; color: root.resolution[modelData.key] === "edit" ? Kirigami.Theme.highlightColor : "transparent" }
                        onClicked: root.setField(modelData.key, "edit")
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PC3.Button {
                text: "All: Your changes"
                onClicked: {
                    var r = {}
                    for (var i = 0; i < root.fields.length; i++)
                        r[root.fields[i].key] = "user"
                    root.resolution = r
                }
            }
            PC3.Button {
                text: "All: Server"
                onClicked: {
                    var r = {}
                    for (var i = 0; i < root.fields.length; i++)
                        r[root.fields[i].key] = "server"
                    root.resolution = r
                }
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
