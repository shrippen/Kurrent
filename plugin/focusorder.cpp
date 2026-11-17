#include "focusorder.h"

#include "tasklogic.h"

#include <algorithm>

namespace TaskLogic
{
QList<TaskEntry> openTasks(const QList<TaskEntry> &tasks, const QString &search)
{
    QList<TaskEntry> out;
    for (const TaskEntry &task : tasks) {
        if (task.completed || task.pendingDelete) {
            continue;
        }
        if (!search.isEmpty()
            && !matchesSearch(task, search, SearchScope::All, SearchCase::Insensitive)) {
            continue;
        }
        out.append(task);
    }
    return out;
}

QList<TaskEntry> focusOrder(QList<TaskEntry> tasks, const QDate &today)
{
    std::stable_sort(tasks.begin(), tasks.end(), [&today](const TaskEntry &a, const TaskEntry &b) {
        const auto ha = horizonOf(a, today);
        const auto hb = horizonOf(b, today);
        if (ha != hb) {
            return int(ha) < int(hb);
        }
        if (a.dueDate.isValid() && b.dueDate.isValid() && a.dueDate != b.dueDate) {
            return a.dueDate < b.dueDate;
        }
        if (priorityBand(a.priority) != priorityBand(b.priority)) {
            return a.priority != 0 && (b.priority == 0 || a.priority < b.priority);
        }
        return a.summary.localeAwareCompare(b.summary) < 0;
    });
    return tasks;
}
}
