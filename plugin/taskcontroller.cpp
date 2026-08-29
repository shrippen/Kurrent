#include "taskcontroller.h"
#include "akonaditaskstore.h"
#include "memorytaskstore.h"
#include "taskcalendar.h"
#include "tasklogic.h"

#include <Akonadi/AgentManager>
#include <Akonadi/Collection>
#include <Akonadi/CollectionFetchJob>
#include <Akonadi/CollectionFetchScope>
#include <Akonadi/ItemFetchJob>
#include <Akonadi/ItemFetchScope>
#include <Akonadi/ServerManager>

#include <KCalendarCore/Event>
#include <KCalendarCore/Todo>

#include <KJob>

#include <QByteArray>
#include <QCursor>
#include <QDate>
#include <QDateTime>
#include <QLocale>
#include <QTime>
#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QScreen>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtGlobal>
#include <QDBusConnection>

#ifdef KURRENT_HAS_NOTIFICATIONS
#include <KNotification>
#endif

#ifdef KURRENT_HAS_GLOBALACCEL
#include <KGlobalAccel>
#include <QAction>
#include <QKeySequence>
#endif

#include "kurrentdbus.h"

#include <algorithm>

Q_LOGGING_CATEGORY(KURRENT_AKONADI, "com.github.shrippen.kurrent.akonadi", QtWarningMsg)

namespace
{
constexpr int kRebuildDelayMs = 50;
constexpr int kCollectionsReloadDelayMs = 250;
constexpr int kAkonadiRetryIntervalMs = 5000;
constexpr int kBusyEventRefreshMs = 5 * 60 * 1000;

bool isTodoItem(const Akonadi::Item &item)
{
    return item.hasPayload<KCalendarCore::Todo::Ptr>() || item.mimeType() == QLatin1String(KCalendarCore::Todo::todoMimeType());
}

KCalendarCore::Todo::Ptr todoFromPayload(const Akonadi::Item &item)
{
    if (!item.hasPayload<KCalendarCore::Todo::Ptr>()) {
        return {};
    }
    return item.payload<KCalendarCore::Todo::Ptr>();
}

void configureItemFetchJob(Akonadi::ItemFetchJob *job)
{
    auto scope = job->fetchScope();
    scope.fetchFullPayload();
    scope.fetchAllAttributes();
    scope.setFetchTags(true);
    // Never fetch ancestors: that issues FetchCollections per item.
    scope.setAncestorRetrieval(Akonadi::ItemFetchScope::None);
    job->setFetchScope(scope);
}

QDateTime dateTimeFromVariant(const QVariant &value)
{
    if (!value.isValid() || value.isNull()) {
        return {};
    }
    if (value.userType() == QMetaType::QDateTime) {
        return value.toDateTime();
    }
    if (value.userType() == QMetaType::QDate) {
        return QDateTime(value.toDate(), QTime(0, 0));
    }
    return value.toDateTime();
}

} // namespace

QHash<Akonadi::Item::Id, TaskController::CachedTask> TaskController::s_tasks;
QList<Akonadi::Collection> TaskController::s_collections;
QList<Akonadi::Collection> TaskController::s_eventCollections;
QHash<qint64, QString> TaskController::s_collectionNames;
QStringList TaskController::s_extraLabels;
QList<TaskController *> TaskController::s_instances;
qint64 TaskController::s_nextTempId = -2;
int TaskController::s_smokeStep = 0;
bool TaskController::s_smokeFinished = false;
TaskController *TaskController::s_smokeLeader = nullptr;

TaskController::TaskController(QObject *parent)
    : QObject(parent)
{
    s_instances.append(this);

    if (smokeTest()) {
        smokeTrace(QStringLiteral("KURRENT_SMOKE_CONTROLLER"));
    }

    m_rebuildTimer.setInterval(kRebuildDelayMs);
    m_rebuildTimer.setSingleShot(true);
    connect(&m_rebuildTimer, &QTimer::timeout, this, &TaskController::rebuildTaskList);

    m_collectionsTimer.setInterval(kCollectionsReloadDelayMs);
    m_collectionsTimer.setSingleShot(true);
    connect(&m_collectionsTimer, &QTimer::timeout, this, &TaskController::loadCollections);

    m_akonadiRetryTimer.setInterval(kAkonadiRetryIntervalMs);
    m_akonadiRetryTimer.setSingleShot(false);
    connect(&m_akonadiRetryTimer, &QTimer::timeout, this, &TaskController::refresh);

    m_reminderTimer.setInterval(30000);
    m_reminderTimer.setSingleShot(false);
    connect(&m_reminderTimer, &QTimer::timeout, this, &TaskController::checkReminders);
    m_reminderTimer.start();

    m_busyEventTimer.setInterval(kBusyEventRefreshMs);
    m_busyEventTimer.setSingleShot(false);
    connect(&m_busyEventTimer, &QTimer::timeout, this, &TaskController::refreshBusyEvents);

    // Akonadi jobs go through the store; MemoryTaskStore swaps in for unit tests.
    m_store = new AkonadiTaskStore(this);
    connect(m_store, &AbstractTaskStore::finished, this, &TaskController::onStoreFinished);

    hydrateFromCache();
    // D-Bus and GlobalAccel talk to the session bus; let QML finish constructing first.
    QTimer::singleShot(0, this, [this]() {
        registerSessionInterface();
        registerGlobalShortcuts();
    });
}

TaskController::~TaskController()
{
    s_instances.removeAll(this);
    if (s_smokeLeader == this) {
        s_smokeLeader = nullptr;
        for (TaskController *instance : s_instances) {
            Q_EMIT instance->smokeLeaderChanged();
        }
    }
}

void TaskController::setTaskStore(AbstractTaskStore *store)
{
    if (!store || store == m_store) {
        return;
    }

    disconnect(m_store, &AbstractTaskStore::finished, this, &TaskController::onStoreFinished);
    if (m_store && m_store->parent() == this) {
        m_store->deleteLater();
    }
    m_store = store;
    if (m_store->parent() == nullptr) {
        m_store->setParent(this);
    }
    connect(m_store, &AbstractTaskStore::finished, this, &TaskController::onStoreFinished);
}

void TaskController::resetSharedStateForTest()
{
    s_tasks.clear();
    s_collections.clear();
    s_eventCollections.clear();
    s_collectionNames.clear();
    s_extraLabels.clear();
    m_undo.clear();
    m_recreateAfterDelete.clear();
    m_collapsedUids.clear();
    m_applyingUndo = false;
    m_errorMessage.clear();
    m_collectionModel.setCollections({});
    m_eventCalendarModel.setCollections({});
    m_busyIntervals.clear();
    m_taskModel.setTasks({});
    m_akonadiAvailable = false;
    Q_EMIT undoChanged();
    Q_EMIT errorMessageChanged();
    updateEmptyKind();
}

void TaskController::setAkonadiAvailableForTest(bool available)
{
    if (m_akonadiAvailable == available) {
        return;
    }
    m_akonadiAvailable = available;
    Q_EMIT akonadiAvailableChanged();
    updateEmptyKind();
}

void TaskController::installTestCollections(const QList<Akonadi::Collection> &collections)
{
    s_collections = collections;
    s_collectionNames.clear();
    for (const Akonadi::Collection &collection : collections) {
        s_collectionNames.insert(collection.id(), collection.displayName());
    }
    m_collectionModel.setCollections(collections);
    m_collectionNames = s_collectionNames;
}

qint64 TaskController::installTestTask(qint64 id, const QString &summary, qint64 collectionId)
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setUid(QStringLiteral("test-uid-%1").arg(id));
    todo->setSummary(summary);

    Akonadi::Item item;
    item.setId(id);
    item.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    item.setPayload(todo);
    item.setParentCollection(Akonadi::Collection(collectionId));

    CachedTask cached;
    cached.item = item;
    cached.todo = todo;
    s_tasks.insert(id, cached);

    if (auto *memory = qobject_cast<MemoryTaskStore *>(m_store)) {
        memory->seedItem(item);
    }

    scheduleRebuildAll();
    return id;
}

bool TaskController::testTaskExists(qint64 id) const
{
    return s_tasks.contains(id);
}

bool TaskController::testTaskSyncing(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    return it != s_tasks.cend() && it->syncing;
}

bool TaskController::testTaskPendingDelete(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    return it != s_tasks.cend() && it->pendingDelete;
}

bool TaskController::testTaskCompleted(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    return it != s_tasks.cend() && it->todo && it->todo->isCompleted();
}

QString TaskController::testTaskSummary(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend() || !it->todo) {
        return {};
    }
    return it->todo->summary();
}

qint64 TaskController::testTaskCollectionId(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend()) {
        return -1;
    }
    return it->item.parentCollection().id();
}

int TaskController::testInflight(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    return it == s_tasks.cend() ? 0 : it->inflight;
}

int TaskController::buildNumber() const
{
#ifndef KURRENT_BUILD_NUMBER
    return 0;
#else
    return KURRENT_BUILD_NUMBER;
#endif
}

QString TaskController::pluginVersion() const
{
#ifndef KURRENT_RELEASE_VERSION
    return QString();
#else
    return QStringLiteral(KURRENT_RELEASE_VERSION);
#endif
}

bool TaskController::devBuild() const
{
#ifndef KURRENT_DEV_BUILD
    return false;
#else
    return KURRENT_DEV_BUILD;
#endif
}

bool TaskController::smokeTest() const
{
    const QByteArray value = qgetenv("KURRENT_SMOKE");
    return value == "1" || value.compare("true", Qt::CaseInsensitive) == 0;
}

int TaskController::smokeStep() const
{
    return s_smokeStep;
}

void TaskController::setSmokeStep(int step)
{
    if (s_smokeStep == step) {
        return;
    }
    s_smokeStep = step;
    for (TaskController *instance : s_instances) {
        Q_EMIT instance->smokeStepChanged();
    }
}

bool TaskController::smokeFinished() const
{
    return s_smokeFinished;
}

bool TaskController::smokeLeader()
{
    if (!smokeTest() || s_smokeFinished) {
        return false;
    }
    if (!s_smokeLeader) {
        s_smokeLeader = this;
        // Notify siblings so only one SmokeTest timer runs.
        for (TaskController *instance : s_instances) {
            if (instance != this) {
                Q_EMIT instance->smokeLeaderChanged();
            }
        }
    }
    return s_smokeLeader == this;
}

void TaskController::smokeTrace(const QString &message) const
{
    qWarning().noquote() << message;
    if (message.contains(QLatin1String("KURRENT_SMOKE_DONE"))) {
        if (!s_smokeFinished) {
            s_smokeFinished = true;
            for (TaskController *instance : s_instances) {
                Q_EMIT instance->smokeFinishedChanged();
            }
        }
    }
    const QString path = QString::fromLocal8Bit(qgetenv("KURRENT_SMOKE_LOG"));
    if (path.isEmpty()) {
        return;
    }
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        file.write(message.toUtf8());
        file.write("\n");
    }
}

