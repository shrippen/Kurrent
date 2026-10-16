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

    // The controller owns the settings: it bridges Plasmoid.configuration (settings pages)
    // with kurrentrc, restores the start view and refreshes.
    TaskController {
        id: taskController
        Component.onCompleted: startSession(Plasmoid.configuration)
    }
}
