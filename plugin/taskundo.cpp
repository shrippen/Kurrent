#include "taskundo.h"

#include "taskcalendar.h"

#include <KLocalizedString>

namespace
{
const QByteArray kOccurrenceApp("KURRENT");
const QByteArray kOccurrenceOrigin("OCCURRENCE-ORIGIN");
}

TaskUndo::TaskUndo(QObject *parent)
    : QObject(parent)
{
}

QString TaskUndo::kindName() const
{
    return TaskLogic::undoKindName(m_stack.peek().kind);
}

TaskLogic::UndoRecord TaskUndo::take()
{
    const TaskLogic::UndoRecord record = m_stack.take();
    Q_EMIT changed();
    return record;
}

void TaskUndo::reset()
{
    m_stack.clear();
    m_recreateAfterDelete.clear();
    m_applying = false;
    Q_EMIT changed();
}

void TaskUndo::push(TaskLogic::UndoRecord record)
{
    if (m_applying || record.kind == TaskLogic::UndoRecord::Kind::None) {
        return;
    }
    if (m_batch) {
        return; // a composite action pushes its own record
    }
    if (m_collecting) {
        m_collected.push_back(record);
        return;
    }
    m_stack.push(record);
    Q_EMIT changed();
}

void TaskUndo::beginCollect()
{
    m_collecting = true;
    m_collected.clear();
}

void TaskUndo::endCollect()
{
    m_collecting = false;
    std::vector<TaskLogic::UndoRecord> collected = std::move(m_collected);
    m_collected.clear();
    if (collected.size() == 1) {
        push(collected.front());
    } else if (collected.size() > 1) {
        TaskLogic::UndoRecord batch;
        batch.kind = TaskLogic::UndoRecord::Kind::Batch;
        batch.batch = std::move(collected);
        push(batch);
    }
}

void TaskUndo::recreateAfterDelete(qint64 itemId, const TaskLogic::UndoRecord &record)
{
    m_recreateAfterDelete.insert(itemId, record);
}

bool TaskUndo::takeRecreate(qint64 itemId, TaskLogic::UndoRecord &record)
{
    if (!m_recreateAfterDelete.contains(itemId)) {
        return false;
    }
    record = m_recreateAfterDelete.take(itemId);
    return true;
}

void TaskUndo::dropRecreate(qint64 itemId)
{
    m_recreateAfterDelete.remove(itemId);
}

void TaskUndo::deleteAfterCreate(const QString &uid)
{
    m_deleteAfterCreate.insert(uid);
}

bool TaskUndo::takeDeleteAfterCreate(const QString &uid)
{
    return m_deleteAfterCreate.remove(uid);
}

QString TaskUndo::label() const
{
    if (!m_stack.canUndo()) {
        return i18n("Undo");
    }
    const TaskLogic::UndoRecord rec = m_stack.peek();
    const bool untitled = rec.summary.trimmed().isEmpty();
    const QString title = untitled ? i18n("(Untitled)") : rec.summary.trimmed();
    switch (rec.kind) {
    case TaskLogic::UndoRecord::Kind::Complete:
        return rec.completed ? i18n("Undo marking “%1” incomplete", title)
                             : i18n("Undo complete of “%1”", title);
    case TaskLogic::UndoRecord::Kind::Reschedule:
        return i18n("Undo reschedule of “%1”", title);
    case TaskLogic::UndoRecord::Kind::Move:
        return i18n("Undo move of “%1”", title);
    case TaskLogic::UndoRecord::Kind::Delete:
        return i18n("Undo delete of “%1”", title);
    case TaskLogic::UndoRecord::Kind::Edit:
        if (rec.restoreLayout) {
            return i18n("Undo Kanban change of “%1”", title);
        }
        return i18n("Undo edit of “%1”", title);
    case TaskLogic::UndoRecord::Kind::KanbanLayout:
        return untitled ? i18n("Undo Kanban order") : i18n("Undo Kanban order of “%1”", title);
    case TaskLogic::UndoRecord::Kind::Batch:
        return i18np("Undo moving %1 task", "Undo moving %1 tasks", int(rec.batch.size()));
    case TaskLogic::UndoRecord::Kind::Detach:
        return i18n("Undo detaching “%1”", title);
    case TaskLogic::UndoRecord::Kind::None:
        break;
    }
    return i18n("Undo");
}