QString TaskController::collectionNameForId(qint64 collectionId) const
{
    return m_collectionNames.value(collectionId, QString());
}

int TaskController::systemCursorSize() const
{
    bool ok = false;
    const int fromEnv = qEnvironmentVariableIntValue("XCURSOR_SIZE", &ok);
    if (ok && fromEnv > 0) {
        return fromEnv;
    }

    const QString configPath = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/kcminputrc");
    QSettings settings(configPath, QSettings::IniFormat);
    settings.beginGroup(QStringLiteral("Mouse"));
    const int fromPlasma = settings.value(QStringLiteral("cursorSize"), 24).toInt();
    return fromPlasma > 0 ? fromPlasma : 24;
}

QVariantMap TaskController::dragScreenLimits() const
{
    QScreen *screen = QGuiApplication::screenAt(QCursor::pos());
    if (!screen) {
        screen = QGuiApplication::primaryScreen();
    }

    QVariantMap limits;
    if (!screen) {
        return limits;
    }

    const QRect geometry = screen->geometry();
    const QRect available = screen->availableGeometry();
    limits.insert(QStringLiteral("right"), geometry.x() + geometry.width());
    // Bottom of the usable desktop (top of a bottom panel / taskbar).
    limits.insert(QStringLiteral("bottom"), available.y() + available.height());
    return limits;
}

QPointF TaskController::dragProxyGap(int cursorSize, int cursorShape) const
{
    const TaskLogic::CursorKind kind = cursorShape == static_cast<int>(Qt::ArrowCursor)
        ? TaskLogic::CursorKind::Arrow
        : TaskLogic::CursorKind::Other;
    return TaskLogic::dragProxyGap(cursorSize, kind);
}

QPointF TaskController::clampDragProxyOffset(qreal cursorX,
                                             qreal cursorY,
                                             qreal gapX,
                                             qreal gapY,
                                             qreal width,
                                             qreal height,
                                             qreal limitRight,
                                             qreal limitBottom) const
{
    return TaskLogic::clampDragProxyOffset(cursorX, cursorY, gapX, gapY, width, height, limitRight, limitBottom);
}

void TaskController::setCurrentView(const QString &view)
{
    if (m_currentView == view) {
        return;
    }
    m_currentView = view;
    scheduleRebuild();
    Q_EMIT currentViewChanged();
}

void TaskController::setManagementView(const QString &view)
{
    if (m_managementView == view) {
        return;
    }
    m_managementView = view;
    scheduleRebuild();
    Q_EMIT managementViewChanged();
}

void TaskController::setSearchQuery(const QString &query)
{
    if (m_searchQuery == query) {
        return;
    }
    m_searchQuery = query;
    scheduleRebuild();
    Q_EMIT searchQueryChanged();
}

void TaskController::setShowCompleted(bool show)
{
    if (m_showCompleted == show) {
        return;
    }
    m_showCompleted = show;
    scheduleRebuild();
    Q_EMIT showCompletedChanged();
}

void TaskController::setSelectedCollectionId(qint64 id)
{
    if (m_selectedCollectionId == id) {
        return;
    }
    m_selectedCollectionId = id;
    scheduleRebuild();
    Q_EMIT selectedCollectionIdChanged();
}

void TaskController::setSelectedLabel(const QString &label)
{
    if (m_selectedLabel == label) {
        return;
    }
    m_selectedLabel = label;
    scheduleRebuild();
    Q_EMIT selectedLabelChanged();
}

void TaskController::setSelectedPriority(int priority)
{
    const int normalized = (priority < 0) ? -1 : TaskLogic::priorityBand(priority);
    if (m_selectedPriority == normalized) {
        return;
    }
    m_selectedPriority = normalized;
    scheduleRebuild();
    Q_EMIT selectedPriorityChanged();
}

void TaskController::setSortMode(const QString &mode)
{
    QString normalized = mode.trimmed();
    if (normalized.isEmpty() || normalized == QLatin1String("default")) {
        normalized = QStringLiteral("priority,due,title");
    }
    if (m_sortMode == normalized) {
        return;
    }
    m_sortMode = normalized;
    scheduleRebuild();
    Q_EMIT sortModeChanged();
}

void TaskController::setCatchUpEnabled(bool enabled)
{
    if (m_catchUpEnabled == enabled) {
        return;
    }
    m_catchUpEnabled = enabled;
    scheduleRebuild();
    Q_EMIT catchUpSettingsChanged();
}

void TaskController::setCatchUpDays(int days)
{
    const int bounded = qBound(0, days, 365);
    if (m_catchUpDays == bounded) {
        return;
    }
    m_catchUpDays = bounded;
    scheduleRebuild();
    Q_EMIT catchUpSettingsChanged();
}

void TaskController::setMorningHour(int hour)
{
    const int bounded = qBound(0, hour, 23);
    if (m_morningHour == bounded) {
        return;
    }
    m_morningHour = bounded;
    scheduleRebuild();
    Q_EMIT catchUpSettingsChanged();
}

void TaskController::setAfternoonHour(int hour)
{
    const int bounded = qBound(0, hour, 23);
    if (m_afternoonHour == bounded) {
        return;
    }
    m_afternoonHour = bounded;
    scheduleRebuild();
    Q_EMIT catchUpSettingsChanged();
}

void TaskController::setEveningHour(int hour)
{
    const int bounded = qBound(0, hour, 23);
    if (m_eveningHour == bounded) {
        return;
    }
    m_eveningHour = bounded;
    scheduleRebuild();
    Q_EMIT catchUpSettingsChanged();
}

void TaskController::setDefaultDueMode(const QString &mode)
{
    const QString normalized = (mode == QLatin1String("today") || mode == QLatin1String("tomorrow"))
            ? mode
            : QStringLiteral("none");
    if (m_defaultDueMode == normalized) {
        return;
    }
    m_defaultDueMode = normalized;
    Q_EMIT defaultDueModeChanged();
}

void TaskController::setSearchTitleOnly(bool titleOnly)
{
    if (m_searchTitleOnly == titleOnly) {
        return;
    }
    m_searchTitleOnly = titleOnly;
    scheduleRebuild();
    Q_EMIT searchSettingsChanged();
}

void TaskController::setSearchCaseSensitive(bool sensitive)
{
    if (m_searchCaseSensitive == sensitive) {
        return;
    }
    m_searchCaseSensitive = sensitive;
    scheduleRebuild();
    Q_EMIT searchSettingsChanged();
}

void TaskController::setCompleteChildren(bool complete)
{
    if (m_completeChildren == complete) {
        return;
    }
    m_completeChildren = complete;
    Q_EMIT completeChildrenChanged();
}

void TaskController::setCountsExcludeCollapsed(bool exclude)
{
    if (m_countsExcludeCollapsed == exclude) {
        return;
    }
    m_countsExcludeCollapsed = exclude;
    Q_EMIT countsExcludeCollapsedChanged();
    scheduleRebuild();
}

void TaskController::setNotificationsEnabled(bool enabled)
{
    if (m_notificationsEnabled == enabled) {
        return;
    }
    m_notificationsEnabled = enabled;
    Q_EMIT notificationsEnabledChanged();
}

void TaskController::setDefaultReminderMinutes(int minutes)
{
    const int bounded = (minutes < 0) ? -1 : minutes;
    if (m_defaultReminderMinutes == bounded) {
        return;
    }
    m_defaultReminderMinutes = bounded;
    Q_EMIT defaultReminderMinutesChanged();
}

void TaskController::setQuietHoursEnabled(bool enabled)
{
    if (m_quietHoursEnabled == enabled) {
        return;
    }
    m_quietHoursEnabled = enabled;
    Q_EMIT quietHoursChanged();
}

void TaskController::setQuietHoursStart(int hour)
{
    const int bounded = qBound(0, hour, 23);
    if (m_quietHoursStart == bounded) {
        return;
    }
    m_quietHoursStart = bounded;
    Q_EMIT quietHoursChanged();
}

void TaskController::setQuietHoursEnd(int hour)
{
    const int bounded = qBound(0, hour, 23);
    if (m_quietHoursEnd == bounded) {
        return;
    }
    m_quietHoursEnd = bounded;
    Q_EMIT quietHoursChanged();
}

void TaskController::setSuppressRemindersDuringEvents(bool enabled)
{
    if (m_suppressRemindersDuringEvents == enabled) {
        return;
    }
    m_suppressRemindersDuringEvents = enabled;
    if (enabled) {
        m_busyEventTimer.start();
        scheduleRefreshBusyEvents();
    } else {
        m_busyEventTimer.stop();
        m_pendingBusyFetchJobs = 0;
        m_busyFetchIntervals.clear();
        m_busyIntervals.clear();
    }
    Q_EMIT eventBusySettingsChanged();
}

void TaskController::setBusyCalendarIds(const QString &ids)
{
    if (m_busyCalendarIds == ids) {
        return;
    }
    m_busyCalendarIds = ids;
    if (m_suppressRemindersDuringEvents) {
        scheduleRefreshBusyEvents();
    }
    Q_EMIT eventBusySettingsChanged();
}

void TaskController::setEnabledCollectionIds(const QVariantList &ids)
{
    QList<qint64> enabled;
    enabled.reserve(ids.size());
    for (const QVariant &value : ids) {
        enabled.append(value.toLongLong());
    }
    m_collectionModel.setEnabledIds(enabled);
    logDebug(QStringLiteral("setEnabledCollectionIds: %1 ids (%2)")
                 .arg(enabled.size())
                 .arg(m_collectionModel.hasCustomEnabledFilter() ? QStringLiteral("custom filter") : QStringLiteral("all")));
    loadTasks();
}

void TaskController::refresh()
{
    if (!initializeAkonadi()) {
        return;
    }
    loadCollections();
}

void TaskController::syncNow()
{
    if (!m_akonadiAvailable) {
        // Try to (re)connect; retry timer keeps trying if this still fails.
        refresh();
        if (!m_akonadiAvailable) {
            setErrorMessage(tr("Akonadi is not available."));
            return;
        }
    }

    setLoading(true);
    const QList<Akonadi::Collection> collections = enabledCollections();
    if (collections.isEmpty()) {
        setLoading(false);
        return;
    }

    for (const Akonadi::Collection &collection : collections) {
        Akonadi::AgentManager::self()->synchronizeCollection(collection);
    }

    setLoading(false);
    loadTasks();
}

