import QtQuick
import QtQuick.Layouts
import "."

/**
 * Full-width status banner with marching warning stripes on its top and bottom
 * edge ("not finished yet", "archived"). Warning color by default, `danger`
 * for the negative color.
 */
Item {
    id: banner

    property string title: ""
    property string text: ""
    property bool danger: false
    readonly property color tone: danger ? KanteStyle.negativeTextColor : KanteStyle.warningColor
    /** Ink on the banner: dark on the bright dark-theme colors, light on the darkened Leinen colors. */
    readonly property color ink: (danger || KanteStyle.light) ? KanteStyle.onStateColor : KanteStyle.accentForegroundColor

    implicitWidth: KanteStyle.unit(400)
    implicitHeight: content.implicitHeight + KanteStyle.unit(40)

    Rectangle { anchors.fill: parent; color: banner.tone }

    KanteHazard {
        anchors.top: parent.top
        width: parent.width
        height: KanteStyle.unit(8)
        color: banner.ink
        stripe: KanteStyle.unit(8)
    }
    KanteHazard {
        anchors.bottom: parent.bottom
        width: parent.width
        height: KanteStyle.unit(8)
        color: banner.ink
        stripe: KanteStyle.unit(8)
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: KanteStyle.unit(20)
        spacing: KanteStyle.unit(4)
        Text {
            Layout.fillWidth: true
            text: banner.title
            color: banner.ink
            font: KanteStyle.headingFont(KanteStyle.defaultFont.pointSize * 2)
            wrapMode: Text.WordWrap
        }
        Text {
            visible: banner.text.length > 0
            Layout.fillWidth: true
            text: banner.text
            color: banner.ink
            font: KanteStyle.labelFont()
            wrapMode: Text.WordWrap
        }
    }
}
