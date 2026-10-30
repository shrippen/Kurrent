import QtQuick
import "."

/**
 * Input level (Kante 1.23, for Kontra): RMS as a bar, the peak as a tick, on a scale of
 * −rangeDb..0 dBFS with three zones: too quiet, good, too loud. The zone the peak is in
 * is named in words (its label bold and underlined) and in the read-out, so it never
 * hangs on colour; `clipped` lights the clip box with its word and a cross.
 *
 *   peakDb, rmsDb   levels in dBFS (≤ 0; below −rangeDb is silence)
 *   clipped         the input clipped (the app holds it for a while)
 *   rangeDb         scale depth (default 60)
 *   quietDb, loudDb zone limits for the peak (default −36 and −6)
 */
Item {
    id: meter

    property real peakDb: -120
    property real rmsDb: -120
    property bool clipped: false
    property real rangeDb: 60
    property real quietDb: -36
    property real loudDb: -6
    property string title: "Eingang"
    property string quietText: "zu leise"
    property string goodText: "gut"
    property string loudText: "zu laut"
    property string clipText: "Übersteuert"
    property string accessibleName: "Eingangspegel"

    /** "quiet", "good", "loud" or "clip". */
    readonly property string zone: clipped ? "clip" : peakDb > loudDb ? "loud" : peakDb < quietDb ? "quiet" : "good"
    readonly property string zoneText: zone === "clip" ? clipText : zone === "loud" ? loudText : zone === "quiet" ? quietText : goodText
    readonly property string peakText: peakDb <= -rangeDb ? "−∞ dB" : (peakDb < -0.05 ? "−" : "") + Math.abs(peakDb).toFixed(0) + " dB"

    readonly property real clipWidth: Math.round(clipMetrics.width + KanteStyle.unit(30))
    readonly property real trackWidth: Math.max(1, width - clipWidth - KanteStyle.unit(8))
    readonly property real trackHeight: KanteStyle.unit(16)
    function xOf(db) {
        return Math.max(0, Math.min(1, (db + rangeDb) / rangeDb)) * trackWidth
    }

    implicitWidth: KanteStyle.unit(420)
    implicitHeight: head.height + trackHeight + zones.height + KanteStyle.unit(12)

    Accessible.role: Accessible.ProgressBar
    Accessible.name: accessibleName
    Accessible.description: peakText + ", " + zoneText

    TextMetrics {
        id: clipMetrics
        font: KanteStyle.labelFont()
        text: meter.clipText
    }

    Item {
        id: head
        width: meter.width
        height: Math.max(titleText.height, valueText.height)
        Text {
            id: titleText
            text: meter.title
            color: KanteStyle.mutedTextColor
            font: KanteStyle.labelFont()
        }
        Text {
            id: valueText
            anchors.right: parent.right
            text: meter.peakText + " · " + meter.zoneText
            color: KanteStyle.textColor
            font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize, true)
        }
    }

    // Track: zones as ground, RMS bar, peak tick.
    Item {
        id: track
        y: head.height + KanteStyle.unit(4)
        width: meter.trackWidth
        height: meter.trackHeight
        Rectangle { anchors.fill: parent; color: KanteStyle.sunkenColor; border.width: 1; border.color: KanteStyle.frameColor }
        Rectangle {
            x: meter.xOf(meter.loudDb)
            width: parent.width - x
            height: parent.height
            color: KanteStyle.tintWarnColor
        }
        Rectangle {
            x: 1
            y: Math.round(parent.height * 0.2)
            width: Math.max(0, meter.xOf(meter.rmsDb) - 1)
            height: Math.round(parent.height * 0.6)
            color: KanteStyle.focusColor
        }
        Rectangle {
            visible: meter.peakDb > -meter.rangeDb
            x: Math.min(parent.width - width, meter.xOf(meter.peakDb))
            width: Math.max(2, KanteStyle.unit(3))
            height: parent.height
            color: KanteStyle.strongTextColor
        }
        // Zone limits
        Repeater {
            model: [meter.quietDb, meter.loudDb]
            delegate: Rectangle {
                required property var modelData
                x: meter.xOf(modelData)
                y: -KanteStyle.unit(3)
                width: 1
                height: parent.height + KanteStyle.unit(6)
                color: KanteStyle.mutedTextColor
            }
        }
    }

    // Clip box: word always there, filled with a cross when clipped.
    Rectangle {
        x: meter.width - width
        width: meter.clipWidth
        height: meter.trackHeight + KanteStyle.unit(4)
        anchors.verticalCenter: track.verticalCenter
        color: meter.clipped ? KanteStyle.negativeTextColor : "transparent"
        border.width: meter.clipped ? 0 : 1
        border.color: KanteStyle.frameColor
        Row {
            anchors.centerIn: parent
            spacing: KanteStyle.unit(4)
            KanteNoteMark {
                visible: meter.clipped
                anchors.verticalCenter: parent.verticalCenter
                width: KanteStyle.unit(12)
                height: width
                noteState: "wrong"
                color: KanteStyle.onStateColor
            }
            Text {
                text: meter.clipText
                color: meter.clipped ? KanteStyle.onStateColor : KanteStyle.disabledTextColor
                font: KanteStyle.labelFont()
            }
        }
    }

    // Zone labels under the track; the zone of the peak bold and underlined.
    Item {
        id: zones
        y: track.y + track.height + KanteStyle.unit(6)
        width: meter.trackWidth
        height: zoneMetrics.height + KanteStyle.unit(4)
        TextMetrics { id: zoneMetrics; font: KanteStyle.labelFont(); text: "Ag" }
        Repeater {
            model: [
                { key: "quiet", from: -meter.rangeDb, to: meter.quietDb, text: meter.quietText },
                { key: "good", from: meter.quietDb, to: meter.loudDb, text: meter.goodText },
                { key: "loud", from: meter.loudDb, to: 0, text: meter.loudText }
            ]
            delegate: Item {
                required property var modelData
                readonly property bool on: meter.zone === modelData.key || (meter.zone === "clip" && modelData.key === "loud")
                x: meter.xOf(modelData.from)
                width: meter.xOf(modelData.to) - x
                height: zones.height
                Text {
                    id: zl
                    // Centred on the zone, kept inside the track (the loud zone is narrow).
                    x: Math.max(-parent.x, Math.min(meter.trackWidth - parent.x - width, (parent.width - width) / 2))
                    text: parent.modelData.text
                    color: parent.on ? KanteStyle.strongTextColor : KanteStyle.mutedTextColor
                    font.family: zoneMetrics.font.family
                    font.pointSize: zoneMetrics.font.pointSize
                    font.capitalization: zoneMetrics.font.capitalization
                    font.letterSpacing: zoneMetrics.font.letterSpacing
                    font.bold: parent.on
                }
                Rectangle {
                    visible: parent.on
                    x: zl.x
                    y: zl.height + 1
                    width: zl.width
                    height: 2
                    color: KanteStyle.textColor
                }
            }
        }
    }
}
