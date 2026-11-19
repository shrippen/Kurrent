#include "sharedtasks.h"

#include <QCoreApplication>

SharedTasks::SharedTasks(QObject *parent)
    : QObject(parent)
{
}

SharedTasks &SharedTasks::instance()
{
    // Child of the application, so it dies with it and not after it.
    static SharedTasks *shared = nullptr;
    if (!shared) {
        shared = new SharedTasks(QCoreApplication::instance());
        connect(shared, &QObject::destroyed, [] {
            shared = nullptr;
        });
    }
    return *shared;
}

QHash<Akonadi::Item::Id, SharedTasks::Entry> &SharedTasks::tasks()
{
    return m_tasks;
}

qint64 SharedTasks::nextTempId()
{
    return m_nextTempId--;
}

const QList<Akonadi::Collection> &SharedTasks::collections() const
{
    return m_collections;
}

const QList<Akonadi::Collection> &SharedTasks::eventCollections() const
{
    return m_eventCollections;
}

const QHash<qint64, QString> &SharedTasks::collectionNames() const
{
    return m_collectionNames;
}

void SharedTasks::setCollections(const QList<Akonadi::Collection> &collections,
                                 const QList<Akonadi::Collection> &eventCollections,
                                 const QHash<qint64, QString> &names)
{
    m_collections = collections;
    m_eventCollections = eventCollections;
    m_collectionNames = names;
    Q_EMIT collectionsChanged();
}

QStringList &SharedTasks::extraLabels()
{
    return m_extraLabels;
}

QStringList &SharedTasks::extraLocations()
{
    return m_extraLocations;
}

const QVector<TaskCalendar::BusyInterval> &SharedTasks::busyIntervals() const
{
    return m_busyIntervals;
}

void SharedTasks::setBusyIntervals(const QVector<TaskCalendar::BusyInterval> &intervals)
{
    m_busyIntervals = intervals;
}

void SharedTasks::markBusyChanged()
{
    m_busyEvents = TaskLogic::BusyEvents::Changed;
}

void SharedTasks::markBusyFetched(const QDate &day)
{
    m_busyEvents = TaskLogic::BusyEvents::Current;
    m_busyFetchedOn = day;
}

bool SharedTasks::busyRefreshDue(const QDate &today) const
{
    return TaskLogic::busyRefreshDue(m_busyEvents, m_busyFetchedOn, today);
}

bool SharedTasks::isEmpty() const
{
    return m_collections.isEmpty() && m_tasks.isEmpty() && m_extraLabels.isEmpty() && m_extraLocations.isEmpty();
}

void SharedTasks::notifyTasksChanged()
{
    Q_EMIT tasksChanged();
}

void SharedTasks::reset()
{
    m_tasks.clear();
    m_nextTempId = -2;
    m_collections.clear();
    m_eventCollections.clear();
    m_collectionNames.clear();
    m_extraLabels.clear();
    m_extraLocations.clear();
    m_busyIntervals.clear();
    m_busyEvents = TaskLogic::BusyEvents::Changed;
    m_busyFetchedOn = QDate();
}
