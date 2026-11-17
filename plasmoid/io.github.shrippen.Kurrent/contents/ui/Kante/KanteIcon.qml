import QtQuick
import QtQuick.Controls.impl

/**
 * A theme icon in one colour (1.73). Kirigami.Icon's isMask colours only where the platform theme
 * does it (Plasma); on Android, in an AppImage and in tests the icon stayed as it is, dark on the
 * dark Kante ground. The Controls' IconImage colours it on every platform.
 *   iconSource  a theme name ("go-next") or a url
 *   color       the colour of the symbol
 * A theme name needs a size (width and height, or both of the Layout's preferred ones): without one
 * it shows nothing. Set iconSource, not name: pick() writes name.
 */
IconImage {
    property var iconSource: ""
    readonly property bool isUrl: /^[a-z]+:|^\//.test(String(iconSource))
    /**
     * Where no file is picked yet. An IconImage without name and source looks up "" in the icon
     * theme on every change, uncached: ~6.5 ms each on Plasma (1.76.3), more than the icon itself.
     */
    readonly property string blank: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='1' height='1'/>"

    source: isUrl ? iconSource : blank

    // IconImage picks the theme's file for its size once, when the name is set. In a layout the size
    // comes later, and a file picked for size 0 is scaled, grey and soft. So: the size first, then the
    // name, also after a new size. No bindings: IconImage writes sourceSize itself (a binding loop).
    // Each pick is a lookup in the icon theme: a layout settles width and height one after the other,
    // so a new size picks once, after both, and the same name at the same size picks nothing (1.76.3).
    property string picked: ""

    function pick() {
        // Not isUrl: its binding may not have followed iconSource yet when this runs.
        const url = /^[a-z]+:|^\//.test(String(iconSource))
        // A url is drawn at the size too, but is no theme name: its key holds the size only.
        const key = !(width > 0 && height > 0) ? "" : (url ? "url" : String(iconSource)) + "@" + width + "x" + height
        if (key === picked) {
            return
        }
        picked = key
        name = ""
        sourceSize = Qt.size(width, height)
        if (key !== "" && !url) {
            name = String(iconSource)
        }
    }
    onWidthChanged: Qt.callLater(pick)
    onHeightChanged: Qt.callLater(pick)
    onIconSourceChanged: pick()
    Component.onCompleted: pick()
}
