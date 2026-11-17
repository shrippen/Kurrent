import QtQuick
import QtQuick.Layouts
import "."

/**
 * File drop area for desktop apps (web: `.drop`). Files and folders dragged from the file manager
 * land here; `dropped(urls)` carries their urls. Not `KanteDropZone`: that is the placeholder of
 * a tile in a drag inside the app, this one receives things from outside.
 *
 *   ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
 *     Drop videos and photos here     `hint`
 *             [ CHOOSE ]              `chooseText`, optional
 *   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
 *
 * The outline is grey and turns cyan while a drag is over the area. Without a pointer: the area
 * takes Tab, and Return, Enter or Space (like the button) fire `chooseRequested()`, where the app
 * opens its file dialog (Kante knows no dialog of the platform). `chooseText` shows the button;
 * empty: no button, the keys still work.
 */
FocusScope {
    id: drop

    /** Text in the area. */
    property string hint: ""
    /** Label of the button; empty: no button. */
    property string chooseText: ""
    /** A drag is over the area and carries files. */
    readonly property alias dragOver: area.containsDrag

    /** Files or folders were dropped; `urls` is the list of urls. */
    signal dropped(var urls)
    /** The user asked to choose files (button, Return, Enter, Space). */
    signal chooseRequested()

    implicitWidth: KanteStyle.unit(320)
    implicitHeight: KanteStyle.unit(72)
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: hint
    Accessible.onPressAction: chooseRequested()

    Keys.onReturnPressed: chooseRequested()
    Keys.onEnterPressed: chooseRequested()
    Keys.onSpacePressed: chooseRequested()

    function take(urls) {
        if (!urls || urls.length === 0) {
            return
        }
        dropped(urls)
    }

    DropArea {
        id: area
        anchors.fill: parent
        onEntered: (event) => { event.accepted = event.hasUrls }
        onDropped: (event) => {
            if (!event.hasUrls) {
                return
            }
            event.accept()
            drop.take(event.urls)
        }
    }

    KanteDropZone {
        anchors.fill: parent
        kind: area.containsDrag ? KanteDropZone.Kind.Gap : KanteDropZone.Kind.Cell
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - KanteStyle.unit(16))
        spacing: KanteStyle.unit(8)

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: drop.hint
            font: KanteStyle.defaultFont
            color: area.containsDrag ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
        }
        KanteButton {
            objectName: "chooseButton"
            visible: drop.chooseText !== ""
            Layout.alignment: Qt.AlignHCenter
            text: drop.chooseText
            size: KanteButton.Size.Small
            focusPolicy: Qt.NoFocus
            onClicked: {
                drop.forceActiveFocus()
                drop.chooseRequested()
            }
        }
    }

    KanteBrackets {
        anchors.fill: parent
        active: drop.activeFocus
    }
}
