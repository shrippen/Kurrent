import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kirigamiaddons.dateandtime as KDateTime
import "../datetime.js" as DateTime
import ".."

RowLayout {
    id: root

    /** "date" or "time" */
    property string mode: "date"
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias enabled: field.enabled
    property Item popupParent: null

    signal textEdited()

    spacing: Design.spaceSmall

    readonly property var tokens: mode === "time" ? DateTime.timeTokens() : DateTime.dateTokens()
    readonly property int maxDigits: DateTime.maxDigitsFor(tokens)

    property bool _internalChange: false
    property int _pendingSelectStart: -1
    property int _pendingSelectEnd: -1

    function setDate(dt) {
        _internalChange = true
        field.text = DateTime.formatDate(dt)
        _internalChange = false
        root.textEdited()
    }

    function clear() {
        _internalChange = true
        field.text = ""
        _internalChange = false
        root.textEdited()
    }

    function _applyDigitMask(rawDigits) {
        var digits = DateTime.digitsOnly(rawDigits).substring(0, maxDigits)
        if (mode === "time") {
            return DateTime.formatTimeDigits(digits)
        }
        return DateTime.formatDateDigits(digits)
    }

    function _selectSegmentAt(pos) {
        var seg = DateTime.segmentAtPosition(field.text, tokens, pos)
        if (!seg) {
            return
        }
        // Defer selection until after mouse handling settles.
        _pendingSelectStart = seg.start
        _pendingSelectEnd = Math.max(seg.end, seg.start)
        Qt.callLater(function() {
            if (_pendingSelectStart < 0) {
                return
            }
            field.select(_pendingSelectStart, _pendingSelectEnd)
            _pendingSelectStart = -1
            _pendingSelectEnd = -1
        })
    }

    QQC2.TextField {
        id: field
        Layout.fillWidth: true
        placeholderText: root.mode === "time" ? DateTime.timePlaceholder() : DateTime.datePlaceholder()
        inputMethodHints: Qt.ImhDigitsOnly

        onTextChanged: {
            if (root._internalChange) {
                return
            }
            var cursor = cursorPosition
            var old = text
            var formatted = root._applyDigitMask(old)
            if (formatted !== old) {
                root._internalChange = true
                text = formatted
                // Keep cursor near end of typed content
                cursorPosition = Math.min(formatted.length, Math.max(0, cursor + (formatted.length - old.length)))
                root._internalChange = false
            }
            root.textEdited()
        }

        // Click on a segment selects that year/month/day/hour/minute.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            cursorShape: Qt.IBeamCursor
            onClicked: function(mouse) {
                var pos = field.positionAt(mouse.x, mouse.y)
                mouse.accepted = false
                Qt.callLater(function() {
                    root._selectSegmentAt(pos)
                })
            }
        }

        Keys.onPressed: function(event) {
            // When a segment is selected, digit input replaces that segment.
            if (event.text && /\d/.test(event.text) && field.selectionStart !== field.selectionEnd) {
                var start = field.selectionStart
                var end = field.selectionEnd
                var before = field.text.substring(0, start)
                var after = field.text.substring(end)
                var digits = DateTime.digitsOnly(before + event.text + after).substring(0, root.maxDigits)
                var formatted = root._applyDigitMask(digits)
                root._internalChange = true
                field.text = formatted
                root._internalChange = false

                // Move to next segment if current one is complete.
                var seg = DateTime.segmentAtPosition(formatted, root.tokens, start)
                var segments = DateTime.computeSegments(formatted, root.tokens)
                var idx = -1
                for (var i = 0; i < segments.length; ++i) {
                    if (segments[i].kind === (seg ? seg.kind : "")) {
                        idx = i
                        break
                    }
                }
                if (idx >= 0 && segments[idx].end - segments[idx].start >= segments[idx].maxLen && idx + 1 < segments.length) {
                    field.select(segments[idx + 1].start, segments[idx + 1].end)
                } else if (idx >= 0) {
                    field.cursorPosition = segments[idx].end
                } else {
                    field.cursorPosition = formatted.length
                }
                root.textEdited()
                event.accepted = true
            }
        }
    }

    QQC2.ToolButton {
        id: pickerButton
        visible: root.mode === "date"
        enabled: root.enabled
        icon.name: "view-calendar"
        onClicked: {
            var current = DateTime.parseDate(field.text)
            datePopup.value = current && current.isValid === true ? current : new Date()
            datePopup.open()
        }
        QQC2.ToolTip.text: i18n("Pick date")
        QQC2.ToolTip.visible: hovered
    }

    KDateTime.DatePopup {
        id: datePopup
        parent: root.popupParent ? root.popupParent : root
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        width: Math.min(Kirigami.Units.gridUnit * 20, (root.popupParent ? root.popupParent.width : 400) - 2 * Kirigami.Units.gridUnit)
        height: Kirigami.Units.gridUnit * 20
        modal: true
        popupType: QQC2.Popup.Item
        onAccepted: root.setDate(value)
    }
}
