#include "taskentry.h"

#include "tasklogic.h"

namespace TaskEntries
{

TaskEntry fromShared(const SharedTasks &shared, const SharedTasks::Entry &cached, int indentLevel, bool hasChildren)
{
    const KCalendarCore::Todo::Ptr &todo = cached.todo;
    TaskEntry entry;
    entry.itemId = cached.item.id();
    entry.uid = todo->uid();
    entry.parentUid = todo->relatedTo();
    entry.summary = todo->summary();
    entry.description = todo->description();
    entry.dueDate = TaskCalendar::dueDateFromTodo(todo);
    entry.startDate = TaskCalendar::startDateFromTodo(todo);
    entry.priority = todo->priority();
    entry.completed = todo->isCompleted();
    entry.completedDate = todo->completed();
    entry.recurring = todo->recurs();
    entry.allDay = todo->allDay();
    entry.percentComplete = todo->percentComplete();
    entry.location = todo->location();
    entry.status = static_cast<int>(todo->status());
    entry.secrecy = static_cast<int>(todo->secrecy());
    entry.recurrencePreset = TaskCalendar::recurrencePresetFromTodo(todo);
    entry.joinUrl = TaskLogic::joinUrl(entry.description, entry.location);
    entry.categories = todo->categories();
    entry.collectionId = cached.item.parentCollection().id();
    entry.collectionName = shared.collectionNames().value(entry.collectionId, cached.item.parentCollection().displayName());
    entry.indentLevel = indentLevel;
    entry.hasChildren = hasChildren;
    entry.treeCollapsed = false;
    entry.treeHidden = false;
    entry.reminderMinutes = TaskCalendar::reminderMinutesFromTodo(todo);
    entry.section = TaskCalendar::sectionFromTodo(todo);
    entry.column = TaskCalendar::columnFromTodo(todo);
    entry.attendees = TaskCalendar::attendeesFromTodo(todo);
    entry.kanbanSortOrder = TaskCalendar::kanbanSortOrderFromTodo(todo);
    entry.geoUrl = TaskCalendar::geoMapUrlFromTodo(todo);
    entry.syncing = cached.syncing;
    entry.pendingDelete = cached.pendingDelete;
    return entry;
}

QVariantMap toMap(const TaskEntry &task)
{
    QVariantMap map{{QStringLiteral("progressBand"), TaskLogic::progressBandKey(task.percentComplete)}};
    map.insert(QStringLiteral("itemId"), task.itemId);
    map.insert(QStringLiteral("uid"), task.uid);
    map.insert(QStringLiteral("parentUid"), task.parentUid);
    map.insert(QStringLiteral("summary"), task.summary);
    map.insert(QStringLiteral("description"), task.description);
    map.insert(QStringLiteral("dueDate"), task.dueDate);
    map.insert(QStringLiteral("overdueDays"), TaskLogic::overdueDays(task, QDate::currentDate()));
    map.insert(QStringLiteral("startDate"), task.startDate);
    map.insert(QStringLiteral("completed"), task.completed);
    map.insert(QStringLiteral("categories"), task.categories);
    map.insert(QStringLiteral("collectionId"), task.collectionId);
    map.insert(QStringLiteral("collectionName"), task.collectionName);
    map.insert(QStringLiteral("percentComplete"), task.percentComplete);
    map.insert(QStringLiteral("priority"), task.priority);
    map.insert(QStringLiteral("status"), task.status);
    map.insert(QStringLiteral("secrecy"), task.secrecy);
    map.insert(QStringLiteral("location"), task.location);
    map.insert(QStringLiteral("recurring"), task.recurring);
    map.insert(QStringLiteral("joinUrl"), task.joinUrl);
    map.insert(QStringLiteral("syncing"), task.syncing);
    map.insert(QStringLiteral("allDay"), task.allDay);
    map.insert(QStringLiteral("recurrencePreset"), task.recurrencePreset);
    map.insert(QStringLiteral("reminderMinutes"), task.reminderMinutes);
    map.insert(QStringLiteral("hasChildren"), task.hasChildren);
    map.insert(QStringLiteral("indentLevel"), task.indentLevel);
    map.insert(QStringLiteral("section"), task.section);
    return map;
}

} // namespace TaskEntries
