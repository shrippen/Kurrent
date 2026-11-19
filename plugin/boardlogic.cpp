#include "boardlogic.h"

#include "taskcalendar.h"
#include "tasklogic.h"

namespace BoardLogic
{

namespace
{
constexpr int StatusCompleted = 3;
constexpr int SecrecyPrivate = 1;
constexpr int SecrecyConfidential = 2;

const Outcome PersistOutcome{Effect::Persist, -1, QString(), QString()};

Outcome persistIf(bool changed)
{
    return changed ? PersistOutcome : Outcome();
}

/** Column membership is the first category: move or add `label` to the front. */
void putLabelFirst(const KCalendarCore::Todo::Ptr &todo, const QString &label)
{
    if (label == QLatin1String("none")) {
        todo->setCategories(QStringList());
        return;
    }
    QStringList cats = todo->categories();
    cats.removeAll(label);
    cats.prepend(label);
    todo->setCategories(cats);
}

// Mutates directly so nested helpers cannot push a second undo.
Outcome applyCompletion(const KCalendarCore::Todo::Ptr &todo, const QString &columnKey, const QDateTime &now)
{
    const bool wantDone = columnKey == QLatin1String("done");
    if (todo->isCompleted() == wantDone) {
        return Outcome();
    }

    TaskCalendar::completeTodo(todo,
                               wantDone ? TaskCalendar::CompleteAction::Mark
                                        : TaskCalendar::CompleteAction::Unmark,
                               now);
    if (!todo->recurs()) {
        todo->setPercentComplete(wantDone ? 100 : 0);
    }
    return PersistOutcome;
}

Outcome applyStatus(const KCalendarCore::Todo::Ptr &todo, const QString &columnKey, const QDateTime &now)
{
    bool ok = false;
    const int status = TaskLogic::normalizeStatusColumnKey(columnKey).toInt(&ok);
    if (!ok) {
        return Outcome();
    }

    bool changed = false;
    const auto kStatus = static_cast<KCalendarCore::Incidence::Status>(status);
    if (todo->status() != kStatus) {
        todo->setStatus(kStatus);
        changed = true;
    }
    if (status != StatusCompleted) {
        if (todo->isCompleted()) {
            todo->setCompleted(false);
            changed = true;
        }
        return persistIf(changed);
    }

    if (!todo->isCompleted()) {
        TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, now);
        changed = true;
    }
    if (!todo->recurs() && todo->percentComplete() != 100) {
        todo->setPercentComplete(100);
        changed = true;
    }
    return persistIf(changed);
}

Outcome applySecrecy(const KCalendarCore::Todo::Ptr &todo, const QString &columnKey)
{
    int secrecy = 0;
    if (columnKey == QLatin1String("private")) {
        secrecy = SecrecyPrivate;
    } else if (columnKey == QLatin1String("confidential")) {
        secrecy = SecrecyConfidential;
    }
    if (static_cast<int>(todo->secrecy()) == secrecy) {
        return Outcome();
    }

    todo->setSecrecy(static_cast<KCalendarCore::Incidence::Secrecy>(secrecy));
    return PersistOutcome;
}

Outcome applyProject(const QString &columnKey)
{
    if (columnKey == QLatin1String("inbox")) {
        return Outcome();
    }

    const qint64 collectionId = columnKey.toLongLong();
    if (collectionId < 0) {
        return Outcome();
    }
    return {Effect::MoveCollection, collectionId, QString(), QString()};
}

Outcome applyDue(const KCalendarCore::Todo::Ptr &todo, const QString &columnKey)
{
    if (columnKey == QLatin1String("no-date")) {
        todo->setDtDue(QDateTime());
        return PersistOutcome;
    }

    QString preset;
    if (columnKey == QLatin1String("today") || columnKey == QLatin1String("overdue")) {
        preset = TaskLogic::ReschedulePreset::Today;
    } else if (columnKey == QLatin1String("tomorrow")) {
        preset = TaskLogic::ReschedulePreset::Tomorrow;
    } else if (columnKey == QLatin1String("this-week") || columnKey == QLatin1String("later")) {
        preset = TaskLogic::ReschedulePreset::NextWeek;
    }
    if (preset.isEmpty()) {
        return Outcome();
    }
    return {Effect::Reschedule, -1, preset, QString()};
}

Outcome applyPriority(const KCalendarCore::Todo::Ptr &todo, const QString &columnKey)
{
    int priority = TaskLogic::PriorityBand::None;
    if (columnKey == QLatin1String("high")) {
        priority = TaskLogic::PriorityBand::High;
    } else if (columnKey == QLatin1String("medium")) {
        priority = TaskLogic::PriorityBand::Medium;
    } else if (columnKey == QLatin1String("low")) {
        priority = TaskLogic::PriorityBand::Low;
    }
    if (TaskLogic::priorityBand(todo->priority()) == priority) {
        return Outcome();
    }

    todo->setPriority(priority);
    return PersistOutcome;
}
} // namespace