void TaskController::createTask(const QString &summary, qint64 collectionId)
{
    if (!m_akonadiAvailable || summary.trimmed().isEmpty()) {
        return;
    }

    Akonadi::Collection collection = collectionById(collectionId);
    if (!CollectionListModel::isTaskWritable(collection)) {
        collection = collectionById(m_selectedCollectionId);
    }
    if (!CollectionListModel::isTaskWritable(collection)) {
        collection = firstWritableCollection();
    }

    if (!CollectionListModel::isTaskWritable(collection)) {
        setErrorMessage(tr("No writable task list selected."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    const TaskLogic::QuickAdd parsed = TaskLogic::parseQuickAdd(summary, QDate::currentDate(), QTime::currentTime(),
                                                                quickAddContext(QString(), QVariantList()));
    if (parsed.collectionId > 0) {
        const Akonadi::Collection fromKeyword = collectionById(parsed.collectionId);
        if (CollectionListModel::isTaskWritable(fromKeyword)) {
            collection = fromKeyword;
        }
    }
    todo->setSummary(parsed.summary.isEmpty() ? summary.trimmed() : parsed.summary);
    if (parsed.hasDue) {
        todo->setDtDue(parsed.due);
        todo->setAllDay(parsed.allDay);
    } else {
        const QDateTime fallback = TaskLogic::defaultDueForMode(m_defaultDueMode, QDate::currentDate());
        if (fallback.isValid()) {
            todo->setDtDue(fallback);
            todo->setAllDay(true);
        }
    }
    if (todo->hasDueDate() && m_defaultReminderMinutes >= 0) {
        TaskCalendar::setReminderMinutes(todo, m_defaultReminderMinutes);
    }
    if (parsed.priority > 0) {
        todo->setPriority(parsed.priority);
    }
    if (!parsed.labels.isEmpty()) {
        todo->setCategories(parsed.labels);
    }

    Akonadi::Item jobItem;
    jobItem.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    jobItem.setPayload<KCalendarCore::Todo::Ptr>(todo);

    const qint64 tempId = s_nextTempId--;
    Akonadi::Item cacheItem = jobItem;
    cacheItem.setId(tempId);
    cacheItem.setParentCollection(collection);

    CachedTask cached;
    cached.item = cacheItem;
    cached.todo = todo;
    cached.syncing = true;
    cached.inflight = 1;
    s_tasks.insert(tempId, cached);
    scheduleRebuildAll();

    submitCreate(jobItem, collection, tempId);
}

void TaskController::submitCreate(const Akonadi::Item &jobItem, const Akonadi::Collection &collection, qint64 tempId)
{
    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Create;
    req.clientId = tempId;
    req.item = jobItem;
    req.collection = collection;
    m_store->submit(req);
}

QVariantMap TaskController::parseQuickAdd(const QString &text, const QString &uiLanguage, const QVariantList &projects) const
{
    const TaskLogic::QuickAdd parsed = TaskLogic::parseQuickAdd(text, QDate::currentDate(), QTime::currentTime(),
                                                                quickAddContext(uiLanguage, projects));
    return quickAddToVariant(parsed);
}

QVariantMap TaskController::suggestQuickAdd(const QString &text, int cursor, const QString &uiLanguage, const QVariantList &projects) const
{
    const TaskLogic::QuickAddSuggestResult suggested = TaskLogic::suggestQuickAdd(text, cursor, quickAddContext(uiLanguage, projects));
    QVariantMap out;
    out.insert(QStringLiteral("tokenStart"), suggested.tokenStart);
    out.insert(QStringLiteral("tokenEnd"), suggested.tokenEnd);
    QVariantList items;
    for (const TaskLogic::QuickAddSuggestion &s : suggested.items) {
        QVariantMap m;
        m.insert(QStringLiteral("kind"), s.kind);
        m.insert(QStringLiteral("insertText"), s.insertText);
        m.insert(QStringLiteral("value"), s.value);
        m.insert(QStringLiteral("collectionId"), s.collectionId);
        m.insert(QStringLiteral("priority"), s.priority);
        m.insert(QStringLiteral("score"), s.score);
        items.append(m);
    }
    out.insert(QStringLiteral("items"), items);
    return out;
}

TaskLogic::QuickAddContext TaskController::quickAddContext(const QString &uiLanguage, const QVariantList &projects) const
{
    TaskLogic::QuickAddContext ctx;
    ctx.uiLanguage = uiLanguage.isEmpty() ? QLocale::system().name() : uiLanguage;
    ctx.labels = m_availableLabels;
    if (!projects.isEmpty()) {
        for (const QVariant &v : projects) {
            const QVariantMap m = v.toMap();
            TaskLogic::QuickAddProject p;
            p.id = m.value(QStringLiteral("collectionId")).toLongLong();
            p.name = m.value(QStringLiteral("name")).toString();
            if (p.id > 0 && !p.name.isEmpty()) {
                ctx.projects.append(p);
            }
        }
        return ctx;
    }
    for (int i = 0; i < m_collectionModel.count(); ++i) {
        if (!m_collectionModel.enabledAt(i) || !m_collectionModel.writableAt(i)) {
            continue;
        }
        TaskLogic::QuickAddProject p;
        p.id = m_collectionModel.collectionIdAt(i);
        p.name = m_collectionModel.nameAt(i);
        ctx.projects.append(p);
    }
    return ctx;
}

QVariantMap TaskController::quickAddToVariant(const TaskLogic::QuickAdd &parsed) const
{
    QVariantMap out;
    out.insert(QStringLiteral("summary"), parsed.summary);
    out.insert(QStringLiteral("hasDue"), parsed.hasDue);
    out.insert(QStringLiteral("allDay"), parsed.allDay);
    out.insert(QStringLiteral("due"), parsed.due);
    out.insert(QStringLiteral("priority"), parsed.priority);
    out.insert(QStringLiteral("labels"), parsed.labels);
    out.insert(QStringLiteral("collectionId"), parsed.collectionId);
    QVariantList spans;
    for (const TaskLogic::QuickAddSpan &span : parsed.spans) {
        QVariantMap m;
        m.insert(QStringLiteral("start"), span.start);
        m.insert(QStringLiteral("length"), span.length);
        m.insert(QStringLiteral("kind"), span.kind);
        m.insert(QStringLiteral("value"), span.value);
        spans.append(m);
    }
    out.insert(QStringLiteral("spans"), spans);
    return out;
}

void TaskController::rescheduleTask(qint64 itemId, const QString &preset)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Reschedule, *cache));
    const QDateTime currentDue = (todo->hasDueDate() && todo->dtDue().isValid()) ? todo->dtDue() : QDateTime();
    const TaskLogic::DaySpan daySpan = todo->allDay() ? TaskLogic::DaySpan::AllDay : TaskLogic::DaySpan::Timed;
    const QDateTime next = TaskLogic::rescheduleDue(currentDue, daySpan, QDateTime::currentDateTime(), preset);
    if (!next.isValid()) {
        return;
    }
    todo->setDtDue(next);
    if (preset == QLatin1String("15m") || preset == QLatin1String("1h") || preset == QLatin1String("4h")) {
        todo->setAllDay(false);
    }
    persistTodo(cache->item, todo);
}

QString TaskController::joinUrlFor(const QString &description, const QString &location) const
{
    return TaskLogic::joinUrl(description, location);
}

TaskController::CachedTask *TaskController::prepareEdit(qint64 itemId)
{
    if (itemId < 0) {
        return nullptr;
    }
    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end() || !it->todo) {
        return nullptr;
    }
    if (!it->revertTodo) {
        it->revertTodo = KCalendarCore::Todo::Ptr(static_cast<KCalendarCore::Todo *>(it->todo->clone()));
        it->revertCollectionId = it->item.parentCollection().id();
    }
    return &*it;
}

void TaskController::finishSync(qint64 itemId, SyncResult ok, const QString &errorString)
{
    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end()) {
        if (ok == SyncResult::Error && !errorString.isEmpty()) {
            setErrorMessage(errorString);
            Q_EMIT error(errorString);
        }
        return;
    }

    it->inflight = qMax(0, it->inflight - 1);
    if (it->inflight > 0) {
        if (ok == SyncResult::Error && !errorString.isEmpty()) {
            setErrorMessage(errorString);
            Q_EMIT error(errorString);
        }
        return;
    }

    if (ok == SyncResult::Error) {
        // Roll back optimistic edit to the snapshot from prepareEdit().
        if (it->revertTodo) {
            it->todo = it->revertTodo;
            it->item.setPayload<KCalendarCore::Todo::Ptr>(it->todo);
            if (it->revertCollectionId > 0) {
                it->item.setParentCollection(Akonadi::Collection(it->revertCollectionId));
            }
        }
        it->pendingDelete = false;
        if (!errorString.isEmpty()) {
            setErrorMessage(errorString);
            Q_EMIT error(errorString);
        }
    }

    it->revertTodo.clear();
    it->revertCollectionId = -1;
    it->syncing = false;
    it->inflight = 0;
    scheduleRebuildAll();
}

void TaskController::onStoreFinished(const AbstractTaskStore::Result &result)
{
    switch (result.kind) {
    case AbstractTaskStore::Kind::Create:
        s_tasks.remove(result.clientId);
        if (!result.ok) {
            scheduleRebuildAll();
            setErrorMessage(result.errorString);
            Q_EMIT error(result.errorString);
            return;
        }
        upsertTask(result.item, result.collectionId);
        scheduleRebuildAll();
        return;

    case AbstractTaskStore::Kind::Delete:
        if (!result.ok) {
            m_recreateAfterDelete.remove(result.clientId);
            finishSync(result.clientId, SyncResult::Error, result.errorString);
            return;
        }
        s_tasks.remove(result.clientId);
        if (m_recreateAfterDelete.contains(result.clientId)) {
            const TaskLogic::UndoRecord record = m_recreateAfterDelete.take(result.clientId);
            recreateTask(record);
            return;
        }
        scheduleRebuildAll();
        return;

    case AbstractTaskStore::Kind::Modify:
    case AbstractTaskStore::Kind::Move:
        finishSync(result.clientId,
                   result.ok ? SyncResult::Ok : SyncResult::Error,
                   result.errorString);
        return;
    }
}

void TaskController::persistTodo(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId)
{
    const qint64 itemId = item.id();
    if (itemId < 0 || !todo) {
        return;
    }

    auto it = s_tasks.find(itemId);
    if (it != s_tasks.end()) {
        it->todo = todo;
        it->item.setPayload<KCalendarCore::Todo::Ptr>(todo);
        it->syncing = true;
        it->inflight += 1;
    }
    scheduleRebuildAll();

    Akonadi::Item modifiedItem = item;
    modifiedItem.setPayload<KCalendarCore::Todo::Ptr>(todo);

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Modify;
    req.clientId = itemId;
    req.item = modifiedItem;
    req.moveAfterModifyId = moveToCollectionId;
    m_store->submit(req);
}

Akonadi::Collection TaskController::collectionById(qint64 collectionId) const
{
    if (collectionId <= 0) {
        return {};
    }
    for (const Akonadi::Collection &collection : s_collections) {
        if (collection.id() == collectionId) {
            return collection;
        }
    }
    return {};
}

