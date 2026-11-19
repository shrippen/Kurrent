#pragma once

#include "sharedtasks.h"
#include "tasklistmodel.h"

#include <QVariantMap>

/** A task of the shared data as the lists and views know it. */
namespace TaskEntries
{
/// The entry of a shared task; its collection name is looked up in `shared`.
TaskEntry fromShared(const SharedTasks &shared, const SharedTasks::Entry &cached, int indentLevel, bool hasChildren);
/// The map QML reads for `task`.
QVariantMap toMap(const TaskEntry &task);
} // namespace TaskEntries
