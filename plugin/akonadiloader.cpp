#include "akonadiloader.h"

#include "akonadiitems.h"
#include "akonadiutil.h"
#include "collectionlistmodel.h"
#include "kurrentlogging.h"
#include "sharedtasks.h"
#include "tasklogic.h"

#include <Akonadi/AgentManager>
#include <Akonadi/CollectionFetchJob>
#include <Akonadi/CollectionFetchScope>
#include <Akonadi/ItemFetchJob>
#include <Akonadi/ItemFetchScope>
#include <Akonadi/Monitor>
#include <Akonadi/ServerManager>

#include <KCalendarCore/Event>
#include <KCalendarCore/Todo>

#include <KJob>
#include <KLocalizedString>

#include <QCoreApplication>

namespace
{
constexpr int kCollectionsReloadDelayMs = 250;
constexpr int kAkonadiRetryIntervalMs = 5000;
constexpr int kBusyEventRefreshMs = 5 * 60 * 1000;
constexpr int kBusyChangeDelayMs = 2000;

void logDebug(const QString &message)
{
    KurrentLogging::verbose(message);
}

QString serverStateName(Akonadi::ServerManager::State state)
{
    switch (state) {
    case Akonadi::ServerManager::NotRunning:
        return QStringLiteral("NotRunning");
    case Akonadi::ServerManager::Starting:
        return QStringLiteral("Starting");
    case Akonadi::ServerManager::Running:
        return QStringLiteral("Running");
    case Akonadi::ServerManager::Stopping:
        return QStringLiteral("Stopping");
    case Akonadi::ServerManager::Broken:
        return QStringLiteral("Broken");
    case Akonadi::ServerManager::Upgrading:
        return QStringLiteral("Upgrading");
    }
    return QStringLiteral("Unknown(%1)").arg(static_cast<int>(state));
}

// A failed job's message, never empty; empty when the job succeeded.
QString fetchError(const KJob *job)
{
    if (!job->error()) {
        return {};
    }
    return job->errorString().isEmpty() ? i18n("Failed to fetch tasks.") : job->errorString();
}

// An entry with a write under way is never settled: the cache is newer than Akonadi.
bool isSettled(const SharedTasks::Entry &entry, Akonadi::Item::Id id)
{
    return id >= 0 && !entry.syncing && !entry.pendingDelete && entry.inflight <= 0;
}

// Whether the cached version stays instead of the incoming one.
bool cachedWins(const SharedTasks::Entry &existing, const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo)
{
    if (existing.syncing || existing.inflight > 0 || existing.pendingDelete || existing.persistQueued) {
        return true;
    }
    const int incomingRevision = item.revision();
    const int cachedRevision = existing.item.revision();
    if (incomingRevision > 0 && cachedRevision > 0 && incomingRevision < cachedRevision) {
        return true;
    }
    // FIX 1: Reject same-revision stale echoes from DAV resource sync races.
    // If revision matches but the todo summary differs, the incoming payload
    // is stale (the resource fetched before our modify propagated). Our local
    // optimistic state is more current.
    if (incomingRevision > 0 && cachedRevision > 0 && incomingRevision == cachedRevision
        && existing.todo && todo
        && existing.todo->summary() != todo->summary()) {
        return true;
    }
    // FIX 1b: If the incoming item has revision 0 (DAV resource notification without
    // revision), never overwrite a cached item that has a real revision. Revision 0
    // means "I don't know the version" — keeping the cached revision is safer.
    return incomingRevision == 0 && cachedRevision > 0;
}

// The task arrived from the store: the row typed before it (temporary id) is done.
void dropTempRows(SharedTasks &shared, const QString &uid)
{
    for (auto it = shared.tasks().begin(); it != shared.tasks().end();) {
        if (it.key() < 0 && it->todo && it->todo->uid() == uid) {
            it = shared.tasks().erase(it);
        } else {
            ++it;
        }
    }
}

// Task lists, event calendars and the names of both, from a collection fetch.
void splitCollections(const QList<Akonadi::Collection> &fetched,
                      QList<Akonadi::Collection> *collections,
                      QList<Akonadi::Collection> *eventCollections,
                      QHash<qint64, QString> *names)
{
    collections->reserve(fetched.size());
    eventCollections->reserve(fetched.size());
    logDebug(QStringLiteral("loadCollections: found %1 calendar collections").arg(fetched.size()));
    for (const Akonadi::Collection &collection : fetched) {
        logDebug(QStringLiteral("  collection id=%1 name=\"%2\" mimes=%3 rights=%4")
                     .arg(collection.id())
                     .arg(collection.displayName())
                     .arg(collection.contentMimeTypes().join(QLatin1Char(',')))
                     .arg(static_cast<int>(collection.rights())));
        if (CollectionListModel::isTaskCollection(collection)) {
            collections->append(collection);
            names->insert(collection.id(), collection.displayName());
        }
        if (CollectionListModel::isEventCollection(collection)) {
            eventCollections->append(collection);
            if (!names->contains(collection.id())) {
                names->insert(collection.id(), collection.displayName());
            }
        }
    }
    logDebug(QStringLiteral("loadCollections: keeping %1 task collections, %2 event calendars")
                 .arg(collections->size())
                 .arg(eventCollections->size()));
}
}

