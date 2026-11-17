import QtQuick
import QtQuick.Controls as QQC2
import "."

/**
 * Tracks over time (Kante 1.81, for Klappe): a ruler with second ticks, one row per track,
 * segments as bars, markers as diamonds and a playhead over all rows. Presentational: the app
 * owns `position` and `tracks` and answers the signals.
 *
 *   duration    length of the time axis in seconds
 *   position    the playhead in seconds
 *   tracks      [{ name, label, shown, segments: [{ from, to, text, selected }],
 *               markers: [{ at, text }] }]; seconds. label: a colour name of
 *               KanteStyle.labels, or "text", "muted", "accent", "focus", "warning",
 *               "ground" (the app's background: a sign on a filled bar reads in every label
 *               colour); "" or an unknown name gives the text colour. shown false: the row is dimmed
 *   trackHeight height of a row, labelWidth width of the name column (KanteStyle units)
 *   hideText, showText   the app's words for the toggle: "<hideText>: <name>" while shown,
 *               "<showText>: <name>" while hidden (tooltip and name for screen readers)
 *   seek(seconds)               click or drag on the ruler or a row; Left / Right move one
 *                               second, Home / End go to the start or end (the item takes Tab)
 *   toggleShown(track)          the eye button of a row
 *   segmentClicked(track, segment)
 *
 * Dragging (opt-in, `draggable: true`): a marker moves in time, so does the start or end of a
 * segment. A press that does not move more than `dragStart` stays a click (seek, and
 * `segmentClicked` on a segment); only a longer move drags. While dragging a line with its
 * time follows the pointer and the pointer is a horizontal resize arrow over what can be
 * grabbed. Kante does not snap: the app answers in the signal and may overwrite `dragSeconds`
 * there to show a snapped time. Nothing moves on its own: the app changes `tracks` on `done`.
 *
 *   draggable   false: nothing can be grabbed
 *   formatTime  function(seconds) -> text for the drag line; null: "m:ss.d"
 *   dragSeconds the time of the drag line; dragging says whether one is held
 *   markDragged(track, marker, seconds, done, shift)
 *   edgeDragged(track, segment, edge, seconds, done, shift)
 *               edge is "from" or "to"; done is false while the button is down and true on
 *               release (with the last shown `dragSeconds`); shift: Shift is held
 *   Per track, marker or segment `locked: true` takes it out of the dragging (a hidden row
 *   is never dragged); a locked one still seeks and selects.
 *
 * Information never by colour alone: a segment carries its text, a selected one is framed
 * wider and in bold, a marker is a diamond with its text as a tooltip, a hidden row shows
 * the crossed eye.
 *
 * Functions for the app and its tests: timeAt(x), xAt(seconds) (in the item's coordinates),
 * segmentAt(x, y) and markerAt(x, y), each {track, index} or null; grabAt(x, y), what a
 * press there would drag, or null.
 */
