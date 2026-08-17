import QtQuick
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
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