AkonadiLoader::AkonadiLoader(QObject *parent)
    : QObject(parent)
    , m_shared(SharedTasks::instance())
{
    m_collectionsTimer.setInterval(kCollectionsReloadDelayMs);
    m_collectionsTimer.setSingleShot(true);
    connect(&m_collectionsTimer, &QTimer::timeout, this, &AkonadiLoader::loadCollections);

    m_retryTimer.setInterval(kAkonadiRetryIntervalMs);
    m_retryTimer.setSingleShot(false);
    connect(&m_retryTimer, &QTimer::timeout, this, &AkonadiLoader::refresh);

    m_busyTimer.setInterval(kBusyEventRefreshMs);
    m_busyTimer.setSingleShot(false);
    connect(&m_busyTimer, &QTimer::timeout, this, &AkonadiLoader::refreshBusyIfDue);
    // Several changes in a row (a sync) fetch once.
    m_busyChangeTimer.setInterval(kBusyChangeDelayMs);
    m_busyChangeTimer.setSingleShot(true);
    connect(&m_busyChangeTimer, &QTimer::timeout, this, &AkonadiLoader::refreshBusyIfDue);
}

AkonadiLoader &AkonadiLoader::instance()
{
    // Child of the application, so it dies with it and not after it.
    static AkonadiLoader *loader = nullptr;
    if (!loader) {
        loader = new AkonadiLoader(QCoreApplication::instance());
        connect(loader, &QObject::destroyed, [] {
            loader = nullptr;
        });
    }
    return *loader;
}

bool AkonadiLoader::available() const
{
    return m_available;
}

bool AkonadiLoader::loading() const
{
    return m_loading;
}

QString AkonadiLoader::errorMessage() const
{
    return m_errorMessage;
}

AkonadiLoader::FetchStats AkonadiLoader::fetchStats() const
{
    FetchStats stats = m_stats;
    stats.pendingJobs = m_pendingFetchJobs;
    return stats;
}

void AkonadiLoader::setAvailable(bool available)
{
    if (m_available == available) {
        return;
    }
    m_available = available;
    Q_EMIT availableChanged();
}

void AkonadiLoader::setLoading(bool loading)
{
    if (m_loading == loading) {
        return;
    }
    m_loading = loading;
    Q_EMIT loadingChanged();
}

void AkonadiLoader::setErrorMessage(const QString &message)
{
    if (m_errorMessage == message) {
        return;
    }
    m_errorMessage = message;
    Q_EMIT errorMessageChanged();
}

void AkonadiLoader::resetForTest(bool available)
{
    m_retryTimer.stop();
    m_collectionsTimer.stop();
    m_busyTimer.stop();
    m_busyChangeTimer.stop();
    m_collectionsReloadPending = false;
    m_pendingFetchJobs = 0;
    m_fetchSeenIds.clear();
    m_fetchOkCollections.clear();
    m_stats = FetchStats();
    m_pendingBusyFetchJobs = 0;
    m_busyFetchIntervals.clear();
    m_enabledIds.clear();
    m_busyCalendarIds.clear();
    setLoading(false);
    setErrorMessage(QString());
    setAvailable(available);
    Q_EMIT fetchStatsChanged();
}

void AkonadiLoader::refresh()
{
    if (!initialize()) {
        return;
    }
    loadCollections();
}