Akonadi::Collection TaskController::firstWritableCollection() const
{
    const QList<qint64> enabledIds = m_collectionModel.enabledIds();
    for (const Akonadi::Collection &collection : s_collections) {
        if (!enabledIds.contains(collection.id())) {
            continue;
        }
        if (CollectionListModel::isTaskWritable(collection)) {
            return collection;
        }
    }
    return {};
}

QString TaskController::recurrencePresetFromTodo(const KCalendarCore::Todo::Ptr &todo)
{
    return TaskCalendar::recurrencePresetFromTodo(todo);
}

void TaskController::applyRecurrencePreset(const KCalendarCore::Todo::Ptr &todo, const QString &preset)
{
    TaskCalendar::applyRecurrencePreset(todo, preset, QDate::currentDate());
}

TaskEntry TaskController::makeTaskEntry(const CachedTask &cached, int indentLevel, bool hasChildren) const
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
    entry.recurring = todo->recurs();
    entry.allDay = todo->allDay();
    entry.percentComplete = todo->percentComplete();
    entry.location = todo->location();
    entry.status = static_cast<int>(todo->status());
    entry.secrecy = static_cast<int>(todo->secrecy());
    entry.recurrencePreset = recurrencePresetFromTodo(todo);
    entry.joinUrl = TaskLogic::joinUrl(entry.description, entry.location);
    entry.categories = todo->categories();
    entry.collectionId = cached.item.parentCollection().id();
    entry.collectionName = m_collectionNames.value(entry.collectionId, cached.item.parentCollection().displayName());
    entry.indentLevel = indentLevel;
    entry.hasChildren = hasChildren;
    entry.treeCollapsed = false;
    entry.treeHidden = false;
    entry.reminderMinutes = TaskCalendar::reminderMinutesFromTodo(todo);
    entry.section = sectionFromTodo(todo);
    entry.syncing = cached.syncing;
    entry.pendingDelete = cached.pendingDelete;
    return entry;
}

void TaskController::updateTask(qint64 itemId,
                                const QString &summary,
                                const QString &description,
                                const QDateTime &dueDate,
                                bool clearDue,
                                int priority,
                                const QStringList &categories)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    todo->setSummary(summary.trimmed());
    todo->setDescription(description);
    todo->setPriority(priority);
    todo->setCategories(categories);

    if (clearDue) {
        todo->setDtDue(QDateTime());
    } else if (dueDate.isValid()) {
        todo->setDtDue(dueDate);
    }

    persistTodo(cache->item, todo);
}

void TaskController::updateTaskFull(qint64 itemId, const QVariantMap &fields)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    const Akonadi::Item originalItem = cache->item;

    if (fields.contains(QStringLiteral("summary"))) {
        todo->setSummary(fields.value(QStringLiteral("summary")).toString().trimmed());
    }
    if (fields.contains(QStringLiteral("description"))) {
        todo->setDescription(fields.value(QStringLiteral("description")).toString());
    }
    if (fields.contains(QStringLiteral("priority"))) {
        todo->setPriority(fields.value(QStringLiteral("priority")).toInt());
    }
    if (fields.contains(QStringLiteral("categories"))) {
        todo->setCategories(fields.value(QStringLiteral("categories")).toStringList());
    }
    if (fields.contains(QStringLiteral("location"))) {
        todo->setLocation(fields.value(QStringLiteral("location")).toString());
    }
    if (fields.contains(QStringLiteral("allDay"))) {
        todo->setAllDay(fields.value(QStringLiteral("allDay")).toBool());
    }
    if (fields.contains(QStringLiteral("status"))) {
        todo->setStatus(static_cast<KCalendarCore::Incidence::Status>(fields.value(QStringLiteral("status")).toInt()));
    }
    if (fields.contains(QStringLiteral("secrecy"))) {
        todo->setSecrecy(static_cast<KCalendarCore::Incidence::Secrecy>(fields.value(QStringLiteral("secrecy")).toInt()));
    }

    const bool clearDue = fields.value(QStringLiteral("clearDue")).toBool();
    if (clearDue) {
        todo->setDtDue(QDateTime());
    } else if (fields.contains(QStringLiteral("dueDate"))) {
        const QDateTime due = dateTimeFromVariant(fields.value(QStringLiteral("dueDate")));
        if (due.isValid()) {
            todo->setDtDue(due);
        }
    }

    const bool clearStart = fields.value(QStringLiteral("clearStart")).toBool();
    if (clearStart) {
        todo->setDtStart(QDateTime());
    } else if (fields.contains(QStringLiteral("startDate"))) {
        const QDateTime start = dateTimeFromVariant(fields.value(QStringLiteral("startDate")));
        if (start.isValid()) {
            todo->setDtStart(start);
        }
    }

    if (fields.contains(QStringLiteral("completed"))) {
        const bool completed = fields.value(QStringLiteral("completed")).toBool();
        TaskCalendar::completeTodo(todo, completed ? TaskCalendar::CompleteAction::Mark : TaskCalendar::CompleteAction::Unmark, QDateTime::currentDateTime());
        if (!fields.contains(QStringLiteral("percentComplete")) && !todo->recurs()) {
            todo->setPercentComplete(completed ? 100 : 0);
        }
    }
    if (fields.contains(QStringLiteral("percentComplete"))) {
        todo->setPercentComplete(fields.value(QStringLiteral("percentComplete")).toInt());
    }

    if (fields.contains(QStringLiteral("recurrencePreset"))) {
        applyRecurrencePreset(todo, fields.value(QStringLiteral("recurrencePreset")).toString());
    }
    if (fields.contains(QStringLiteral("section"))) {
        TaskCalendar::setSection(todo, fields.value(QStringLiteral("section")).toString());
    }
    if (fields.contains(QStringLiteral("reminderMinutes"))) {
        TaskCalendar::setReminderMinutes(todo, fields.value(QStringLiteral("reminderMinutes")).toInt());
    }

    qint64 moveToCollectionId = -1;
    if (fields.contains(QStringLiteral("collectionId"))) {
        const qint64 targetCollectionId = fields.value(QStringLiteral("collectionId")).toLongLong();
        if (targetCollectionId > 0 && targetCollectionId != originalItem.parentCollection().id()) {
            const Akonadi::Collection destination = collectionById(targetCollectionId);
            if (CollectionListModel::isTaskWritable(destination)) {
                moveToCollectionId = targetCollectionId;
                cache->item.setParentCollection(destination);
            } else {
                setErrorMessage(tr("This project cannot accept tasks."));
                Q_EMIT error(m_errorMessage);
            }
        }
    }

    if (fields.contains(QStringLiteral("parentUid"))) {
        const qint64 effectiveCollectionId = moveToCollectionId > 0
            ? moveToCollectionId
            : cache->item.parentCollection().id();
        applyParentUid(cache, fields.value(QStringLiteral("parentUid")).toString(), effectiveCollectionId);
    }

    persistTodo(originalItem, todo, moveToCollectionId);
}

void TaskController::setTaskParent(qint64 itemId, const QString &parentUid)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    if (!applyParentUid(cache, parentUid, cache->item.parentCollection().id())) {
        return;
    }

    persistTodo(cache->item, cache->todo);
}

QVariantList TaskController::parentCandidates(qint64 itemId, qint64 collectionId) const
{
    QVariantList out;
    if (collectionId <= 0) {
        return out;
    }

    QString selfUid;
    const auto selfIt = s_tasks.constFind(itemId);
    if (selfIt != s_tasks.cend() && selfIt->todo) {
        selfUid = selfIt->todo->uid();
    }

    QHash<QString, QString> parentByUid;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo) {
            parentByUid.insert(it->todo->uid(), it->todo->relatedTo());
        }
    }

    QSet<QString> forbidden;
    if (!selfUid.isEmpty()) {
        forbidden.insert(selfUid);
        const QStringList descendants = TaskLogic::descendantUids(selfUid, parentByUid);
        for (const QString &uid : descendants) {
            forbidden.insert(uid);
        }
    }

    struct ParentRow {
        QString summary;
        QString uid;
        int priority = 0;
        QStringList categories;
    };
    QList<ParentRow> rows;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (!it->todo || it->pendingDelete) {
            continue;
        }
        if (it->item.parentCollection().id() != collectionId) {
            continue;
        }
        const QString uid = it->todo->uid();
        if (forbidden.contains(uid)) {
            continue;
        }
        ParentRow row;
        row.uid = uid;
        row.summary = it->todo->summary().trimmed();
        if (row.summary.isEmpty()) {
            row.summary = tr("(Untitled)");
        }
        row.priority = it->todo->priority();
        row.categories = it->todo->categories();
        rows.append(row);
    }

    std::sort(rows.begin(), rows.end(), [](const ParentRow &a, const ParentRow &b) {
        return QString::compare(a.summary, b.summary, Qt::CaseInsensitive) < 0;
    });

    for (const auto &row : rows) {
        out.append(QVariantMap{
            {QStringLiteral("uid"), row.uid},
            {QStringLiteral("summary"), row.summary},
            {QStringLiteral("priority"), row.priority},
            {QStringLiteral("categories"), row.categories},
        });
    }
    return out;
}

bool TaskController::applyParentUid(CachedTask *cache, const QString &parentUid, qint64 collectionId)
{
    if (!cache || !cache->todo) {
        return false;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    const QString trimmedParent = parentUid.trimmed();
    if (trimmedParent.isEmpty()) {
        if (todo->relatedTo().isEmpty()) {
            return true;
        }
        todo->setRelatedTo(QString());
        return true;
    }

    if (trimmedParent == todo->uid()) {
        setErrorMessage(tr("A task cannot be its own parent."));
        Q_EMIT error(m_errorMessage);
        return false;
    }
    if (wouldCreateParentCycle(cache->item.id(), trimmedParent)) {
        setErrorMessage(tr("Cannot create a circular task hierarchy."));
        Q_EMIT error(m_errorMessage);
        return false;
    }

    const CachedTask *parentCache = nullptr;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo && it->todo->uid() == trimmedParent) {
            parentCache = &(*it);
            break;
        }
    }
    if (!parentCache) {
        setErrorMessage(tr("Parent task not found."));
        Q_EMIT error(m_errorMessage);
        return false;
    }
    if (collectionId > 0 && parentCache->item.parentCollection().id() != collectionId) {
        setErrorMessage(tr("Parent task must be in the same project."));
        Q_EMIT error(m_errorMessage);
        return false;
    }

    if (todo->relatedTo() == trimmedParent) {
        return true;
    }
    todo->setRelatedTo(trimmedParent);
    return true;
}

void TaskController::addTaskCategory(qint64 itemId, const QString &category)
{
    const QString trimmed = category.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    QStringList categories = todo->categories();
    if (categories.contains(trimmed)) {
        return;
    }
    categories.append(trimmed);
    todo->setCategories(categories);
    persistTodo(cache->item, todo);
}

