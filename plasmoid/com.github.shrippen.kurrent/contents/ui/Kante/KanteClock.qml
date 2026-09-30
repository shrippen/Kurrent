import QtQuick
import "."

/**
 * Analogue clock: a square face with square ticks, hour and minute hands in the
 * strong text colour, a yellow second hand that steps, a yellow pin. No red: red is danger.
 * `running` follows the system time once a second; set `time` yourself otherwise.
 */
Item {
    id: clock

    property date time: new Date()
    property bool running: true
    property bool seconds: true

    implicitWidth: KanteStyle.unit(140)
    implicitHeight: implicitWidth

    Timer {
        interval: 1000
        repeat: true
        running: clock.running && clock.visible
        triggeredOnStart: true
        onTriggered: clock.time = new Date()
    }

    KanteCard { anchors.fill: parent; chamfer: 0; color: KanteStyle.cardColor }

    Repeater {
        model: 12
        delegate: Item {
            required property int index
            anchors.fill: parent
            rotation: index * 30
            Rectangle {
                x: parent.width / 2 - width / 2
                y: KanteStyle.unit(index % 3 === 0 ? 6 : 8)
                width: index % 3 === 0 ? 2 : 1.5
                height: KanteStyle.unit(index % 3 === 0 ? 9 : 5)
                color: KanteStyle.mutedTextColor
            }
        }
    }

    component Hand: Item {
        property real angle: 0
        property real length: 0.3
        property real thickness: 2
        property color tone: KanteStyle.strongTextColor
        anchors.fill: parent
        rotation: angle
        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - parent.height * length
            width: thickness
            height: parent.height * length
            color: tone
        }
    }

    Hand { angle: (clock.time.getHours() % 12 + clock.time.getMinutes() / 60) * 30; length: 0.26; thickness: 3.5 }
    Hand { angle: (clock.time.getMinutes() + clock.time.getSeconds() / 60) * 6; length: 0.38; thickness: 2.5 }
    Hand { visible: clock.seconds; angle: clock.time.getSeconds() * 6; length: 0.42; thickness: 1.5; tone: KanteStyle.accentColor }

    Rectangle {
        anchors.centerIn: parent
        width: KanteStyle.unit(6)
        height: width
        color: KanteStyle.accentColor
    }
}