bool AkonadiLoader::syncNow()
{
    if (!m_available) {
        // Try to (re)connect; retry timer keeps trying if this still fails.
        refresh();
        if (!m_available) {
            setErrorMessage(i18n("Akonadi is not available."));
            return false;
        }
    }

    setLoading(true);
    const QList<Akonadi::Collection> collections = enabledCollections();
    if (collections.isEmpty()) {
        setLoading(false);
        return true;
    }

    for (const Akonadi::Collection &collection : collections) {
        Akonadi::AgentManager::self()->synchronizeCollection(collection);
    }

    setLoading(false);
    loadTasks();
    return true;
}

void AkonadiLoader::scheduleRetry()
{
    if (!m_retryTimer.isActive()) {
        logDebug(QStringLiteral("scheduleAkonadiRetry: retrying every %1 ms").arg(kAkonadiRetryIntervalMs));
        m_retryTimer.start();
    }
}

void AkonadiLoader::ensureServerWatch()
{
    if (m_serverWatchConnected) {
        return;
    }
    m_serverWatchConnected = true;
    connect(Akonadi::ServerManager::self(), &Akonadi::ServerManager::stateChanged,
            this, [this](Akonadi::ServerManager::State state) {
                logAkonadi(QStringLiteral("ServerManager stateChanged=%1 monitor=%2 akonadiAvailable=%3")
                               .arg(serverStateName(state))
                               .arg(m_monitor != nullptr)
                               .arg(m_available));
                if (state != Akonadi::ServerManager::Running && m_monitor) {
                    logAkonadi(QStringLiteral("ServerManager: not Running while monitor is attached — ItemModifyJob may stall or fail"));
                }
                if (state == Akonadi::ServerManager::Running && !m_monitor) {
                    refresh();
                }
            });
}

bool AkonadiLoader::initialize()
{
    if (m_monitor) {
        return true;
    }

    ensureServerWatch();

    if (!Akonadi::ServerManager::isRunning()) {
        const Akonadi::ServerManager::State state = Akonadi::ServerManager::state();
        bool startOk = true;
        if (state == Akonadi::ServerManager::NotRunning || state == Akonadi::ServerManager::Broken) {
            startOk = Akonadi::ServerManager::start();
        }

        const bool comingUp = startOk
            && state != Akonadi::ServerManager::Broken
            && state != Akonadi::ServerManager::Stopping
            && (state != Akonadi::ServerManager::NotRunning || !m_retryTimer.isActive());

        setAvailable(false);
        setLoading(comingUp);
        setErrorMessage(QString());
        logAkonadi(QStringLiteral("initializeAkonadi: waiting for Akonadi (state=%1 comingUp=%2 startOk=%3)")
                     .arg(serverStateName(state))
                     .arg(comingUp)
                     .arg(startOk));
        scheduleRetry();
        return false;
    }

    return attachMonitor();
}

