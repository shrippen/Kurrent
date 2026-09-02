#include "taskcontroller.h"
#include "akonaditaskstore.h"
#include "kurrentlogging.h"
#include "memorytaskstore.h"
#include "sharedsettings.h"
#include "taskcalendar.h"
#include "tasklogic.h"

#include <Akonadi/AgentManager>
#include <Akonadi/Collection>
#include <Akonadi/CollectionFetchJob>
#include <Akonadi/CollectionFetchScope>
#include <Akonadi/ItemCreateJob>
#include <Akonadi/ItemFetchJob>
#include <Akonadi/ItemFetchScope>
#include <Akonadi/ServerManager>

#include <KCalendarCore/Event>
#include <KCalendarCore/Todo>

#include <KLocalizedString>

#include <KJob>

#include <QByteArray>
#include <QCursor>
#include <QDate>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QTime>
#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QHash>
#include <QLoggingCategory>
#include <QScreen>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtConcurrent>
#include <QtGlobal>
#include <QDBusConnection>
#include <algorithm>

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

namespace
{
constexpr int kRebuildDelayMs = 50;
constexpr int kCollectionsReloadDelayMs = 250;
constexpr int kAkonadiRetryIntervalMs = 5000;
constexpr int kAsyncRebuildThreshold = 40;

void logAkonadi(const QString &message)
{
    KurrentLogging::info(message);
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

QString storeKindName(AbstractTaskStore::Kind kind)
{
    switch (kind) {
    case AbstractTaskStore::Kind::Create:
        return QStringLiteral("Create");
    case AbstractTaskStore::Kind::Modify:
        return QStringLiteral("Modify");
    case AbstractTaskStore::Kind::Move:
        return QStringLiteral("Move");
    case AbstractTaskStore::Kind::Delete:
        return QStringLiteral("Delete");
    }
    return QStringLiteral("Unknown");
}
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

KCalendarCore::Todo::Ptr cloneTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo) {
        return {};
    }
    return KCalendarCore::Todo::Ptr(static_cast<KCalendarCore::Todo *>(todo->clone()));
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

QString kanbanManualOrderColumnKey(const QString &source, const QString &columnKey)
{
    if (source == TaskLogic::KanbanSource::Status) {
        return TaskLogic::normalizeStatusColumnKey(columnKey);
    }
    return columnKey;
}

QVariantList kanbanManualOrderForColumn(const QVariantMap &comboMap, const QString &source, const QString &columnKey)
{
    const QString key = kanbanManualOrderColumnKey(source, columnKey);
    QVariantList stored = comboMap.value(key).toList();
    if (!stored.isEmpty() || source != TaskLogic::KanbanSource::Status) {
        return stored;
    }
    static const QHash<QString, QString> legacyByNorm = {
        {QStringLiteral("4"), QStringLiteral("needs-action")},
        {QStringLiteral("6"), QStringLiteral("in-process")},
        {QStringLiteral("3"), QStringLiteral("completed")},
        {QStringLiteral("5"), QStringLiteral("cancelled")},
    };
    const QString legacy = legacyByNorm.value(key);
    if (!legacy.isEmpty()) {
        return comboMap.value(legacy).toList();
    }
    return {};
}

} // namespace

QHash<Akonadi::Item::Id, TaskController::CachedTask> TaskController::s_tasks;
QList<Akonadi::Collection> TaskController::s_collections;
QList<Akonadi::Collection> TaskController::s_eventCollections;
QHash<qint64, QString> TaskController::s_collectionNames;
QStringList TaskController::s_extraLabels;
QStringList TaskController::s_extraLocations;
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

    connect(&m_rebuildWatcher, &QFutureWatcher<TaskLogic::TaskRebuildOutput>::finished, this,
            &TaskController::onRebuildFinished);

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

    KurrentLogging::reloadFromSharedSettings();
    connect(SharedSettings::instance(), &SharedSettings::changed, this, []() {
        KurrentLogging::reloadFromSharedSettings();
    });

    hydrateFromCache();
    loadRebuildPerfProfile();
    // D-Bus and GlobalAccel talk to the session bus; let QML finish constructing first.
    QTimer::singleShot(0, this, [this]() {
        registerSessionInterface();
        registerGlobalShortcuts();
    });
}

TaskController::~TaskController()
{
    if (m_rebuildWatcher.isRunning()) {
        m_rebuildWatcher.waitForFinished();
    }
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
    s_extraLocations.clear();
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

QStringList TaskController::testTaskCategories(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend() || !it->todo) {
        return {};
    }
    return it->todo->categories();
}

int TaskController::testTaskPriority(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend() || !it->todo) {
        return 0;
    }
    return it->todo->priority();
}

int TaskController::testTaskStatus(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend() || !it->todo) {
        return 0;
    }
    return static_cast<int>(it->todo->status());
}

int TaskController::testTaskSecrecy(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend() || !it->todo) {
        return 0;
    }
    return static_cast<int>(it->todo->secrecy());
}

QString TaskController::testTaskLocation(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend() || !it->todo) {
        return {};
    }
    return it->todo->location();
}

QString TaskController::testKanbanColumnKey(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    if (it == s_tasks.cend()) {
        return {};
    }
    const TaskEntry entry = makeTaskEntry(*it, 0, false);
    return TaskLogic::kanbanColumnKey(entry, m_kanbanColumnSource, filterState(), QDate::currentDate());
}

int TaskController::testTaskRevision(qint64 id) const
{
    const auto it = s_tasks.constFind(id);
    return it == s_tasks.cend() ? -1 : it->item.revision();
}

