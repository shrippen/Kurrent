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

    source: isUrl ? iconSource : ""

    // IconImage picks the theme's file for its size once, when the name is set. In a layout the size
    // comes later, and a file picked for size 0 is scaled, grey and soft. So: the size first, then the
    // name, also after a new size. No bindings: IconImage writes sourceSize itself (a binding loop).
    function pick() {
        name = ""
        sourceSize = Qt.size(width, height)
        const url = /^[a-z]+:|^\//.test(String(iconSource))
        if (!url && width > 0 && height > 0) {
            name = String(iconSource)
        }
    }
    onWidthChanged: pick()
    onHeightChanged: pick()
    onIconSourceChanged: pick()
    Component.onCompleted: pick()
}
