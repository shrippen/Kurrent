/*
 * Stable color assignment for projects/labels.
 * Deterministic HSL from the key unless an override is set from kurrentrc.
 * Shared overrides live on Design.qml (singleton); this file stays importable from qmltestrunner.
 */

var _projectColors = {}
var _labelColors = {}
var _locationColors = {}
var _colorForKeyCache = {}

function setColorOverrides(projects, labels, locations) {
    _projectColors = projects || {}
    _labelColors = labels || {}
    _locationColors = locations || {}
    _colorForKeyCache = {}
}

function _hashString(str) {
    // FNV-1a-ish simple hash (deterministic, fast).
    var hash = 2166136261;
    for (var i = 0; i < str.length; ++i) {
        hash ^= str.charCodeAt(i);
        hash = Math.imul(hash, 16777619);
    }
    // Convert to positive 32-bit.
    return Math.abs(hash | 0);
}

function colorForKey(key, kind) {
    var s = String(key);
    var kindKey = kind || "project"
    var cacheKey = kindKey + "\0" + s
    if (_colorForKeyCache[cacheKey] !== undefined) {
        return _colorForKeyCache[cacheKey]
    }

    var map = _projectColors
    if (kind === "label") {
        map = _labelColors
    } else if (kind === "location") {
        map = _locationColors
    }
    if (map && map[s]) {
        _colorForKeyCache[cacheKey] = map[s]
        return map[s]
    }
    if (s.length === 0) {
        var emptyColor = Qt.hsla(0, 0, 0.5, 1);
        _colorForKeyCache[cacheKey] = emptyColor
        return emptyColor;
    }

    // Spread hues across the full 360° using the hash.
    var hue = _hashString(s) % 360;

    // Fixed saturation/lightness to keep the palette readable.
    // Projects/labels mainly need distinct accent colors.
    var saturation = 0.62;
    var lightness = 0.46;

    var color = Qt.hsla(hue / 360.0, saturation, lightness, 1);
    _colorForKeyCache[cacheKey] = color
    return color;
}

/*
 * Priority colors (KCalendarCore: 1 = highest, 9 = lowest).
 * 1-3 High  → red tones (1 strongest)
 * 4-6 Medium → yellow tones (4 strongest)
 * 7-9 Low   → blue tones (7 strongest)
 */
function colorForPriority(priority) {
    var p = Number(priority);
    if (!(p >= 1 && p <= 9)) {
        return Qt.hsla(0, 0, 0.5, 1);
    }

    // 0 = strongest within band, 1 = weakest
    var bandT = 0;
    var hue = 0;
    var saturation = 0.7;
    var lightnessStrong = 0.42;
    var lightnessWeak = 0.58;

    if (p <= 3) {
        // High → red
        bandT = (p - 1) / 2.0;
        hue = 0 / 360.0;
        saturation = 0.78;
        lightnessStrong = 0.40;
        lightnessWeak = 0.55;
    } else if (p <= 6) {
        // Medium → yellow / amber
        bandT = (p - 4) / 2.0;
        hue = 42 / 360.0;
        saturation = 0.85;
        lightnessStrong = 0.44;
        lightnessWeak = 0.58;
    } else {
        // Low → blue
        bandT = (p - 7) / 2.0;
        hue = 210 / 360.0;
        saturation = 0.68;
        lightnessStrong = 0.42;
        lightnessWeak = 0.58;
    }

    var lightness = lightnessStrong + (lightnessWeak - lightnessStrong) * bandT;
    return Qt.hsla(hue, saturation, lightness, 1);
}

function priorityLabel(priority) {
    var p = Number(priority);
    if (p >= 1 && p <= 3) {
        return "high";
    }
    if (p >= 4 && p <= 6) {
        return "medium";
    }
    if (p >= 7 && p <= 9) {
        return "low";
    }
    return "";
}

/** Map any raw priority to UI storage values 0 / 1 / 5 / 9. */
function normalizePriority(priority) {
    var p = Number(priority);
    if (!(p >= 1 && p <= 9)) {
        return 0;
    }
    if (p <= 3) {
        return 1;
    }
    if (p <= 6) {
        return 5;
    }
    return 9;
}

/** Index into [None, High, Medium, Low] for segmented controls. */
function priorityToIndex(priority) {
    switch (normalizePriority(priority)) {
    case 1:
        return 1;
    case 5:
        return 2;
    case 9:
        return 3;
    default:
        return 0;
    }
}

function indexToPriority(index) {
    switch (Number(index)) {
    case 1:
        return 1;
    case 2:
        return 5;
    case 3:
        return 9;
    default:
        return 0;
    }
}