Outcome applyKanbanColumn(const KCalendarCore::Todo::Ptr &todo, const QString &source,
                          const QString &writeMode, const QString &columnKey, const QDateTime &now)
{
    if (writeMode == WriteMode::Custom || source == TaskLogic::KanbanSource::Column) {
        TaskCalendar::setColumn(todo, columnKey);
        return PersistOutcome;
    }
    if (source == TaskLogic::KanbanSource::Completion) {
        return applyCompletion(todo, columnKey, now);
    }
    if (source == TaskLogic::KanbanSource::Status) {
        return applyStatus(todo, columnKey, now);
    }
    if (source == TaskLogic::KanbanSource::Secrecy) {
        return applySecrecy(todo, columnKey);
    }
    if (source == TaskLogic::KanbanSource::Project) {
        return applyProject(columnKey);
    }
    if (source == TaskLogic::KanbanSource::Due) {
        return applyDue(todo, columnKey);
    }
    if (source == TaskLogic::KanbanSource::Priority) {
        return applyPriority(todo, columnKey);
    }
    if (source == TaskLogic::KanbanSource::Label) {
        putLabelFirst(todo, columnKey);
        return PersistOutcome;
    }
    if (source == TaskLogic::KanbanSource::DaySection) {
        TaskCalendar::setSection(todo, columnKey == QLatin1String("unscheduled") ? QString() : columnKey);
        return PersistOutcome;
    }
    if (writeMode == WriteMode::Both) {
        TaskCalendar::setColumn(todo, columnKey);
        return PersistOutcome;
    }
    return Outcome();
}

Outcome applyMatrixLane(const KCalendarCore::Todo::Ptr &todo, const QString &laneAxis, const QString &laneKey)
{
    if (laneAxis == QLatin1String("label")) {
        putLabelFirst(todo, laneKey);
        return PersistOutcome;
    }
    if (laneAxis == QLatin1String("priority")) {
        todo->setPriority(laneKey.toInt());
        return PersistOutcome;
    }
    if (laneAxis == QLatin1String("parent")) {
        return {Effect::SetParent, -1, QString(), laneKey == QLatin1String("none") ? QString() : laneKey};
    }
    if (laneKey == QLatin1String("inbox")) {
        return Outcome();
    }
    return {Effect::MoveCollection, laneKey.toLongLong(), QString(), QString()};
}

bool applyMatrixTime(const KCalendarCore::Todo::Ptr &todo, const QDateTime &dueBefore, const QString &timeKey,
                     const QString &bucketMode, const QDate &today)
{
    if (timeKey == QLatin1String("unscheduled")) {
        if (!todo->hasDueDate()) {
            return false;
        }
        todo->setDtDue(QDateTime());
        return true;
    }

    const QDateTime next = TaskLogic::dueForBucketDrop(dueBefore, timeKey, bucketMode, today);
    if (!next.isValid()) {
        return false;
    }

    todo->setDtDue(next);
    if (!dueBefore.isValid()) {
        todo->setAllDay(true);
    }
    return true;
}

}
