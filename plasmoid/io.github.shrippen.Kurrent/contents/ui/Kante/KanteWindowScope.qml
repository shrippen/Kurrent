import QtQuick
import "."

/**
 * Kante colours for a whole Kirigami.ApplicationWindow: its content (a KanteScope on
 * `contentItem`) and its global toolbars, in every bar style (ToolBar, Titles, Breadcrumb).
 *
 *   Kirigami.ApplicationWindow {
 *       id: root
 *       KanteWindowScope { window: root }
 *   }
 *
 * Why not KanteScope alone (1.78): Kirigami's bars set the Header colour set themselves,
 * which stops them inheriting from the window, so a scope on `contentItem` never reached
 * them: in Kante they showed the platform's colours (Android Material: #fffbfe). The bars
 * get a scope of their own, as their child:
 *
 *   window ── pageStack ── page ── globalToolBarItem ── KanteBarScope    (each page, layers too)
 *                      └── PageRowGlobalToolBarUI ───── KanteBarScope    (the stack)
 *
 * The bar sits on the page ground (`KanteStyle.backgroundColor`), the web nav's ground
 * (`.nav`, --bg-void), not on the window role (`dialogColor`) of the content below. With
 * Kante off the bars have the platform's Header colours again.
 *
 * Kirigami names no hook for the bars: the page's is `Page.globalToolBarItem`; the stack's
 * is a Loader inside the PageRow that no property names, found from
 * `pageStack.globalToolBar.leftHandleAnchor` (an item inside that bar) upwards. A scope made by a
 * Loader died before the bar of a page that slides out after a pop, so each scope is created
 * on the bar itself.
 */
Item {
    id: root

    /** The Kirigami.ApplicationWindow. */
    required property QtObject window

    visible: false

    readonly property var stack: window ? window.pageStack : null
    readonly property Item stackBar: barOf(stack ? stack.globalToolBar.leftHandleAnchor : null)

    // The anchor sits in the bar's contentItem: up to the bar (the item with `breadcrumbVisible`).
    function barOf(anchor) {
        let item = anchor
        while (item && item.breadcrumbVisible === undefined) {
            item = item.parent
        }
        return item
    }

    readonly property string scopeName: "kanteBarScope"
    readonly property Component barScope: KanteBarScope {
        objectName: root.scopeName
    }

    // One scope per bar: a bar shown again (or reported twice) keeps its scope.
    function themeBar(bar) {
        if (!bar || bar.children.some(c => c.objectName === scopeName)) {
            return
        }
        barScope.createObject(bar, { target: bar })
    }

    KanteScope {
        target: root.window ? root.window.contentItem : null
    }

    Repeater {
        model: root.stack ? root.stack.items : []

        Item {
            required property var modelData
            readonly property Item bar: modelData ? modelData.globalToolBarItem : null

            onBarChanged: {
                if (root) {
                    root.themeBar(bar)
                }
            }
            Component.onCompleted: {
                if (root) {
                    root.themeBar(bar)
                }
            }
        }
    }

    // Pages on the layers (modal pages) have a bar of their own too. The page of a layer is read
    // again whenever the depth changes.
    Repeater {
        model: root.stack ? root.stack.layers.depth : 0

        Item {
            required property int index
            readonly property var page: root.stack.layers.depth > index ? root.stack.layers.get(index) : null
            readonly property Item bar: page ? (page.globalToolBarItem ?? null) : null

            onBarChanged: {
                if (root) {
                    root.themeBar(bar)
                }
            }
            Component.onCompleted: {
                if (root) {
                    root.themeBar(bar)
                }
            }
        }
    }

    onStackBarChanged: themeBar(stackBar)
    Component.onCompleted: themeBar(stackBar)
}