TaskLogic::UndoRecord TaskUndo::snapshot(TaskLogic::UndoRecord::Kind kind, const SharedTasks::Entry &cache)
{
    TaskLogic::UndoRecord record;
    record.kind = kind;
    record.itemId = cache.item.id();
    if (!cache.todo) {
        return record;
    }
    record.summary = cache.todo->summary();
    record.description = cache.todo->description();
    record.location = cache.todo->location();
    record.hadDue = cache.todo->hasDueDate() && cache.todo->dtDue().isValid();
    record.due = record.hadDue ? cache.todo->dtDue() : QDateTime();
    record.start = (cache.todo->hasStartDate() && cache.todo->dtStart().isValid()) ? cache.todo->dtStart() : QDateTime();
    record.allDay = cache.todo->allDay();
    record.completed = cache.todo->isCompleted();
    record.priority = cache.todo->priority();
    record.percentComplete = cache.todo->percentComplete();
    record.categories = cache.todo->categories();
    record.parentUid = cache.todo->relatedTo();
    record.collectionId = cache.item.parentCollection().id();
    record.section = TaskCalendar::sectionFromTodo(cache.todo);
    record.status = static_cast<int>(cache.todo->status());
    record.secrecy = static_cast<int>(cache.todo->secrecy());
    record.column = TaskCalendar::columnFromTodo(cache.todo);
    if (cache.todo->recurs()) {
        record.recurs = true;
        record.seriesStart = cache.todo->dtStart(true);
        record.seriesDue = cache.todo->hasDueDate() ? cache.todo->dtDue(true) : QDateTime();
        record.occurrence = cache.todo->dtRecurrence();
        record.occurrenceMark = cache.todo->customProperty(kOccurrenceApp, kOccurrenceOrigin);
    }
    return record;
}

void TaskUndo::restoreSeries(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record)
{
    if (!record.recurs || !todo) {
        return;
    }
    // Back to the series' own dates, then the occurrence: setDtDue(…, true) above would
    // otherwise have written the occurrence as the series' first DUE.
    if (record.seriesStart.isValid()) {
        todo->setDtStart(record.seriesStart);
    }
    if (record.seriesDue.isValid()) {
        todo->setDtDue(record.seriesDue, true);
    }
    todo->setDtRecurrence(record.occurrence == record.seriesStart ? QDateTime() : record.occurrence);
    if (!record.occurrenceMark.isEmpty()) {
        todo->setCustomProperty(kOccurrenceApp, kOccurrenceOrigin, record.occurrenceMark);
    } else {
        todo->removeCustomProperty(kOccurrenceApp, kOccurrenceOrigin);
    }
}

void TaskUndo::restoreFields(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record)
{
    switch (record.kind) {
    case TaskLogic::UndoRecord::Kind::Edit:
        restoreEdit(todo, record);
        break;
    case TaskLogic::UndoRecord::Kind::Complete:
        restoreComplete(todo, record);
        break;
    case TaskLogic::UndoRecord::Kind::Reschedule:
        restoreReschedule(todo, record);
        break;
    default:
        break;
    }
}

void TaskUndo::restoreEdit(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record)
{
    todo->setSummary(record.summary);
    todo->setDescription(record.description);
    todo->setLocation(record.location);
    todo->setPriority(record.priority);
    todo->setPercentComplete(record.percentComplete);
    todo->setCategories(record.categories);
    todo->setRelatedTo(record.parentUid);
    todo->setCompleted(record.completed);
    todo->setStatus(static_cast<KCalendarCore::Incidence::Status>(record.status));
    todo->setSecrecy(static_cast<KCalendarCore::Incidence::Secrecy>(record.secrecy));
    TaskCalendar::setSection(todo, record.section);
    TaskCalendar::setColumn(todo, record.column);
    if (record.hadDue) {
        todo->setDtDue(record.due, true);
        todo->setAllDay(record.allDay);
    } else {
        todo->setDtDue(QDateTime());
    }
    if (record.start.isValid()) {
        todo->setDtStart(record.start);
    } else {
        todo->setDtStart(QDateTime());
    }
    restoreSeries(todo, record);
}

void TaskUndo::restoreComplete(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record)
{
    todo->setCompleted(record.completed);
    todo->setPercentComplete(record.percentComplete);
    if (record.start.isValid()) {
        todo->setDtStart(record.start);
    }
    if (record.hadDue) {
        todo->setDtDue(record.due, true);
        todo->setAllDay(record.allDay);
    }
    restoreSeries(todo, record);
}

void TaskUndo::restoreReschedule(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record)
{
    if (record.hadDue) {
        todo->setDtDue(record.due, true);
        todo->setAllDay(record.allDay);
    } else {
        todo->setDtDue(QDateTime());
    }
    restoreSeries(todo, record);
}

KCalendarCore::Todo::Ptr TaskUndo::rebuild(const TaskLogic::UndoRecord &record)
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(record.summary);
    todo->setDescription(record.description);
    todo->setLocation(record.location);
    if (record.hadDue) {
        todo->setDtDue(record.due);
        todo->setAllDay(record.allDay);
    }
    if (record.start.isValid()) {
        todo->setDtStart(record.start);
    }
    todo->setPriority(record.priority);
    todo->setPercentComplete(record.percentComplete);
    todo->setCompleted(record.completed);
    todo->setCategories(record.categories);
    if (!record.parentUid.isEmpty()) {
        todo->setRelatedTo(record.parentUid);
    }
    TaskCalendar::setSection(todo, record.section);
    return todo;
}