void TaskController::setTaskPriority(qint64 itemId, int priority)
{
    const int normalized = TaskLogic::priorityBand(priority);
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    if (TaskLogic::priorityBand(todo->priority()) == normalized) {
        return;
    }
    todo->setPriority(normalized);
    persistTodo(cache->item, todo);
}

void TaskController::moveTaskToCollection(qint64 itemId, qint64 collectionId)
{
    if (collectionId <= 0) {
        return;
    }

    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    if (cache->item.parentCollection().id() == collectionId) {
        return;
    }

    pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Move, *cache));

    const Akonadi::Collection destination = collectionById(collectionId);
    if (!CollectionListModel::isTaskWritable(destination)) {
        setErrorMessage(tr("This project cannot accept tasks."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    const Akonadi::Item jobItem = cache->item;
    cache->item.setParentCollection(destination);
    cache->syncing = true;
    cache->inflight += 1;
    scheduleRebuildAll();

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Move;
    req.clientId = itemId;
    req.item = jobItem;
    req.collection = destination;
    m_store->submit(req);
}

void TaskController::setTaskCompleted(qint64 itemId, bool completed)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Complete, *cache));
    TaskCalendar::completeTodo(todo, completed ? TaskCalendar::CompleteAction::Mark : TaskCalendar::CompleteAction::Unmark, QDateTime::currentDateTime());
    persistTodo(cache->item, todo);

    if (completed && m_completeChildren && todo) {
        QHash<QString, QString> parentByUid;
        QHash<QString, qint64> idByUid;
        for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
            if (!it->todo) {
                continue;
            }
            parentByUid.insert(it->todo->uid(), it->todo->relatedTo());
            idByUid.insert(it->todo->uid(), it.key());
        }
        const QStringList kids = TaskLogic::descendantUids(todo->uid(), parentByUid);
        const bool wasApplying = m_applyingUndo;
        m_applyingUndo = true;
        for (const QString &uid : kids) {
            const qint64 childId = idByUid.value(uid, -1);
            if (childId < 0) {
                continue;
            }
            CachedTask *child = prepareEdit(childId);
            if (!child || !child->todo || child->todo->isCompleted()) {
                continue;
            }
            TaskCalendar::completeTodo(child->todo, TaskCalendar::CompleteAction::Mark, QDateTime::currentDateTime());
            persistTodo(child->item, child->todo);
        }
        m_applyingUndo = wasApplying;
    }
}

void TaskController::deleteTask(qint64 itemId)
{
    if (itemId < 0) {
        s_tasks.remove(itemId);
        scheduleRebuildAll();
        return;
    }

    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        return;
    }

    pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Delete, *cache));

    const Akonadi::Item jobItem = cache->item;
    cache->pendingDelete = true;
    cache->syncing = true;
    cache->inflight += 1;
    scheduleRebuildAll();

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Delete;
    req.clientId = itemId;
    req.item = jobItem;
    m_store->submit(req);
}

void TaskController::undo()
{
    if (!m_undo.canUndo()) {
        return;
    }

    const TaskLogic::UndoRecord record = m_undo.take();
    Q_EMIT undoChanged();
    m_applyingUndo = true;

    if (record.kind == TaskLogic::UndoRecord::Kind::Delete) {
        auto it = s_tasks.find(record.itemId);
        if (it != s_tasks.end() && it->pendingDelete) {
            m_recreateAfterDelete.insert(record.itemId, record);
            it->pendingDelete = false;
            it->syncing = it->inflight > 1;
            scheduleRebuildAll();
            m_applyingUndo = false;
            return;
        }
        recreateTask(record);
        m_applyingUndo = false;
        return;
    }

    if (record.kind == TaskLogic::UndoRecord::Kind::Move) {
        if (record.collectionId > 0) {
            moveTaskToCollection(record.itemId, record.collectionId);
        }
        m_applyingUndo = false;
        return;
    }

    CachedTask *cache = prepareEdit(record.itemId);
    if (!cache || !cache->todo) {
        m_applyingUndo = false;
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    if (record.kind == TaskLogic::UndoRecord::Kind::Complete) {
        todo->setCompleted(record.completed);
        todo->setPercentComplete(record.percentComplete);
        if (record.start.isValid()) {
            todo->setDtStart(record.start);
        }
        if (record.hadDue) {
            todo->setDtDue(record.due, true);
            todo->setAllDay(record.allDay);
        }
        persistTodo(cache->item, todo);
    } else if (record.kind == TaskLogic::UndoRecord::Kind::Reschedule) {
        if (record.hadDue) {
            todo->setDtDue(record.due, true);
            todo->setAllDay(record.allDay);
        } else {
            todo->setDtDue(QDateTime());
        }
        persistTodo(cache->item, todo);
    }
    m_applyingUndo = false;
}

void TaskController::toggleTreeCollapsed(const QString &uid)
{
    if (uid.isEmpty()) {
        return;
    }
    if (m_collapsedUids.contains(uid)) {
        m_collapsedUids.remove(uid);
    } else {
        m_collapsedUids.insert(uid);
    }
    scheduleRebuild();
}

TaskLogic::UndoRecord TaskController::snapshotUndo(TaskLogic::UndoRecord::Kind kind, const CachedTask &cache) const
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
    return record;
}

void TaskController::pushUndo(TaskLogic::UndoRecord record)
{
    if (m_applyingUndo || record.kind == TaskLogic::UndoRecord::Kind::None) {
        return;
    }
    m_undo.push(record);
    Q_EMIT undoChanged();
}

void TaskController::recreateTask(const TaskLogic::UndoRecord &record)
{
    Akonadi::Collection collection = collectionById(record.collectionId);
    if (!CollectionListModel::isTaskWritable(collection)) {
        collection = firstWritableCollection();
    }
    if (!CollectionListModel::isTaskWritable(collection)) {
        setErrorMessage(tr("No writable task list selected."));
        Q_EMIT error(m_errorMessage);
        return;
    }

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

    Akonadi::Item jobItem;
    jobItem.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    jobItem.setPayload<KCalendarCore::Todo::Ptr>(todo);

    const qint64 tempId = s_nextTempId--;
    Akonadi::Item cacheItem = jobItem;
    cacheItem.setId(tempId);
    cacheItem.setParentCollection(collection);

    CachedTask cached;
    cached.item = cacheItem;
    cached.todo = todo;
    cached.syncing = true;
    cached.inflight = 1;
    s_tasks.insert(tempId, cached);
    scheduleRebuildAll();

    submitCreate(jobItem, collection, tempId);
}

void TaskController::logDebug(const QString &message)
{
    qCDebug(KURRENT_AKONADI) << message;
}

void TaskController::updateDebugInfo(int builtTasks, int filteredTasks, int filteredOutCompleted, int filteredOutView, int filteredOutSearch)
{
    const QList<qint64> enabledIds = m_collectionModel.enabledIds();
    QStringList collectionLines;
    for (int row = 0; row < m_collectionModel.rowCount() && row < 8; ++row) {
        const qint64 id = m_collectionModel.collectionIdAt(row);
        collectionLines.append(QStringLiteral("%1:%2").arg(id).arg(m_collectionNames.value(id)));
    }
    if (m_collectionModel.rowCount() > 8) {
        collectionLines.append(QStringLiteral("… +%1 more").arg(m_collectionModel.rowCount() - 8));
    }

    QStringList enabledIdStrings;
    for (qint64 id : enabledIds) {
        enabledIdStrings.append(QString::number(id));
    }

    const QString info = QStringLiteral(
        "Akonadi: %1 | Collections: %2 | Enabled: %3 (%4)\n"
        "Last fetch: items=%5 accepted=%6 | rejected: notTodo=%7 noPayload=%8 disabled=%9 noCollection=%10\n"
        "Cache: %11 tasks | Built: %12 | Shown: %13 (view=%14)\n"
        "Filters dropped: completed=%15 view=%16 search=%17 | showCompleted=%18 search=\"%19\"\n"
        "Collections: %20")
                             .arg(m_akonadiAvailable ? QStringLiteral("ok") : QStringLiteral("offline"))
                             .arg(m_collectionModel.rowCount())
                             .arg(enabledIds.size())
                             .arg(m_collectionModel.hasCustomEnabledFilter()
                                      ? QStringLiteral("custom: %1").arg(enabledIdStrings.join(QLatin1Char(',')))
                                      : QStringLiteral("all"))
                             .arg(m_lastFetchItemCount)
                             .arg(m_lastFetchAccepted)
                             .arg(m_lastFetchRejectedNotTodo)
                             .arg(m_lastFetchRejectedNoPayload)
                             .arg(m_lastFetchRejectedDisabled)
                             .arg(m_lastFetchRejectedNoCollection)
                             .arg(s_tasks.size())
                             .arg(builtTasks)
                             .arg(filteredTasks)
                             .arg(m_currentView)
                             .arg(filteredOutCompleted)
                             .arg(filteredOutView)
                             .arg(filteredOutSearch)
                             .arg(m_showCompleted)
                             .arg(m_searchQuery)
                             .arg(collectionLines.join(QStringLiteral(", ")));

    if (m_debugInfo == info) {
        return;
    }
    m_debugInfo = info;
    Q_EMIT debugInfoChanged();
}

void TaskController::setLoading(bool loading)
{
    if (m_loading == loading) {
        return;
    }
    m_loading = loading;
    Q_EMIT loadingChanged();
    updateEmptyKind();
}

void TaskController::setErrorMessage(const QString &message)
{
    if (m_errorMessage == message) {
        return;
    }
    m_errorMessage = message;
    Q_EMIT errorMessageChanged();
    updateEmptyKind();
}

void TaskController::updateEmptyKind()
{
    int visibleCount = 0;
    for (int i = 0; i < m_taskModel.count(); ++i) {
        if (!m_taskModel.taskAt(i).treeHidden) {
            ++visibleCount;
        }
    }
    const QString kind = TaskLogic::emptyKind(
        m_loading ? TaskLogic::LoadState::Loading : TaskLogic::LoadState::Idle,
        m_akonadiAvailable ? TaskLogic::BackendState::Online : TaskLogic::BackendState::Offline,
        m_collectionModel.count(),
        visibleCount,
        m_errorMessage.isEmpty() ? TaskLogic::ErrorPresence::None : TaskLogic::ErrorPresence::Present);
    if (m_emptyKind == kind) {
        return;
    }
    m_emptyKind = kind;
    Q_EMIT emptyKindChanged();
}

void TaskController::scheduleAkonadiRetry()
{
    if (!m_akonadiRetryTimer.isActive()) {
        logDebug(QStringLiteral("scheduleAkonadiRetry: retrying every %1 ms").arg(kAkonadiRetryIntervalMs));
        m_akonadiRetryTimer.start();
    }
}

