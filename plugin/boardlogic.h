#pragma once

#include <KCalendarCore/Todo>

#include <QDateTime>
#include <QString>

/** What dropping a task on a Kanban column or a matrix cell changes in the task. Pure: no store, no undo. */
namespace BoardLogic
{

namespace WriteMode
{
inline const QString Custom = QStringLiteral("custom");
inline const QString Both = QStringLiteral("both");
}

/** What the caller does after a drop was applied to the todo. */
enum class Effect {
    Nothing,        // nothing changed, do not persist
    Persist,        // the todo changed, persist it
    MoveCollection, // move the task to `Outcome::collectionId`; the todo is untouched
    Reschedule,     // reschedule with `Outcome::preset`; the todo is untouched
    SetParent,      // matrix only: set the parent to `Outcome::parentUid` (empty = none)
};

struct Outcome {
    Effect effect = Effect::Nothing;
    qint64 collectionId = -1;
    QString preset;
    QString parentUid;
};

/** Applies a Kanban column to `todo` according to the column source and the write mode. */
Outcome applyKanbanColumn(const KCalendarCore::Todo::Ptr &todo, const QString &source,
                          const QString &writeMode, const QString &columnKey, const QDateTime &now);

/** Applies the lane of a matrix cell (label, priority, parent or project axis) to `todo`. */
Outcome applyMatrixLane(const KCalendarCore::Todo::Ptr &todo, const QString &laneAxis, const QString &laneKey);

/** Applies the time column of a matrix cell to `todo` (`dueBefore`: its due date before the drop);
 *  true when the todo changed. */
bool applyMatrixTime(const KCalendarCore::Todo::Ptr &todo, const QDateTime &dueBefore, const QString &timeKey,
                     const QString &bucketMode, const QDate &today);

}
