import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import com.github.shrippen.kurrent 1.0

// Loaded from main.qml so a missing Store-only install does not fail the applet import.
Item {
    id: root

    width: 0
    height: 0
    visible: false

    property alias controller: taskController
    readonly property var settings: SharedSettings

    TaskController {
        id: taskController
        showCompleted: Plasmoid.configuration.showCompleted
        catchUpEnabled: Plasmoid.configuration.catchUpEnabled !== false
        catchUpDays: Plasmoid.configuration.catchUpDays || 14
        morningHour: Plasmoid.configuration.morningHour !== undefined ? Plasmoid.configuration.morningHour : 6
        afternoonHour: Plasmoid.configuration.afternoonHour !== undefined ? Plasmoid.configuration.afternoonHour : 12
        eveningHour: Plasmoid.configuration.eveningHour !== undefined ? Plasmoid.configuration.eveningHour : 18
        defaultDueMode: Plasmoid.configuration.defaultDueMode || "none"
        searchTitleOnly: Plasmoid.configuration.searchTitleOnly === true
        searchCaseSensitive: Plasmoid.configuration.searchCaseSensitive === true
        completeChildren: Plasmoid.configuration.completeChildren === true
        countsExcludeCollapsed: Plasmoid.configuration.countsExcludeCollapsed === true
        notificationsEnabled: Plasmoid.configuration.notificationsEnabled !== false
        defaultReminderMinutes: Plasmoid.configuration.defaultReminderMinutes !== undefined
                ? Plasmoid.configuration.defaultReminderMinutes : -1
        quietHoursEnabled: Plasmoid.configuration.quietHoursEnabled === true
        quietHoursStart: Plasmoid.configuration.quietHoursStart !== undefined ? Plasmoid.configuration.quietHoursStart : 22
        quietHoursEnd: Plasmoid.configuration.quietHoursEnd !== undefined ? Plasmoid.configuration.quietHoursEnd : 7

        Component.onCompleted: {
            var view = Plasmoid.configuration.defaultView || "inbox"
            if (Plasmoid.configuration.rememberLastView && Plasmoid.configuration.lastView) {
                view = Plasmoid.configuration.lastView
            }
            currentView = view
            sortMode = Plasmoid.configuration.sortMode || "default"

            selectedCollectionId = -1
            selectedLabel = ""
            selectedPriority = -1
            managementView = ""

            var raw = Plasmoid.configuration.enabledCollections || ""
            if (raw.trim()) {
                var parts = raw.split(",")
                var ids = []
                for (var i = 0; i < parts.length; ++i) {
                    var value = parseInt(parts[i].trim(), 10)
                    if (!isNaN(value)) {
                        ids.push(value)
                    }
                }
                if (ids.length > 0) {
                    setEnabledCollectionIds(ids)
                }
            }
            Qt.callLater(function() { refresh() })
        }
    }
}
