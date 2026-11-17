import QtQuick
import "."

/**
 * A pannable, zoomable vector view (Kante 1.81, for Klappe): plans drawn from data, such as a
 * floor plan in metres. Presentational: the app owns `shapes` and answers the signals.
 *
 *   contentWidth, contentHeight   size of the plan in model units (x right, y down)
 *   gridStep                      grid in model units, 0 = none; left out while the lines would
 *                                 be closer than a few pixels
 *   shapes     [{ kind, points, radius, width, label, stroke, fill, text, key, selected, opacity }]
 *     kind     "line" (2 points), "polyline", "polygon" (closed), "circle" (points [cx, cy], radius)
 *     points   [x0, y0, x1, y1, …] in model units
 *     width    stroke width in model units, 0 = hairline (always at least one pixel)
 *     label    a colour of KanteStyle.labels, or "text", "muted", "accent", "focus", "warning",
 *              "ground" (the app's background: a sign on a filled shape, such as a dot in a
 *              filled circle, reads in every label colour)
 *     stroke   "solid" (default), "dashed", "dotted": a dash is a mark, not only a colour
 *     fill     "none" (default), "solid", "tint" (the colour at a fifth of its strength)
 *     text     small caption beside the shape, always at the same size on screen. A "\n" starts
 *              a new line (spaced 1.25 font sizes); the canvas does not wrap, the app does.
 *     captionSize  font size of the caption in model units: the caption then scales with the
 *              zoom, like the shape, and is left out below 4 px. Default: the small font, fixed.
 *     textAnchor  "center" (default) or "topLeft": a polygon's caption starts at its top left
 *              corner, with a small margin, instead of at its centre
 *     opacity  0..1 (default 1): fades fill, stroke, selection frame and caption; not the hit test
 *     key      id given back by the signals; selected: framed wider in the focus colour
 *     Drawn in order, so the last shape is on top (and wins the hit test).
 *   Image     { kind: "image", source, points: [x, y], width, height, rotation, opacity, key }
 *             a background such as a scanned plan. source is an absolute url or path:
 *             loadImage resolves a relative one against Kante, so pass Qt.resolvedUrl(...);
 *             points is the top left corner and width, height the size, both in model units;
 *             rotation in degrees, clockwise, about the top left corner; opacity 0..1 (default 1).
 *             Drawn in order like any shape. Loaded on first use and the view repaints when it
 *             arrives; a missing image draws nothing and is no error. It is background: the hit
 *             test never finds it (keyAt gives "" over it, shapeClicked and shapeDragged report
 *             what lies beneath, or empty ground), and it takes no label, fill, stroke or text.
 *   zoom       pixels per model unit; writing it zooms about the middle of the view
 *   fitOnLoad  fit() when the view gets its size, until the view is panned or zoomed
 *   fit()      the whole plan in view, centred
 *   mapToModel(px, py), mapFromModel(x, y)    {x, y} between view pixels and model units
 *   keyAt(px, py)             key of the topmost shape under a pixel, "" for none
 *   shapeClicked(key, x, y)   click without drag; key "" on empty ground; x, y in model units
 *   shapeDoubleClicked(key, x, y)   double click, as shapeClicked (a click comes first)
 *   shapeHovered(key, x, y)   the pointer moved; key "" when it is over nothing
 *   editing    the left button edits instead of panning: a drag on a shape or on empty ground
 *              reports shapeDragged; pan stays on the middle button and with space held
 *   shapeDragged(key, fromX, fromY, x, y, done)   in editing, a left drag: key of the shape
 *              it began on ("" on empty ground), where it began and where it is now (model
 *              units); done on release. The app moves or draws; the canvas changes nothing.
 *
 * Hit test: inside a polygon or circle that has a fill, or within a few pixels of an outline,
 * line or polyline (an unfilled polygon is only hit at its edge, so a room does not hide what
 * lies in it). Pan: middle button, space held, or left button on empty ground. Zoom: wheel or
 * pinch about the pointer. Keyboard (the item takes Tab): plus and minus zoom, 0 fits, arrows pan.
 *
 * Drawn with one Canvas, repainted when a property changes; 600 shapes with 272 captions take about
 * 15 ms to draw (offscreen), about 6 ms zoomed in, as shapes and captions out of view are left out.
 * Captions are the dear part (fillText, about 45 µs each): keep the text for what needs it.
 */