void TaskController::testApplyExternalItem(const Akonadi::Item &item)
{
    upsertTask(item);
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
    clearTaskSelection();
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

void TaskController::setSelectedProgressBand(const QString &band)
{
    const QString trimmed = band.trimmed();
    const QString normalized = TaskLogic::progressBandKeys().contains(trimmed) ? trimmed : QString();
    if (m_selectedProgressBand == normalized) {
        return;
    }
    m_selectedProgressBand = normalized;
    scheduleRebuild();
    Q_EMIT selectedProgressBandChanged();
}

void TaskController::setSelectedStatus(int status)
{
    const int normalized = (status < 0) ? -1 : TaskLogic::normalizeStatus(status);
    if (m_selectedStatus == normalized) {
        return;
    }
    m_selectedStatus = normalized;
    scheduleRebuild();
    Q_EMIT selectedStatusChanged();
}

void TaskController::setSelectedSecrecy(int secrecy)
{
    const int normalized = (secrecy < 0) ? -1 : qBound(0, secrecy, 2);
    if (m_selectedSecrecy == normalized) {
        return;
    }
    m_selectedSecrecy = normalized;
    scheduleRebuild();
    Q_EMIT selectedSecrecyChanged();
}

void TaskController::setSelectedLocation(const QString &location)
{
    const QString trimmed = location.trimmed();
    if (m_selectedLocation == trimmed) {
        return;
    }
    m_selectedLocation = trimmed;
    scheduleRebuild();
    Q_EMIT selectedLocationChanged();
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
    maybeShowReorganizing();
    scheduleRebuild();
    Q_EMIT sortModeChanged();
}

void TaskController::setListGroupMode(const QString &mode)
{
    QString normalized = mode.trimmed();
    if (normalized == TaskLogic::ListGroupSource::None) {
        normalized.clear();
    }
    if (m_listGroupMode == normalized) {
        return;
    }
    m_listGroupMode = normalized;
    maybeShowReorganizing();
    scheduleRebuild();
    Q_EMIT listGroupModeChanged();
}

void TaskController::setMainPaneMode(const QString &mode)
{
    const QString normalized = mode.isEmpty() ? TaskLogic::MainPaneMode::List : mode;
    if (m_mainPaneMode == normalized) {
        return;
    }
    m_mainPaneMode = normalized;
    Q_EMIT mainPaneModeChanged();
}

void TaskController::setKanbanColumnSource(const QString &source)
{
    const QString normalized = source.isEmpty() ? TaskLogic::KanbanSource::Status : source;
    if (m_kanbanColumnSource == normalized) {
        return;
    }
    m_kanbanColumnSource = normalized;
    updateKanbanLayout();
    Q_EMIT kanbanColumnSourceChanged();
}

void TaskController::setKanbanWriteMode(const QString &mode)
{
    const QString normalized = mode.isEmpty() ? QStringLiteral("fields") : mode;
    if (m_kanbanWriteMode == normalized) {
        return;
    }
    m_kanbanWriteMode = normalized;
    Q_EMIT kanbanWriteModeChanged();
}

void TaskController::setKanbanManualOrderJson(const QString &json)
{
    const QString trimmed = json.trimmed().isEmpty() ? QStringLiteral("{}") : json;
    if (m_kanbanManualOrderJson == trimmed) {
        return;
    }
    m_kanbanManualOrderJson = trimmed;
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(trimmed.toUtf8(), &err);
    m_kanbanManualOrder = (err.error == QJsonParseError::NoError && doc.isObject())
            ? doc.object().toVariantMap()
            : QVariantMap();
    Q_EMIT kanbanManualOrderJsonChanged();
    updateKanbanLayout();
}

void TaskController::setSwimlaneLaneAxis(const QString &axis)
{
    const QString normalized = axis.isEmpty() ? QStringLiteral("project") : axis;
    if (m_swimlaneLaneAxis == normalized) {
        return;
    }
    m_swimlaneLaneAxis = normalized;
    Q_EMIT swimlaneSettingsChanged();
}

void TaskController::setSwimlaneTimeBucket(const QString &bucket)
{
    const QString normalized = bucket.isEmpty() ? QStringLiteral("day") : bucket;
    if (m_swimlaneTimeBucket == normalized) {
        return;
    }
    m_swimlaneTimeBucket = normalized;
    Q_EMIT swimlaneSettingsChanged();
}

void TaskController::setPlanTimeBucket(const QString &bucket)
{
    const QString normalized = bucket.isEmpty() ? QStringLiteral("week") : bucket;
    if (m_planTimeBucket == normalized) {
        return;
    }
    m_planTimeBucket = normalized;
    Q_EMIT planSettingsChanged();
}

void TaskController::setPlanHorizon(int horizon)
{
    if (m_planHorizon == horizon) {
        return;
    }
    m_planHorizon = horizon;
    Q_EMIT planSettingsChanged();
}

void TaskController::setPlanShowUndated(bool show)
{
    if (m_planShowUndated == show) {
        return;
    }
    m_planShowUndated = show;
    Q_EMIT planSettingsChanged();
}

void TaskController::setPlanShowCompleted(bool show)
{
    if (m_planShowCompleted == show) {
        return;
    }
    m_planShowCompleted = show;
    Q_EMIT planSettingsChanged();
}

void TaskController::setMultiSelectEnabled(bool enabled)
{
    if (m_multiSelectEnabled == enabled) {
        return;
    }
    m_multiSelectEnabled = enabled;
    if (!enabled && !m_selectedTaskIds.isEmpty()) {
        m_selectedTaskIds.clear();
        Q_EMIT selectedTaskIdsChanged();
    }
    Q_EMIT multiSelectEnabledChanged();
}

void TaskController::setSmartViewsJson(const QString &json)
{
    if (m_smartViewsJson == json) {
        return;
    }
    m_smartViewsJson = json;
    m_smartViews = TaskLogic::parseSmartViews(json);
    scheduleRebuild();
    Q_EMIT smartViewsJsonChanged();
}

void TaskController::setSelectedTaskIds(const QStringList &ids)
{
    if (m_selectedTaskIds == ids) {
        return;
    }
    m_selectedTaskIds = ids;
    Q_EMIT selectedTaskIdsChanged();
}

void TaskController::toggleTaskSelection(qint64 itemId, bool ctrl, bool shift)
{
    Q_UNUSED(shift)
    const QString key = QString::number(itemId);
    QStringList ids = m_selectedTaskIds;
    if (ctrl) {
        if (ids.contains(key)) {
            ids.removeAll(key);
        } else {
            ids.append(key);
        }
    } else {
        ids = {key};
    }
    setSelectedTaskIds(ids);
}

void TaskController::clearTaskSelection()
{
    if (m_selectedTaskIds.isEmpty()) {
        return;
    }
    m_selectedTaskIds.clear();
    Q_EMIT selectedTaskIdsChanged();
}

TaskLogic::FilterState TaskController::filterState() const
{
    TaskLogic::FilterState filters;
    filters.currentView = m_currentView;
    filters.searchQuery = m_searchQuery;
    filters.showCompleted = m_showCompleted;
    filters.selectedCollectionId = m_selectedCollectionId;
    filters.selectedLabel = m_selectedLabel;
    filters.selectedPriority = m_selectedPriority;
    filters.selectedProgressBand = m_selectedProgressBand;
    filters.selectedStatus = m_selectedStatus;
    filters.selectedSecrecy = m_selectedSecrecy;
    filters.selectedLocation = m_selectedLocation;
    filters.catchUpEnabled = m_catchUpEnabled;
    filters.catchUpDays = m_catchUpDays;
    filters.morningHour = m_morningHour;
    filters.afternoonHour = m_afternoonHour;
    filters.eveningHour = m_eveningHour;
    filters.searchScope = m_searchTitleOnly ? TaskLogic::SearchScope::TitleOnly : TaskLogic::SearchScope::All;
    filters.searchCase = m_searchCaseSensitive ? TaskLogic::SearchCase::Sensitive : TaskLogic::SearchCase::Insensitive;
    filters.listGroupMode = m_listGroupMode;
    // Inject smart view rules so that buildRebuildInput() and
    // matchesViewFilter() apply the saved filter criteria.
    if (m_currentView.startsWith(QLatin1String("smart:"))) {
        const QString smartId = m_currentView.mid(6);
        for (const TaskLogic::SmartViewDef &def : m_smartViews) {
            if (def.id == smartId) {
                filters.hasSmartRules = true;
                filters.smartRules = def.rules;
                break;
            }
        }
    }
    // Provide all smart views so computeCounts can pre-compute sidebar badges.
    filters.allSmartViews.clear();
    for (const TaskLogic::SmartViewDef &def : m_smartViews) {
        filters.allSmartViews.append({def.id, def.rules});
    }
    return filters;
}

QString TaskController::kanbanColumnKeyForTask(qint64 itemId) const
{
    const int row = m_taskModel.rowForItemId(itemId);
    if (row < 0) {
        return {};
    }
    const TaskEntry task = m_taskModel.taskAt(row);
    return TaskLogic::kanbanColumnKey(task, m_kanbanColumnSource, filterState(), QDate::currentDate());
}

QString TaskController::kanbanColumnLabelForKey(const QString &key) const
{
    if (m_kanbanColumnSource == TaskLogic::KanbanSource::Project) {
        const qint64 id = key.toLongLong();
        if (id > 0) {
            return m_collectionNames.value(id, key);
        }
        return tr("Inbox");
    }
    if (m_kanbanColumnSource == TaskLogic::KanbanSource::Label && key != QLatin1String("none")) {
        return key;
    }
    if (m_kanbanColumnSource == TaskLogic::KanbanSource::Status) {
        const QString nk = TaskLogic::normalizeStatusColumnKey(key);
        if (nk == QLatin1String("0")) {
            return tr("None");
        }
        if (nk == QLatin1String("4")) {
            return tr("Needs action");
        }
        if (nk == QLatin1String("6")) {
            return tr("In process");
        }
        if (nk == QLatin1String("3")) {
            return tr("Completed");
        }
        if (nk == QLatin1String("5")) {
            return tr("Canceled");
        }
    }
    return TaskLogic::kanbanColumnLabel(key, m_kanbanColumnSource);
}

QString TaskController::listGroupLabelForKey(const QString &key) const
{
    const QString mode = m_listGroupMode.trimmed();
    if (mode.isEmpty() || mode == TaskLogic::ListGroupSource::None) {
        return key;
    }
    if (mode == TaskLogic::ListGroupSource::Project) {
        const qint64 id = key.toLongLong();
        if (id > 0) {
            return m_collectionNames.value(id, key);
        }
        return tr("Inbox");
    }
    if (mode == TaskLogic::ListGroupSource::Label) {
        return key == QLatin1String("none") ? tr("Unlabeled") : key;
    }
    if (mode == TaskLogic::ListGroupSource::Location) {
        return key == QLatin1String("none") ? tr("No location") : key;
    }
    if (mode == TaskLogic::ListGroupSource::Progress) {
        if (key == QLatin1String("0-25")) {
            return tr("0–25%");
        }
        if (key == QLatin1String("26-50")) {
            return tr("26–50%");
        }
        if (key == QLatin1String("51-75")) {
            return tr("51–75%");
        }
        if (key == QLatin1String("76-100")) {
            return tr("76–100%");
        }
    }
    if (mode == TaskLogic::ListGroupSource::Status) {
        if (key == QLatin1String("0")) {
            return tr("None");
        }
        if (key == QLatin1String("4")) {
            return tr("Needs action");
        }
        if (key == QLatin1String("6")) {
            return tr("In process");
        }
        if (key == QLatin1String("3")) {
            return tr("Completed");
        }
        if (key == QLatin1String("5")) {
            return tr("Canceled");
        }
    }
    return TaskLogic::listGroupLabel(key, mode);
}

QStringList TaskController::kanbanColumnKeysForVisibleTasks() const
{
    QStringList keys;
    QSet<QString> seen;
    QHash<QString, QString> names;
    const int count = m_taskModel.count();
    const QDate today = QDate::currentDate();
    const TaskLogic::FilterState filters = filterState();

    // Label columns: one per known label (sidebar catalog), not only first-label of visible tasks.
    if (m_kanbanColumnSource == TaskLogic::KanbanSource::Label) {
        bool hasUnlabeled = false;
        for (int i = 0; i < count; ++i) {
            if (m_taskModel.taskAt(i).categories.isEmpty()) {
                hasUnlabeled = true;
                break;
            }
        }
        for (const QString &label : m_availableLabels) {
            if (!label.isEmpty() && !seen.contains(label)) {
                seen.insert(label);
                keys.append(label);
            }
        }
        for (int i = 0; i < count; ++i) {
            for (const QString &category : m_taskModel.taskAt(i).categories) {
                if (!category.isEmpty() && !seen.contains(category)) {
                    seen.insert(category);
                    keys.append(category);
                }
            }
        }
        if (hasUnlabeled || keys.isEmpty()) {
            keys.append(QStringLiteral("none"));
        }
        return TaskLogic::orderKanbanColumnKeys(keys, m_kanbanColumnSource, names);
    }

    // Fixed vocabularies always start with the full column set (empty columns stay droppable).
    const QStringList fixed = TaskLogic::fixedKanbanColumnKeys(m_kanbanColumnSource);
    for (const QString &key : fixed) {
        if (!seen.contains(key)) {
            seen.insert(key);
            keys.append(key);
        }
    }

    for (int i = 0; i < count; ++i) {
        const TaskEntry task = m_taskModel.taskAt(i);
        const QString key = TaskLogic::kanbanColumnKey(task, m_kanbanColumnSource, filters, today);
        if (!seen.contains(key)) {
            seen.insert(key);
            keys.append(key);
        }
        if (m_kanbanColumnSource == TaskLogic::KanbanSource::Project && key != QLatin1String("inbox")) {
            names.insert(key, task.collectionName);
        }
    }
    return TaskLogic::orderKanbanColumnKeys(keys, m_kanbanColumnSource, names);
}

void TaskController::moveTaskToKanbanColumn(qint64 itemId, const QString &columnKey)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }

    if (!m_applyingUndo && !m_batchUndo) {
        TaskLogic::UndoRecord record = snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache);
        record.restoreLayout = true;
        record.kanbanManualOrderJson = m_kanbanManualOrderJson;
        record.sortMode = m_sortMode;
        pushUndo(record);
    }

    if (m_kanbanWriteMode == QLatin1String("custom")) {
        TaskCalendar::setColumn(cache->todo, columnKey);
        persistTodo(cache->item, cache->todo);
        return;
    }

    const TaskEntry before = makeTaskEntry(*cache, 0, false);
    const QString source = m_kanbanColumnSource;
    KCalendarCore::Todo::Ptr todo = cache->todo;

    if (source == TaskLogic::KanbanSource::Completion) {
        // Mutate directly so nested helpers cannot push a second undo or return early
        // while the model still has a stale band.
        const bool wantDone = columnKey == QLatin1String("done");
        if (todo->isCompleted() != wantDone) {
            TaskCalendar::completeTodo(todo,
                                       wantDone ? TaskCalendar::CompleteAction::Mark
                                                : TaskCalendar::CompleteAction::Unmark,
                                       QDateTime::currentDateTime());
            if (!todo->recurs()) {
                todo->setPercentComplete(wantDone ? 100 : 0);
            }
            persistTodo(cache->item, todo);
        }
        return;
    }
    if (source == TaskLogic::KanbanSource::Status) {
        const QString nk = TaskLogic::normalizeStatusColumnKey(columnKey);
        bool ok = false;
        const int status = nk.toInt(&ok);
        if (!ok) {
            return;
        }
        const auto kStatus = static_cast<KCalendarCore::Incidence::Status>(status);
        bool changed = false;
        if (todo->status() != kStatus) {
            todo->setStatus(kStatus);
            changed = true;
        }
        if (status == 3) {
            if (!todo->isCompleted()) {
                TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime::currentDateTime());
                changed = true;
            }
            if (!todo->recurs() && todo->percentComplete() != 100) {
                todo->setPercentComplete(100);
                changed = true;
            }
        } else if (todo->isCompleted()) {
            todo->setCompleted(false);
            changed = true;
        }
        if (changed) {
            persistTodo(cache->item, todo);
        }
        return;
    }
    if (source == TaskLogic::KanbanSource::Secrecy) {
        int secrecy = 0;
        if (columnKey == QLatin1String("private")) {
            secrecy = 1;
        } else if (columnKey == QLatin1String("confidential")) {
            secrecy = 2;
        }
        if (static_cast<int>(todo->secrecy()) != secrecy) {
            todo->setSecrecy(static_cast<KCalendarCore::Incidence::Secrecy>(secrecy));
            persistTodo(cache->item, todo);
        }
        return;
    }
    if (source == TaskLogic::KanbanSource::Project) {
        qint64 collectionId = -1;
        if (columnKey != QLatin1String("inbox")) {
            collectionId = columnKey.toLongLong();
        }
        if (collectionId >= 0) {
            moveTaskToCollection(itemId, collectionId);
        }
        return;
    }
    if (source == TaskLogic::KanbanSource::Due) {
        QString preset;
        if (columnKey == QLatin1String("today")) {
            preset = QStringLiteral("today");
        } else if (columnKey == QLatin1String("tomorrow")) {
            preset = TaskLogic::ReschedulePreset::Tomorrow;
        } else if (columnKey == QLatin1String("this-week")) {
            preset = TaskLogic::ReschedulePreset::NextWeek;
        } else if (columnKey == QLatin1String("no-date")) {
            todo->setDtDue(QDateTime());
            persistTodo(cache->item, todo);
            return;
        } else if (columnKey == QLatin1String("overdue") || columnKey == QLatin1String("later")) {
            preset = columnKey == QLatin1String("overdue") ? QStringLiteral("today") : TaskLogic::ReschedulePreset::NextWeek;
        }
        if (!preset.isEmpty()) {
            // Nested reschedule pushes its own undo — suppress via batch flag (already set from finishKanbanDrop).
            rescheduleTask(itemId, preset);
        }
        return;
    }
    if (source == TaskLogic::KanbanSource::Priority) {
        int priority = TaskLogic::PriorityBand::None;
        if (columnKey == QLatin1String("high")) {
            priority = TaskLogic::PriorityBand::High;
        } else if (columnKey == QLatin1String("medium")) {
            priority = TaskLogic::PriorityBand::Medium;
        } else if (columnKey == QLatin1String("low")) {
            priority = TaskLogic::PriorityBand::Low;
        }
        if (TaskLogic::priorityBand(todo->priority()) != priority) {
            todo->setPriority(priority);
            persistTodo(cache->item, todo);
        }
        return;
    }
    if (source == TaskLogic::KanbanSource::Label) {
        if (columnKey == QLatin1String("none")) {
            todo->setCategories(QStringList());
        } else {
            // Column membership is first category: move/ensure this label to the front.
            QStringList cats = before.categories;
            cats.removeAll(columnKey);
            cats.prepend(columnKey);
            todo->setCategories(cats);
        }
        persistTodo(cache->item, todo);
        return;
    }
    if (source == TaskLogic::KanbanSource::DaySection) {
        TaskCalendar::setSection(todo, columnKey == QLatin1String("unscheduled") ? QString() : columnKey);
        persistTodo(cache->item, todo);
        return;
    }
    if (source == TaskLogic::KanbanSource::Column) {
        TaskCalendar::setColumn(todo, columnKey);
        persistTodo(cache->item, todo);
        return;
    }
    if (m_kanbanWriteMode == QLatin1String("both")) {
        TaskCalendar::setColumn(todo, columnKey);
        persistTodo(cache->item, todo);
    }
}

