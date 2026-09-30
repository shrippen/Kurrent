import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "."

/**
 * Chip: an entity (a tag, a customer) or a filter. A colour square and a name in
 * a 1 px frame of that colour. `checked` fills it (filters, `checkable`);
 * `removable` adds a cross and emits `removeRequested`. Entity colours are
 * squares, never circles.
 */
Item {
    id: chip

    property string text: ""
    property color chipColor: KanteStyle.tagColor
    property bool checkable: false
    property bool checked: false
    property bool removable: false
    signal clicked()
    signal removeRequested()

    implicitHeight: KanteStyle.unit(24)
    implicitWidth: row.implicitWidth + KanteStyle.unit(16)
    activeFocusOnTab: true

    function activate() {
        if (checkable) {
            checked = !checked
        }
        clicked()
    }

    Keys.onReturnPressed: activate()
    Keys.onSpacePressed: activate()

    Rectangle {
        anchors.fill: parent
        color: chip.checked ? chip.chipColor : (hover.hovered ? KanteStyle.tint1Color : "transparent")
        border.width: 1
        border.color: chip.chipColor
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        visible: chip.activeFocus
        color: "transparent"
        border.width: 2
        border.color: KanteStyle.focusColor
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: KanteStyle.unit(6)
        Rectangle {
            Layout.preferredWidth: KanteStyle.unit(8)
            Layout.preferredHeight: KanteStyle.unit(8)
            color: chip.checked ? KanteStyle.onStateColor : chip.chipColor
        }
        Text {
            text: chip.text
            color: chip.checked ? KanteStyle.onStateColor : chip.chipColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, false)
        }
        Text {
            visible: chip.removable
            text: "×"
            color: chip.checked ? KanteStyle.onStateColor : chip.chipColor
            font: KanteStyle.monoFont(KanteStyle.labelFont().pointSize, true)
            TapHandler { onTapped: chip.removeRequested() }
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: chip.activate() }
    Accessible.role: chip.checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.name: chip.text
    Accessible.checked: chip.checked
}