FocusScope {
    id: root

    property real duration: 10
    property real position: 0
    property var tracks: []
    property real trackHeight: KanteStyle.unit(34)
    property real labelWidth: KanteStyle.unit(150)
    property string hideText: "Hide"
    property string showText: "Show"
    /** Name for screen readers. */
    property string accessibleName: "Timeline"

    signal seek(real seconds)
    signal toggleShown(int track)
    signal segmentClicked(int track, int segment)
    signal markDragged(int track, int marker, real seconds, bool done, bool shift)
    signal edgeDragged(int track, int segment, string edge, real seconds, bool done, bool shift)

    property bool draggable: false
    property var formatTime: null
    property real dragSeconds: 0
    readonly property bool dragging: _grab !== null
    // The held thing while dragging: { track, index, edge ("" for a marker), seconds }.
    property var _grab: null

    /// Shortest move (px) that turns a press into a drag, and the reach (px) of an edge.
    readonly property real dragStart: KanteStyle.unit(4)
    readonly property real edgeReach: KanteStyle.unit(5)
    readonly property string edgeFrom: "from"
    readonly property string edgeTo: "to"
    readonly property int tenthsPerSecond: KanteStyle.tenthsPerSecond
    readonly property int tenthsPerMinute: 60 * tenthsPerSecond

    readonly property real rulerHeight: KanteStyle.unit(24)
    readonly property real laneWidth: Math.max(1, width - labelWidth)
    readonly property real pixelsPerSecond: laneWidth / Math.max(0.001, duration)
    // The ruler's step in seconds: the smallest of these that leaves a label its room.
    readonly property var steps: [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800, 3600]
    readonly property real tickStep: {
        const room = KanteStyle.unit(56)
        for (const s of steps) {
            if (s * pixelsPerSecond >= room) {
                return s
            }
        }
        return steps[steps.length - 1]
    }
    readonly property int tickCount: Math.floor(Math.max(0, duration) / tickStep) + 1
    readonly property real markerSize: KanteStyle.unit(12)
    property var hovered: null
    onTracksChanged: hovered = null

    implicitWidth: KanteStyle.unit(640)
    implicitHeight: rulerHeight + tracks.length * trackHeight
    activeFocusOnTab: true
    clip: true

    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName
    Accessible.description: Math.round(position) + " / " + Math.round(duration) + " s"

    function _clampTime(t) {
        return Math.max(0, Math.min(duration, t))
    }

    /** Seconds at an x of this item. */
    function timeAt(x) {
        return _clampTime((x - labelWidth) / pixelsPerSecond)
    }

    /** The x of this item at `seconds`. */
    function xAt(seconds) {
        return labelWidth + seconds * pixelsPerSecond
    }

    function _trackAt(y) {
        const row = Math.floor((y - rulerHeight) / trackHeight)
        return row >= 0 && row < tracks.length ? row : -1
    }

    /** The segment under a point of this item: {track, index}, or null. */
    function segmentAt(x, y) {
        const t = _trackAt(y)
        if (t < 0) {
            return null
        }

        const secs = (x - labelWidth) / pixelsPerSecond
        const segs = tracks[t].segments || []
        // Topmost (last drawn) first.
        for (let i = segs.length - 1; i >= 0; i--) {
            if (secs >= segs[i].from && secs <= segs[i].to) {
                return { track: t, index: i }
            }
        }
        return null
    }

    /** The marker under a point of this item: {track, index}, or null. */
    function markerAt(x, y) {
        const t = _trackAt(y)
        if (t < 0) {
            return null
        }

        const marks = tracks[t].markers || []
        const reach = markerSize / 2
        for (let i = marks.length - 1; i >= 0; i--) {
            if (Math.abs(xAt(marks[i].at) - x) <= reach) {
                return { track: t, index: i }
            }
        }
        return null
    }

    /** What a press at (x, y) of this item would hold: {track, index, edge, seconds}, or null. */
    function grabAt(x, y) {
        const t = _trackAt(y)
        if (!draggable || t < 0 || tracks[t].shown === false || tracks[t].locked === true) {
            return null
        }

        const mark = markerAt(x, y)
        const marker = mark ? tracks[t].markers[mark.index] : null
        if (marker && marker.locked !== true) {
            return { track: t, index: mark.index, edge: "", seconds: marker.at }
        }
        return _edgeAt(t, x)
    }

    // The edge of an unlocked segment of row t nearest to x, within edgeReach; on a tie (two
    // segments touch) the edge of the segment x is in.
    function _edgeAt(t, x) {
        let found = null
        let nearest = edgeReach
        const segs = tracks[t].segments || []
        for (let i = 0; i < segs.length; i++) {
            if (segs[i].locked === true) {
                continue
            }

            const inside = x >= xAt(segs[i].from) && x <= xAt(segs[i].to)
            const edges = [[edgeFrom, segs[i].from], [edgeTo, segs[i].to]]
            for (const [edge, seconds] of edges) {
                const distance = Math.abs(xAt(seconds) - x)
                if (distance < nearest || (distance === nearest && (found === null || inside))) {
                    nearest = distance
                    found = { track: t, index: i, edge: edge, seconds: seconds }
                }
            }
        }
        return found
    }

    function _emitDrag(done, shift) {
        const g = _grab
        if (g.edge === "") {
            markDragged(g.track, g.index, dragSeconds, done, shift)
            return
        }
        edgeDragged(g.track, g.index, g.edge, dragSeconds, done, shift)
    }

    // "m:ss.d", cut off like a timecode (59.96 -> 0:59.9).
    function _stamp(s) {
        const tenths = KanteStyle.wholeTenths(s)
        const sec = (tenths % tenthsPerMinute) / tenthsPerSecond
        return Math.floor(tenths / tenthsPerMinute) + ":" + (sec < 10 ? "0" : "") + sec.toFixed(1)
    }

    function _clock(s) {
        const m = Math.floor(s / 60)
        const r = s % 60
        return m > 0 ? m + ":" + (r < 10 ? "0" : "") + r : String(r)
    }

    Keys.onLeftPressed: root.seek(_clampTime(position - 1))
    Keys.onRightPressed: root.seek(_clampTime(position + 1))
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Home) {
            root.seek(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            root.seek(duration)
            event.accepted = true
        }
    }

    // Ruler: a tick and a label per step.
    Item {
        id: ruler
        x: root.labelWidth
        width: root.laneWidth
        height: root.rulerHeight

        Repeater {
            model: root.tickCount
            delegate: Item {
                required property int index
                readonly property real secs: index * root.tickStep
                x: secs * root.pixelsPerSecond
                height: ruler.height

                Rectangle {
                    y: parent.height - height
                    width: 1
                    height: KanteStyle.unit(6)
                    color: KanteStyle.mutedTextColor
                }
                QQC2.Label {
                    x: KanteStyle.unit(3)
                    width: Math.max(0, root.tickStep * root.pixelsPerSecond - KanteStyle.unit(3))
                    text: root._clock(parent.secs)
                    font: KanteStyle.smallFont
                    color: KanteStyle.mutedTextColor
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        y: root.rulerHeight - 1
        width: root.width
        height: 1
        color: KanteStyle.ruleColor
    }

    // Rows.
    Repeater {
        model: root.tracks
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool shown: modelData.shown !== false

            y: root.rulerHeight + index * root.trackHeight
            width: root.width
            height: root.trackHeight

            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: KanteStyle.ruleColor
            }

            Row {
                x: KanteStyle.unit(4)
                width: root.labelWidth - KanteStyle.unit(8)
                height: parent.height
                spacing: KanteStyle.unit(4)

                KanteToolButton {
                    id: toggle
                    objectName: "toggle" + row.index
                    anchors.verticalCenter: parent.verticalCenter
                    icon.name: row.shown ? "view-visible" : "view-hidden"
                    display: KanteToolButton.IconOnly
                    focusPolicy: Qt.TabFocus
                    text: (row.shown ? root.hideText : root.showText) + ": " + row.modelData.name
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: text
                    Accessible.name: text
                    onClicked: root.toggleShown(row.index)
                }
                QQC2.Label {
                    width: parent.width - toggle.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    font: KanteStyle.smallFont
                    color: KanteStyle.textColor
                    opacity: row.shown ? 1 : 0.4
                    elide: Text.ElideRight
                }
            }

            // Lane content, dimmed as a whole when hidden.
            Item {
                x: root.labelWidth
                width: root.laneWidth
                height: parent.height
                opacity: row.shown ? 1 : 0.35
                clip: true

                Repeater {
                    model: row.modelData.segments || []
                    delegate: Rectangle {
                        id: seg
                        required property var modelData
                        readonly property color fill: KanteStyle.namedColor(row.modelData.label)
                        readonly property bool picked: modelData.selected === true

                        x: modelData.from * root.pixelsPerSecond
                        y: KanteStyle.unit(4)
                        width: Math.max(1, (modelData.to - modelData.from) * root.pixelsPerSecond)
                        height: row.height - KanteStyle.unit(8)
                        color: fill
                        border.width: picked ? KanteStyle.unit(3) : 0
                        border.color: KanteStyle.focusColor

                        QQC2.Label {
                            anchors.fill: parent
                            anchors.leftMargin: KanteStyle.unit(5)
                            anchors.rightMargin: KanteStyle.unit(3)
                            verticalAlignment: Text.AlignVCenter
                            text: seg.modelData.text || ""
                            font.family: KanteStyle.smallFont.family
                            font.pixelSize: KanteStyle.fontPixels(KanteStyle.smallFont)
                            font.bold: seg.picked
                            color: KanteStyle.inkOn(seg.fill)
                            elide: Text.ElideRight
                        }
                    }
                }

                Repeater {
                    model: row.modelData.markers || []
                    delegate: Rectangle {
                        id: mark
                        required property var modelData
                        // A diamond: a square turned by 45 degrees, its diagonal as wide as markerSize.
                        readonly property real side: root.markerSize / Math.SQRT2

                        x: modelData.at * root.pixelsPerSecond - width / 2
                        y: (row.height - height) / 2
                        width: side
                        height: side
                        rotation: 45
                        color: KanteStyle.backgroundColor
                        border.width: KanteStyle.unit(2)
                        border.color: KanteStyle.namedColor(row.modelData.label)
                    }
                }
            }
        }
    }

    // Playhead over ruler and rows.
    Rectangle {
        x: root.xAt(root._clampTime(root.position)) - width / 2
        width: KanteStyle.unit(2)
        height: root.height
        color: KanteStyle.focusColor
        visible: root.width > root.labelWidth
    }

    MouseArea {
        id: area
        x: root.labelWidth
        width: root.laneWidth
        height: root.height
        hoverEnabled: true
        cursorShape: root.dragging || overGrab ? Qt.SizeHorCursor : Qt.ArrowCursor

        // What the press holds, where it was (px) and whether it became a drag.
        property var held: null
        property real pressX: 0
        property bool dragged: false
        property bool onGrab: false
        property bool overGrab: false

        function _seekTo(mx) {
            root.forceActiveFocus()
            root.seek(root.timeAt(mx + root.labelWidth))
        }

        function _shift(mouse) {
            return (mouse.modifiers & Qt.ShiftModifier) !== 0
        }

        onPressed: function (mouse) {
            dragged = false
            pressX = mouse.x
            held = root.grabAt(mouse.x + root.labelWidth, mouse.y)
            onGrab = held !== null
            if (held) {
                root.forceActiveFocus()
                return
            }
            _seekTo(mouse.x)
        }
        onPositionChanged: function (mouse) {
            if (!pressed) {
                root.hovered = root.markerAt(mouse.x + root.labelWidth, mouse.y)
                overGrab = root.grabAt(mouse.x + root.labelWidth, mouse.y) !== null
                return
            }
            if (!held) {
                _seekTo(mouse.x)
                return
            }
            if (!root.dragging && Math.abs(mouse.x - pressX) < root.dragStart) {
                return
            }

            root._grab = held
            dragged = true
            root.dragSeconds = root.timeAt(mouse.x + root.labelWidth)
            root._emitDrag(false, _shift(mouse))
        }
        onReleased: function (mouse) {
            if (root.dragging) {
                root._emitDrag(true, _shift(mouse))
                root._grab = null
            }
            held = null
            overGrab = root.grabAt(mouse.x + root.labelWidth, mouse.y) !== null
        }
        onCanceled: {
            root._grab = null
            held = null
        }
        onExited: {
            root.hovered = null
            overGrab = false
        }
        onClicked: function (mouse) {
            if (dragged) {
                return
            }

            // A press on a grabbable thing did not seek yet.
            if (onGrab) {
                _seekTo(mouse.x)
            }
            const hit = root.segmentAt(mouse.x + root.labelWidth, mouse.y)
            if (hit) {
                root.segmentClicked(hit.track, hit.index)
            }
        }

        QQC2.ToolTip {
            visible: root.hovered !== null && area.containsMouse && !root.dragging
            text: {
                const track = root.hovered ? root.tracks[root.hovered.track] : null
                const mark = track && track.markers ? track.markers[root.hovered.index] : null
                return mark && mark.text ? mark.text : ""
            }
        }
    }

    // Where the drag lands, with its time.
    Rectangle {
        id: dragLine
        objectName: "dragLine"
        visible: root.dragging
        x: root.xAt(root.dragSeconds) - width / 2
        width: KanteStyle.lineWidth
        height: root.height
        color: KanteStyle.accentColor

        Rectangle {
            objectName: "dragTime"
            readonly property real gap: KanteStyle.unit(4)
            // Left of the line when there is no room on its right.
            x: dragLine.x + dragLine.width + gap + width > root.width ? -width - gap : dragLine.width + gap
            y: root.rulerHeight
            width: stamp.implicitWidth + 2 * gap
            height: stamp.implicitHeight + gap
            color: KanteStyle.backgroundColor
            border.width: KanteStyle.borderWidth
            border.color: KanteStyle.accentColor

            QQC2.Label {
                id: stamp
                objectName: "dragText"
                anchors.centerIn: parent
                text: root.formatTime ? root.formatTime(root.dragSeconds) : root._stamp(root.dragSeconds)
                font: KanteStyle.smallFont
                color: KanteStyle.textColor
            }
        }
    }

    // Focus frame.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.activeFocus ? KanteStyle.unit(2) : 0
        border.color: KanteStyle.focusColor
    }
}
