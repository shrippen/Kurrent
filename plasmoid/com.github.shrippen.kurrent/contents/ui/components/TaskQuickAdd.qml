import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."
import "../Kante"

// Quick Add that creates the task: the text is read for date, priority, labels and
// @project; without a project in it the target follows the new-task rule (selected
// project, setting, or a choice in a small popup). Used by the list and the Agenda. With
// `day` set, a text without a date lands on that day (a block from startMinute to endMinute
// when given).
Item {
    id: root

    property var controller: null
    property Item popupHost: null
    /** Only re-triggers the project list; the controller applies it. */
    property string hiddenProjects: ""
    property var day: null
    property int startMinute: -1
    property int endMinute: -1
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    readonly property alias fieldFocus: field.fieldFocus
    /** True while the project choice is open (the field has no focus then). */
    readonly property bool asking: projectAskPopup.visible
    signal created()
    signal escaped()

    property string pendingText: ""
    property var askProjects: []

    implicitHeight: field.implicitHeight
    implicitWidth: field.implicitWidth

    readonly property var writableProjects: {
        if (!controller) {
            return []
        }
        var _count = controller.collectionModel ? controller.collectionModel.count : 0
        var _hidden = hiddenProjects
        return controller.writableProjects()
    }

    function forceActiveFocus() {
        field.forceActiveFocus()
    }

    function create(text, collectionId) {
        if (day) {
            controller.agendaAddTask(text, collectionId, day, startMinute, endMinute)
        } else {
            controller.createTask(text, collectionId)
        }
        root.created()
    }

    function submit() {
        var text = field.text.trim()
        if (!text || !controller) {
            return
        }
        var parsed = controller.parseQuickAdd(text, Qt.locale().name, writableProjects)
        if (parsed && parsed.collectionId > 0) {
            field.text = ""
            create(text, parsed.collectionId)
            return
        }
        // Selected project, the "new task project" setting, or the only one (controller).
        var target = controller.newTaskTarget()
        if (!target.ask) {
            field.text = ""
            create(text, target.collectionId)
            return
        }
        pendingText = text
        field.text = ""
        askProjects = target.choices
        projectAskPopup.open()
    }

    function confirm(collectionId) {
        var text = pendingText
        pendingText = ""
        projectAskPopup.close()
        if (text && collectionId > 0) {
            create(text, collectionId)
        }
    }

    QuickAddField {
        id: field
        width: root.width
        controller: root.controller
        projects: root.writableProjects
        popupHost: root.popupHost || root
        onAccepted: root.submit()
        onEscaped: root.escaped()
    }

    QQC2.Popup {
        id: projectAskPopup
        KantePopupSkin { popup: projectAskPopup }
        parent: root.popupHost || root
        popupType: QQC2.Popup.Item
        modal: true
        dim: true
        focus: true
        clip: true
        padding: Design.spaceSmall
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        z: 1500

    width: Math.min(Kirigami.Units.gridUnit * 18,
                    Math.max(Kirigami.Units.gridUnit * 12, parent.width - Design.spaceMedium * 2))
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - implicitHeight) / 2)

    background: Rectangle {
        radius: 4
        color: Kirigami.Theme.backgroundColor
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: Design.spaceSmall

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.bold: true
            text: root.pendingText
                  ? i18n("Choose a project for “%1”", root.pendingText)
                  : i18n("Choose a project")
        }

        ListView {
            id: projectAskList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight,
                                             Kirigami.Units.gridUnit * 12)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.askProjects
            spacing: 0

            delegate: QQC2.ItemDelegate {
                required property var modelData
                width: projectAskList.width
                onClicked: root.confirm(modelData.collectionId)

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
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                policy: projectAskList.contentHeight > projectAskList.height
                        ? QQC2.ScrollBar.AlwaysOn
                        : QQC2.ScrollBar.AlwaysOff
            }
        }

        KanteButton {
            Layout.alignment: Qt.AlignRight
            text: i18n("Cancel")
            onClicked: projectAskPopup.close()
        }
    }

    onClosed: {
        if (root.pendingText) {
            field.text = root.pendingText
            root.pendingText = ""
            field.forceActiveFocus()
        }
    }
    }
}