bool AkonadiLoader::attachMonitor()
{
    if (m_monitor) {
        return true;
    }

    m_retryTimer.stop();
    setAvailable(true);
    setErrorMessage(QString());
    logAkonadi(QStringLiteral("initializeAkonadi: Akonadi running, creating monitor"));
    m_busyTimer.start();
    scheduleRefreshBusyEvents();

    watchBusyEvents();

    m_monitor = new Akonadi::Monitor(this);
    m_monitor->setMimeTypeMonitored(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    // Monitor otherwise FetchCollections on every collection notification
    // (including statistics bumps from calendar events).
    m_monitor->fetchCollection(false);
    m_monitor->fetchCollectionStatistics(false);

    auto itemScope = m_monitor->itemFetchScope();
    itemScope.fetchFullPayload();
    itemScope.fetchAllAttributes();
    itemScope.setFetchTags(true);
    itemScope.setAncestorRetrieval(Akonadi::ItemFetchScope::None);
    m_monitor->setItemFetchScope(itemScope);

    connect(m_monitor, &Akonadi::Monitor::collectionAdded, this, [this](const Akonadi::Collection &) {
        scheduleLoadCollections();
    });
    connect(m_monitor, &Akonadi::Monitor::collectionRemoved, this, [this](const Akonadi::Collection &) {
        scheduleLoadCollections();
    });
    connect(m_monitor, static_cast<void (Akonadi::Monitor::*)(const Akonadi::Collection &, const QSet<QByteArray> &)>(&Akonadi::Monitor::collectionChanged),
            this, [this](const Akonadi::Collection &, const QSet<QByteArray> &parts) {
                // Ignore empty/statistics-only updates (fired constantly as items change).
                if (parts.isEmpty() || (parts.size() == 1 && parts.contains("Statistics"))) {
                    return;
                }
                static const QSet<QByteArray> structural{
                    QByteArrayLiteral("NAME"),
                    QByteArrayLiteral("CONTENT"),
                    QByteArrayLiteral("ENABLED"),
                    QByteArrayLiteral("ACCESSRIGHTS"),
                    QByteArrayLiteral("ENTITYDISPLAY"),
                };
                if (!parts.intersects(structural)) {
                    return;
                }
                scheduleLoadCollections();
            });

    connect(m_monitor, &Akonadi::Monitor::itemAdded, this, [this](const Akonadi::Item &item) {
        logDebug(QStringLiteral("Monitor itemAdded id=%1 mime=%2 collection=%3 payload=%4")
                     .arg(item.id())
                     .arg(item.mimeType())
                     .arg(item.parentCollection().id())
                     .arg(item.hasPayload<KCalendarCore::Todo::Ptr>()));
        applyItem(item);
    });
    connect(m_monitor, &Akonadi::Monitor::itemChanged, this, [this](const Akonadi::Item &item) {
        applyItem(item);
    });
    connect(m_monitor, &Akonadi::Monitor::itemRemoved, this, [this](const Akonadi::Item &item) {
        removeItem(item.id());
    });
    connect(m_monitor, &Akonadi::Monitor::itemMoved, this, [this](const Akonadi::Item &item, const Akonadi::Collection &, const Akonadi::Collection &) {
        applyItem(item);
    });
    return true;
}

void AkonadiLoader::scheduleLoadCollections()
{
    if (!m_available) {
        return;
    }
    m_collectionsTimer.start();
}

void AkonadiLoader::loadCollections()
{
    if (!m_available) {
        return;
    }

    if (m_collectionFetchJob) {
        // Don't kill in-flight FetchCollections — that errors in akonadiserver.
        m_collectionsReloadPending = true;
        return;
    }

    m_collectionsReloadPending = false;
    setLoading(true);
    auto *job = new Akonadi::CollectionFetchJob(Akonadi::Collection::root(), Akonadi::CollectionFetchJob::Recursive, this);
    m_collectionFetchJob = job;

    auto scope = job->fetchScope();
    scope.setContentMimeTypes({
        QString::fromLatin1(KCalendarCore::Todo::todoMimeType()),
        QString::fromLatin1(KCalendarCore::Event::eventMimeType()),
    });
    scope.setIncludeStatistics(false);
    scope.setAncestorRetrieval(Akonadi::CollectionFetchScope::None);
    scope.setListFilter(Akonadi::CollectionFetchScope::Display);
    job->setFetchScope(scope);

    connect(job, &Akonadi::CollectionFetchJob::result, this, &AkonadiLoader::onCollectionsFetched);
}

void AkonadiLoader::onCollectionsFetched(KJob *kjob)
{
    auto *fetchJob = qobject_cast<Akonadi::CollectionFetchJob *>(kjob);
    if (m_collectionFetchJob == fetchJob) {
        m_collectionFetchJob = nullptr;
    }

    if (!fetchJob || kjob->error()) {
        setLoading(false);
        setErrorMessage(kjob ? kjob->errorString() : i18n("Failed to fetch collections."));
        logDebug(QStringLiteral("loadCollections failed: %1").arg(m_errorMessage));
        Q_EMIT fetchStatsChanged();
        if (m_collectionsReloadPending) {
            m_collectionsReloadPending = false;
            scheduleLoadCollections();
        }
        return;
    }

    QHash<qint64, QString> names;
    QList<Akonadi::Collection> collections;
    QList<Akonadi::Collection> eventCollections;
    splitCollections(fetchJob->collections(), &collections, &eventCollections, &names);

    m_shared.setCollections(collections, eventCollections, names);

    if (collections.isEmpty()) {
        setErrorMessage(i18n("No task lists found in Akonadi. Configure CalDAV in KOrganizer or Kalendar."));
    } else {
        setErrorMessage(QString());
    }

    if (m_collectionsReloadPending) {
        m_collectionsReloadPending = false;
        scheduleLoadCollections();
        return;
    }

    m_shared.markBusyChanged(); // fetched after the tasks, not beside them
    loadTasks();
}

void AkonadiLoader::loadTasks()
{
    if (!m_available) {
        return;
    }

    const QList<Akonadi::Collection> collections = enabledCollections();

    // Keep the in-process cache visible until fetches finish (badge / list stay filled).
    m_fetchSeenIds.clear();
    m_fetchOkCollections.clear();
    m_stats = FetchStats();

    logDebug(QStringLiteral("loadTasks: fetching from %1 enabled collections").arg(collections.size()));
    for (const Akonadi::Collection &collection : collections) {
        logDebug(QStringLiteral("  fetch collection id=%1 name=\"%2\"").arg(collection.id()).arg(m_shared.collectionNames().value(collection.id())));
    }

    if (collections.isEmpty()) {
        // Nothing enabled: drop settled tasks, keep optimistic/temp rows.
        for (auto it = m_shared.tasks().begin(); it != m_shared.tasks().end();) {
            if (!isSettled(*it, it.key())) {
                ++it;
                continue;
            }
            it = m_shared.tasks().erase(it);
        }
        setLoading(false);
        logDebug(QStringLiteral("loadTasks: no enabled collections"));
        m_shared.notifyTasksChanged();
        refreshBusyIfDue();
        return;
    }

    setLoading(true);
    m_pendingFetchJobs = collections.size();
    Q_EMIT fetchStatsChanged();

    for (const Akonadi::Collection &collection : collections) {
        fetchTodos(collection);
    }
}

// Two fetches per list: headers (id, MIME type), then the payload of the tasks only. A list
// that is a whole calendar holds mostly events: 529 tasks among 7506 items took ~1 s of
// main-thread parsing in one fetch, ~0.2 s in two.
void AkonadiLoader::fetchTodos(const Akonadi::Collection &collection)
{
    const qint64 collectionId = collection.id();
    auto *headers = new Akonadi::ItemFetchJob(collection, this);
    headers->fetchScope().setAncestorRetrieval(Akonadi::ItemFetchScope::None);
    connect(headers, &Akonadi::ItemFetchJob::result, this, [this, headers, collectionId](KJob *) {
        const QString error = fetchError(headers);
        if (!error.isEmpty()) {
            onItemsFetched({}, error, collectionId);
            return;
        }

        const Akonadi::Item::List todos = AkonadiItems::todos(headers->items());
        if (todos.isEmpty()) {
            onItemsFetched({}, QString(), collectionId);
            return;
        }

        auto *job = new Akonadi::ItemFetchJob(todos, this);
        configureItemFetchJob(job);
        connect(job, &Akonadi::ItemFetchJob::result, this, [this, job, collectionId](KJob *) {
            onItemsFetched(job->items(), fetchError(job), collectionId);
        });
    });
}

// `error` empty: the fetch succeeded (`items` may be empty).
void AkonadiLoader::onItemsFetched(const Akonadi::Item::List &items, const QString &error, qint64 collectionId)
{
    m_stats.items += items.size();
    logDebug(QStringLiteral("onItemsFetched collection=%1 items=%2 error=%3")
                 .arg(collectionId)
                 .arg(items.size())
                 .arg(error.isEmpty() ? QStringLiteral("none") : error));

    if (error.isEmpty()) {
        m_fetchOkCollections.insert(collectionId);
        for (const Akonadi::Item &item : items) {
            if (item.id() > 0) {
                m_fetchSeenIds.insert(item.id());
            }
            applyItem(item, collectionId);
        }
    } else if (m_errorMessage.isEmpty()) {
        setErrorMessage(error);
    }

    // Counted down after the items are in: the last job's items stay quiet too.
    --m_pendingFetchJobs;
    Q_EMIT fetchStatsChanged();
    if (m_pendingFetchJobs > 0) {
        return;
    }
    m_pendingFetchJobs = 0;
    pruneAfterWave();

    setLoading(false);
    logDebug(QStringLiteral("loadTasks complete: cache=%1 accepted=%2 rejected(payload=%3,todo=%4,disabled=%5,noCol=%6)")
                 .arg(m_shared.tasks().size())
                 .arg(m_stats.accepted)
                 .arg(m_stats.rejectedNoPayload)
                 .arg(m_stats.rejectedNotTodo)
                 .arg(m_stats.rejectedDisabled)
                 .arg(m_stats.rejectedNoCollection));
    Q_EMIT fetchStatsChanged();
    // The one rebuild of the wave: applyItem stays quiet while jobs are pending.
    m_shared.notifyTasksChanged();
    refreshBusyIfDue();
}

// Prune settled tasks that vanished from successfully fetched collections,
// or whose collection is no longer enabled. Failed collections keep their cache.
void AkonadiLoader::pruneAfterWave()
{
    QSet<qint64> enabledIds;
    for (const Akonadi::Collection &collection : enabledCollections()) {
        enabledIds.insert(collection.id());
    }
    for (auto it = m_shared.tasks().begin(); it != m_shared.tasks().end();) {
        if (!isSettled(*it, it.key())) {
            ++it;
            continue;
        }
        const qint64 col = it->item.parentCollection().id();
        const bool goneFromOkFetch = m_fetchOkCollections.contains(col) && !m_fetchSeenIds.contains(it.key());
        const bool collectionDisabled = !enabledIds.contains(col);
        if (goneFromOkFetch || collectionDisabled) {
            it = m_shared.tasks().erase(it);
        } else {
            ++it;
        }
    }
    m_fetchSeenIds.clear();
    m_fetchOkCollections.clear();
}

void AkonadiLoader::applyItem(const Akonadi::Item &item, qint64 fallbackCollectionId)
{
    if (!AkonadiItems::isTodo(item)) {
        ++m_stats.rejectedNotTodo;
        return;
    }

    qint64 collectionId = item.parentCollection().id();
    if (collectionId <= 0 && fallbackCollectionId > 0) {
        collectionId = fallbackCollectionId;
    }
    if (collectionId <= 0) {
        ++m_stats.rejectedNoCollection;
        return;
    }

    if (!isCollectionEnabled(collectionId)) {
        ++m_stats.rejectedDisabled;
        removeItem(item.id());
        return;
    }

    KCalendarCore::Todo::Ptr todo = todoFromPayload(item);
    if (!todo) {
        ++m_stats.rejectedNoPayload;
        return;
    }

    Akonadi::Item storedItem = item;
    if (storedItem.parentCollection().id() <= 0) {
        Akonadi::Collection parent(collectionId);
        storedItem.setParentCollection(parent);
    }

    const auto existing = m_shared.tasks().constFind(storedItem.id());
    if (existing != m_shared.tasks().cend() && cachedWins(*existing, item, todo)) {
        return;
    }

    if (!todo->uid().isEmpty()) {
        dropTempRows(m_shared, todo->uid());
    }

    ++m_stats.accepted;
    SharedTasks::Entry cached;
    cached.item = storedItem;
    cached.todo = cloneTodo(todo);
    m_shared.tasks().insert(storedItem.id(), cached);
    if (m_pendingFetchJobs == 0) {
        m_shared.notifyTasksChanged();
    }
}

void AkonadiLoader::removeItem(Akonadi::Item::Id itemId)
{
    if (m_shared.tasks().remove(itemId) && m_pendingFetchJobs == 0) {
        m_shared.notifyTasksChanged();
    }
}

void AkonadiLoader::setEnabledCollectionIds(const QList<qint64> &ids)
{
    const QSet<qint64> enabled(ids.cbegin(), ids.cend());
    if (enabled == m_enabledIds) {
        return;
    }
    m_enabledIds = enabled;
    loadTasks();
}

// Empty set: every task list. The list must be known, so an item of a list we do not show is dropped.
bool AkonadiLoader::isCollectionEnabled(qint64 collectionId) const
{
    if (!m_enabledIds.isEmpty()) {
        return m_enabledIds.contains(collectionId);
    }
    for (const Akonadi::Collection &collection : m_shared.collections()) {
        if (collection.id() == collectionId) {
            return true;
        }
    }
    return false;
}

QList<Akonadi::Collection> AkonadiLoader::enabledCollections() const
{
    QList<Akonadi::Collection> result;
    result.reserve(m_shared.collections().size());

    for (const Akonadi::Collection &collection : m_shared.collections()) {
        if (m_enabledIds.isEmpty() || m_enabledIds.contains(collection.id())) {
            result.append(Akonadi::Collection(collection.id()));
        }
    }

    return result;
}
