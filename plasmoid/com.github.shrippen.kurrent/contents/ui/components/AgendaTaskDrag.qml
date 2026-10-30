import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami
import "../agenda.js" as Agenda

// Drags a task in the Agenda through the drag host's proxy (FullView.beginTaskDrag). Drop
// targets read dragHost.draggingTask. Open tasks only.
DragHandler {
    id: handler

    required property var task
    property Item dragHost: null
    property bool suspended: false

    target: null
    enabled: !!dragHost && !!task && !task.completed && !suspended
    dragThreshold: Math.round(Kirigami.Units.gridUnit * 0.6)

    function follow() {
        var g = handler.parent.mapToGlobal(centroid.position.x, centroid.position.y)
        dragHost.updateTaskDragPosition(g.x, g.y)
    }

    onActiveChanged: {
        if (!dragHost) {
            return
        }
        if (active) {
            dragHost.beginTaskDrag(Agenda.dragPayload(task))
            follow()
        } else {
            dragHost.endTaskDrag()
        }
    }
    onCentroidChanged: {
        if (active) {
            follow()
        }
    }
}
