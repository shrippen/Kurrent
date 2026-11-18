#pragma once

#include <Akonadi/Collection>
#include <Akonadi/Item>

#include <QDateTime>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QString>
#include <QTimer>
#include <QVector>

#include "taskcalendar.h"

class KJob;
class SharedTasks;

namespace Akonadi
{
class CollectionFetchJob;
class Monitor;
}

/**
 * Reads task lists, tasks and busy events from Akonadi into SharedTasks and
 * watches them for changes, once per process. Before, each controller (every
 * widget and every open settings page) ran its own monitors and fetches.
 *
 *   Akonadi ──monitors, fetches──> AkonadiLoader ──applies──> SharedTasks
 *                                       │
 *                                       └─ available, loading, error ──> controllers
 *
 * Writes do not pass here; they go through the task store. The loader only
 * decides which version of a task wins when one arrives (applyItem).
 */
class AkonadiLoader : public QObject
{
    Q_OBJECT

public:
    /// What the last fetch wave brought, for the debug line.
    struct FetchStats {
        int items = 0;
        int accepted = 0;
        int rejectedNotTodo = 0;
        int rejectedNoPayload = 0;
        int rejectedDisabled = 0;
        int rejectedNoCollection = 0;
        int pendingJobs = 0;
    };

    /// The one loader of the process, created on first use (parent: the application).
    static AkonadiLoader &instance();

    /// Connects to Akonadi (starting it when needed, retrying while it comes up),
    /// then loads the task lists and their tasks.
    void refresh();

    /// Asks the resources of the enabled task lists to sync with their servers.
    /// Without Akonadi it tries to connect; false (and errorMessage set) if that fails.
    bool syncNow();

    bool available() const;
    bool loading() const;
    /// Why loading failed ("Akonadi is not available", no task lists, a fetch error); empty when fine.
    QString errorMessage() const;
    FetchStats fetchStats() const;

    /// Task lists to load (empty: all), from the shared setting.
    void setEnabledCollectionIds(const QList<qint64> &ids);

    /// Event calendars whose events count as busy (comma-separated ids), from the shared setting.
    void setBusyCalendarIds(const QString &csv);

    /// An item from a fetch or a monitor. Takes it into SharedTasks unless the cached
    /// version must win: a write of ours is under way, or the incoming one is older.
    void applyItem(const Akonadi::Item &item, qint64 fallbackCollectionId = -1);

    /// Back to the state of a fresh process without touching Akonadi (tests).
    void resetForTest(bool available);

Q_SIGNALS:
    void availableChanged();
    void loadingChanged();
    void errorMessageChanged();
    /// A fetch job ended or the wave did (pending jobs and counts changed).
    void fetchStatsChanged();

    friend class TaskControllerMultiTest; // tests/taskcontroller_multi_test.cpp feeds a busy fetch result
    friend class AkonadiLoaderTest; // tests/akonadiloader_test.cpp sets the job counter of a wave

private:
    explicit AkonadiLoader(QObject *parent);

    bool isCollectionEnabled(qint64 collectionId) const;
    void removeItem(Akonadi::Item::Id itemId);
    /// Fetches the busy events again if one changed or the day did.
    void refreshBusyIfDue();

    bool initialize();
    bool attachMonitor();
    void ensureServerWatch();
    void scheduleRetry();
    void scheduleLoadCollections();
    void loadCollections();
    void onCollectionsFetched(KJob *job);
    void loadTasks();
    void fetchTodos(const Akonadi::Collection &collection);
    void onItemsFetched(const Akonadi::Item::List &items, const QString &error, qint64 collectionId);
    void pruneAfterWave();
    QList<Akonadi::Collection> enabledCollections() const;

    void watchBusyEvents();
    void scheduleRefreshBusyEvents();
    void refreshBusyEvents();
    void onBusyEventsFetched(KJob *job, const QDateTime &rangeStart, const QDateTime &rangeEnd);
    QList<Akonadi::Collection> busyEventCollections() const;

    void setAvailable(bool available);
    void setLoading(bool loading);
    void setErrorMessage(const QString &message);

    SharedTasks &m_shared;

    bool m_available = false;
    bool m_loading = false;
    QString m_errorMessage;

    QSet<qint64> m_enabledIds;
    QString m_busyCalendarIds;

    bool m_serverWatchConnected = false;
    QTimer m_retryTimer;
    QTimer m_collectionsTimer;
    QPointer<Akonadi::Monitor> m_monitor;
    QPointer<Akonadi::CollectionFetchJob> m_collectionFetchJob;
    bool m_collectionsReloadPending = false;

    int m_pendingFetchJobs = 0;
    QSet<Akonadi::Item::Id> m_fetchSeenIds;
    QSet<qint64> m_fetchOkCollections;
    FetchStats m_stats;

    QPointer<Akonadi::Monitor> m_eventMonitor;
    QTimer m_busyTimer;
    QTimer m_busyChangeTimer;
    int m_pendingBusyFetchJobs = 0;
    QVector<TaskCalendar::BusyInterval> m_busyFetchIntervals;
};
