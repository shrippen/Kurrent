import QtQuick

/**
 * Update check (Kante 1.22, non-visual): asks versions.json whether a newer release of
 * `project` exists and offers it as `available`, `latestVersion`, `latestUrl`. It never
 * downloads or installs anything; showing the hint (KanteCallout, a menu entry) is up to
 * the app. At most one request per `interval`, a plain GET without parameters or
 * cookies. Failures stay silent. Format and rules:
 * shrippen.github.io/overview/VERSIONS.md.
 *
 * Only for builds nothing else updates (tarball, AppImage, own release); leave it out of
 * F-Droid, Flathub, AUR and KDE Store builds, and keep `enabled` false in demo mode.
 *
 * `memory` holds the last answer and the dismissed version as a JSON string; persist it
 * so a restart does not ask again:
 *   KanteUpdateCheck {
 *       project: "plasmai"; version: Plasmoid.metaData.version
 *       enabled: Plasmoid.configuration.updateCheck && !demo
 *       memory: Plasmoid.configuration.updateMemory
 *       onMemoryChanged: Plasmoid.configuration.updateMemory = memory
 *   }
 */
QtObject {
    id: check

    /** Project id from shrippen.github.io/overview/sites.json. */
    property string project: ""
    /** Installed version. */
    property string version: ""
    property bool enabled: true
    property string url: "https://shrippen.github.io/versions.json"
    /** Milliseconds between two requests. */
    property int interval: 24 * 60 * 60 * 1000
    /** Last answer and dismissed version (JSON); persist it, see above. */
    property string memory: ""

    readonly property string latestVersion: _latest ? _latest.version : ""
    readonly property string latestDate: _latest ? _latest.date : ""
    readonly property string latestUrl: _latest ? _latest.url : ""
    /** A newer version than `version` exists and was not dismissed. */
    readonly property bool available: enabled && _latest !== null
        && compareVersions(_latest.version, version) > 0 && _latest.version !== _read().dismissed

    property var _latest: null
    property var _request: null
    // start after every binding (memory above all) is in place, else a restart would ask again
    property bool _ready: false
    Component.onCompleted: _ready = true

    property Timer _timer: Timer {
        interval: Math.min(check.interval, 60 * 60 * 1000)
        repeat: true
        running: check._ready && check.enabled && check.project !== "" && check.version !== ""
        triggeredOnStart: true
        onTriggered: check.check(false)
    }

    /** -1, 0, 1. Parts split at "." compare as numbers, missing parts count 0, anything after "-" or "+" is ignored. */
    function compareVersions(a, b) {
        function parts(v) {
            return String(v).replace(/^v/, "").split(/[-+]/)[0].split(".").map(function (p) { return parseInt(p, 10) || 0 })
        }
        var x = parts(a)
        var y = parts(b)
        for (var i = 0; i < Math.max(x.length, y.length); i++) {
            var d = (x[i] || 0) - (y[i] || 0)
            if (d !== 0)
                return d < 0 ? -1 : 1
        }
        return 0
    }

    /** Ask now; without `force` only when the last answer is older than `interval` or for another version. */
    function check(force) {
        if (!enabled || project === "" || version === "" || _request !== null)
            return
        var saved = _read()
        if (!force && saved.from === version && Date.now() - (saved.at || 0) < interval) {
            _latest = saved.latest || null
            return
        }
        var xhr = new XMLHttpRequest()
        _request = xhr
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            _request = null
            if (xhr.status === 200)
                receive(xhr.responseText)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    /** Take a versions.json text (also for tests); anything unexpected counts as "no update". */
    function receive(text) {
        var latest = null
        try {
            var data = JSON.parse(text)
            var entry = data && data.format === 1 && data.projects ? data.projects[project] : null
            if (entry && entry.version && /^https:\/\//.test(entry.url || ""))
                latest = { version: String(entry.version), date: String(entry.date || ""), url: String(entry.url) }
        } catch (e) {
            latest = null
        }
        _latest = latest
        _write({ at: Date.now(), from: version, latest: latest, dismissed: _read().dismissed })
    }

    /** Hide the hint until the next version. */
    function dismiss() {
        if (_latest === null)
            return
        var saved = _read()
        saved.dismissed = _latest.version
        _write(saved)
    }

    function _read() {
        try {
            var saved = JSON.parse(memory)
            return saved && typeof saved === "object" ? saved : {}
        } catch (e) {
            return {}
        }
    }

    function _write(saved) {
        memory = JSON.stringify(saved)
    }
}
