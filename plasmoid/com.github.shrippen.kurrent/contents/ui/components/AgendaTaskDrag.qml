import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

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
            dragHost.beginTaskDrag({
                "itemId": task.itemId,
                "uid": task.uid,
                "summary": task.summary || "",
                "parentUid": task.parentUid || "",
                "categories": task.categories || [],
                "collectionId": task.collectionId,
                "priority": task.priority
            })
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