QVariantList TaskController::kanbanTaskIndicesForColumn(const QString &columnKey) const
{
    struct Row {
        int index = 0;
        int sort = 0;
    };
    QList<Row> rows;
    const QDate today = QDate::currentDate();
    const TaskLogic::FilterState filters = filterState();
    for (int i = 0; i < m_taskModel.count(); ++i) {
        const TaskEntry task = m_taskModel.taskAt(i);
        if (TaskLogic::kanbanColumnKey(task, m_kanbanColumnSource, filters, today) != columnKey) {
            continue;
        }
        rows.append({i, task.kanbanSortOrder});
    }
    std::sort(rows.begin(), rows.end(), [](const Row &left, const Row &right) {
        if (left.sort != right.sort) {
            return left.sort < right.sort;
        }
        return left.index < right.index;
    });
    QVariantList indices;
    indices.reserve(rows.size());
    for (const Row &row : rows) {
        indices.append(row.index);
    }
    return indices;
}

QVariantMap TaskController::taskEntryToVariantMap(const TaskEntry &task) const
{
    QVariantMap map;
    map.insert(QStringLiteral("itemId"), task.itemId);
    map.insert(QStringLiteral("uid"), task.uid);
    map.insert(QStringLiteral("parentUid"), task.parentUid);
    map.insert(QStringLiteral("summary"), task.summary);
    map.insert(QStringLiteral("description"), task.description);
    map.insert(QStringLiteral("dueDate"), task.dueDate);
    map.insert(QStringLiteral("startDate"), task.startDate);
    map.insert(QStringLiteral("completed"), task.completed);
    map.insert(QStringLiteral("categories"), task.categories);
    map.insert(QStringLiteral("collectionId"), task.collectionId);
    map.insert(QStringLiteral("collectionName"), task.collectionName);
    map.insert(QStringLiteral("percentComplete"), task.percentComplete);
    map.insert(QStringLiteral("priority"), task.priority);
    map.insert(QStringLiteral("status"), task.status);
    map.insert(QStringLiteral("secrecy"), task.secrecy);
    map.insert(QStringLiteral("location"), task.location);
    map.insert(QStringLiteral("recurring"), task.recurring);
    map.insert(QStringLiteral("joinUrl"), task.joinUrl);
    map.insert(QStringLiteral("syncing"), task.syncing);
    return map;
}

QVariantList TaskController::kanbanTasksForColumn(const QString &columnKey) const
{
    QList<TaskEntry> tasks;
    const QDate today = QDate::currentDate();
    const TaskLogic::FilterState filters = filterState();
    for (int i = 0; i < m_taskModel.count(); ++i) {
        const TaskEntry task = m_taskModel.taskAt(i);
        if (TaskLogic::kanbanColumnKey(task, m_kanbanColumnSource, filters, today) != columnKey) {
            continue;
        }
        tasks.append(task);
    }

    if (m_sortMode == QLatin1String("custom")) {
        const QString combo = m_currentView + QLatin1Char('|') + m_kanbanColumnSource;
        const QVariantMap comboMap = m_kanbanManualOrder.value(combo).toMap();
        QList<qint64> ids;
        QHash<qint64, TaskEntry> byId;
        ids.reserve(tasks.size());
        for (const TaskEntry &task : tasks) {
            ids.append(task.itemId);
            byId.insert(task.itemId, task);
        }
        QList<qint64> manual;
        const QVariantList stored = kanbanManualOrderForColumn(comboMap, m_kanbanColumnSource, columnKey);
        for (const QVariant &v : stored) {
            manual.append(v.toLongLong());
        }
        ids = TaskLogic::applyManualKanbanOrder(ids, manual);
        QVariantList out;
        out.reserve(ids.size());
        for (qint64 id : ids) {
            out.append(taskEntryToVariantMap(byId.value(id)));
        }
        return out;
    }

    const QString sortMode = m_sortMode;
    std::sort(tasks.begin(), tasks.end(), [&](const TaskEntry &left, const TaskEntry &right) {
        const int cmp = TaskLogic::compareTasks(left, right, sortMode);
        if (cmp != 0) {
            return cmp < 0;
        }
        return left.itemId < right.itemId;
    });
    QVariantList out;
    out.reserve(tasks.size());
    for (const TaskEntry &task : tasks) {
        out.append(taskEntryToVariantMap(task));
    }
    return out;
}

QVariantMap TaskController::taskRowSnapshot(int row) const
{
    if (row < 0 || row >= m_taskModel.count()) {
        return {};
    }
    return taskEntryToVariantMap(m_taskModel.taskAt(row));
}

void TaskController::reorderKanbanCard(qint64 itemId, const QString &columnKey, int targetIndex)
{
    QList<qint64> ids;
    const QDate today = QDate::currentDate();
    const TaskLogic::FilterState filters = filterState();
    for (int i = 0; i < m_taskModel.count(); ++i) {
        const TaskEntry task = m_taskModel.taskAt(i);
        if (task.itemId == itemId) {
            continue; // may still sit in the old column in the model until rebuild
        }
        if (TaskLogic::kanbanColumnKey(task, m_kanbanColumnSource, filters, today) == columnKey) {
            ids.append(task.itemId);
        }
    }
    // targetIndex = insert position in the list *without* the dragged card.
    const int insertAt = qBound(0, targetIndex, ids.size());
    QList<qint64> next = ids;
    next.insert(insertAt, itemId);
    if (next == ids && ids.contains(itemId)) {
        return;
    }
    // Also no-op when the only change would re-append the same singleton order.
    if (ids.size() == next.size() - 1) {
        // always inserting; compare against previous stored order for this column
        const QString combo = m_currentView + QLatin1Char('|') + m_kanbanColumnSource;
        const QVariantList prevStored = kanbanManualOrderForColumn(
                m_kanbanManualOrder.value(combo).toMap(), m_kanbanColumnSource, columnKey);
        QList<qint64> prevIds;
        for (const QVariant &v : prevStored) {
            prevIds.append(v.toLongLong());
        }
        if (prevIds == next) {
            return;
        }
    }

    if (!m_applyingUndo && !m_batchUndo) {
        TaskLogic::UndoRecord record;
        record.kind = TaskLogic::UndoRecord::Kind::KanbanLayout;
        record.restoreLayout = true;
        record.kanbanManualOrderJson = m_kanbanManualOrderJson;
        record.sortMode = m_sortMode;
        pushUndo(record);
    }

    const QString combo = m_currentView + QLatin1Char('|') + m_kanbanColumnSource;
    QVariantMap root = m_kanbanManualOrder;
    QVariantMap comboMap = root.value(combo).toMap();
    const QString orderKey = kanbanManualOrderColumnKey(m_kanbanColumnSource, columnKey);

    // Drop the id from every other column's stored order so it cannot snap back.
    for (auto it = comboMap.begin(); it != comboMap.end(); ++it) {
        if (it.key() == orderKey) {
            continue;
        }
        QVariantList other = it.value().toList();
        QVariantList cleaned;
        cleaned.reserve(other.size());
        for (const QVariant &v : other) {
            if (v.toLongLong() != itemId) {
                cleaned.append(v);
            }
        }
        it.value() = cleaned;
    }

    QVariantList stored;
    stored.reserve(next.size());
    for (qint64 id : next) {
        stored.append(id);
    }
    comboMap.insert(orderKey, stored);
    root.insert(combo, comboMap);

    const QByteArray encoded = QJsonDocument::fromVariant(root).toJson(QJsonDocument::Compact);
    setKanbanManualOrderJson(QString::fromUtf8(encoded));
    if (m_sortMode != QLatin1String("custom")) {
        setSortMode(QStringLiteral("custom"));
    }
}

void TaskController::finishKanbanDrop(qint64 itemId, const QString &columnKey, int targetGap,
                                       const QString &sourceColumnKey, int sourceIndex)
{
    if (itemId < 0 || columnKey.isEmpty()) {
        return;
    }

    int targetIndex = targetGap;
    if (targetIndex < 0) {
        const QVariantList tasks = kanbanTasksForColumn(columnKey);
        targetIndex = tasks.size();
    }

    const bool sameColumn = sourceColumnKey == columnKey;
    // Gap indices include the dragged card's old slot. After removing it, gaps below
    // the source shift down by one — same as "drop on self / immediately below".
    if (sameColumn && (targetIndex == sourceIndex || targetIndex == sourceIndex + 1)) {
        return;
    }

    CachedTask *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }

    TaskLogic::UndoRecord record = snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache);
    record.restoreLayout = true;
    record.kanbanManualOrderJson = m_kanbanManualOrderJson;
    record.sortMode = m_sortMode;

    // Insert index in the destination list *without* the dragged card.
    int insertAt = targetIndex;
    if (sameColumn && sourceIndex >= 0 && sourceIndex < targetIndex) {
        --insertAt;
    }
    insertAt = qMax(0, insertAt);

    m_batchUndo = true;
    moveTaskToKanbanColumn(itemId, columnKey);
    reorderKanbanCard(itemId, columnKey, insertAt);
    m_batchUndo = false;

    pushUndo(record);
}

