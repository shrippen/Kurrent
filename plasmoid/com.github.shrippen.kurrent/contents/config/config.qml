import QtQuick
import org.kde.plasma.configuration 2.0

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
        icon: "panel"
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
}
