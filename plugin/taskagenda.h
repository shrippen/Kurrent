#pragma once

#include "agendalogic.h"
#include "sharedtasks.h"
#include "tasklistmodel.h"
#include "taskundo.h"

#include <QDate>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

/**
 * The agenda and heatmap topic of one controller: what the day, week and month planner
 * and the heatmap show, where a drop puts a task, and the planner's settings.
 *
 *   QML ── controller ──> TaskAgenda ── reads ──> SharedTasks, AgendaLogic
 *                             │
 *                             └── Writes (update, move or detach an occurrence) ──> controller
 *
 * It reads the shared tasks itself, but writes only through `Writes`, so every change
 * still goes through the controller's write path and its undo. The heatmap counts the
 * visible tasks the controller hands in, except completions, which count all tasks.
 */
class TaskAgenda : public QObject
{
    Q_OBJECT

public:
    /// The writes the agenda asks for; each one is recorded for undo by the controller.
    struct Writes {
        std::function<void(qint64, const QVariantMap &)> update;
        /// Moves a series' current occurrence by days; false if nothing moved.
        std::function<bool(qint64, qint64)> moveOccurrence;
        /// Makes a task of a series' occurrence at the given times.
        std::function<void(qint64, const QDateTime &, const QDateTime &)> detach;
    };

    TaskAgenda(SharedTasks &shared, TaskUndo &undo, Writes writes, QObject *parent);

    QDate selectedDate() const { return m_selectedDate; }
    void setSelectedDate(const QDate &date);
    QString mode() const { return m_mode; }
    void setMode(const QString &mode);
    bool weekend() const { return m_weekend; }
    void setWeekend(bool show);
    int workMinutes() const { return m_workMinutes; }
    void setWorkMinutes(int minutes);

    QVariantMap heatmapCountsForMonth(const QList<TaskEntry> &visible, const QDate &monthStart, const QString &mode) const;
    QVariantMap heatmapCountsForYear(const QList<TaskEntry> &visible, int year, const QString &mode) const;
    QVariantMap heatmapCountsAll(const QDate &start, const QDate &end, const QString &mode) const;
    QVariantMap heatmapPeriod(const QList<TaskEntry> &visible, const QDate &monthStart, const QVariantList &years,
                              const QString &mode) const;
    QVariantList heatmapTasksForDay(const QList<TaskEntry> &visible, const QDate &day, const QString &mode) const;

    QVariantList agendaEventsForDay(const QDate &day) const;
    QVariantList agendaTasksForRange(const QDate &from, const QDate &to) const;
    QVariantMap agendaTasksByDay(const QDate &from, const QDate &to) const;
    QVariantList agendaDays(const QDate &from, int count) const;
    QVariantList agendaSuggestions(const QDate &target) const;
    QVariantList agendaMonth(const QDate &anyDay, bool weekend) const;
    QVariantList agendaOverdue() const;
    QVariantMap agendaGhostSlot(const QVariantList &items, int minute, int length) const;

    void agendaPlaceTask(qint64 itemId, const QDate &day, int minute);
    QVariantMap agendaPlacement(qint64 itemId, const QDate &day, int minute) const;
    bool agendaWouldDetach(qint64 itemId, int start, int end) const;
    void agendaSetBlock(qint64 itemId, const QDate &day, int start, int end);
    void agendaMoveToDay(qint64 itemId, const QDate &day);
    void agendaShiftToDay(qint64 itemId, const QDate &day);
    /// agendaShiftToDay for several tasks as one undo step.
    void agendaShiftAllToDay(const QVariantList &itemIds, const QDate &day);

Q_SIGNALS:
    void selectedDateChanged();
    void settingsChanged();

private:
    /// Every task the Agenda knows (all projects, not only the filtered list).
    QList<TaskEntry> agendaEntries() const;
    /// Busy minutes on `day`: timed events and open task blocks, without `skipItemId`.
    QList<AgendaLogic::Span> agendaBusy(const QDate &day, const QList<TaskEntry> &tasks, qint64 skipItemId) const;
    TaskEntry entryOf(const SharedTasks::Entry &cached) const;
    bool isSeries(qint64 itemId) const;
    QDate seriesOccurrenceDay(qint64 itemId) const;

    SharedTasks &m_shared;
    TaskUndo &m_undo;
    Writes m_writes;
    QDate m_selectedDate = QDate::currentDate();
    QString m_mode = AgendaLogic::Mode::Day;
    bool m_weekend = true;
    int m_workMinutes = AgendaLogic::kDefaultWorkMinutes;
};