QVariantMap TaskController::swimlaneMatrixForVisibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return TaskLogic::buildSwimlaneMatrix(tasks, m_swimlaneLaneAxis, m_swimlaneTimeBucket, QDate::currentDate());
}

QVariantMap TaskController::planMatrixGridForVisibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return TaskLogic::buildPlanMatrixGrid(tasks, m_planTimeBucket, m_planHorizon, m_planShowUndated, m_planShowCompleted, QDate::currentDate());
}

QStringList TaskController::busyDayStripForVisibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return TaskLogic::busyDayKeys(tasks, QDate::currentDate());
}

QString TaskController::swimlaneLaneLabelForKey(const QString &key) const
{
    if (m_swimlaneLaneAxis == QLatin1String("project")) {
        if (key == QLatin1String("inbox")) {
            return tr("Inbox");
        }
        const qint64 id = key.toLongLong();
        if (id > 0) {
            return m_collectionNames.value(id, key);
        }
    }
    return TaskLogic::swimlaneLaneLabel(key, m_swimlaneLaneAxis);
}

QString TaskController::swimlaneTimeLabelForKey(const QString &key) const
{
    return TaskLogic::swimlaneTimeLabel(key, m_swimlaneTimeBucket);
}

void TaskController::setPlanPreviewFilter(qint64 collectionId, const QString &weekKey)
{
    m_planPreviewProject = collectionId >= 0 ? QString::number(collectionId) : QStringLiteral("inbox");
    m_planPreviewWeek = weekKey;
    scheduleRebuild();
}

void TaskController::clearPlanPreviewFilter()
{
    if (m_planPreviewWeek.isEmpty()) {
        return;
    }
    m_planPreviewWeek.clear();
    m_planPreviewProject.clear();
    scheduleRebuild();
}

QVariantMap TaskController::heatmapCountsForMonth(const QDate &monthStart, const QString &mode) const
{
    if (mode == QLatin1String("completed")) {
        const QDate monthEnd = monthStart.addMonths(1).addDays(-1);
        return heatmapCountsAll(monthStart, monthEnd, mode);
    }
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return TaskLogic::heatmapCounts(tasks, mode, monthStart);
}

QVariantMap TaskController::planMatrixForVisibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return TaskLogic::planMatrixCounts(tasks, QDate::currentDate());
}

QVariantList TaskController::agendaEventsForDay(const QDate &day) const
{
    QVariantList result;
    if (!day.isValid()) {
        return result;
    }
    const QDateTime dayStart(day, QTime(0, 0));
    const QDateTime dayEnd(day.addDays(1), QTime(0, 0));
    for (const TaskCalendar::BusyInterval &interval : m_busyIntervals) {
        if (interval.end <= dayStart || interval.start >= dayEnd) {
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("start"), interval.start);
        row.insert(QStringLiteral("end"), interval.end);
        row.insert(QStringLiteral("summary"), interval.summary);
        row.insert(QStringLiteral("calendarId"), interval.collectionId);
        const QString calName = s_collectionNames.value(interval.collectionId);
        row.insert(QStringLiteral("calendarName"), calName);
        const bool allDay = interval.start.time() == QTime(0, 0) && interval.end.time() == QTime(0, 0);
        row.insert(QStringLiteral("allDay"), allDay);
        result.append(row);
    }
    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("start")).toDateTime()
               < b.toMap().value(QStringLiteral("start")).toDateTime();
    });
    return result;
}

QVariantMap TaskController::heatmapCountsAll(const QDate &start, const QDate &end, const QString &mode) const
{
    QVariantMap counts;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        const CachedTask &cached = it.value();
        if (!cached.todo) continue;
        TaskEntry entry;
        entry.itemId = it.key();
        entry.completed = cached.todo->isCompleted();
        entry.completedDate = cached.todo->completed();
        entry.dueDate = TaskCalendar::dueDateFromTodo(cached.todo);
        entry.startDate = cached.todo->dtStart();
        const QString key = TaskLogic::heatmapDayKey(entry, mode, start);
        if (key.isEmpty()) continue;
        const QDate day = QDate::fromString(key, Qt::ISODate);
        if (!day.isValid() || day < start || day > end) continue;
        counts.insert(key, counts.value(key, 0).toInt() + 1);
    }
    return counts;
}

QVariantList TaskController::agendaTasksForRange(const QDate &from, const QDate &to) const
{
    QVariantList result;
    if (!from.isValid() || !to.isValid() || from > to) {
        return result;
    }
    // Iterate ALL Akonadi tasks (s_tasks) so completed tasks are always included,
    // regardless of the current sidebar filter state.
    const QDateTime rangeStart(from, QTime(0, 0));
    const QDateTime rangeEnd(to.addDays(1), QTime(0, 0));
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        const CachedTask &cached = it.value();
        if (!cached.todo) continue;
        const bool isCompleted = cached.todo->isCompleted();
        const QDateTime dueDt = TaskCalendar::dueDateFromTodo(cached.todo);
        const QDateTime compDt = cached.todo->completed();
        // Uncompleted tasks: match by dueDate
        bool matchUncompleted = !isCompleted && dueDt.isValid()
                && dueDt >= rangeStart && dueDt < rangeEnd;
        // Completed tasks: match by completedDate; fallback to dueDate if completedDate is invalid
        bool matchCompleted = isCompleted
                && ((compDt.isValid() && compDt >= rangeStart && compDt < rangeEnd)
                    || (!compDt.isValid() && dueDt.isValid() && dueDt >= rangeStart && dueDt < rangeEnd));
        if (!matchUncompleted && !matchCompleted) {
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("itemId"), it.key());
        row.insert(QStringLiteral("uid"), cached.todo->uid());
        row.insert(QStringLiteral("summary"), cached.todo->summary());
        row.insert(QStringLiteral("completed"), isCompleted);
        row.insert(QStringLiteral("completedDate"), compDt);
        row.insert(QStringLiteral("due"), dueDt);
        row.insert(QStringLiteral("priority"), cached.todo->priority());
        row.insert(QStringLiteral("categories"), cached.todo->categories());
        result.append(row);
    }
    return result;
}

QVariantMap TaskController::heatmapCountsForYear(int year, const QString &mode) const
{
    // For completions, iterate all Akonadi tasks (not just filtered model)
    // because completed tasks are excluded from the filtered model by default.
    if (mode == QLatin1String("completed")) {
        return heatmapCountsAll(QDate(year, 1, 1), QDate(year, 12, 31), mode);
    }
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return TaskLogic::heatmapCountsForYear(tasks, mode, QDate(year, 1, 1));
}

QVariantList TaskController::eventCalendars() const
{
    QVariantList result;
    result.reserve(s_eventCollections.size());
    for (const Akonadi::Collection &collection : s_eventCollections) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), collection.id());
        row.insert(QStringLiteral("name"), collection.displayName());
        row.insert(QStringLiteral("enabled"), TaskLogic::isEnabledCsv(m_busyCalendarIds, collection.id()));
        result.append(row);
    }
    return result;
}

void TaskController::setAgendaSelectedDate(const QDate &date)
{
    if (date == m_agendaSelectedDate) {
        return;
    }
    m_agendaSelectedDate = date;
    Q_EMIT agendaSelectedDateChanged();
}

void TaskController::bulkCompleteTasks(const QVariantList &itemIds, bool completed)
{
    for (const QVariant &id : itemIds) {
        setTaskCompleted(id.toLongLong(), completed);
    }
}

void TaskController::bulkDeleteTasks(const QVariantList &itemIds)
{
    for (const QVariant &id : itemIds) {
        deleteTask(id.toLongLong());
    }
    clearTaskSelection();
}

void TaskController::bulkMoveTasks(const QVariantList &itemIds, qint64 collectionId)
{
    for (const QVariant &id : itemIds) {
        moveTaskToCollection(id.toLongLong(), collectionId);
    }
}

void TaskController::bulkAddLabel(const QVariantList &itemIds, const QString &label)
{
    for (const QVariant &id : itemIds) {
        addTaskCategory(id.toLongLong(), label);
    }
}

void TaskController::bulkRemoveLabel(const QVariantList &itemIds, const QString &label)
{
    for (const QVariant &id : itemIds) {
        CachedTask *cache = prepareEdit(id.toLongLong());
        if (!cache || !cache->todo) {
            continue;
        }
        QStringList cats = TaskLogic::removeLabel(cache->todo->categories(), label);
        cache->todo->setCategories(cats);
        persistTodo(cache->item, cache->todo);
    }
}

void TaskController::bulkSetPriority(const QVariantList &itemIds, int priority)
{
    for (const QVariant &id : itemIds) {
        setTaskPriority(id.toLongLong(), priority);
    }
}

void TaskController::bulkRescheduleTasks(const QVariantList &itemIds, const QString &preset)
{
    for (const QVariant &id : itemIds) {
        rescheduleTask(id.toLongLong(), preset);
    }
}

QString TaskController::bulkExportUids(const QVariantList &itemIds) const
{
    QStringList uids;
    for (const QVariant &id : itemIds) {
        const int row = m_taskModel.rowForItemId(id.toLongLong());
        if (row < 0) {
            continue;
        }
        const QString uid = m_taskModel.uidAt(row);
        if (!uid.isEmpty()) {
            uids.append(uid);
        }
    }
    return uids.join(QLatin1Char('\n'));
}

void TaskController::reloadTask(qint64 itemId)
{
    const Akonadi::Item item = itemById(itemId);
    if (!item.isValid()) {
        return;
    }
    auto *job = new Akonadi::ItemFetchJob(item, this);
    job->fetchScope().fetchFullPayload();
    connect(job, &Akonadi::ItemFetchJob::result, this, [this, itemId](KJob *fetchJob) {
        auto *itemJob = qobject_cast<Akonadi::ItemFetchJob *>(fetchJob);
        if (!itemJob || itemJob->error() || itemJob->items().isEmpty()) {
            return;
        }
        upsertTask(itemJob->items().constFirst());
        scheduleRebuildAll();
        if (m_conflictItemId == itemId) {
            m_conflictItemId = -1;
            Q_EMIT conflictItemIdChanged();
        }
    });
}

void TaskController::dismissConflict()
{
    if (m_conflictItemId < 0) {
        return;
    }
    m_conflictItemId = -1;
    Q_EMIT conflictItemIdChanged();
}

