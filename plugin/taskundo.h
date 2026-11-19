#pragma once

#include "sharedtasks.h"
#include "tasklogic.h"

#include <KCalendarCore/Todo>

#include <QHash>
#include <QObject>
#include <QSet>

#include <vector>

/**
 * The undo topic of one controller: the stack of records, the rules for what
 * gets pushed, and the pure record logic (snapshot a task, write a record back
 * into a Todo, rebuild a deleted Todo).
 *
 *   controller ── push / take / guards ──> TaskUndo ── changed ──> controller
 *
 * The controller dispatches a taken record (it needs its own actions for that)
 * and wraps it in an `Applying` guard so the writes it makes are not recorded.
 */
class TaskUndo : public QObject
{
    Q_OBJECT

public:
    /// While alive, nothing is recorded (an undo is being applied).
    class Applying
    {
    public:
        explicit Applying(TaskUndo &undo) : m_undo(undo), m_was(undo.m_applying) { undo.m_applying = true; }
        ~Applying() { m_undo.m_applying = m_was; }
        Applying(const Applying &) = delete;
        Applying &operator=(const Applying &) = delete;

    private:
        TaskUndo &m_undo;
        bool m_was;
    };

    /// While alive, pushes are dropped: a composite action pushes its own record.
    class Batching
    {
    public:
        explicit Batching(TaskUndo &undo) : m_undo(undo), m_was(undo.m_batch) { undo.m_batch = true; }
        ~Batching() { m_undo.m_batch = m_was; }
        Batching(const Batching &) = delete;
        Batching &operator=(const Batching &) = delete;

    private:
        TaskUndo &m_undo;
        bool m_was;
    };

    explicit TaskUndo(QObject *parent);

    bool canUndo() const { return m_stack.canUndo(); }
    QString kindName() const;
    QString label() const;
    /// Takes the newest record off the stack.
    TaskLogic::UndoRecord take();
    /// Empties the stack and the pending recreate / delete bookkeeping.
    void reset();

    /// True while an edit would be recorded (not applying, not in a batch).
    bool recording() const { return !m_applying && !m_batch; }
    bool applying() const { return m_applying; }
    /// Records one step; dropped while applying or batching, collected while collecting.
    void push(TaskLogic::UndoRecord record);

    /// Until endCollect: pushes are gathered into one step (agenda "all to day").
    void beginCollect();
    void endCollect();

    /// A deleted task whose delete is still in flight is recreated once it finishes.
    void recreateAfterDelete(qint64 itemId, const TaskLogic::UndoRecord &record);
    bool takeRecreate(qint64 itemId, TaskLogic::UndoRecord &record);
    void dropRecreate(qint64 itemId);
    /// A detached occurrence still being created is deleted once the create finishes.
    void deleteAfterCreate(const QString &uid);
    bool takeDeleteAfterCreate(const QString &uid);

    static TaskLogic::UndoRecord snapshot(TaskLogic::UndoRecord::Kind kind, const SharedTasks::Entry &cache);
    /// Writes the fields `record` holds for its kind back into `todo` (Edit, Complete, Reschedule).
    static void restoreFields(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record);
    /// A new Todo with the content of a deleted task.
    static KCalendarCore::Todo::Ptr rebuild(const TaskLogic::UndoRecord &record);

Q_SIGNALS:
    void changed();

private:
    static void restoreSeries(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record);
    static void restoreEdit(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record);
    static void restoreComplete(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record);
    static void restoreReschedule(const KCalendarCore::Todo::Ptr &todo, const TaskLogic::UndoRecord &record);

    TaskLogic::UndoStack m_stack;
    bool m_applying = false;
    bool m_batch = false;
    bool m_collecting = false;
    std::vector<TaskLogic::UndoRecord> m_collected;
    QHash<qint64, TaskLogic::UndoRecord> m_recreateAfterDelete;
    QSet<QString> m_deleteAfterCreate;
};