FocusScope {
    id: root

    property real contentWidth: 100
    property real contentHeight: 100
    property real gridStep: 0
    property var shapes: []
    property real zoom: 1
    property bool fitOnLoad: true
    /** Name for screen readers. */
    property string accessibleName: "Plan"

    signal shapeClicked(string key, real x, real y)
    signal shapeDoubleClicked(string key, real x, real y)
    signal shapeHovered(string key, real x, real y)
    signal shapeDragged(string key, real fromX, real fromY, real x, real y, bool done)

    property bool editing: false

    // Where the model origin lies in the view.
    property real panX: 0
    property real panY: 0

    readonly property real _minZoom: 0.001
    readonly property real _maxZoom: 100000
    readonly property real _wheelStep: 1.0015
    readonly property real _keyZoom: 1.25
    readonly property real _dragSlop: KanteStyle.unit(4)
    readonly property real _reach: KanteStyle.unit(6)
    readonly property real _margin: KanteStyle.unit(24)
    // Distance between caption lines, in font sizes.
    readonly property real _lineSpacing: 1.25
    // A caption sized in model units is not drawn below this many pixels (unreadable).
    readonly property real _minCaptionPx: 4
    // The margin of a caption sized in model units, in its font sizes.
    readonly property real _captionGapEm: 0.3
    readonly property real _minGridGap: KanteStyle.unit(6)
    readonly property real _tintAlpha: 0.2
    readonly property real _gridAlpha: 0.3

    // fit() while no one has moved the view: a layout settles the size after the first one.
    property bool _touched: false
    property bool _fitting: false
    property bool _ready: false
    property real _lastZoom: zoom
    property real _anchorX: width / 2
    property bool _anchored: false
    property real _anchorY: height / 2
    property bool _spaceDown: false
    property string _hoverKey: ""

    implicitWidth: KanteStyle.unit(480)
    implicitHeight: KanteStyle.unit(360)
    activeFocusOnTab: true
    clip: true

    Accessible.role: Accessible.Graphic
    Accessible.name: accessibleName

    /** View pixels to model units. */
    function mapToModel(px, py) {
        return { x: (px - panX) / zoom, y: (py - panY) / zoom }
    }

    /** Model units to view pixels. */
    function mapFromModel(x, y) {
        return { x: panX + x * zoom, y: panY + y * zoom }
    }

    /** The whole plan in view, centred. */
    function fit() {
        if (width <= 0 || height <= 0 || contentWidth <= 0 || contentHeight <= 0) {
            return
        }

        const room = Math.max(1, Math.min(_margin, width / 4, height / 4))
        const z = Math.min((width - 2 * room) / contentWidth, (height - 2 * room) / contentHeight)
        _fitting = true
        _lastZoom = z
        zoom = z
        panX = (width - contentWidth * z) / 2
        panY = (height - contentHeight * z) / 2
        _fitting = false
        _touched = false
        canvas.requestPaint()
    }

    // Zooms by `factor`, the model point under (px, py) stays under it.
    function _zoomAt(px, py, factor) {
        _anchorX = px
        _anchorY = py
        _anchored = true
        zoom = Math.max(_minZoom, Math.min(_maxZoom, zoom * factor))
        _anchored = false
    }

    // Any change of `zoom`, also an app's own: about the anchor, else about the middle.
    onZoomChanged: {
        if (_ready && !_fitting) {
            _touched = true
        }
        if (_lastZoom > 0 && zoom !== _lastZoom) {
            const ax = _anchored ? _anchorX : width / 2
            const ay = _anchored ? _anchorY : height / 2
            const k = zoom / _lastZoom
            panX = ax - (ax - panX) * k
            panY = ay - (ay - panY) * k
        }
        _lastZoom = zoom
        canvas.requestPaint()
    }

    // Space held while the focus leaves never sends its release.
    onActiveFocusChanged: {
        if (!activeFocus) {
            _spaceDown = false
        }
    }

    onPanXChanged: canvas.requestPaint()
    onPanYChanged: canvas.requestPaint()
    onShapesChanged: canvas.requestPaint()
    onGridStepChanged: canvas.requestPaint()
    onContentWidthChanged: canvas.requestPaint()
    onContentHeightChanged: canvas.requestPaint()
    onWidthChanged: _maybeFit()
    onHeightChanged: _maybeFit()
    Component.onCompleted: {
        _ready = true
        _maybeFit()
    }

    // A drag or a key moved the view.
    function _pan(dx, dy) {
        _touched = true
        panX += dx
        panY += dy
    }

    function _maybeFit() {
        if (fitOnLoad && !_touched) {
            fit()
        }
        canvas.requestPaint()
    }

    // Distance from (px, py) to the segment (ax, ay)-(bx, by).
    function _segDist(px, py, ax, ay, bx, by) {
        const dx = bx - ax
        const dy = by - ay
        const len2 = dx * dx + dy * dy
        const t = len2 > 0 ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) : 0
        return Math.hypot(px - (ax + t * dx), py - (ay + t * dy))
    }

    // Distance to the outline of a point list, closed or not.
    function _outlineDist(pts, mx, my, closed) {
        const n = Math.floor(pts.length / 2)
        let best = Infinity
        for (let i = 0; i + 1 < n; i++) {
            best = Math.min(best, _segDist(mx, my, pts[2 * i], pts[2 * i + 1], pts[2 * i + 2], pts[2 * i + 3]))
        }
        if (closed && n > 2) {
            best = Math.min(best, _segDist(mx, my, pts[2 * n - 2], pts[2 * n - 1], pts[0], pts[1]))
        }
        return best
    }

    // Even-odd test: is the model point inside the polygon.
    function _inPolygon(pts, mx, my) {
        const n = Math.floor(pts.length / 2)
        let inside = false
        for (let i = 0, j = n - 1; i < n; j = i++) {
            const xi = pts[2 * i]
            const yi = pts[2 * i + 1]
            const xj = pts[2 * j]
            const yj = pts[2 * j + 1]
            if ((yi > my) !== (yj > my) && mx < (xj - xi) * (my - yi) / (yj - yi) + xi) {
                inside = !inside
            }
        }
        return inside
    }

    // Is the model point (mx, my) on shape s; `reach` is the hit distance in model units.
    function _hits(s, mx, my, reach) {
        const pts = s.points || []
        const filled = s.fill === "solid" || s.fill === "tint"
        const half = (s.width || 0) / 2
        switch (s.kind) {
        case "image":
            // Background: never hit.
            return false
        case "circle":
            if (pts.length < 2) {
                return false
            }

            const d = Math.hypot(mx - pts[0], my - pts[1])
            const r = s.radius || 0
            return filled ? d <= r + reach : Math.abs(d - r) <= reach + half
        case "polygon":
            if (filled && _inPolygon(pts, mx, my)) {
                return true
            }
            return _outlineDist(pts, mx, my, true) <= reach + half
        case "line":
        case "polyline":
            return _outlineDist(pts, mx, my, false) <= reach + half
        }
        return false
    }

    /** The index of the topmost shape under a pixel, -1 for none. */
    function shapeAt(px, py) {
        const m = mapToModel(px, py)
        const reach = _reach / zoom
        for (let i = shapes.length - 1; i >= 0; i--) {
            if (_hits(shapes[i], m.x, m.y, reach)) {
                return i
            }
        }
        return -1
    }

    /** The key of the topmost shape under a pixel, "" for none. */
    function keyAt(px, py) {
        const i = shapeAt(px, py)
        if (i < 0) {
            return ""
        }

        // A key of 0 is a key.
        const key = shapes[i].key
        return key === undefined || key === null ? "" : String(key)
    }

    Keys.onPressed: function (event) {
        const step = KanteStyle.unit(40)
        event.accepted = true
        switch (event.key) {
        case Qt.Key_Plus:
        case Qt.Key_Equal:
            _zoomAt(width / 2, height / 2, _keyZoom)
            break
        case Qt.Key_Minus:
            _zoomAt(width / 2, height / 2, 1 / _keyZoom)
            break
        case Qt.Key_0:
            fit()
            break
        case Qt.Key_Left:
            _pan(step, 0)
            break
        case Qt.Key_Right:
            _pan(-step, 0)
            break
        case Qt.Key_Up:
            _pan(0, step)
            break
        case Qt.Key_Down:
            _pan(0, -step)
            break
        case Qt.Key_Space:
            _spaceDown = true
            break
        default:
            event.accepted = false
        }
    }
    Keys.onReleased: function (event) {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
            _spaceDown = false
        }
    }

    // The theme and the font repaint the canvas.
    readonly property var _look: [KanteStyle.backgroundColor, KanteStyle.textColor, KanteStyle.mutedTextColor,
        KanteStyle.accentColor, KanteStyle.focusColor, KanteStyle.warningColor, KanteStyle.ruleColor,
        KanteStyle.smallFont]
    on_LookChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        // Image sources already asked for.
        property var _asked: ({})

        // Per paint: colours by label name, and what the context was last given, so each
        // value is worked out once and a context state is set only when it changes.
        property var _colors: ({})
        property var _inks: ({})
        property var _tints: ({})
        property string _dashKey: ""
        property string _fillKey: ""
        property string _align: ""
        property real _fontPx: 0
        property string _fontFamily: ""
        property real _ctxFontPx: 0

        // The colour of a label name, worked out once per paint.
        function _color(name) {
            let c = _colors[name]
            if (c === undefined) {
                c = KanteStyle.namedColor(name)
                _colors[name] = c
            }
            return c
        }

        // The colour of a caption: the label colour, readable on the ground.
        function _ink(name) {
            let c = _inks[name]
            if (c === undefined) {
                c = KanteStyle.readable(_color(name), KanteStyle.backgroundColor)
                _inks[name] = c
            }
            return c
        }

        function _tint(name) {
            let c = _tints[name]
            if (c === undefined) {
                c = Qt.alpha(_color(name), root._tintAlpha)
                _tints[name] = c
            }
            return c
        }

        // Does shape s, stroked `lineW` wide in view pixels, reach into the view.
        function _onScreen(s, lineW) {
            const pts = s.points || []
            let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity
            for (let i = 0; i + 1 < pts.length; i += 2) {
                x0 = Math.min(x0, pts[i])
                x1 = Math.max(x1, pts[i])
                y0 = Math.min(y0, pts[i + 1])
                y1 = Math.max(y1, pts[i + 1])
            }
            const r = s.kind === "circle" ? s.radius || 0 : 0
            const reach = lineW / 2 + KanteStyle.unit(2) + 1
            return root.panX + (x1 + r) * root.zoom + reach >= 0
                && root.panX + (x0 - r) * root.zoom - reach <= width
                && root.panY + (y1 + r) * root.zoom + reach >= 0
                && root.panY + (y0 - r) * root.zoom - reach <= height
        }
        onImageLoaded: requestPaint()

        // Strokes and fills of one shape, in view pixels.
        function _trace(ctx, s) {
            const pts = s.points || []
            if (s.kind === "circle") {
                if (pts.length < 2) {
                    return false
                }

                ctx.beginPath()
                ctx.arc(root.panX + pts[0] * root.zoom, root.panY + pts[1] * root.zoom, (s.radius || 0) * root.zoom, 0, 2 * Math.PI)
                return true
            }
            if (pts.length < 4) {
                return false
            }

            ctx.beginPath()
            for (let i = 0; i + 1 < pts.length; i += 2) {
                const x = root.panX + pts[i] * root.zoom
                const y = root.panY + pts[i + 1] * root.zoom
                if (i === 0) {
                    ctx.moveTo(x, y)
                } else {
                    ctx.lineTo(x, y)
                }
            }
            if (s.kind === "polygon") {
                ctx.closePath()
            }
            return true
        }

        // An image shape: top left corner, size in model units, turned about the corner.
        function _image(ctx, s) {
            const pts = s.points || []
            if (!s.source || pts.length < 2) {
                return
            }

            const src = String(s.source)
            // Asked once; onImageLoaded repaints. An image Qt already holds is ready at once
            // and sends no signal, so look again right after asking.
            if (!isImageLoaded(src) && !_asked[src]) {
                _asked[src] = true
                loadImage(src)
            }
            if (!isImageLoaded(src)) {
                return
            }

            ctx.save()
            ctx.globalAlpha = _alpha(s)
            const a = (s.rotation || 0) * Math.PI / 180
            ctx.transform(Math.cos(a), Math.sin(a), -Math.sin(a), Math.cos(a),
                          root.panX + pts[0] * root.zoom, root.panY + pts[1] * root.zoom)
            ctx.drawImage(src, 0, 0, (s.width || 0) * root.zoom, (s.height || 0) * root.zoom)
            ctx.restore()
        }

        // A shape's opacity, 0..1; 1 when not given.
        function _alpha(s) {
            return Number.isFinite(s.opacity) ? Math.max(0, Math.min(1, s.opacity)) : 1
        }

        function _dash(ctx, stroke) {
            const key = stroke || "solid"
            if (key === _dashKey) {
                return
            }

            _dashKey = key
            switch (stroke) {
            case "dashed":
                ctx.setLineDash([KanteStyle.unit(8), KanteStyle.unit(5)])
                return
            case "dotted":
                ctx.setLineDash([KanteStyle.unit(2), KanteStyle.unit(4)])
                return
            }
            ctx.setLineDash([])
        }

        // The caption's font size in pixels: model units grow with the zoom, else the small font;
        // 0 when too small to read.
        function _captionPx(s) {
            if (!(s.captionSize > 0)) {
                return _fontPx
            }
            const px = s.captionSize * root.zoom
            return px < root._minCaptionPx ? 0 : px
        }

        // Where a caption goes, in view pixels: {x, y, align, top}; `top` lifts the first line.
        function _captionSpot(s, pts, fontPx, gap, rows) {
            const zx = v => root.panX + v * root.zoom
            const zy = v => root.panY + v * root.zoom
            if (s.kind === "circle") {
                return { x: zx(pts[0]) + (s.radius || 0) * root.zoom + gap, y: zy(pts[1]),
                         align: "left", top: -rows / 2 }
            }
            if (s.kind !== "polygon") {
                const n = pts.length
                return { x: zx((pts[0] + pts[n - 2]) / 2) + gap, y: zy((pts[1] + pts[n - 1]) / 2) - gap,
                         align: "left", top: -rows / 2 }
            }
            const xs = pts.filter((v, i) => i % 2 === 0)
            const ys = pts.filter((v, i) => i % 2 === 1)
            // Several lines hang from the top left when the shape asks, else centre on the box.
            if (s.textAnchor === "topLeft") {
                return { x: zx(Math.min(...xs)) + gap, y: zy(Math.min(...ys)) + gap + fontPx / 2,
                         align: "left", top: 0 }
            }
            return { x: zx((Math.min(...xs) + Math.max(...xs)) / 2), y: zy((Math.min(...ys) + Math.max(...ys)) / 2),
                     align: "center", top: -rows / 2 }
        }

        // Draws a shape's caption beside it.
        function _caption(ctx, s) {
            const pts = s.points || []
            const fontPx = _captionPx(s)
            if (pts.length < 2 || fontPx === 0) {
                return
            }

            const gap = s.captionSize > 0 ? fontPx * root._captionGapEm : KanteStyle.unit(4)
            const lines = String(s.text).split("\n")
            const rows = (lines.length - 1) * fontPx * root._lineSpacing
            const spot = _captionSpot(s, pts, fontPx, gap, rows)
            const x = spot.x
            const align = spot.align

            // Outside the view (fillText is the dearest call). Wide glyphs (CJK) take up to about
            // 1.1 em; two em for each character leaves room for them.
            const emsPerChar = 2
            const reach = String(s.text).length * emsPerChar * fontPx
            const yFirst = spot.y + spot.top
            if (x + reach < 0 || x - reach > width || yFirst + rows + fontPx < 0 || yFirst - fontPx > height) {
                return
            }

            if (fontPx !== _ctxFontPx) {
                _ctxFontPx = fontPx
                ctx.font = fontPx + "px \"" + _fontFamily + "\", sans-serif"
            }
            if (align !== _align) {
                _align = align
                ctx.textAlign = align
            }
            const label = String(s.label)
            if (label !== _fillKey) {
                _fillKey = label
                ctx.fillStyle = _ink(s.label)
            }
            for (let i = 0; i < lines.length; i++) {
                ctx.fillText(lines[i], x, yFirst + i * fontPx * root._lineSpacing)
            }
        }

        function _grid(ctx) {
            const step = root.gridStep * root.zoom
            if (root.gridStep <= 0 || step < root._minGridGap) {
                return
            }

            const w = root.contentWidth * root.zoom
            const h = root.contentHeight * root.zoom
            ctx.strokeStyle = Qt.alpha(KanteStyle.ruleColor, root._gridAlpha)
            ctx.lineWidth = 1
            ctx.setLineDash([])
            ctx.beginPath()
            for (let gx = 0; gx <= root.contentWidth + 1e-9; gx += root.gridStep) {
                const x = Math.round(root.panX + gx * root.zoom) + 0.5
                ctx.moveTo(x, root.panY)
                ctx.lineTo(x, root.panY + h)
            }
            for (let gy = 0; gy <= root.contentHeight + 1e-9; gy += root.gridStep) {
                const y = Math.round(root.panY + gy * root.zoom) + 0.5
                ctx.moveTo(root.panX, y)
                ctx.lineTo(root.panX + w, y)
            }
            ctx.stroke()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = KanteStyle.backgroundColor
            ctx.fillRect(0, 0, width, height)

            _grid(ctx)

            // The edge of the plan.
            ctx.strokeStyle = KanteStyle.ruleColor
            ctx.lineWidth = 1
            ctx.setLineDash([])
            ctx.strokeRect(root.panX, root.panY, root.contentWidth * root.zoom, root.contentHeight * root.zoom)

            const font = KanteStyle.smallFont
            _fontPx = KanteStyle.fontPixels(font)
            _fontFamily = font.family
            _ctxFontPx = _fontPx
            ctx.font = _fontPx + "px \"" + font.family + "\", sans-serif"
            ctx.textBaseline = "middle"
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            _colors = ({})
            _inks = ({})
            _tints = ({})
            _dashKey = "solid"

            const frame = KanteStyle.unit(2)
            for (const s of root.shapes) {
                if (s.kind === "image") {
                    _image(ctx, s)
                    continue
                }

                const color = _color(s.label)
                const lineW = Math.max(1, (s.width || 0) * root.zoom)
                if (!_onScreen(s, s.selected === true ? lineW + 2 * frame : lineW) || !_trace(ctx, s)) {
                    continue
                }

                ctx.globalAlpha = _alpha(s)
                if (s.fill === "solid" || s.fill === "tint") {
                    ctx.fillStyle = s.fill === "solid" ? color : _tint(s.label)
                    ctx.fill()
                }
                // A selected shape sits in a wider frame of the focus colour.
                if (s.selected === true) {
                    _dashKey = "solid"
                    ctx.setLineDash([])
                    ctx.strokeStyle = KanteStyle.focusColor
                    ctx.lineWidth = lineW + 2 * frame
                    ctx.stroke()
                }
                _dash(ctx, s.stroke)
                ctx.strokeStyle = color
                ctx.lineWidth = lineW
                ctx.stroke()
            }

            // Captions last, so no shape covers one.
            ctx.setLineDash([])
            _fillKey = ""
            _align = ""
            for (const s of root.shapes) {
                if (s.text && s.kind !== "image") {
                    ctx.globalAlpha = _alpha(s)
                    _caption(ctx, s)
                }
            }
            ctx.globalAlpha = 1
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: panning ? Qt.ClosedHandCursor : (root._spaceDown ? Qt.OpenHandCursor : Qt.ArrowCursor)

        property bool panning: false
        property bool moved: false
        // In editing: a left drag the app gets, and the shape it began on.
        property bool dragging: false
        property string dragKey: ""
        // Where the drag began, in model units: fixed at the press, whatever the view does.
        property real dragFromX: 0
        property real dragFromY: 0
        property real lastModelX: 0
        property real lastModelY: 0
        property real lastX: 0
        property real lastY: 0
        property real startX: 0
        property real startY: 0

        function _model(mx, my) {
            return root.mapToModel(mx, my)
        }

        onPressed: function (mouse) {
            root.forceActiveFocus()
            lastX = startX = mouse.x
            lastY = startY = mouse.y
            moved = false
            // Middle button and space always pan; the left button pans from empty ground,
            // unless the app edits: then it gets the drag.
            const forced = mouse.button === Qt.MiddleButton || root._spaceDown
            panning = forced || (!root.editing && root.shapeAt(mouse.x, mouse.y) < 0)
            dragging = root.editing && !forced
            dragKey = dragging ? root.keyAt(mouse.x, mouse.y) : ""
            const from = _model(startX, startY)
            dragFromX = lastModelX = from.x
            dragFromY = lastModelY = from.y
        }
        function _drag(mx, my, done) {
            const m = _model(mx, my)
            lastModelX = m.x
            lastModelY = m.y
            root.shapeDragged(dragKey, dragFromX, dragFromY, m.x, m.y, done)
        }
        onPositionChanged: function (mouse) {
            if (!pressed) {
                const k = root.keyAt(mouse.x, mouse.y)
                const m = _model(mouse.x, mouse.y)
                // Over a shape the position goes on; over nothing only the change is reported.
                if (k !== "" || root._hoverKey !== "") {
                    root.shapeHovered(k, m.x, m.y)
                }
                root._hoverKey = k
                return
            }
            if (Math.hypot(mouse.x - startX, mouse.y - startY) > root._dragSlop) {
                moved = true
            }
            if (dragging && moved) {
                _drag(mouse.x, mouse.y, false)
                return
            }
            if (!panning || !moved) {
                return
            }

            root._pan(mouse.x - lastX, mouse.y - lastY)
            lastX = mouse.x
            lastY = mouse.y
        }
        onReleased: function (mouse) {
            if (dragging && moved) {
                _drag(mouse.x, mouse.y, true)
            }
            panning = false
            dragging = false
        }
        // A pinch or the window took the press over: end the drag where it was last seen.
        onCanceled: {
            if (dragging && moved) {
                root.shapeDragged(dragKey, dragFromX, dragFromY, lastModelX, lastModelY, true)
            }
            panning = false
            dragging = false
        }
        onExited: {
            if (root._hoverKey !== "") {
                root.shapeHovered("", 0, 0)
                root._hoverKey = ""
            }
        }
        onClicked: function (mouse) {
            if (moved || mouse.button !== Qt.LeftButton) {
                return
            }

            const m = _model(mouse.x, mouse.y)
            root.shapeClicked(root.keyAt(mouse.x, mouse.y), m.x, m.y)
        }
        onDoubleClicked: function (mouse) {
            if (mouse.button !== Qt.LeftButton) {
                return
            }

            // The second click is reported as before; the double click follows it.
            const m = _model(mouse.x, mouse.y)
            const key = root.keyAt(mouse.x, mouse.y)
            root.shapeClicked(key, m.x, m.y)
            root.shapeDoubleClicked(key, m.x, m.y)
        }
        onWheel: function (wheel) {
            root._zoomAt(wheel.x, wheel.y, Math.pow(root._wheelStep, wheel.angleDelta.y))
        }
    }

    PinchHandler {
        id: pinch
        target: null
        property real last: 1
        onActiveChanged: last = 1
        onActiveScaleChanged: {
            if (!active) {
                return
            }

            root._zoomAt(centroid.position.x, centroid.position.y, activeScale / last)
            last = activeScale
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