QVariantList TaskController::smartViewsList() const
{
    QVariantList result;
    for (const TaskLogic::SmartViewDef &def : m_smartViews) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), def.id);
        row.insert(QStringLiteral("name"), def.name);
        row.insert(QStringLiteral("icon"), def.icon);
        row.insert(QStringLiteral("mode"), def.defaultMode);
        row.insert(QStringLiteral("sort"), def.sortOverride);
        row.insert(QStringLiteral("viewId"), QStringLiteral("smart:") + def.id);
        result.append(row);
    }
    return result;
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
    // Keep the timer running and intervals populated: the Agenda view and
    // reminder suppression share the same busy-event cache.
    m_busyEventTimer.start();
    scheduleRefreshBusyEvents();
    Q_EMIT eventBusySettingsChanged();
}

void TaskController::setBusyCalendarIds(const QString &ids)
{
    if (m_busyCalendarIds == ids) {
        return;
    }
    m_busyCalendarIds = ids;
    if (m_akonadiAvailable) {
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
        logAkonadi(QStringLiteral("prepareEdit: no cache for itemId=%1 cacheHit=%2 hasTodo=%3")
                       .arg(itemId)
                       .arg(it != s_tasks.end())
                       .arg(it != s_tasks.end() && bool(it->todo)));
        return nullptr;
    }
    if (!it->revertTodo) {
        it->revertTodo = cloneTodo(it->todo);
        it->revertCollectionId = it->item.parentCollection().id();
    }
    return &*it;
}

void TaskController::finishSync(qint64 itemId, SyncResult ok, const QString &errorString, const Akonadi::Item &ackedItem)
{
    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end()) {
        if (ok == SyncResult::Error && !errorString.isEmpty()) {
            logAkonadi(QStringLiteral("finishSync: missing cache itemId=%1 error=%2").arg(itemId).arg(errorString));
            setErrorMessage(errorString);
            Q_EMIT error(errorString);
        }
        return;
    }

    it->inflight = qMax(0, it->inflight - 1);
    if (it->inflight > 0) {
        logAkonadi(QStringLiteral("finishSync: still inflight itemId=%1 remaining=%2 ok=%3 error=%4")
                       .arg(itemId)
                       .arg(it->inflight)
                       .arg(ok == SyncResult::Ok)
                       .arg(errorString));
        if (ok == SyncResult::Error && !errorString.isEmpty()) {
            setErrorMessage(errorString);
            Q_EMIT error(errorString);
        }
        updateSyncingCount();
        return;
    }

    if (ok == SyncResult::Error) {
        logAkonadi(QStringLiteral("finishSync: ROLLBACK itemId=%1 rev=%2 collection=%3 queued=%4 error=%5")
                       .arg(itemId)
                       .arg(it->item.revision())
                       .arg(it->item.parentCollection().id())
                       .arg(it->persistQueued)
                       .arg(errorString));

        const bool isConflict = errorString.contains(QLatin1String("conflict"), Qt::CaseInsensitive)
                                || errorString.contains(QLatin1String("Concurrent"), Qt::CaseInsensitive);

        // FIX 2: Auto-resolve conflict — refetch fresh item, reapply user changes, resubmit.
        // Must happen BEFORE rollback clears submittedTodo/revertTodo.
        if (isConflict && it->submittedTodo) {
            logAkonadi(QStringLiteral("finishSync: conflict detected on itemId=%1, auto-resolving").arg(itemId));
            autoResolveConflict(itemId);
            return;
        }

        // Roll back optimistic edit to the last acknowledged snapshot.
        if (it->revertTodo) {
            it->todo = it->revertTodo;
            it->item.setPayload<KCalendarCore::Todo::Ptr>(it->todo);
            if (it->revertCollectionId > 0) {
                it->item.setParentCollection(Akonadi::Collection(it->revertCollectionId));
            }
        }
        it->pendingDelete = false;
        it->persistQueued = false;
        it->persistQueuedMoveId = -1;
        it->submittedTodo.clear();
        if (!errorString.isEmpty()) {
            setErrorMessage(errorString);
            Q_EMIT error(errorString);
        }
        if (isConflict) {
            m_conflictItemId = itemId;
            Q_EMIT conflictItemIdChanged();
        }
        it->revertTodo.clear();
        it->revertCollectionId = -1;
        it->syncing = false;
        it->inflight = 0;
        scheduleRebuildAll();
        return;
    }

    if (ackedItem.revision() > 0) {
        it->item.setRevision(ackedItem.revision());
    }
    if (ackedItem.parentCollection().id() > 0) {
        it->item.setParentCollection(ackedItem.parentCollection());
    }
    if (it->submittedTodo) {
        it->revertTodo = it->submittedTodo;
        it->revertCollectionId = it->item.parentCollection().id();
    }
    it->submittedTodo.clear();

    if (it->persistQueued) {
        const qint64 moveId = it->persistQueuedMoveId;
        logAkonadi(QStringLiteral("finishSync: flush queued persist itemId=%1 moveTo=%2")
                       .arg(itemId)
                       .arg(moveId));
        it->persistQueued = false;
        it->persistQueuedMoveId = -1;
        persistTodo(it->item, it->todo, moveId);
        return;
    }

    it->revertTodo.clear();
    it->revertCollectionId = -1;
    it->syncing = false;
    it->inflight = 0;
    scheduleRebuildAll();
}

void TaskController::onStoreFinished(const AbstractTaskStore::Result &result)
{
    logAkonadi(QStringLiteral("storeFinished kind=%1 clientId=%2 ok=%3 collection=%4 rev=%5 error=%6")
                   .arg(storeKindName(result.kind))
                   .arg(result.clientId)
                   .arg(result.ok)
                   .arg(result.collectionId)
                   .arg(result.item.isValid() ? result.item.revision() : -1)
                   .arg(result.errorString));
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
                   result.errorString,
                   result.item);
        return;
    }
}

void TaskController::persistTodo(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId)
{
    const qint64 itemId = item.id();
    if (itemId < 0 || !todo) {
        logAkonadi(QStringLiteral("persistTodo: skip invalid itemId=%1 hasTodo=%2").arg(itemId).arg(bool(todo)));
        return;
    }

    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end()) {
        logAkonadi(QStringLiteral("persistTodo: skip, not in cache itemId=%1 summary=%2")
                       .arg(itemId)
                       .arg(todo->summary()));
        return;
    }

    it->todo = todo;
    it->item.setPayload<KCalendarCore::Todo::Ptr>(todo);
    it->syncing = true;
    scheduleRebuildAll();

    if (it->inflight > 0) {
        it->persistQueued = true;
        it->persistQueuedMoveId = moveToCollectionId;
        logAkonadi(QStringLiteral("persistTodo: QUEUE while inflight itemId=%1 inflight=%2 rev=%3 collection=%4 akonadi=%5 moveTo=%6 summary=%7")
                       .arg(itemId)
                       .arg(it->inflight)
                       .arg(it->item.revision())
                       .arg(it->item.parentCollection().id())
                       .arg(m_akonadiAvailable)
                       .arg(moveToCollectionId)
                       .arg(todo->summary()));
        return;
    }

    if (!m_akonadiAvailable) {
        logAkonadi(QStringLiteral("persistTodo: SUBMIT while Akonadi offline itemId=%1 rev=%2 collection=%3 summary=%4")
                       .arg(itemId).arg(it->item.revision())
                       .arg(it->item.parentCollection().id()).arg(todo->summary()));
    }

    // FIX: If the cached item has revision 0, the DAV resource will send a broken
    // modify (no If-Match ETag → server rejects with 412). Refetch the item first
    // to get the correct Akonadi revision before submitting.
    if (m_akonadiAvailable && it->item.revision() == 0) {
        logAkonadi(QStringLiteral("persistTodo: revision=0 for itemId=%1, refetching before submit").arg(itemId));
        auto refetchItem = it->item;
        auto desiredTodo = todo;
        auto moveId = moveToCollectionId;
        auto *job = new Akonadi::ItemFetchJob(refetchItem, this);
        configureItemFetchJob(job);
        connect(job, &Akonadi::ItemFetchJob::result, this,
                [this, itemId, desiredTodo, moveId](KJob *kjob) {
            auto *fetchJob = qobject_cast<Akonadi::ItemFetchJob *>(kjob);
            auto it2 = s_tasks.find(itemId);
            if (!fetchJob || fetchJob->error() || fetchJob->items().isEmpty() || it2 == s_tasks.end()) {
                // Refetch failed: submit anyway, let autoResolveConflict handle it
                auto it3 = s_tasks.find(itemId);
                if (it3 != s_tasks.end()) {
                    submitModify(*it3, moveId);
                }
                return;
            }
            // Update cache with fresh item (correct revision)
            auto freshItem = fetchJob->items().constFirst();
            it2->item = freshItem;
            it2->item.setPayload<KCalendarCore::Todo::Ptr>(desiredTodo);
            logAkonadi(QStringLiteral("persistTodo: refetched itemId=%1, now rev=%2")
                           .arg(itemId).arg(freshItem.revision()));
            submitModify(*it2, moveId);
        });
        return;
    }

    submitModify(*it, moveToCollectionId);
}

void TaskController::submitModify(CachedTask &cached, qint64 moveToCollectionId)
{
    KCalendarCore::Todo::Ptr snapshot = cloneTodo(cached.todo);
    cached.submittedTodo = snapshot;
    cached.syncing = true;
    cached.inflight = 1;
    cached.persistQueued = false;

    Akonadi::Item modifiedItem = cached.item;
    modifiedItem.setPayload<KCalendarCore::Todo::Ptr>(snapshot);

    logAkonadi(QStringLiteral("submitModify itemId=%1 rev=%2 collection=%3 moveTo=%4 akonadi=%5 summary=%6")
                   .arg(cached.item.id())
                   .arg(modifiedItem.revision())
                   .arg(modifiedItem.parentCollection().id())
                   .arg(moveToCollectionId)
                   .arg(m_akonadiAvailable)
                   .arg(snapshot ? snapshot->summary() : QString()));

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Modify;
    req.clientId = cached.item.id();
    req.item = modifiedItem;
    req.moveAfterModifyId = moveToCollectionId;
    m_store->submit(req);
}

