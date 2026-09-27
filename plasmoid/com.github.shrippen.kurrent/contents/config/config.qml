import QtQuick
import org.kde.plasma.configuration 2.0

ConfigModel {
    // DevBuildMarker.qml is generated at build time; without it (plain source tree) this is a
    // release build. Loaded by URL so a missing file cannot break the whole config dialog.
    readonly property bool isDevBuild: {
        var c = Qt.createComponent(Qt.resolvedUrl("DevBuildMarker.qml"))
        if (c.status !== Component.Ready) {
            return false
        }
        var marker = c.createObject(null)
        var dev = !!(marker && marker.isDevBuild)
        if (marker) {
            marker.destroy()
        }
        return dev
    }

    // Eight pages; projects, labels and locations share "Organize".
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Tasks")
        icon: "view-list-details"
        source: "configTasks.qml"
    }
    ConfigCategory {
        name: i18n("Sidebar")
        icon: "view-sidetree"
        source: "configSidebar.qml"
    }
    ConfigCategory {
        name: i18n("Views")
        icon: "view-filter"
        source: "configViews.qml"
    }
    ConfigCategory {
        name: i18n("Panel & notifications")
        icon: "preferences-desktop-notification"
        source: "configPanel.qml"
    }
    ConfigCategory {
        name: i18n("Organize")
        icon: "folder-tag"
        source: "configOrganize.qml"
    }
    ConfigCategory {
        name: i18n("Diagnostics")
        icon: "tools-report-bug"
        source: "configDiagnostics.qml"
        visible: isDevBuild
    }
}
