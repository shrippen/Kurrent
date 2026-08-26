import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "../colors.js" as Colors
import ".."

Item {
    id: root

    property var collectionModel
    property string hiddenProjects: ""
    property int collectionId: -1
    property bool includeEmptyProjects: false
    property bool includeHiddenProjects: false

    /** Show radios when count <= this; otherwise ComboBox. */
    readonly property int directLimit: 4

    property var projects: []

    implicitHeight: useCombo ? combo.implicitHeight
                             : (projects.length === 0 ? emptyLabel.implicitHeight : radioRow.implicitHeight)
    implicitWidth: parent ? parent.width : Kirigami.Units.gridUnit * 12

    function _isHidden(id) {
        if (!hiddenProjects) {
            return false
        }
        return hiddenProjects.split(",").indexOf(String(id)) >= 0
    }

    function rebuild() {
        var out = []
        if (!collectionModel) {
            projects = out
            return
        }
        for (var i = 0; i < collectionModel.count; ++i) {
            var id = collectionModel.collectionIdAt(i)
            var name = collectionModel.nameAt(i)
            var taskCount = collectionModel.taskCountAt(i)
            if (!collectionModel.enabledAt(i)) {
                continue
            }
            var writable = collectionModel.writableAt(i)
            var hidden = !includeHiddenProjects && _isHidden(id)
            var emptyOk = includeEmptyProjects || taskCount > 0
            // Same filter as sidebar unless include* flags override it; always keep current.
            if (((emptyOk && !hidden && writable) || id === collectionId)) {
                out.push({ collectionId: id, name: name })
            }
        }
        projects = out

        if (out.length === 0) {
            return
        }
        var found = false
        for (var j = 0; j < out.length; ++j) {
            if (out[j].collectionId === collectionId) {
                found = true
                break
            }
        }
        if (!found) {
            collectionId = out[0].collectionId
        }
        syncComboIndex()
    }

    function syncComboIndex() {
        if (!combo.visible) {
            return
        }
        for (var i = 0; i < projects.length; ++i) {
            if (projects[i].collectionId === collectionId) {
                combo.currentIndex = i
                return
            }
        }
        combo.currentIndex = 0
    }

    onCollectionModelChanged: rebuild()
    onHiddenProjectsChanged: rebuild()
    onIncludeEmptyProjectsChanged: rebuild()
    onIncludeHiddenProjectsChanged: rebuild()

    Connections {
        target: root.collectionModel || null
        ignoreUnknownSignals: true
        function onCountChanged() { root.rebuild() }
    }

    readonly property bool useCombo: projects.length > directLimit

    // Direct radio row when few projects (same layout style as Priority).
    RowLayout {
        id: radioRow
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Design.spaceMedium
        visible: !root.useCombo && projects.length > 0

        QQC2.ButtonGroup {
            id: projectGroup
        }

        Repeater {
            model: root.projects
            delegate: QQC2.RadioButton {
                required property var modelData
                text: modelData.name
                checked: root.collectionId === modelData.collectionId
                QQC2.ButtonGroup.group: projectGroup
                onClicked: root.collectionId = modelData.collectionId

                contentItem: RowLayout {
                    spacing: Design.spaceSmall
                    Kirigami.Icon {
                        source: "folder"
                        color: Design.colorForKey(String(modelData.collectionId))
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                    QQC2.Label {
                        text: modelData.name
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    QQC2.ComboBox {
        id: combo
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.useCombo
        model: root.projects
        textRole: "name"

        contentItem: RowLayout {
            spacing: Design.spaceSmall
            anchors.left: parent.left
            anchors.right: parent.indicator.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Design.spaceSmall

            Kirigami.Icon {
                source: "folder"
                color: combo.currentIndex >= 0 && combo.currentIndex < root.projects.length
                       ? Design.colorForKey(String(root.projects[combo.currentIndex].collectionId))
                       : Kirigami.Theme.textColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: combo.displayText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        delegate: QQC2.ItemDelegate {
            width: combo.width
            required property var modelData
            required property int index
            highlighted: combo.highlightedIndex === index

            contentItem: RowLayout {
                spacing: Design.spaceSmall
                Kirigami.Icon {
                    source: "folder"
                    color: Design.colorForKey(String(modelData.collectionId))
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    width: Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                }
            }
        }

        onActivated: function(index) {
            if (index >= 0 && index < root.projects.length) {
                root.collectionId = root.projects[index].collectionId
            }
        }
    }

    QQC2.Label {
        id: emptyLabel
        anchors.left: parent.left
        visible: projects.length === 0
        text: i18n("No projects available")
        opacity: 0.7
    }
}