void TaskController::autoResolveConflict(qint64 itemId)
{
    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end()) {
        return;
    }

    if (!it->submittedTodo) {
        logAkonadi(QStringLiteral("autoResolveConflict: no submittedTodo for itemId=%1, surfacing error").arg(itemId));
        it->syncing = false;
        it->inflight = 0;
        m_conflictItemId = itemId;
        Q_EMIT conflictItemIdChanged();
        scheduleRebuildAll();
        return;
    }

    // Save the user's desired state
    auto desiredTodo = cloneTodo(it->submittedTodo);

    logAkonadi(QStringLiteral("autoResolveConflict: refetching itemId=%1 to reapply changes").arg(itemId));

    // Fetch the item fresh from Akonadi to get the current revision
    Akonadi::Item fetchItem(itemId);
    auto *job = new Akonadi::ItemFetchJob(fetchItem, this);
    configureItemFetchJob(job);
    connect(job, &Akonadi::ItemFetchJob::result, this,
            [this, itemId, desiredTodo](KJob *kjob) {
        auto *itemJob = qobject_cast<Akonadi::ItemFetchJob *>(kjob);
        if (!itemJob || itemJob->error() || itemJob->items().isEmpty()) {
            logAkonadi(QStringLiteral("autoResolveConflict: refetch failed for itemId=%1, surfacing error").arg(itemId));
            auto it2 = s_tasks.find(itemId);
            if (it2 != s_tasks.end()) {
                it2->submittedTodo.clear();
                it2->syncing = false;
                it2->inflight = 0;
                it2->revertTodo.clear();
                it2->revertCollectionId = -1;
            }
            m_conflictItemId = itemId;
            Q_EMIT conflictItemIdChanged();
            scheduleRebuildAll();
            return;
        }

        auto freshItem = itemJob->items().constFirst();
        auto it3 = s_tasks.find(itemId);
        if (it3 == s_tasks.end()) {
            return;
        }

        // Update cache with fresh Akonadi state (correct revision)
        KCalendarCore::Todo::Ptr freshTodo = todoFromItem(freshItem);
        it3->item = freshItem;
        if (freshTodo) {
            it3->todo = freshTodo;
        }

        it3->revertCollectionId = freshItem.parentCollection().id();

        // 3-way diff: base (revertTodo), user (desiredTodo), server (freshTodo)
        KCalendarCore::Todo::Ptr baseTodo = it3->revertTodo ? it3->revertTodo : freshTodo;
        QVariantList conflicts = computeMergeDiff(baseTodo, desiredTodo, freshTodo);

        if (!conflicts.isEmpty()) {
            // Fields conflict → show merge dialog
            logAkonadi(QStringLiteral("autoResolveConflict: %1 conflicts for itemId=%2, showing dialog")
                           .arg(conflicts.size()).arg(itemId));
            m_pendingMergeItemId = itemId;
            m_pendingMergeFields = conflicts;
            m_pendingMergeFreshTodo = freshTodo;
            m_conflictItemId = itemId;
            Q_EMIT conflictItemIdChanged();
            Q_EMIT mergeConflictAvailable(conflicts, itemId);
            return;
        }

        // No field conflicts → safe to auto-apply user changes
        logAkonadi(QStringLiteral("autoResolveConflict: no field conflicts, auto-applying itemId=%1 with fresh rev=%2")
                       .arg(itemId).arg(freshItem.revision()));

        it3->todo = desiredTodo;
        it3->item.setPayload<KCalendarCore::Todo::Ptr>(desiredTodo);
        it3->revertTodo = freshTodo ? cloneTodo(freshTodo) : KCalendarCore::Todo::Ptr();

        const qint64 moveId = it3->persistQueuedMoveId;
        it3->persistQueuedMoveId = -1;
        submitModify(*it3, moveId);
    });
}

QVariantList TaskController::computeMergeDiff(const KCalendarCore::Todo::Ptr &base,
                                              const KCalendarCore::Todo::Ptr &user,
                                              const KCalendarCore::Todo::Ptr &server) const
{
    QVariantList conflicts;
    auto addIfConflict = [&](const QString &key, const QString &label,
                              const QVariant &baseVal, const QVariant &userVal, const QVariant &serverVal) {
        if (userVal != baseVal && serverVal != baseVal) {
            QVariantMap m;
            m[QStringLiteral("key")] = key;
            m[QStringLiteral("label")] = label;
            m[QStringLiteral("userValue")] = userVal;
            m[QStringLiteral("serverValue")] = serverVal;
            m[QStringLiteral("baseValue")] = baseVal;
            conflicts.append(m);
        }
    };
    if (base && user && server) {
        addIfConflict(QStringLiteral("summary"), i18n("Summary"),
                       base->summary(), user->summary(), server->summary());
        addIfConflict(QStringLiteral("description"), i18n("Description"),
                       base->description(), user->description(), server->description());
        addIfConflict(QStringLiteral("priority"), i18n("Priority"),
                       base->priority(), user->priority(), server->priority());
        addIfConflict(QStringLiteral("percentComplete"), i18n("Progress"),
                       base->percentComplete(), user->percentComplete(), server->percentComplete());
        addIfConflict(QStringLiteral("categories"), i18n("Labels"),
                       base->categories().join(QStringLiteral(",")),
                       user->categories().join(QStringLiteral(",")),
                       server->categories().join(QStringLiteral(",")));
        addIfConflict(QStringLiteral("location"), i18n("Location"),
                       base->location(), user->location(), server->location());
        addIfConflict(QStringLiteral("dueDate"), i18n("Due date"),
                       base->hasDueDate() ? QVariant(base->dtDue()) : QVariant(),
                       user->hasDueDate() ? QVariant(user->dtDue()) : QVariant(),
                       server->hasDueDate() ? QVariant(server->dtDue()) : QVariant());
        addIfConflict(QStringLiteral("startDate"), i18n("Start date"),
                       base->hasStartDate() ? QVariant(base->dtStart()) : QVariant(),
                       user->hasStartDate() ? QVariant(user->dtStart()) : QVariant(),
                       server->hasStartDate() ? QVariant(server->dtStart()) : QVariant());
    }
    return conflicts;
}

void TaskController::resolveMergeConflict(const QVariantMap &resolution)
{
    const qint64 itemId = m_pendingMergeItemId;
    if (itemId < 0 || !m_pendingMergeFreshTodo) {
        return;
    }

    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end()) {
        m_pendingMergeItemId = -1;
        m_pendingMergeFields.clear();
        m_pendingMergeFreshTodo.clear();
        return;
    }

    logAkonadi(QStringLiteral("resolveMergeConflict: applying resolution for itemId=%1 fields=%2")
                   .arg(itemId).arg(resolution.size()));

    KCalendarCore::Todo::Ptr merged = KCalendarCore::Todo::Ptr(new KCalendarCore::Todo(*m_pendingMergeFreshTodo));

    for (auto it2 = resolution.constBegin(); it2 != resolution.constEnd(); ++it2) {
        const QString key = it2.key();
        const QString choice = it2.value().toString();
        if (choice == QLatin1String("user")) {
            for (const QVariant &fv : m_pendingMergeFields) {
                QVariantMap field = fv.toMap();
                if (field.value(QStringLiteral("key")).toString() != key) continue;
                const QVariant uv = field.value(QStringLiteral("userValue"));
                if (key == QLatin1String("summary")) merged->setSummary(uv.toString());
                else if (key == QLatin1String("description")) merged->setDescription(uv.toString());
                else if (key == QLatin1String("priority")) merged->setPriority(uv.toInt());
                else if (key == QLatin1String("percentComplete")) merged->setPercentComplete(uv.toInt());
                else if (key == QLatin1String("categories")) merged->setCategories(uv.toString().split(QLatin1Char(','), Qt::SkipEmptyParts));
                else if (key == QLatin1String("location")) merged->setLocation(uv.toString());
                else if (key == QLatin1String("dueDate")) {
                    if (uv.toDateTime().isValid()) merged->setDtDue(uv.toDateTime());
                    else merged->setDtDue(QDateTime());
                } else if (key == QLatin1String("startDate")) {
                    if (uv.toDateTime().isValid()) merged->setDtStart(uv.toDateTime());
                    else merged->setDtStart(QDateTime());
                }
                break;
            }
        }
        // "server" → keep fresh todo value (already set above)
    }

    // Check if any "edit" choices remain
    bool needsEditor = false;
    for (auto it2 = resolution.constBegin(); it2 != resolution.constEnd(); ++it2) {
        if (it2.value().toString() == QLatin1String("edit")) {
            needsEditor = true;
            break;
        }
    }

    if (needsEditor) {
        it->todo = merged;
        it->item.setPayload<KCalendarCore::Todo::Ptr>(merged);
        it->revertTodo = cloneTodo(m_pendingMergeFreshTodo);
        it->revertCollectionId = it->item.parentCollection().id();
        m_pendingMergeItemId = -1;
        m_pendingMergeFields.clear();
        m_pendingMergeFreshTodo.clear();
        m_conflictItemId = -1;
        Q_EMIT conflictItemIdChanged();
        scheduleRebuildAll();
        return;
    }

    it->todo = merged;
    it->item.setPayload<KCalendarCore::Todo::Ptr>(merged);
    it->submittedTodo = cloneTodo(merged);
    it->revertTodo = cloneTodo(m_pendingMergeFreshTodo);
    it->revertCollectionId = it->item.parentCollection().id();
    it->syncing = true;

    m_pendingMergeItemId = -1;
    m_pendingMergeFields.clear();
    m_pendingMergeFreshTodo.clear();
    m_conflictItemId = -1;
    Q_EMIT conflictItemIdChanged();

    submitModify(*it, -1);
}

void TaskController::testMergeConflict()
{
    if (s_tasks.isEmpty()) {
        logAkonadi(QStringLiteral("testMergeConflict: no tasks in cache"));
        return;
    }
    auto it = s_tasks.constBegin();
    const qint64 itemId = it.key();
    const auto &cached = it.value();
    if (!cached.todo) return;

    auto baseTodo = cloneTodo(cached.todo);
    auto userTodo = cloneTodo(cached.todo);
    auto serverTodo = cloneTodo(cached.todo);

    userTodo->setSummary(baseTodo->summary() + QStringLiteral(" (edited)"));
    serverTodo->setSummary(baseTodo->summary() + QStringLiteral(" (changed)"));
    userTodo->setPriority(1);
    serverTodo->setPriority(9);

    m_pendingMergeItemId = itemId;
    m_pendingMergeFreshTodo = serverTodo;
    m_pendingMergeFields = computeMergeDiff(baseTodo, userTodo, serverTodo);

    logAkonadi(QStringLiteral("testMergeConflict: showing %1 conflicting fields for itemId=%2")
                   .arg(m_pendingMergeFields.size()).arg(itemId));

    Q_EMIT mergeConflictAvailable(m_pendingMergeFields, itemId);
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
    entry.completedDate = todo->completed();
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
    entry.column = TaskCalendar::columnFromTodo(todo);
    entry.attendees = TaskCalendar::attendeesFromTodo(todo);
    entry.kanbanSortOrder = TaskCalendar::kanbanSortOrderFromTodo(todo);
    entry.geoUrl = TaskCalendar::geoMapUrlFromTodo(todo);
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

    if (!m_applyingUndo) {
        pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache));
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

    if (!m_applyingUndo) {
        pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache));
    }

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

void TaskController::createTaskFull(const QVariantMap &fields)
{
    if (!m_akonadiAvailable) {
        return;
    }

    // Resolve collection
    qint64 collectionId = fields.value(QStringLiteral("collectionId")).toLongLong();
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

    // Apply all fields the same way updateTaskFull does.
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
        const QDateTime startDate = dateTimeFromVariant(fields.value(QStringLiteral("startDate")));
        if (startDate.isValid()) {
            todo->setDtStart(startDate);
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

    Akonadi::Item item(todo->mimeType());
    item.setPayload<KCalendarCore::Todo::Ptr>(todo);
    item.setParentCollection(collection);

    auto *job = new Akonadi::ItemCreateJob(item, collection, this);
    connect(job, &KJob::result, this, [this, job]() {
        if (job->error() != KJob::NoError) {
            setErrorMessage(tr("Failed to create task: %1").arg(job->errorText()));
            Q_EMIT error(m_errorMessage);
        }
    });
}

void TaskController::setTaskParent(qint64 itemId, const QString &parentUid)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        setErrorMessage(tr("Task not found."));
        Q_EMIT error(m_errorMessage);
        return;
    }

    if (!m_applyingUndo) {
        pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache));
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
    if (!m_applyingUndo) {
        pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache));
    }
    const QStringList categories = TaskLogic::addLabel(todo->categories(), trimmed);
    if (categories == todo->categories()) {
        return;
    }
    todo->setCategories(categories);
    persistTodo(cache->item, todo);
}

