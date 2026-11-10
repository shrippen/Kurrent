import QtQuick
import "."

/**
 * A live value (a figure, a status word). When `text` changes a cyan strip lights
 * up behind it and fades, and whole numbers count up to the new one, so a change
 * is seen without blinking. Without motion the text just changes.
 */
Item {
    id: live

    property string text: ""
    property font font: KanteStyle.monoFont(KanteStyle.defaultFont.pointSize * 1.2, true)
    property color color: KanteStyle.strongTextColor
    property int horizontalAlignment: Text.AlignLeft
    readonly property string shown: label.text

    implicitWidth: label.implicitWidth + KanteStyle.unit(12)
    implicitHeight: label.implicitHeight + KanteStyle.unit(4)

    property string _from: ""
    property bool _ready: false

    function _isInteger(s) {
        return /^\D*\d[\d\s .,]*\D*$/.test(s) && !/[.,]\d{1,2}(\D|$)/.test(s)
    }
    function _format(v, like) {
        var sep = (/\d([\s .,])\d/.exec(like) || [])[1] || ""
        var pre = /^\D*/.exec(like)[0]
        var post = /\D*$/.exec(like)[0]
        return pre + String(v).replace(/\B(?=(\d{3})+(?!\d))/g, sep) + post
    }

    property real _v: 0
    property real _target: 0

    onTextChanged: {
        if (!_ready) {
            label.text = text
            _from = text
            return
        }
        if (KanteStyle.animate) {
            flash.restart()
        }
        if (KanteStyle.animate && _isInteger(_from) && _isInteger(text)) {
            _v = parseInt(_from.replace(/\D/g, ""), 10)
            _target = parseInt(text.replace(/\D/g, ""), 10)
            count.restart()
        } else {
            label.text = text
        }
        _from = text
    }
    Component.onCompleted: {
        label.text = text
        _from = text
        _ready = true
    }

    NumberAnimation {
        id: count
        target: live
        property: "_v"
        to: live._target
        duration: 630
        easing.type: Easing.OutCubic
        onFinished: label.text = live.text
    }
    on_VChanged: if (count.running) label.text = _format(Math.round(_v), live.text)

    // The strip: cyan ground with a 3 px bar on the left, fading out.
    Rectangle {
        id: strip
        anchors.fill: parent
        color: KanteStyle.selectionColor
        opacity: 0
        Rectangle { width: 3; height: parent.height; color: KanteStyle.focusColor }
    }
    NumberAnimation { id: flash; target: strip; property: "opacity"; from: 1; to: 0; duration: 1100; easing.type: Easing.OutCubic }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: KanteStyle.unit(6)
        width: parent.width - KanteStyle.unit(12)
        horizontalAlignment: live.horizontalAlignment
        font: live.font
        color: live.color
        elide: Text.ElideRight
    }
}
