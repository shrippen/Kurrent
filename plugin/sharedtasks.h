#pragma once

#include "taskcalendar.h"
#include "tasklogic.h"

#include <Akonadi/Collection>
#include <Akonadi/Item>
#include <KCalendarCore/Todo>

#include <QDate>
#include <QHash>
#include <QList>
#include <QObject>
#include <QStringList>
#include <QVector>

/**
 * The data all Kurrent controllers of one process share: tasks with their sync
 * state, the task lists, the event calendars, busy times, and labels and places
 * created before a task uses them. A widget, a second widget and an open settings
 * page each have a controller; all read this one copy and listen to its signals,
 * instead of copying the data into each other.
 *
 *   controller A ──┐                  ┌─ collectionsChanged ─> collection models
 *   controller B ──┼──> SharedTasks ──┼─ tasksChanged ───────> rebuild the lists
 *   settings page ─┘                  └─ busyChanged ────────> reminders, agenda
 *
 * It holds data only: no Akonadi jobs, no monitors (loading stays in the controller
 * for now), so it runs in tests without Akonadi.
 */
class SharedTasks : public QObject
{
    Q_OBJECT

public:
    /// A task and where its write to the store stands.
    struct Entry {
        Akonadi::Item item;
        KCalendarCore::Todo::Ptr todo;
        bool syncing = false;
        bool pendingDelete = false;
        int inflight = 0;
        bool persistQueued = false;
        qint64 persistQueuedMoveId = -1;
        KCalendarCore::Todo::Ptr revertTodo;
        KCalendarCore::Todo::Ptr submittedTodo;
        qint64 revertCollectionId = -1;
    };

    /// The one instance of the process, created on first use (parent: the application).
    static SharedTasks &instance();

    /// Tasks by item id; temporary ids (< 0) for creates not yet stored. Controllers
    /// change entries in place and then call notifyTasksChanged().
    QHash<Akonadi::Item::Id, Entry> &tasks();

    /// A new temporary id for a create on its way to the store: -2, -3, ...
    qint64 nextTempId();

    const QList<Akonadi::Collection> &collections() const;
    const QList<Akonadi::Collection> &eventCollections() const;
    const QHash<qint64, QString> &collectionNames() const;

    /// Sets lists, calendars and names together; emits collectionsChanged.
    void setCollections(const QList<Akonadi::Collection> &collections,
                        const QList<Akonadi::Collection> &eventCollections,
                        const QHash<qint64, QString> &names);

    /// Labels and places created in the UI before a task carries them.
    QStringList &extraLabels();
    QStringList &extraLocations();

    const QVector<TaskCalendar::BusyInterval> &busyIntervals() const;
    /// Emits busyChanged.
    void setBusyIntervals(const QVector<TaskCalendar::BusyInterval> &intervals);

    /// Busy events must be fetched again: one changed, or the task lists did.
    void markBusyChanged();
    /// Busy events were fetched on `day`.
    void markBusyFetched(const QDate &day);
    bool busyRefreshDue(const QDate &today) const;

    /// Nothing loaded yet: a new controller has nothing to start from.
    bool isEmpty() const;

    /// Tells every controller that tasks, labels or places changed (one rebuild each).
    void notifyTasksChanged();

    /// Back to the state of a fresh process (tests).
    void reset();

Q_SIGNALS:
    void collectionsChanged();
    void tasksChanged();
    void busyChanged();

private:
    explicit SharedTasks(QObject *parent);

    QHash<Akonadi::Item::Id, Entry> m_tasks;
    qint64 m_nextTempId = -2;
    QList<Akonadi::Collection> m_collections;
    QList<Akonadi::Collection> m_eventCollections;
    QHash<qint64, QString> m_collectionNames;
    QStringList m_extraLabels;
    QStringList m_extraLocations;
    QVector<TaskCalendar::BusyInterval> m_busyIntervals;
    TaskLogic::BusyEvents m_busyEvents = TaskLogic::BusyEvents::Changed;
    QDate m_busyFetchedOn;
};