void TaskController::removeTaskCategory(qint64 itemId, const QString &category)
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
    const QStringList categories = TaskLogic::removeLabel(todo->categories(), trimmed);
    if (categories == todo->categories()) {
        return;
    }
    if (!m_applyingUndo) {
        pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache));
    }
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
    if (!m_applyingUndo) {
        pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Edit, *cache));
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

    if (record.restoreLayout) {
        setKanbanManualOrderJson(record.kanbanManualOrderJson);
        setSortMode(record.sortMode);
    }

    if (record.kind == TaskLogic::UndoRecord::Kind::KanbanLayout) {
        m_applyingUndo = false;
        return;
    }

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

    if (record.kind == TaskLogic::UndoRecord::Kind::Edit) {
        if (record.collectionId > 0) {
            CachedTask *existing = prepareEdit(record.itemId);
            if (existing && existing->item.parentCollection().id() != record.collectionId) {
                moveTaskToCollection(record.itemId, record.collectionId);
            }
        }
        applyTaskUndo(record);
        persistTodo(cache->item, cache->todo);
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

void TaskController::applyTaskUndo(const TaskLogic::UndoRecord &record)
{
    CachedTask *cache = prepareEdit(record.itemId);
    if (!cache || !cache->todo) {
        return;
    }
    KCalendarCore::Todo::Ptr todo = cache->todo;
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
    record.status = static_cast<int>(cache.todo->status());
    record.secrecy = static_cast<int>(cache.todo->secrecy());
    record.column = TaskCalendar::columnFromTodo(cache.todo);
    return record;
}

void TaskController::pushUndo(TaskLogic::UndoRecord record)
{
    if (m_applyingUndo || m_batchUndo || record.kind == TaskLogic::UndoRecord::Kind::None) {
        return;
    }
    m_undo.push(record);
    Q_EMIT undoChanged();
}

QString TaskController::undoLabel() const
{
    if (!m_undo.canUndo()) {
        return tr("Undo");
    }
    const TaskLogic::UndoRecord rec = m_undo.peek();
    const QString title = rec.summary.trimmed().isEmpty() ? tr("(Untitled)") : rec.summary.trimmed();
    switch (rec.kind) {
    case TaskLogic::UndoRecord::Kind::Complete:
        return rec.completed ? tr("Undo marking “%1” incomplete").arg(title)
                             : tr("Undo complete of “%1”").arg(title);
    case TaskLogic::UndoRecord::Kind::Reschedule:
        return tr("Undo reschedule of “%1”").arg(title);
    case TaskLogic::UndoRecord::Kind::Move:
        return tr("Undo move of “%1”").arg(title);
    case TaskLogic::UndoRecord::Kind::Delete:
        return tr("Undo delete of “%1”").arg(title);
    case TaskLogic::UndoRecord::Kind::Edit:
        if (rec.restoreLayout) {
            return tr("Undo Kanban change of “%1”").arg(title);
        }
        return tr("Undo edit of “%1”").arg(title);
    case TaskLogic::UndoRecord::Kind::KanbanLayout:
        return title == tr("(Untitled)") ? tr("Undo Kanban order")
                                         : tr("Undo Kanban order of “%1”").arg(title);
    case TaskLogic::UndoRecord::Kind::None:
        break;
    }
    return tr("Undo");
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
    KurrentLogging::verbose(message);
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
                logAkonadi(QStringLiteral("ServerManager stateChanged=%1 monitor=%2 akonadiAvailable=%3")
                               .arg(serverStateName(state))
                               .arg(m_monitor != nullptr)
                               .arg(m_akonadiAvailable));
                if (state != Akonadi::ServerManager::Running && m_monitor) {
                    logAkonadi(QStringLiteral("ServerManager: not Running while monitor is attached — ItemModifyJob may stall or fail"));
                }
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
        logAkonadi(QStringLiteral("initializeAkonadi: waiting for Akonadi (state=%1 comingUp=%2 startOk=%3)")
                     .arg(serverStateName(state))
                     .arg(comingUp)
                     .arg(startOk));
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
    logAkonadi(QStringLiteral("initializeAkonadi: Akonadi running, creating monitor"));
    Q_EMIT akonadiAvailableChanged();
    updateEmptyKind();
    m_busyEventTimer.start();
    scheduleRefreshBusyEvents();

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
        for (TaskController *inst : s_instances) {
            Q_EMIT inst->eventBusySettingsChanged();
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

        scheduleRefreshBusyEvents();

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
    updateSyncingCount();

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
    updateSyncingCount();

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
    if (existing != s_tasks.end()) {
        if (existing->syncing || existing->inflight > 0 || existing->pendingDelete || existing->persistQueued) {
            return;
        }
        const int incomingRevision = item.revision();
        const int cachedRevision = existing->item.revision();
        if (incomingRevision > 0 && cachedRevision > 0 && incomingRevision < cachedRevision) {
            return;
        }
        // FIX 1: Reject same-revision stale echoes from DAV resource sync races.
        // If revision matches but the todo summary differs, the incoming payload
        // is stale (the resource fetched before our modify propagated). Our local
        // optimistic state is more current.
        if (incomingRevision > 0 && cachedRevision > 0 && incomingRevision == cachedRevision
            && existing->todo && todo
            && existing->todo->summary() != todo->summary()) {
            return;
        }
        // FIX 1b: If the incoming item has revision 0 (DAV resource notification without
        // revision), never overwrite a cached item that has a real revision. Revision 0
        // means "I don't know the version" — keeping the cached revision is safer.
        if (incomingRevision == 0 && cachedRevision > 0) {
            return;
        }
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
    cached.todo = cloneTodo(todo);
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

void TaskController::setListReorganizing(bool reorganizing)
{
    if (m_listReorganizing == reorganizing) {
        return;
    }
    m_listReorganizing = reorganizing;
    Q_EMIT listReorganizingChanged();
}

void TaskController::maybeShowReorganizing()
{
    setListReorganizing(true);
}

void TaskController::initRebuildPerfDefaults()
{
    const int cores = qMax(1, QThread::idealThreadCount());
    m_rebuildBaseMs = 12;
    m_rebuildMsPerTask = 0.14 / qMax(1.0, cores / 2.0);
    m_viewColdLoadMs = 90;
}

void TaskController::loadRebuildPerfProfile()
{
    initRebuildPerfDefaults();
    const QVariantMap settings = SharedSettings::instance()->values();
    const QString json = settings.value(QStringLiteral("rebuildPerfProfile")).toString().trimmed();
    if (json.isEmpty()) {
        Q_EMIT rebuildPerfChanged();
        return;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        Q_EMIT rebuildPerfChanged();
        return;
    }
    const QJsonObject obj = doc.object();
    if (obj.contains(QStringLiteral("msPerTask"))) {
        m_rebuildMsPerTask = qMax(0.01, obj.value(QStringLiteral("msPerTask")).toDouble(0.08));
    }
    if (obj.contains(QStringLiteral("baseMs"))) {
        m_rebuildBaseMs = qMax(0, obj.value(QStringLiteral("baseMs")).toInt(12));
    }
    if (obj.contains(QStringLiteral("viewColdLoadMs"))) {
        m_viewColdLoadMs = qMax(0, obj.value(QStringLiteral("viewColdLoadMs")).toInt(90));
    }
    if (obj.contains(QStringLiteral("updatedAt"))) {
        m_rebuildPerfUpdatedAt = obj.value(QStringLiteral("updatedAt")).toVariant().toLongLong();
    }
    Q_EMIT rebuildPerfChanged();
}

void TaskController::persistRebuildPerfProfile()
{
    QJsonObject obj;
    obj.insert(QStringLiteral("msPerTask"), m_rebuildMsPerTask);
    obj.insert(QStringLiteral("baseMs"), m_rebuildBaseMs);
    obj.insert(QStringLiteral("viewColdLoadMs"), m_viewColdLoadMs);
    obj.insert(QStringLiteral("updatedAt"), m_rebuildPerfUpdatedAt);
    const QByteArray encoded = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    SharedSettings::instance()->storeString(QStringLiteral("rebuildPerfProfile"), QString::fromUtf8(encoded));
}

void TaskController::maybePersistRebuildPerfWeekly()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    constexpr qint64 kWeekMs = 7LL * 24 * 3600 * 1000;
    if (m_rebuildPerfUpdatedAt > 0 && now - m_rebuildPerfUpdatedAt < kWeekMs) {
        return;
    }
    if (m_rebuildSampleCount <= 0) {
        if (m_rebuildPerfUpdatedAt <= 0) {
            m_rebuildPerfUpdatedAt = now;
            persistRebuildPerfProfile();
        }
        return;
    }

    const double measured = m_rebuildSampleSumPerTask / m_rebuildSampleCount;
    if (m_rebuildPerfUpdatedAt > 0) {
        m_rebuildMsPerTask = m_rebuildMsPerTask * 0.35 + measured * 0.65;
    } else {
        m_rebuildMsPerTask = measured;
    }
    m_rebuildSampleSumPerTask = 0.0;
    m_rebuildSampleCount = 0;
    m_rebuildPerfUpdatedAt = now;
    persistRebuildPerfProfile();
    Q_EMIT rebuildPerfChanged();
}

void TaskController::recordRebuildTiming(qint64 elapsedMs, int taskCount)
{
    if (elapsedMs <= 0) {
        return;
    }
    const int n = qMax(1, taskCount);
    const double perTask = qMax(0.0, static_cast<double>(elapsedMs - m_rebuildBaseMs) / n);
    m_rebuildSampleSumPerTask += perTask;
    ++m_rebuildSampleCount;
    maybePersistRebuildPerfWeekly();
}

int TaskController::estimatedRebuildMs() const
{
    const int n = s_tasks.size();
    return m_rebuildBaseMs + qRound(n * m_rebuildMsPerTask);
}

int TaskController::estimatedViewSwitchMs(bool coldLoader) const
{
    const int cold = coldLoader ? m_viewColdLoadMs : 0;
    return qMax(cold, estimatedRebuildMs());
}

QList<TaskEntry> TaskController::snapshotAllTasks() const
{
    QList<TaskEntry> allTasks;
    allTasks.reserve(s_tasks.size());
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (!it->todo) {
            continue;
        }
        allTasks.append(makeTaskEntry(it.value(), 0, false));
    }
    return allTasks;
}

TaskLogic::ListGroupOrderContext TaskController::buildListGroupOrderContext() const
{
    TaskLogic::ListGroupOrderContext ctx;
    const QVariantMap settings = SharedSettings::instance()->values();
    const bool showEmpty = settings.value(QStringLiteral("showEmptyProjects")).toBool();

    QSet<qint64> hiddenProjects;
    for (const QString &part : settings.value(QStringLiteral("hiddenProjects")).toString().split(QLatin1Char(','))) {
        bool ok = false;
        const qint64 id = part.trimmed().toLongLong(&ok);
        if (ok) {
            hiddenProjects.insert(id);
        }
    }

    const QStringList hiddenLabelTokens =
            TaskLogic::parseTokens(settings.value(QStringLiteral("hiddenLabels")).toString(),
                                   QStringLiteral("||"));
    const QSet<QString> hiddenLabels(hiddenLabelTokens.begin(), hiddenLabelTokens.end());

    const QStringList hiddenLocationTokens =
            TaskLogic::parseTokens(settings.value(QStringLiteral("hiddenLocations")).toString(),
                                   QStringLiteral("||"));
    const QSet<QString> hiddenLocations(hiddenLocationTokens.begin(), hiddenLocationTokens.end());

    for (int row = 0; row < m_collectionModel.rowCount(); ++row) {
        const qint64 collectionId = m_collectionModel.collectionIdAt(row);
        if (hiddenProjects.contains(collectionId)) {
            continue;
        }
        if (!showEmpty && m_collectionModel.taskCountAt(row) <= 0) {
            continue;
        }
        ctx.projectKeys.append(QString::number(collectionId));
    }

    for (const QString &label : m_availableLabels) {
        if (!hiddenLabels.contains(label)) {
            ctx.labelKeys.append(label);
        }
    }

    for (const QString &location : m_availableLocations) {
        if (!hiddenLocations.contains(location)) {
            ctx.locationKeys.append(location);
        }
    }

    return ctx;
}

TaskLogic::TaskRebuildInput TaskController::buildRebuildInput(const QList<TaskEntry> &allTasks) const
{
    TaskLogic::TaskRebuildInput input;
    input.allTasks = allTasks;
    input.filters = filterState();
    input.collapsedUids = m_collapsedUids;
    input.sortMode = m_sortMode;
    input.listGroupMode = m_listGroupMode;
    input.listGroupOrder = buildListGroupOrderContext();
    input.planPreviewWeek = m_planPreviewWeek;
    input.planPreviewProject = m_planPreviewProject;
    input.hierarchyAware = m_currentView == QLatin1String("completed")
            || !m_searchQuery.trimmed().isEmpty()
            || TaskLogic::hasSidebarFilters(input.filters);
    return input;
}

void TaskController::applyRebuildOutput(const TaskLogic::TaskRebuildOutput &output)
{
    const QList<TaskEntry> &countSource = m_countsExcludeCollapsed ? output.flatForCounts : output.allTasks;
    m_collectionModel.setTaskCounts(TaskLogic::collectionTaskCounts(countSource));
    m_taskModel.setTasks(output.tasks);

    // Defer the remaining updates by one event-loop iteration: the model
    // update renders first and animations (sidebar highlight, view
    // transitions) are not interrupted by the follow-up main-thread work.
    m_deferredCountSource = countSource;
    m_deferredAllTasks = output.allTasks;
    m_deferredFlatCount = output.flatForCounts.size();
    m_deferredVisibleCount = output.tasks.size();
    m_deferredOutCompleted = output.filtered.filteredOutCompleted;
    m_deferredOutView = output.filtered.filteredOutView;
    m_deferredOutSearch = output.filtered.filteredOutSearch;
    if (!m_deferredTailPending) {
        m_deferredTailPending = true;
        QTimer::singleShot(0, this, &TaskController::applyDeferredRebuildTail);
    }
}

void TaskController::applyDeferredRebuildTail()
{
    if (!m_deferredTailPending) {
        return;
    }
    // If the model is still applying chunked row operations, defer again —
    // updateEmptyKind and updateCounts would read intermediate row counts.
    if (m_taskModel.chunksActive()) {
        QTimer::singleShot(0, this, &TaskController::applyDeferredRebuildTail);
        return;
    }
    m_deferredTailPending = false;
    updatePendingCount(m_deferredCountSource);
    updateSyncingCount();
    updateAvailableLabels(m_deferredAllTasks);
    updateAvailableLocations(m_deferredAllTasks);
    updateCounts(m_deferredCountSource);
    publishSharedCache();
    updateEmptyKind();
    updateDebugInfo(m_deferredFlatCount,
                    m_deferredVisibleCount,
                    m_deferredOutCompleted,
                    m_deferredOutView,
                    m_deferredOutSearch);
    updateKanbanLayout();
}

void TaskController::startAsyncRebuild(const TaskLogic::TaskRebuildInput &input)
{
    ++m_rebuildGeneration;
    m_pendingRebuildGeneration = m_rebuildGeneration;
    m_rebuildAgainPending = false;
    m_lastRebuildTaskCount = input.allTasks.size();
    m_rebuildTiming.start();
    setListReorganizing(true);
    const QDate today = QDate::currentDate();
    m_rebuildWatcher.setFuture(QtConcurrent::run([input, today]() {
        return TaskLogic::computeTaskRebuild(input, today);
    }));
}

void TaskController::onRebuildFinished()
{
    if (m_rebuildWatcher.future().isCanceled()) {
        if (m_rebuildAgainPending) {
            m_rebuildAgainPending = false;
            rebuildTaskList();
            return;
        }
        setListReorganizing(false);
        return;
    }

    const quint64 generation = m_pendingRebuildGeneration;
    if (generation != m_rebuildGeneration) {
        return;
    }

    applyRebuildOutput(m_rebuildWatcher.result());
    recordRebuildTiming(m_rebuildTiming.elapsed(), m_lastRebuildTaskCount);

    if (m_rebuildAgainPending) {
        m_rebuildAgainPending = false;
        rebuildTaskList();
        return;
    }
    setListReorganizing(false);
}

void TaskController::rebuildTaskList()
{
    const QList<TaskEntry> allTasks = snapshotAllTasks();
    const TaskLogic::TaskRebuildInput input = buildRebuildInput(allTasks);

    if (m_rebuildWatcher.isRunning()) {
        m_rebuildAgainPending = true;
        ++m_rebuildGeneration;
        setListReorganizing(true);
        return;
    }
    startAsyncRebuild(input);
}

void TaskController::updateKanbanLayout()
{
    m_kanbanColumnKeys = kanbanColumnKeysForVisibleTasks();
    ++m_kanbanRevision;
    Q_EMIT kanbanLayoutChanged();
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
    return TaskLogic::matchesFilters(task, filterState());
}

bool TaskController::taskMatchesViewId(const TaskEntry &task, const QString &viewId) const
{
    if (viewId.startsWith(QLatin1String("smart:"))) {
        const QString smartId = viewId.mid(6);
        for (const TaskLogic::SmartViewDef &def : m_smartViews) {
            if (def.id == smartId) {
                return TaskLogic::matchesSmartView(task, def.rules, QDate::currentDate());
            }
        }
        return false;
    }
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

void TaskController::updateSyncingCount()
{
    int jobs = m_pendingFetchJobs;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->syncing || it->pendingDelete || it->inflight > 0) {
            jobs += qMax(1, it->inflight);
        }
    }
    if (m_syncingCount == jobs) {
        return;
    }
    m_syncingCount = jobs;
    Q_EMIT syncingCountChanged();
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

void TaskController::updateAvailableLocations(const QList<TaskEntry> &tasks)
{
    const QStringList sorted = TaskLogic::collectAvailableLocations(tasks, s_extraLocations);
    if (m_availableLocations == sorted) {
        return;
    }
    m_availableLocations = sorted;
    Q_EMIT availableLocationsChanged();
}

void TaskController::updateCounts(const QList<TaskEntry> &tasks)
{
    const TaskLogic::FilterState filters = filterState();
    const TaskLogic::SidebarCounts counts = TaskLogic::computeCounts(tasks, filters, s_extraLabels, QDate::currentDate());

    if (m_labelTaskCounts != counts.totalLabels) {
        m_labelTaskCounts = counts.totalLabels;
        Q_EMIT labelTaskCountsChanged();
    }
    if (m_viewTaskCounts != counts.viewCounts || m_sidebarProjectCounts != counts.sidebarProjects
        || m_sidebarLabelCounts != counts.sidebarLabels || m_sidebarPriorityCounts != counts.sidebarPriorities
        || m_sidebarProgressCounts != counts.sidebarProgress || m_sidebarStatusCounts != counts.sidebarStatus
        || m_sidebarSecrecyCounts != counts.sidebarSecrecy || m_sidebarLocationCounts != counts.sidebarLocations) {
        m_viewTaskCounts = counts.viewCounts;
        m_sidebarProjectCounts = counts.sidebarProjects;
        m_sidebarLabelCounts = counts.sidebarLabels;
        m_sidebarPriorityCounts = counts.sidebarPriorities;
        m_sidebarProgressCounts = counts.sidebarProgress;
        m_sidebarStatusCounts = counts.sidebarStatus;
        m_sidebarSecrecyCounts = counts.sidebarSecrecy;
        m_sidebarLocationCounts = counts.sidebarLocations;
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
    if (s_collections.isEmpty() && s_tasks.isEmpty() && s_extraLabels.isEmpty() && s_extraLocations.isEmpty()) {
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

void TaskController::createLocation(const QString &name)
{
    if (!TaskLogic::canCreateLabel(name, m_availableLocations, s_extraLocations)) {
        return;
    }
    s_extraLocations.append(name.trimmed());
    scheduleRebuildAll();
}

void TaskController::deleteLocation(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    s_extraLocations.removeAll(trimmed);

    if (!m_akonadiAvailable) {
        initializeAkonadi();
    }

    QList<qint64> toUpdate;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo && it->todo->location().trimmed() == trimmed) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        CachedTask *cache = prepareEdit(itemId);
        if (!cache || !cache->todo) {
            continue;
        }
        cache->todo->setLocation(QString());
        persistTodo(cache->item, cache->todo);
    }

    scheduleRebuildAll();
}

void TaskController::renameLocation(const QString &from, const QString &to)
{
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (!TaskLogic::canRenameLabel(source, dest, m_availableLocations, s_extraLocations)) {
        return;
    }

    for (int i = 0; i < s_extraLocations.size(); ++i) {
        if (s_extraLocations.at(i) == source) {
            s_extraLocations[i] = dest;
        }
    }
    s_extraLocations.removeAll(source);
    if (!s_extraLocations.contains(dest)) {
        s_extraLocations.append(dest);
    }

    QList<qint64> toUpdate;
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (it->todo && it->todo->location().trimmed() == source) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        CachedTask *cache = prepareEdit(itemId);
        if (!cache || !cache->todo) {
            continue;
        }
        cache->todo->setLocation(dest);
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

void TaskController::broadcastDbusSearchAndShow(const QString &query)
{
    for (TaskController *controller : s_instances) {
        Q_EMIT controller->dbusSearchRequested(query);
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
    if (!m_akonadiAvailable) {
        return;
    }
    QTimer::singleShot(0, this, &TaskController::refreshBusyEvents);
}

void TaskController::refreshBusyEvents()
{
    // Busy events feed both reminder suppression and the Agenda view,
    // so they are fetched whenever Akonadi is available.
    if (!m_akonadiAvailable) {
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
    // Wide enough for agenda week navigation and heatmap click-through.
    const QDateTime rangeStart = now.addDays(-35);
    const QDateTime rangeEnd = now.addDays(70);

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
                const int before = m_busyFetchIntervals.size();
                TaskCalendar::appendBusyIntervals(event, rangeStart, rangeEnd, &m_busyFetchIntervals);
                for (int i = before; i < m_busyFetchIntervals.size(); ++i) {
                    m_busyFetchIntervals[i].collectionId = item.parentCollection().id();
                }
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