void TaskController::ensureServerWatch()
{
    if (m_serverWatchConnected) {
        return;
    }
    m_serverWatchConnected = true;
    connect(Akonadi::ServerManager::self(), &Akonadi::ServerManager::stateChanged,
            this, [this](Akonadi::ServerManager::State state) {
                if (state == Akonadi::ServerManager::Running && !m_monitor) {
                    refresh();
                }
            });
}

bool TaskController::initializeAkonadi()
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
            && (state != Akonadi::ServerManager::NotRunning || !m_akonadiRetryTimer.isActive());

        m_akonadiAvailable = false;
        setLoading(comingUp);
        setErrorMessage(QString());
        logDebug(QStringLiteral("initializeAkonadi: waiting for Akonadi (state=%1 comingUp=%2)")
                     .arg(static_cast<int>(state))
                     .arg(comingUp));
        Q_EMIT akonadiAvailableChanged();
        updateEmptyKind();
        scheduleAkonadiRetry();
        return false;
    }

    return attachAkonadiMonitor();
}

bool TaskController::attachAkonadiMonitor()
{
    if (m_monitor) {
        return true;
    }

    m_akonadiRetryTimer.stop();
    m_akonadiAvailable = true;
    setErrorMessage(QString());
    logDebug(QStringLiteral("initializeAkonadi: Akonadi running, creating monitor"));
    Q_EMIT akonadiAvailableChanged();
    updateEmptyKind();

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
        upsertTask(item);
    });
    connect(m_monitor, &Akonadi::Monitor::itemChanged, this, [this](const Akonadi::Item &item) {
        upsertTask(item);
    });
    connect(m_monitor, &Akonadi::Monitor::itemRemoved, this, [this](const Akonadi::Item &item) {
        removeTask(item.id());
    });
    connect(m_monitor, &Akonadi::Monitor::itemMoved, this, [this](const Akonadi::Item &item, const Akonadi::Collection &, const Akonadi::Collection &) {
        upsertTask(item);
    });
    return true;
}

void TaskController::scheduleLoadCollections()
{
    if (!m_akonadiAvailable) {
        return;
    }
    m_collectionsTimer.start();
}

void TaskController::loadCollections()
{
    if (!m_akonadiAvailable) {
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

    connect(job, &Akonadi::CollectionFetchJob::result, this, [this, job](KJob *kjob) {
        if (m_collectionFetchJob == job) {
            m_collectionFetchJob = nullptr;
        }

        auto *fetchJob = qobject_cast<Akonadi::CollectionFetchJob *>(kjob);
        if (!fetchJob || kjob->error()) {
            setLoading(false);
            setErrorMessage(kjob ? kjob->errorString() : tr("Failed to fetch collections."));
            logDebug(QStringLiteral("loadCollections failed: %1").arg(m_errorMessage));
            updateDebugInfo(0, 0, 0, 0, 0);
            if (m_collectionsReloadPending) {
                m_collectionsReloadPending = false;
                scheduleLoadCollections();
            }
            return;
        }

        m_collectionNames.clear();
        const QList<Akonadi::Collection> fetched = fetchJob->collections();
        QList<Akonadi::Collection> collections;
        QList<Akonadi::Collection> eventCollections;
        collections.reserve(fetched.size());
        eventCollections.reserve(fetched.size());
        logDebug(QStringLiteral("loadCollections: found %1 calendar collections").arg(fetched.size()));
        for (const Akonadi::Collection &collection : fetched) {
            logDebug(QStringLiteral("  collection id=%1 name=\"%2\" mimes=%3 rights=%4")
                         .arg(collection.id())
                         .arg(collection.displayName())
                         .arg(collection.contentMimeTypes().join(QLatin1Char(',')))
                         .arg(static_cast<int>(collection.rights())));
            if (CollectionListModel::isTaskCollection(collection)) {
                collections.append(collection);
                m_collectionNames.insert(collection.id(), collection.displayName());
            }
            if (CollectionListModel::isEventCollection(collection)) {
                eventCollections.append(collection);
                if (!m_collectionNames.contains(collection.id())) {
                    m_collectionNames.insert(collection.id(), collection.displayName());
                }
            }
        }
        logDebug(QStringLiteral("loadCollections: keeping %1 task collections, %2 event calendars")
                     .arg(collections.size())
                     .arg(eventCollections.size()));

        s_collections = collections;
        s_eventCollections = eventCollections;
        s_collectionNames = m_collectionNames;
        m_collectionModel.setCollections(collections);
        m_eventCalendarModel.setCollections(eventCollections);
        for (TaskController *other : s_instances) {
            if (other != this) {
                other->m_collectionNames = s_collectionNames;
                other->m_collectionModel.setCollections(s_collections);
                other->m_eventCalendarModel.setCollections(s_eventCollections);
            }
        }

        if (collections.isEmpty()) {
            setErrorMessage(tr("No task lists found in Akonadi. Configure CalDAV in KOrganizer or Kalendar."));
        } else {
            setErrorMessage(QString());
        }

        if (m_collectionsReloadPending) {
            m_collectionsReloadPending = false;
            scheduleLoadCollections();
            return;
        }

        if (m_suppressRemindersDuringEvents) {
            scheduleRefreshBusyEvents();
        }

        loadTasks();
    });
}

void TaskController::loadTasks()
{
    if (!m_akonadiAvailable) {
        return;
    }

    const QList<Akonadi::Collection> collections = enabledCollections();

    // Keep the in-process cache visible until fetches finish (badge / list stay filled).
    m_fetchSeenIds.clear();
    m_fetchOkCollections.clear();

    m_lastFetchItemCount = 0;
    m_lastFetchAccepted = 0;
    m_lastFetchRejectedNotTodo = 0;
    m_lastFetchRejectedNoPayload = 0;
    m_lastFetchRejectedDisabled = 0;
    m_lastFetchRejectedNoCollection = 0;

    logDebug(QStringLiteral("loadTasks: fetching from %1 enabled collections").arg(collections.size()));
    for (const Akonadi::Collection &collection : collections) {
        logDebug(QStringLiteral("  fetch collection id=%1 name=\"%2\"").arg(collection.id()).arg(m_collectionNames.value(collection.id())));
    }

    if (collections.isEmpty()) {
        // Nothing enabled: drop settled tasks, keep optimistic/temp rows.
        for (auto it = s_tasks.begin(); it != s_tasks.end();) {
            if (it.key() < 0 || it->syncing || it->pendingDelete || it->inflight > 0) {
                ++it;
                continue;
            }
            it = s_tasks.erase(it);
        }
        setLoading(false);
        logDebug(QStringLiteral("loadTasks: no enabled collections"));
        scheduleRebuild();
        return;
    }

    setLoading(true);
    m_pendingFetchJobs = collections.size();

    for (const Akonadi::Collection &collection : collections) {
        const qint64 collectionId = collection.id();
        auto *job = new Akonadi::ItemFetchJob(collection, this);
        configureItemFetchJob(job);
        connect(job, &Akonadi::ItemFetchJob::result, this, [this, collectionId](KJob *kjob) {
            onItemsFetched(kjob, collectionId);
        });
    }
}

void TaskController::onItemsFetched(KJob *job, qint64 collectionId)
{
    --m_pendingFetchJobs;

    if (auto *fetchJob = qobject_cast<Akonadi::ItemFetchJob *>(job)) {
        const int itemCount = fetchJob->items().size();
        m_lastFetchItemCount += itemCount;
        logDebug(QStringLiteral("onItemsFetched collection=%1 items=%2 error=%3")
                     .arg(collectionId)
                     .arg(itemCount)
                     .arg(job->error() ? job->errorString() : QStringLiteral("none")));

        if (!job->error()) {
            m_fetchOkCollections.insert(collectionId);
            for (const Akonadi::Item &item : fetchJob->items()) {
                if (item.id() > 0) {
                    m_fetchSeenIds.insert(item.id());
                }
                upsertTask(item, collectionId);
            }
        } else if (m_errorMessage.isEmpty()) {
            setErrorMessage(job->errorString());
        }
    }

    if (m_pendingFetchJobs <= 0) {
        m_pendingFetchJobs = 0;

        // Prune settled tasks that vanished from successfully fetched collections,
        // or whose collection is no longer enabled. Failed collections keep their cache.
        QSet<qint64> enabledIds;
        for (const Akonadi::Collection &collection : enabledCollections()) {
            enabledIds.insert(collection.id());
        }
        for (auto it = s_tasks.begin(); it != s_tasks.end();) {
            if (it.key() < 0 || it->syncing || it->pendingDelete || it->inflight > 0) {
                ++it;
                continue;
            }
            const qint64 col = it->item.parentCollection().id();
            const bool goneFromOkFetch = m_fetchOkCollections.contains(col) && !m_fetchSeenIds.contains(it.key());
            const bool collectionDisabled = !enabledIds.contains(col);
            if (goneFromOkFetch || collectionDisabled) {
                it = s_tasks.erase(it);
            } else {
                ++it;
            }
        }
        m_fetchSeenIds.clear();
        m_fetchOkCollections.clear();

        setLoading(false);
        logDebug(QStringLiteral("loadTasks complete: cache=%1 accepted=%2 rejected(payload=%3,todo=%4,disabled=%5,noCol=%6)")
                     .arg(s_tasks.size())
                     .arg(m_lastFetchAccepted)
                     .arg(m_lastFetchRejectedNoPayload)
                     .arg(m_lastFetchRejectedNotTodo)
                     .arg(m_lastFetchRejectedDisabled)
                     .arg(m_lastFetchRejectedNoCollection));
        scheduleRebuild();
    }
}

void TaskController::upsertTask(const Akonadi::Item &item, qint64 fallbackCollectionId)
{
    if (!isTodoItem(item)) {
        ++m_lastFetchRejectedNotTodo;
        return;
    }

    qint64 collectionId = item.parentCollection().id();
    if (collectionId <= 0 && fallbackCollectionId > 0) {
        collectionId = fallbackCollectionId;
    }
    if (collectionId <= 0) {
        ++m_lastFetchRejectedNoCollection;
        return;
    }

    if (!isCollectionEnabled(collectionId)) {
        ++m_lastFetchRejectedDisabled;
        removeTask(item.id());
        return;
    }

    KCalendarCore::Todo::Ptr todo = todoFromPayload(item);
    if (!todo) {
        ++m_lastFetchRejectedNoPayload;
        return;
    }

    Akonadi::Item storedItem = item;
    if (storedItem.parentCollection().id() <= 0) {
        Akonadi::Collection parent(collectionId);
        storedItem.setParentCollection(parent);
    }

    const auto existing = s_tasks.find(storedItem.id());
    if (existing != s_tasks.end() && existing->syncing) {
        return;
    }

    if (!todo->uid().isEmpty()) {
        const QString uid = todo->uid();
        for (auto it = s_tasks.begin(); it != s_tasks.end();) {
            if (it.key() < 0 && it->todo && it->todo->uid() == uid) {
                it = s_tasks.erase(it);
            } else {
                ++it;
            }
        }
    }

    ++m_lastFetchAccepted;
    CachedTask cached;
    cached.item = storedItem;
    cached.todo = todo;
    s_tasks.insert(storedItem.id(), cached);
    if (m_pendingFetchJobs == 0) {
        scheduleRebuild();
    }
}

void TaskController::removeTask(Akonadi::Item::Id itemId)
{
    if (s_tasks.remove(itemId) && m_pendingFetchJobs == 0) {
        scheduleRebuild();
    }
}

void TaskController::scheduleRebuild()
{
    if (!m_rebuildTimer.isActive()) {
        m_rebuildTimer.start();
    }
}

QList<Akonadi::Collection> TaskController::enabledCollections() const
{
    const QList<qint64> enabledIds = m_collectionModel.enabledIds();
    QList<Akonadi::Collection> result;
    result.reserve(enabledIds.size());

    for (int row = 0; row < m_collectionModel.rowCount(); ++row) {
        const qint64 collectionId = m_collectionModel.collectionIdAt(row);
        if (enabledIds.contains(collectionId)) {
            result.append(Akonadi::Collection(collectionId));
        }
    }

    return result;
}

bool TaskController::isCollectionEnabled(qint64 collectionId) const
{
    return m_collectionModel.enabledIds().contains(collectionId);
}

void TaskController::rebuildTaskList()
{
    QList<TaskEntry> allTasks;
    allTasks.reserve(s_tasks.size());
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (!it->todo) {
            continue;
        }
        allTasks.append(makeTaskEntry(it.value(), 0, false));
    }

    // Filter first (hierarchy-aware for search/sidebar), then flatten. Collapse is
    // skipped while those filters are active so a matching child under a collapsed
    // parent still appears with its ancestors.

    TaskLogic::FilterState filters;
    filters.currentView = m_currentView;
    filters.searchQuery = m_searchQuery;
    filters.showCompleted = m_showCompleted;
    filters.selectedCollectionId = m_selectedCollectionId;
    filters.selectedLabel = m_selectedLabel;
    filters.selectedPriority = m_selectedPriority;
    filters.catchUpEnabled = m_catchUpEnabled;
    filters.catchUpDays = m_catchUpDays;
    filters.morningHour = m_morningHour;
    filters.afternoonHour = m_afternoonHour;
    filters.eveningHour = m_eveningHour;
    filters.searchScope = m_searchTitleOnly ? TaskLogic::SearchScope::TitleOnly : TaskLogic::SearchScope::All;
    filters.searchCase = m_searchCaseSensitive ? TaskLogic::SearchCase::Sensitive : TaskLogic::SearchCase::Insensitive;

    const bool hierarchyAware = m_currentView == QLatin1String("completed")
            || !m_searchQuery.trimmed().isEmpty()
            || m_selectedCollectionId >= 0
            || !m_selectedLabel.isEmpty()
            || m_selectedPriority >= 0;

    const TaskLogic::VisibleFilterResult filtered = TaskLogic::filterVisibleTasks(allTasks, filters, QDate::currentDate());
    const QSet<QString> collapseForList = hierarchyAware ? QSet<QString>() : m_collapsedUids;
    QList<TaskEntry> tasks = TaskLogic::flattenTree(filtered.tasks, m_sortMode, collapseForList);

    // Sidebar/badge counts: default includes collapsed subtasks so collapsing does not
    // change numbers. Optional: count only visible (non-collapsed / non-hidden) rows.
    const QList<TaskEntry> flatForCounts = TaskLogic::flattenTree(allTasks, m_sortMode, m_collapsedUids);
    const QList<TaskEntry> &countSource = m_countsExcludeCollapsed ? flatForCounts : allTasks;
    m_collectionModel.setTaskCounts(TaskLogic::collectionTaskCounts(countSource));
    m_taskModel.setTasks(tasks);
    updatePendingCount(countSource);
    updateAvailableLabels(allTasks);
    updateCounts(countSource);
    publishSharedCache();
    updateEmptyKind();

    updateDebugInfo(flatForCounts.size(),
                    tasks.size(),
                    filtered.filteredOutCompleted,
                    filtered.filteredOutView,
                    filtered.filteredOutSearch);
}

