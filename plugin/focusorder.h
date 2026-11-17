#pragma once

#include "tasklistmodel.h"

#include <QDate>
#include <QList>
#include <QString>

namespace TaskLogic
{
/** The open tasks (not done, not being deleted) whose text matches `search`, in list order.
 *  An empty search matches all. */
QList<TaskEntry> openTasks(const QList<TaskEntry> &tasks, const QString &search);

/** Now and Soon by due date, overdue first; Someday by priority, then title. */
QList<TaskEntry> focusOrder(QList<TaskEntry> tasks, const QDate &today);
}
