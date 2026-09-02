import QtQuick
import org.kde.plasma.configuration 2.0
import "DevBuildMarker.qml" as DevBuild

ConfigModel {
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
        name: i18n("Tasks")
        icon: "view-list-details"
        source: "configTasks.qml"
    }
    ConfigCategory {
        name: i18n("Editor")
        icon: "document-edit"
        source: "configEditor.qml"
    }
    ConfigCategory {
        name: i18n("Panel")
        icon: "plasmashell"
        source: "configPanel.qml"
    }
    ConfigCategory {
        name: i18n("Notifications")
        icon: "preferences-desktop-notification"
        source: "configNotifications.qml"
    }
    ConfigCategory {
        name: i18n("Projects")
        icon: "folder"
        source: "configProjects.qml"
    }
    ConfigCategory {
        name: i18n("Labels")
        icon: "tag"
        source: "configLabels.qml"
    }
    ConfigCategory {
        name: i18n("Locations")
        icon: "mark-location"
        source: "configLocations.qml"
    }
    ConfigCategory {
        name: i18n("Diagnostics")
        icon: "tools-report-bug"
        source: "configDiagnostics.qml"
        visible: DevBuild.isDevBuild
    }
}