bool TaskController::wouldCreateParentCycle(qint64 itemId, const QString &parentUid) const
{
    const auto draggedIt = s_tasks.constFind(itemId);
    if (draggedIt == s_tasks.cend() || !draggedIt->todo) {
        return true;
    }

    QHash<QString, QString> parentByUid;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo) {
            parentByUid.insert(it->todo->uid(), it->todo->relatedTo());
        }
    }
    return TaskLogic::wouldCreateParentCycle(draggedIt->todo->uid(), parentUid, parentByUid);
}

bool TaskController::taskMatchesView(const TaskEntry &task) const
{
    return taskMatchesViewId(task, m_currentView) && taskMatchesFilters(task);
}

bool TaskController::taskMatchesFilters(const TaskEntry &task) const
{
    return TaskLogic::matchesFilters(task, m_selectedCollectionId, m_selectedLabel, m_selectedPriority);
}

bool TaskController::taskMatchesViewId(const TaskEntry &task, const QString &viewId) const
{
    return TaskLogic::matchesView(task, viewId, QDate::currentDate());
}

bool TaskController::taskMatchesSearch(const TaskEntry &task) const
{
    return TaskLogic::matchesSearch(task, m_searchQuery,
        m_searchTitleOnly ? TaskLogic::SearchScope::TitleOnly : TaskLogic::SearchScope::All,
        m_searchCaseSensitive ? TaskLogic::SearchCase::Sensitive : TaskLogic::SearchCase::Insensitive);
}

Akonadi::Item TaskController::itemById(qint64 itemId) const
{
    return s_tasks.value(itemId).item;
}

KCalendarCore::Todo::Ptr TaskController::todoFromItem(const Akonadi::Item &item) const
{
    return todoFromPayload(item);
}

QString TaskController::sectionFromTodo(const KCalendarCore::Todo::Ptr &todo) const
{
    return TaskCalendar::sectionFromTodo(todo);
}

void TaskController::updatePendingCount(const QList<TaskEntry> &tasks)
{
    const int pending = TaskLogic::pendingRootCount(tasks);
    if (m_pendingCount == pending) {
        return;
    }
    m_pendingCount = pending;
    Q_EMIT pendingCountChanged();
}

void TaskController::updateAvailableLabels(const QList<TaskEntry> &tasks)
{
    const QStringList sorted = TaskLogic::collectAvailableLabels(tasks, s_extraLabels);
    if (m_availableLabels == sorted) {
        return;
    }
    m_availableLabels = sorted;
    Q_EMIT availableLabelsChanged();
}

void TaskController::updateCounts(const QList<TaskEntry> &tasks)
{
    TaskLogic::FilterState filters;
    filters.currentView = m_currentView;
    filters.searchQuery = m_searchQuery;
    filters.showCompleted = m_showCompleted;
    filters.selectedCollectionId = m_selectedCollectionId;
    filters.selectedLabel = m_selectedLabel;
    filters.selectedPriority = m_selectedPriority;
    filters.catchUpEnabled = m_catchUpEnabled;
    filters.catchUpDays = m_catchUpDays;
    filters.morningHour = m_morningHour;
    filters.afternoonHour = m_afternoonHour;
    filters.eveningHour = m_eveningHour;
    filters.searchScope = m_searchTitleOnly ? TaskLogic::SearchScope::TitleOnly : TaskLogic::SearchScope::All;
    filters.searchCase = m_searchCaseSensitive ? TaskLogic::SearchCase::Sensitive : TaskLogic::SearchCase::Insensitive;

    const TaskLogic::SidebarCounts counts = TaskLogic::computeCounts(tasks, filters, s_extraLabels, QDate::currentDate());

    if (m_labelTaskCounts != counts.totalLabels) {
        m_labelTaskCounts = counts.totalLabels;
        Q_EMIT labelTaskCountsChanged();
    }
    if (m_viewTaskCounts != counts.viewCounts || m_sidebarProjectCounts != counts.sidebarProjects
        || m_sidebarLabelCounts != counts.sidebarLabels || m_sidebarPriorityCounts != counts.sidebarPriorities) {
        m_viewTaskCounts = counts.viewCounts;
        m_sidebarProjectCounts = counts.sidebarProjects;
        m_sidebarLabelCounts = counts.sidebarLabels;
        m_sidebarPriorityCounts = counts.sidebarPriorities;
        Q_EMIT sidebarCountsChanged();
    }
}

void TaskController::publishSharedCache()
{
    s_collectionNames = m_collectionNames;
}

void TaskController::scheduleRebuildAll()
{
    for (TaskController *controller : s_instances) {
        if (controller) {
            controller->scheduleRebuild();
        }
    }
}

bool TaskController::hydrateFromCache()
{
    if (s_collections.isEmpty() && s_tasks.isEmpty() && s_extraLabels.isEmpty()) {
        return false;
    }
    m_collectionNames = s_collectionNames;
    if (!s_collections.isEmpty()) {
        m_collectionModel.setCollections(s_collections);
    }
    if (!s_eventCollections.isEmpty()) {
        m_eventCalendarModel.setCollections(s_eventCollections);
    }
    scheduleRebuild();
    return true;
}

void TaskController::createLabel(const QString &name)
{
    if (!TaskLogic::canCreateLabel(name, m_availableLabels, s_extraLabels)) {
        return;
    }
    s_extraLabels.append(name.trimmed());
    scheduleRebuildAll();
}

void TaskController::deleteLabel(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    s_extraLabels.removeAll(trimmed);

    if (!m_akonadiAvailable) {
        initializeAkonadi();
    }

    QList<qint64> toUpdate;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo && it->todo->categories().contains(trimmed)) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        CachedTask *cache = prepareEdit(itemId);
        if (!cache) {
            continue;
        }
        QStringList categories = cache->todo->categories();
        categories.removeAll(trimmed);
        cache->todo->setCategories(categories);
        persistTodo(cache->item, cache->todo);
    }

    scheduleRebuildAll();
}

void TaskController::renameLabel(const QString &from, const QString &to)
{
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (!TaskLogic::canRenameLabel(source, dest, m_availableLabels, s_extraLabels)) {
        return;
    }

    for (int i = 0; i < s_extraLabels.size(); ++i) {
        if (s_extraLabels.at(i) == source) {
            s_extraLabels[i] = dest;
        }
    }
    s_extraLabels.removeAll(source);
    if (!s_extraLabels.contains(dest)) {
        s_extraLabels.append(dest);
    }

    QList<qint64> toUpdate;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo && it->todo->categories().contains(source)) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        CachedTask *cache = prepareEdit(itemId);
        if (!cache) {
            continue;
        }
        cache->todo->setCategories(TaskLogic::renameLabel(cache->todo->categories(), source, dest));
        persistTodo(cache->item, cache->todo);
    }
    scheduleRebuildAll();
}

void TaskController::snoozeTask(qint64 itemId, const QString &preset)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }
    pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Reschedule, *cache));
    TaskCalendar::snoozeReminder(cache->todo, preset, QDateTime::currentDateTime());
    persistTodo(cache->item, cache->todo);
}

QString TaskController::renameSeparatedList(const QString &raw, const QString &from, const QString &to, const QString &separator) const
{
    return TaskLogic::renameToken(raw, from, to, separator);
}

QString TaskController::setColorOverride(const QString &raw, const QString &key, const QString &color) const
{
    return TaskLogic::setColorOverride(raw, key, color);
}

QString TaskController::moveColorKey(const QString &raw, const QString &from, const QString &to) const
{
    QVariantMap map = TaskLogic::parseColorMap(raw);
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (source.isEmpty() || dest.isEmpty() || !map.contains(source)) {
        return TaskLogic::serializeColorMap(map);
    }
    const QString color = map.value(source).toString();
    map.remove(source);
    map.insert(dest, color);
    return TaskLogic::serializeColorMap(map);
}

QStringList TaskController::mergeOrderedKeys(const QString &raw, const QString &defaultsCsv, const QString &separator) const
{
    return TaskLogic::mergeOrderedKeys(TaskLogic::parseTokens(raw, separator),
                                       TaskLogic::parseTokens(defaultsCsv, QStringLiteral(",")));
}

QStringList TaskController::visibleOrderedKeys(const QString &orderRaw, const QString &hiddenRaw, const QString &defaultsCsv, const QString &orderSep, const QString &hiddenSep) const
{
    const QStringList defaults = TaskLogic::parseTokens(defaultsCsv, QStringLiteral(","));
    const QStringList ordered = TaskLogic::mergeOrderedKeys(TaskLogic::parseTokens(orderRaw, orderSep), defaults);
    return TaskLogic::visibleOrderedKeys(ordered, TaskLogic::parseTokens(hiddenRaw, hiddenSep));
}

QString TaskController::moveOrderedKey(const QString &raw, const QString &key, int delta, const QString &defaultsCsv, const QString &separator) const
{
    const QStringList defaults = TaskLogic::parseTokens(defaultsCsv, QStringLiteral(","));
    const QStringList ordered = TaskLogic::mergeOrderedKeys(TaskLogic::parseTokens(raw, separator), defaults);
    return TaskLogic::joinTokens(TaskLogic::moveOrderedKey(ordered, key, delta), separator);
}

QString TaskController::toggleToken(const QString &raw, const QString &token, const QString &separator) const
{
    return TaskLogic::toggleToken(raw, token, separator);
}

void TaskController::registerSessionInterface()
{
    static bool registered = false;
    if (registered) {
        return;
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }
    if (!bus.registerService(QStringLiteral("org.github.shrippen.Kurrent"))) {
        return;
    }
    new KurrentDBusAdaptor(this);
    if (!bus.registerObject(QStringLiteral("/Kurrent"), this)) {
        return;
    }
    registered = true;
}

void TaskController::broadcastDbusShow()
{
    for (TaskController *controller : s_instances) {
        Q_EMIT controller->dbusShowRequested();
    }
}

void TaskController::broadcastDbusAddTask(const QString &summary)
{
    for (TaskController *controller : s_instances) {
        Q_EMIT controller->dbusAddTaskRequested(summary);
    }
}

void TaskController::broadcastDbusOpenView(const QString &view)
{
    for (TaskController *controller : s_instances) {
        Q_EMIT controller->dbusOpenViewRequested(view);
    }
}

void TaskController::registerGlobalShortcuts()
{
#ifdef KURRENT_HAS_GLOBALACCEL
    static bool registered = false;
    if (registered) {
        return;
    }
    auto *showAction = new QAction(this);
    showAction->setObjectName(QStringLiteral("show-kurrent"));
    showAction->setText(tr("Show Kurrent"));
    KGlobalAccel::self()->setDefaultShortcut(showAction, {QKeySequence(QStringLiteral("Meta+Shift+K"))});
    KGlobalAccel::self()->setShortcut(showAction, {QKeySequence(QStringLiteral("Meta+Shift+K"))});
    connect(showAction, &QAction::triggered, this, []() {
        TaskController::broadcastDbusShow();
    });

    auto *addAction = new QAction(this);
    addAction->setObjectName(QStringLiteral("add-kurrent-task"));
    addAction->setText(tr("Add Kurrent task"));
    KGlobalAccel::self()->setDefaultShortcut(addAction, {QKeySequence(QStringLiteral("Meta+Shift+N"))});
    KGlobalAccel::self()->setShortcut(addAction, {QKeySequence(QStringLiteral("Meta+Shift+N"))});
    connect(addAction, &QAction::triggered, this, []() {
        TaskController::broadcastDbusAddTask(QString());
    });
    registered = true;
#else
    return;
#endif
}

QList<Akonadi::Collection> TaskController::busyEventCollections() const
{
    QList<Akonadi::Collection> result;
    result.reserve(s_eventCollections.size());
    for (const Akonadi::Collection &collection : s_eventCollections) {
        if (TaskLogic::isEnabledCsv(m_busyCalendarIds, collection.id())) {
            result.append(collection);
        }
    }
    return result;
}

bool TaskController::isInBusyEvent(const QDateTime &when) const
{
    if (!m_suppressRemindersDuringEvents || m_busyIntervals.isEmpty()) {
        return false;
    }
    return TaskCalendar::isBusyAt(when, m_busyIntervals);
}

void TaskController::scheduleRefreshBusyEvents()
{
    if (!m_suppressRemindersDuringEvents || !m_akonadiAvailable) {
        return;
    }
    QTimer::singleShot(0, this, &TaskController::refreshBusyEvents);
}

void TaskController::refreshBusyEvents()
{
    if (!m_suppressRemindersDuringEvents || !m_akonadiAvailable) {
        m_busyIntervals.clear();
        return;
    }

    const QList<Akonadi::Collection> collections = busyEventCollections();
    if (collections.isEmpty()) {
        m_busyIntervals.clear();
        return;
    }

    if (m_pendingBusyFetchJobs > 0) {
        return;
    }

    const QDateTime now = QDateTime::currentDateTime();
    const QDateTime rangeStart = now.addDays(-1);
    const QDateTime rangeEnd = now.addDays(2);

    m_busyFetchIntervals.clear();
    m_pendingBusyFetchJobs = collections.size();

    for (const Akonadi::Collection &collection : collections) {
        auto *job = new Akonadi::ItemFetchJob(collection, this);
        configureItemFetchJob(job);
        connect(job, &Akonadi::ItemFetchJob::result, this, [this, rangeStart, rangeEnd](KJob *kjob) {
            onBusyEventsFetched(kjob, rangeStart, rangeEnd);
        });
    }
}

void TaskController::onBusyEventsFetched(KJob *job, const QDateTime &rangeStart, const QDateTime &rangeEnd)
{
    if (!m_suppressRemindersDuringEvents) {
        return;
    }

    --m_pendingBusyFetchJobs;

    if (auto *fetchJob = qobject_cast<Akonadi::ItemFetchJob *>(job)) {
        if (!job->error()) {
            for (const Akonadi::Item &item : fetchJob->items()) {
                if (item.mimeType() != QLatin1String(KCalendarCore::Event::eventMimeType())
                    && !item.hasPayload<KCalendarCore::Event::Ptr>()) {
                    continue;
                }
                if (!item.hasPayload<KCalendarCore::Event::Ptr>()) {
                    continue;
                }
                const KCalendarCore::Event::Ptr event = item.payload<KCalendarCore::Event::Ptr>();
                TaskCalendar::appendBusyIntervals(event, rangeStart, rangeEnd, &m_busyFetchIntervals);
            }
        }
    }

    if (m_pendingBusyFetchJobs > 0) {
        return;
    }

    m_pendingBusyFetchJobs = 0;
    m_busyIntervals = m_busyFetchIntervals;
    m_busyFetchIntervals.clear();
    for (TaskController *other : s_instances) {
        if (other != this) {
            other->m_busyIntervals = m_busyIntervals;
        }
    }
}

void TaskController::checkReminders()
{
    if (!m_notificationsEnabled || !m_akonadiAvailable) {
        return;
    }
    const QDateTime now = QDateTime::currentDateTime();
    if (TaskLogic::inQuietHours(now.time(), m_quietHoursStart, m_quietHoursEnd,
        m_quietHoursEnabled ? TaskLogic::QuietHoursMode::Enabled : TaskLogic::QuietHoursMode::Disabled)) {
        return;
    }
    if (isInBusyEvent(now)) {
        return;
    }
    const QDateTime from = m_lastReminderScan.isValid() ? m_lastReminderScan : now.addSecs(-45);
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (!it->todo || it->todo->isCompleted()) {
            continue;
        }
        const QDateTime when = TaskCalendar::nextReminderTime(it->todo, from);
        if (!when.isValid() || when > now || when <= from) {
            continue;
        }
        const QDateTime last = m_lastNotifiedReminder.value(it.key());
        if (last.isValid() && last == when) {
            continue;
        }
        m_lastNotifiedReminder.insert(it.key(), when);
        notifyReminder(it.key(), it->todo->summary(), when);
    }
    m_lastReminderScan = now;
}

void TaskController::notifyReminder(qint64 itemId, const QString &summary, const QDateTime &when)
{
#ifdef KURRENT_HAS_NOTIFICATIONS
    auto *notification = new KNotification(QStringLiteral("taskReminder"), KNotification::CloseOnTimeout, this);
    notification->setTitle(summary.isEmpty() ? tr("Task reminder") : summary);
    notification->setText(when.isValid() ? tr("Due %1").arg(QLocale().toString(when, QLocale::ShortFormat)) : tr("A task is due."));
    KNotificationAction *snooze15 = notification->addAction(tr("15 minutes"));
    KNotificationAction *snoozeHour = notification->addAction(tr("1 hour"));
    KNotificationAction *snoozeTomorrow = notification->addAction(tr("Tomorrow"));
    connect(snooze15, &KNotificationAction::activated, this, [this, itemId]() {
        snoozeTask(itemId, QStringLiteral("15m"));
    });
    connect(snoozeHour, &KNotificationAction::activated, this, [this, itemId]() {
        snoozeTask(itemId, QStringLiteral("1h"));
    });
    connect(snoozeTomorrow, &KNotificationAction::activated, this, [this, itemId]() {
        snoozeTask(itemId, QStringLiteral("tomorrow"));
    });
    notification->sendEvent();
#else
    Q_UNUSED(itemId);
    Q_UNUSED(summary);
    Q_UNUSED(when);
#endif
}
