#include "taskcontroller.h"

#include "agendalogic.h"
#include "akonadiitems.h"
#include "akonadiloader.h"
#include "akonadiutil.h"
#include "boardlogic.h"
#include "kurrentlogging.h"
#ifdef KURRENT_WITH_DEMO
#include "demodata.h"
#endif
#include "memorytaskstore.h"
#include "sessionhooks.h"
#include "sharedsettings.h"
#include "taskcalendar.h"
#include "taskentry.h"
#include "tasklogic.h"

#include <Akonadi/Collection>

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
#include <QProcess>
#include <optional>
#include <QTime>
#include <QDebug>
#include <QFile>
#include <QDesktopServices>
#include <QUrl>
#include <QGuiApplication>
#include <QHash>
#include <QLoggingCategory>
#include <QScopedValueRollback>
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
constexpr int kAsyncRebuildThreshold = 40;
constexpr int kDefaultCatchUpDays = 14;
const QString kSmartPrefix = QStringLiteral("smart:");

// kurrentrc keys the controller reads or writes (SharedSettings::specs()).
namespace Key
{
const QString DefaultView = QStringLiteral("defaultView");
const QString RememberLastView = QStringLiteral("rememberLastView");
const QString LastView = QStringLiteral("lastView");
const QString EnabledCollections = QStringLiteral("enabledCollections");
const QString ShowCompleted = QStringLiteral("showCompleted");
const QString CatchUpEnabled = QStringLiteral("catchUpEnabled");
const QString CatchUpDays = QStringLiteral("catchUpDays");
const QString MorningHour = QStringLiteral("morningHour");
const QString AfternoonHour = QStringLiteral("afternoonHour");
const QString EveningHour = QStringLiteral("eveningHour");
const QString DefaultDueMode = QStringLiteral("defaultDueMode");
const QString SearchTitleOnly = QStringLiteral("searchTitleOnly");
const QString SearchCaseSensitive = QStringLiteral("searchCaseSensitive");
const QString CompleteChildren = QStringLiteral("completeChildren");
const QString CountsExcludeCollapsed = QStringLiteral("countsExcludeCollapsed");
const QString NotificationsEnabled = QStringLiteral("notificationsEnabled");
const QString DefaultReminderMinutes = QStringLiteral("defaultReminderMinutes");
const QString QuietHoursEnabled = QStringLiteral("quietHoursEnabled");
const QString QuietHoursStart = QStringLiteral("quietHoursStart");
const QString QuietHoursEnd = QStringLiteral("quietHoursEnd");
const QString SuppressReminders = QStringLiteral("suppressRemindersDuringEvents");
const QString BusyCalendarIds = QStringLiteral("busyCalendarIds");
const QString SmartViews = QStringLiteral("smartViews");
const QString SortMode = QStringLiteral("sortMode");
const QString SortScope = QStringLiteral("sortScope");
const QString SortModeByView = QStringLiteral("sortModeByView");
const QString ListGroupMode = QStringLiteral("listGroupMode");
const QString MainPaneMode = QStringLiteral("mainPaneMode");
const QString KanbanColumnSource = QStringLiteral("kanbanColumnSource");
const QString KanbanWriteMode = QStringLiteral("kanbanWriteMode");
const QString KanbanManualOrder = QStringLiteral("kanbanManualOrder");
const QString KanbanSortByColumn = QStringLiteral("kanbanSortModeByViewColumn");
const QString SwimlaneLaneAxis = QStringLiteral("swimlaneLaneAxis");
const QString SwimlaneTimeBucket = QStringLiteral("swimlaneTimeBucket");
const QString SwimlaneHorizon = QStringLiteral("swimlaneHorizon");
const QString PlanTimeBucket = QStringLiteral("planTimeBucket");
const QString PlanHorizon = QStringLiteral("planHorizon");
const QString PlanShowUndated = QStringLiteral("planShowUndated");
const QString PlanShowCompleted = QStringLiteral("planShowCompleted");
const QString AgendaMode = QStringLiteral("agendaMode");
const QString AgendaWeekend = QStringLiteral("agendaWeekend");
const QString AgendaWorkMinutes = QStringLiteral("agendaWorkMinutes");
const QString MultiSelectEnabled = QStringLiteral("multiSelectEnabled");
const QString KanbanHideCanceled = QStringLiteral("kanbanHideCanceled");
const QString HiddenProjects = QStringLiteral("hiddenProjects");
const QString HiddenLabels = QStringLiteral("hiddenLabels");
const QString HiddenLocations = QStringLiteral("hiddenLocations");
const QString ShowEmptyProjects = QStringLiteral("showEmptyProjects");
const QString NewTaskProjectMode = QStringLiteral("newTaskProjectMode");
const QString NewTaskDefaultCollection = QStringLiteral("newTaskDefaultCollectionId");
const QString PanelBadge = QStringLiteral("panelBadge");
const QString PanelBadgeOverdueColor = QStringLiteral("panelBadgeOverdueColor");
}

const QString kIdSeparator = QStringLiteral(",");
const QString kNameSeparator = QStringLiteral("||");
const QString kScopeAll = QStringLiteral("all");

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

QList<TaskController *> TaskController::s_instances;
TaskController::SessionServices TaskController::s_sessionServices = TaskController::SessionServices::On;

TaskController::TaskController(QObject *parent)
    : QObject(parent)
{
    s_instances.append(this);

    createHooks();

    m_rebuildTimer.setInterval(kRebuildDelayMs);
    m_rebuildTimer.setSingleShot(true);
    connect(&m_rebuildTimer, &QTimer::timeout, this, &TaskController::rebuildTaskList);
    connectShared();
    connectLoader();

    connect(&m_rebuildWatcher, &QFutureWatcher<TaskLogic::TaskRebuildOutput>::finished, this,
            &TaskController::onRebuildFinished);


    // Every write goes through the writer and its store; MemoryTaskStore swaps in for unit tests.
    m_bridge = new SettingsBridge(this);
    m_writer = new TaskWriter(m_shared, [this] { return m_akonadiAvailable; }, this);
    connect(m_writer, &TaskWriter::finished, this, &TaskController::onStoreFinished);
    connect(m_writer, &TaskWriter::error, this, &TaskController::error);
    connect(m_writer, &TaskWriter::conflictItemIdChanged, this, &TaskController::conflictItemIdChanged);
    connect(m_writer, &TaskWriter::mergeConflictAvailable, this, &TaskController::mergeConflictAvailable);
    connect(m_writer, &TaskWriter::inflightChanged, this, &TaskController::updateSyncingCount);
    m_undo = new TaskUndo(this);
    connect(m_undo, &TaskUndo::changed, this, &TaskController::undoChanged);
    createReminders();
    m_agenda = new TaskAgenda(
        m_shared, *m_undo,
        {[this](qint64 itemId, const QVariantMap &fields) { updateTaskFull(itemId, fields); },
         [this](qint64 itemId, qint64 days) { return moveSeriesOccurrence(itemId, days); },
         [this](qint64 itemId, const QDateTime &start, const QDateTime &due) { detachSeriesOccurrence(itemId, start, due); }},
        this);
    connect(m_agenda, &TaskAgenda::selectedDateChanged, this, &TaskController::agendaSelectedDateChanged);
    connect(m_agenda, &TaskAgenda::settingsChanged, this, &TaskController::agendaSettingsChanged);

    // The sort menu's offer depends on the sort, the layout, the Kanban columns and the group.
    connect(this, &TaskController::sortModeChanged, this, &TaskController::sortOptionsChanged);
    connect(this, &TaskController::mainPaneModeChanged, this, &TaskController::sortOptionsChanged);
    connect(this, &TaskController::kanbanColumnSourceChanged, this, &TaskController::sortOptionsChanged);
    connect(this, &TaskController::listGroupModeChanged, this, &TaskController::sortOptionsChanged);
    connect(this, &TaskController::mainPaneModeChanged, this, &TaskController::blockedFiltersChanged);
    connect(this, &TaskController::kanbanColumnSourceChanged, this, &TaskController::blockedFiltersChanged);
    connect(this, &TaskController::swimlaneSettingsChanged, this, &TaskController::blockedFiltersChanged);
    connect(this, &TaskController::pendingCountChanged, this, &TaskController::badgeChanged);
    connect(this, &TaskController::kanbanLayoutChanged, this, &TaskController::shownKanbanColumnsChanged);
    connect(this, &TaskController::kanbanColumnSourceChanged, this, &TaskController::shownKanbanColumnsChanged);
    connect(this, &TaskController::sidebarCountsChanged, this, &TaskController::badgeChanged);
    connect(this, &TaskController::settingsChanged, this, &TaskController::badgeChanged);

    KurrentLogging::reloadFromSharedSettings();
    connect(SharedSettings::instance(), &SharedSettings::changed, this, []() {
        KurrentLogging::reloadFromSharedSettings();
    });

#ifdef KURRENT_WITH_DEMO
    if (DemoData::enabled()) {
        loadDemoData();
    } else {
        hydrateFromCache();
    }
#else
    hydrateFromCache();
#endif
    loadRebuildPerfProfile();
    // D-Bus and GlobalAccel talk to the session bus; let QML finish constructing first.
    QTimer::singleShot(0, this, [this]() {
        if (s_sessionServices == SessionServices::Off) {
            return;
        }
        registerSessionInterface();
        registerGlobalShortcuts();
    });
}

// Reminders; they ask whether Akonadi is up and snooze through this controller's write path.
void TaskController::createReminders()
{
    m_reminders = new TaskReminders(
        m_shared,
        {[this] { return m_akonadiAvailable; },
         [this](qint64 itemId, const QString &preset) { snoozeTask(itemId, preset); }},
        this);
    connect(m_reminders, &TaskReminders::enabledChanged, this, &TaskController::notificationsEnabledChanged);
    connect(m_reminders, &TaskReminders::defaultMinutesChanged, this, &TaskController::defaultReminderMinutesChanged);
    connect(m_reminders, &TaskReminders::quietHoursChanged, this, &TaskController::quietHoursChanged);
    connect(m_reminders, &TaskReminders::suppressDuringEventsChanged, this, &TaskController::eventBusySettingsChanged);
}

// The smoke test and screenshot hooks; their signals are this controller's.
void TaskController::createHooks()
{
    m_hooks = new SessionHooks(this);
    connect(m_hooks, &SessionHooks::smokeStepChanged, this, &TaskController::smokeStepChanged);
    connect(m_hooks, &SessionHooks::smokeFinishedChanged, this, &TaskController::smokeFinishedChanged);
    connect(m_hooks, &SessionHooks::smokeLeaderChanged, this, &TaskController::smokeLeaderChanged);
    if (smokeTest()) {
        smokeTrace(QStringLiteral("KURRENT_SMOKE_CONTROLLER"));
    }
}

// The shared data changed (this controller's or another's): show it.
void TaskController::connectShared()
{
    connect(&m_shared, &SharedTasks::tasksChanged, this, &TaskController::scheduleRebuild);
    connect(&m_shared, &SharedTasks::collectionsChanged, this, [this]() {
        m_collectionModel.setCollections(m_shared.collections());
        m_eventCalendarModel.setCollections(m_shared.eventCollections());
        Q_EMIT eventBusySettingsChanged();
    });
}

// One loader serves all controllers; this one shows what it reports.
void TaskController::connectLoader()
{
    const AkonadiLoader &loader = AkonadiLoader::instance();
    connect(&loader, &AkonadiLoader::availableChanged, this, &TaskController::mirrorLoader);
    connect(&loader, &AkonadiLoader::loadingChanged, this, &TaskController::mirrorLoader);
    connect(&loader, &AkonadiLoader::errorMessageChanged, this, &TaskController::mirrorLoader);
    connect(&loader, &AkonadiLoader::fetchStatsChanged, this, &TaskController::updateSyncingCount);
    mirrorLoader();
}

// A demo controller has its own data and never listens to the loader.
void TaskController::mirrorLoader()
{
    if (m_demo) {
        return;
    }

    const AkonadiLoader &loader = AkonadiLoader::instance();
    if (m_akonadiAvailable != loader.available()) {
        m_akonadiAvailable = loader.available();
        Q_EMIT akonadiAvailableChanged();
    }
    if (m_loading != loader.loading()) {
        m_loading = loader.loading();
        Q_EMIT loadingChanged();
    }
    if (m_errorMessage != loader.errorMessage()) {
        m_errorMessage = loader.errorMessage();
        Q_EMIT errorMessageChanged();
    }
    updateEmptyKind();
}

TaskController::~TaskController()
{
    if (m_rebuildWatcher.isRunning()) {
        m_rebuildWatcher.waitForFinished();
    }
    s_instances.removeAll(this);
}

void TaskController::setTaskStore(AbstractTaskStore *store)
{
    m_writer->setStore(store);
}

void TaskController::setSessionServices(SessionServices services)
{
    s_sessionServices = services;
}

bool TaskController::demoMode() const
{
    return m_demo;
}

#ifdef KURRENT_WITH_DEMO
void TaskController::loadDemoData()
{
    m_demo = true;
    auto *store = new MemoryTaskStore;
    setTaskStore(store);
    m_agenda->setSelectedDate(DemoData::seed(m_shared, *store));
    m_akonadiAvailable = true;
    Q_EMIT akonadiAvailableChanged();
    m_shared.notifyTasksChanged();
}
#else
void TaskController::loadDemoData()
{
}
#endif

void TaskController::resetSharedStateForTest()
{
    m_shared.reset();
    if (!m_demo) {
        AkonadiLoader::instance().resetForTest(false);
    }
    m_undo->reset();
    m_collapsedUids.clear();
    m_errorMessage.clear();
    m_collectionModel.setCollections({});
    m_eventCalendarModel.setCollections({});
    m_taskModel.setTasks({});
    m_akonadiAvailable = false;
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
    QHash<qint64, QString> names;
    for (const Akonadi::Collection &collection : collections) {
        names.insert(collection.id(), collection.displayName());
    }
    m_shared.setCollections(collections, {}, names);
}

qint64 TaskController::installTestTask(qint64 id, const QString &summary, qint64 collectionId)
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setUid(QStringLiteral("test-uid-%1").arg(id));
    todo->setSummary(summary);
    installTestTodo(id, todo, collectionId);
    return id;
}

void TaskController::installTestTodo(qint64 id, const KCalendarCore::Todo::Ptr &todo, qint64 collectionId)
{
    Akonadi::Item item;
    item.setId(id);
    item.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    item.setPayload(todo);
    item.setParentCollection(Akonadi::Collection(collectionId));

    SharedTasks::Entry cached;
    cached.item = item;
    cached.todo = todo;
    m_shared.tasks().insert(id, cached);

    if (auto *memory = qobject_cast<MemoryTaskStore *>(m_writer->store())) {
        memory->seedItem(item);
    }

    m_shared.notifyTasksChanged();
}

bool TaskController::testTaskExists(qint64 id) const
{
    return m_shared.tasks().contains(id);
}

bool TaskController::testTaskSyncing(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    return it != m_shared.tasks().cend() && it->syncing;
}

bool TaskController::testTaskPendingDelete(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    return it != m_shared.tasks().cend() && it->pendingDelete;
}

bool TaskController::testTaskCompleted(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    return it != m_shared.tasks().cend() && it->todo && it->todo->isCompleted();
}

QString TaskController::testTaskSummary(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return {};
    }
    return it->todo->summary();
}

qint64 TaskController::testTaskCollectionId(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend()) {
        return -1;
    }
    return it->item.parentCollection().id();
}

int TaskController::testInflight(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    return it == m_shared.tasks().cend() ? 0 : it->inflight;
}

QStringList TaskController::testTaskCategories(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return {};
    }
    return it->todo->categories();
}

int TaskController::testTaskPriority(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return 0;
    }
    return it->todo->priority();
}

int TaskController::testTaskStatus(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return 0;
    }
    return static_cast<int>(it->todo->status());
}

int TaskController::testTaskSecrecy(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return 0;
    }
    return static_cast<int>(it->todo->secrecy());
}

QDateTime TaskController::testTaskDue(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo || !it->todo->hasDueDate()) {
        return {};
    }
    return it->todo->dtDue();
}

QString TaskController::testTaskLocation(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return {};
    }
    return it->todo->location();
}

QString TaskController::testKanbanColumnKey(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    if (it == m_shared.tasks().cend()) {
        return {};
    }
    const TaskEntry entry = makeTaskEntry(*it, 0, false);
    return TaskLogic::kanbanColumnKey(entry, m_kanbanColumnSource, filterState(), QDate::currentDate());
}

int TaskController::testTaskRevision(qint64 id) const
{
    const auto it = m_shared.tasks().constFind(id);
    return it == m_shared.tasks().cend() ? -1 : it->item.revision();
}

void TaskController::testApplyExternalItem(const Akonadi::Item &item)
{
    AkonadiLoader::instance().applyItem(item);
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
    return m_hooks->smokeTest();
}

QString TaskController::screenshotDir() const
{
    return m_hooks->screenshotDir();
}

QString TaskController::screenshotPlan() const
{
    return m_hooks->screenshotPlan();
}

int TaskController::smokeStep() const
{
    return m_hooks->smokeStep();
}

void TaskController::setSmokeStep(int step)
{
    m_hooks->setSmokeStep(step);
}

bool TaskController::smokeFinished() const
{
    return m_hooks->smokeFinished();
}

bool TaskController::smokeLeader()
{
    return m_hooks->smokeLeader();
}

void TaskController::smokeTrace(const QString &message) const
{
    m_hooks->smokeTrace(message);
}

QString TaskController::collectionNameForId(qint64 collectionId) const
{
    return m_shared.collectionNames().value(collectionId, QString());
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
    clearMatrixDrilldown();
    scheduleRebuild();
    Q_EMIT currentViewChanged();
    if (m_session) {
        followView();
    }
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

    // A Kanban reorder switches to Custom: remember it for this view and column source.
    if (m_mainPaneMode == TaskLogic::MainPaneMode::Kanban && m_sortMode == TaskLogic::SortMode::Custom) {
        persistSort(m_sortMode);
    }
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
    if (normalized != TaskLogic::MainPaneMode::List) {
        clearMatrixDrilldown();
    }
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
    persist(Key::KanbanManualOrder, m_kanbanManualOrderJson);
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
    const QString normalized = bucket.isEmpty() ? QStringLiteral("week") : bucket;
    if (m_swimlaneTimeBucket == normalized) {
        return;
    }
    m_swimlaneTimeBucket = normalized;
    Q_EMIT swimlaneSettingsChanged();
}

void TaskController::setSwimlaneHorizon(int horizon)
{
    horizon = qBound(0, horizon, 366);
    if (m_swimlaneHorizon == horizon) {
        return;
    }
    m_swimlaneHorizon = horizon;
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
            return m_shared.collectionNames().value(id, key);
        }
        return i18n("Inbox");
    }
    if (m_kanbanColumnSource == TaskLogic::KanbanSource::Label && key != QLatin1String("none")) {
        return key;
    }
    if (m_kanbanColumnSource == TaskLogic::KanbanSource::Status) {
        const QString nk = TaskLogic::normalizeStatusColumnKey(key);
        if (nk == QLatin1String("0")) {
            return i18n("None");
        }
        if (nk == QLatin1String("4")) {
            return i18n("Needs action");
        }
        if (nk == QLatin1String("6")) {
            return i18n("In process");
        }
        if (nk == QLatin1String("3")) {
            return i18n("Completed");
        }
        if (nk == QLatin1String("5")) {
            return i18n("Canceled");
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
            return m_shared.collectionNames().value(id, key);
        }
        return i18n("Inbox");
    }
    if (mode == TaskLogic::ListGroupSource::Label) {
        return key == QLatin1String("none") ? i18n("Unlabeled") : key;
    }
    if (mode == TaskLogic::ListGroupSource::Location) {
        return key == QLatin1String("none") ? i18n("No location") : key;
    }
    if (mode == TaskLogic::ListGroupSource::Progress) {
        if (key == QLatin1String("0-25")) {
            return i18n("0–25%");
        }
        if (key == QLatin1String("26-50")) {
            return i18n("26–50%");
        }
        if (key == QLatin1String("51-75")) {
            return i18n("51–75%");
        }
        if (key == QLatin1String("76-100")) {
            return i18n("76–100%");
        }
    }
    if (mode == TaskLogic::ListGroupSource::Status) {
        if (key == QLatin1String("0")) {
            return i18n("None");
        }
        if (key == QLatin1String("4")) {
            return i18n("Needs action");
        }
        if (key == QLatin1String("6")) {
            return i18n("In process");
        }
        if (key == QLatin1String("3")) {
            return i18n("Completed");
        }
        if (key == QLatin1String("5")) {
            return i18n("Canceled");
        }
    }
    if (mode == TaskLogic::ListGroupSource::Priority) {
        if (key == QLatin1String("high")) {
            return i18n("High");
        }
        if (key == QLatin1String("medium")) {
            return i18n("Medium");
        }
        if (key == QLatin1String("low")) {
            return i18n("Low");
        }
        if (key == QLatin1String("none")) {
            return i18n("None");
        }
    }
    if (mode == TaskLogic::ListGroupSource::Secrecy) {
        if (key == QLatin1String("public")) {
            return i18n("Public");
        }
        if (key == QLatin1String("private")) {
            return i18n("Private");
        }
        if (key == QLatin1String("confidential")) {
            return i18n("Confidential");
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
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }

    if (m_undo->recording()) {
        TaskLogic::UndoRecord record = TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache);
        record.restoreLayout = true;
        record.kanbanManualOrderJson = m_kanbanManualOrderJson;
        record.sortMode = m_sortMode;
        m_undo->push(record);
    }

    const BoardLogic::Outcome outcome = BoardLogic::applyKanbanColumn(cache->todo, m_kanbanColumnSource,
                                                                      m_kanbanWriteMode, columnKey,
                                                                      QDateTime::currentDateTime());
    switch (outcome.effect) {
    case BoardLogic::Effect::Persist:
        persistTodo(cache->item, cache->todo);
        break;
    case BoardLogic::Effect::MoveCollection:
        moveTaskToCollection(itemId, outcome.collectionId);
        break;
    case BoardLogic::Effect::Reschedule:
        // Nested reschedule pushes its own undo — suppress via batch flag (already set from finishKanbanDrop).
        rescheduleTask(itemId, outcome.preset);
        break;
    case BoardLogic::Effect::Nothing:
    case BoardLogic::Effect::SetParent:
        break;
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
    return TaskEntries::toMap(task);
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

    const QList<TaskLogic::SortLevel> sortKeys = TaskLogic::parseSortMode(m_sortMode);
    std::sort(tasks.begin(), tasks.end(), [&](const TaskEntry &left, const TaskEntry &right) {
        const int cmp = TaskLogic::compareTasks(left, right, sortKeys);
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

QVariantMap TaskController::taskSnapshotById(qint64 itemId) const
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (it == m_shared.tasks().cend() || !it->todo || it->pendingDelete) {
        return {};
    }
    return taskEntryToVariantMap(makeTaskEntry(*it, 0, false));
}

QVariantList TaskController::childTasks(const QString &uid) const
{
    if (uid.isEmpty()) {
        return {};
    }

    QList<TaskEntry> children;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (!it->todo || it->pendingDelete || it->todo->relatedTo() != uid) {
            continue;
        }
        children.append(makeTaskEntry(*it, 0, false));
    }
    std::sort(children.begin(), children.end(), [](const TaskEntry &a, const TaskEntry &b) {
        return QString::localeAwareCompare(a.summary, b.summary) < 0;
    });

    QVariantList out;
    out.reserve(children.size());
    for (const TaskEntry &child : std::as_const(children)) {
        out.append(taskEntryToVariantMap(child));
    }
    return out;
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

    if (m_undo->recording()) {
        TaskLogic::UndoRecord record;
        record.kind = TaskLogic::UndoRecord::Kind::KanbanLayout;
        record.restoreLayout = true;
        record.kanbanManualOrderJson = m_kanbanManualOrderJson;
        record.sortMode = m_sortMode;
        m_undo->push(record);
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

    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }

    TaskLogic::UndoRecord record = TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache);
    record.restoreLayout = true;
    record.kanbanManualOrderJson = m_kanbanManualOrderJson;
    record.sortMode = m_sortMode;

    // Insert index in the destination list *without* the dragged card.
    int insertAt = targetIndex;
    if (sameColumn && sourceIndex >= 0 && sourceIndex < targetIndex) {
        --insertAt;
    }
    insertAt = qMax(0, insertAt);

    {
        TaskUndo::Batching batching(*m_undo);
        moveTaskToKanbanColumn(itemId, columnKey);
        reorderKanbanCard(itemId, columnKey, insertAt);
    }

    m_undo->push(record);
}

QVariantMap TaskController::swimlaneMatrixForVisibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }

    // Preferred lane order; with `includeAllRows` these lanes stay visible as (empty) drop targets.
    QStringList order;
    if (m_swimlaneLaneAxis == QLatin1String("priority")) {
        order = {QString::number(TaskLogic::PriorityBand::High), QString::number(TaskLogic::PriorityBand::Medium),
                 QString::number(TaskLogic::PriorityBand::Low), QString::number(TaskLogic::PriorityBand::None)};
    } else if (m_swimlaneLaneAxis == QLatin1String("label")) {
        QStringList labels = m_availableLabels;
        labels.removeAll(QString());
        labels.removeDuplicates();
        std::sort(labels.begin(), labels.end(), [](const QString &a, const QString &b) {
            return QString::localeAwareCompare(a, b) < 0;
        });
        order = labels;
        order.append(QStringLiteral("none"));
    } else if (m_swimlaneLaneAxis == QLatin1String("project")) {
        order = projectLaneOrder();
    }

    QVariantMap result = TaskLogic::buildSwimlaneMatrix(tasks, m_swimlaneLaneAxis, m_swimlaneTimeBucket,
                                                        m_swimlaneHorizon, order, QDate::currentDate());

    QVariantMap labels;
    QVariantMap taskMap;
    for (const TaskEntry &task : std::as_const(tasks)) {
        taskMap.insert(QString::number(task.itemId), taskEntryToVariantMap(task));
    }
    QStringList lanes = result.value(QStringLiteral("lanes")).toStringList();
    if (m_swimlaneLaneAxis == QLatin1String("project")) {
        for (const QString &lane : std::as_const(lanes)) {
            labels.insert(lane, lane == QLatin1String("inbox") ? i18n("Inbox") : m_shared.collectionNames().value(lane.toLongLong(), lane));
        }
    } else if (m_swimlaneLaneAxis == QLatin1String("parent")) {
        QHash<QString, QString> summaries;
        for (const TaskEntry &task : std::as_const(tasks)) {
            summaries.insert(task.uid, task.summary);
        }
        for (const QString &lane : std::as_const(lanes)) {
            QString name = summaries.value(lane);
            if (name.isEmpty() && lane != QLatin1String("none")) {
                for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
                    if (it->todo && it->todo->uid() == lane) {
                        name = it->todo->summary();
                        break;
                    }
                }
            }
            labels.insert(lane, name.isEmpty() ? lane : name);
        }
        std::sort(lanes.begin(), lanes.end(), [&labels](const QString &a, const QString &b) {
            if (a == QLatin1String("none") || b == QLatin1String("none")) {
                return b == QLatin1String("none") && a != b;
            }
            return QString::localeAwareCompare(labels.value(a).toString(), labels.value(b).toString()) < 0;
        });
        result.insert(QStringLiteral("lanes"), lanes);
    }
    result.insert(QStringLiteral("laneLabels"), labels);
    result.insert(QStringLiteral("tasks"), taskMap);
    return result;
}

QStringList TaskController::projectLaneOrder() const
{
    QList<QPair<QString, QString>> named;
    for (auto it = m_shared.collectionNames().cbegin(); it != m_shared.collectionNames().cend(); ++it) {
        if (it.key() > 0 && CollectionListModel::isTaskWritable(collectionById(it.key()))) {
            named.append({QString::number(it.key()), it.value()});
        }
    }
    std::sort(named.begin(), named.end(), [](const QPair<QString, QString> &a, const QPair<QString, QString> &b) {
        return QString::localeAwareCompare(a.second, b.second) < 0;
    });
    QStringList order;
    for (const auto &entry : std::as_const(named)) {
        order.append(entry.first);
    }
    return order;
}

QVariantMap TaskController::planMatrixGridForVisibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    QStringList order = projectLaneOrder();
    order.prepend(QStringLiteral("inbox"));
    QVariantMap result = TaskLogic::buildPlanMatrixGrid(tasks, m_planTimeBucket, m_planHorizon, m_planShowUndated,
                                                        m_planShowCompleted, order, QDate::currentDate());
    QVariantMap labels;
    const QStringList rows = result.value(QStringLiteral("projects")).toStringList();
    for (const QString &row : rows) {
        labels.insert(row, row == QLatin1String("inbox") ? i18n("Inbox") : m_shared.collectionNames().value(row.toLongLong(), row));
    }
    result.insert(QStringLiteral("laneLabels"), labels);
    return result;
}

void TaskController::moveTaskToMatrixCell(qint64 itemId, const QString &laneKey, const QString &timeKey)
{
    if (itemId < 0 || laneKey.isEmpty() || timeKey.isEmpty()) {
        return;
    }
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }

    const QDate today = QDate::currentDate();
    const int horizon = TaskLogic::matrixHorizon(m_swimlaneTimeBucket, m_swimlaneHorizon, true);
    const TaskEntry before = makeTaskEntry(*cache, 0, false);
    QSet<QString> parents;
    if (m_swimlaneLaneAxis == QLatin1String("parent")) {
        QList<TaskEntry> all;
        for (int i = 0; i < m_taskModel.count(); ++i) {
            all.append(m_taskModel.taskAt(i));
        }
        parents = TaskLogic::parentUidSet(all);
    }
    const bool laneChanged = laneKey != TaskLogic::swimlaneLaneKey(before, m_swimlaneLaneAxis, &parents);
    const bool timeChanged = timeKey != TaskLogic::matrixTimeKey(before, m_swimlaneTimeBucket, horizon, today);
    if (!laneChanged && !timeChanged) {
        return;
    }
    if (timeChanged && (timeKey == QLatin1String("overdue") || timeKey == QLatin1String("later"))) {
        Q_EMIT error(i18n("Drop tasks onto a specific period, not onto Overdue or Later."));
        return;
    }

    const TaskLogic::UndoRecord record = TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache);
    KCalendarCore::Todo::Ptr todo = cache->todo;
    qint64 moveToCollection = -1;
    bool changed = false;

    std::optional<TaskUndo::Batching> batching(std::in_place, *m_undo);
    if (laneChanged) {
        const BoardLogic::Outcome lane = BoardLogic::applyMatrixLane(todo, m_swimlaneLaneAxis, laneKey);
        if (lane.effect == BoardLogic::Effect::SetParent
            && !applyParentUid(cache, lane.parentUid, cache->item.parentCollection().id())) {
            return;
        }
        changed = lane.effect == BoardLogic::Effect::Persist || lane.effect == BoardLogic::Effect::SetParent;
        if (lane.effect == BoardLogic::Effect::MoveCollection) {
            moveToCollection = lane.collectionId;
        }
    }
    if (timeChanged && BoardLogic::applyMatrixTime(todo, before.dueDate, timeKey, m_swimlaneTimeBucket, today)) {
        changed = true;
    }
    if (changed) {
        persistTodo(cache->item, todo);
    }
    if (moveToCollection > 0) {
        moveTaskToCollection(itemId, moveToCollection);
        changed = true;
    }
    batching.reset();

    if (changed) {
        m_undo->push(record);
    }
}

void TaskController::setMatrixDrilldown(const QString &source, const QString &laneKey,
                                        const QString &timeKey, const QString &label)
{
    if (source == QLatin1String("plan")) {
        m_matrixDrillAxis = QStringLiteral("project");
        m_matrixDrillBucket = m_planTimeBucket;
        m_matrixDrillHorizon = TaskLogic::matrixHorizon(m_planTimeBucket, m_planHorizon, false);
        m_matrixDrillIncludeCompleted = m_planShowCompleted;
    } else {
        m_matrixDrillAxis = m_swimlaneLaneAxis;
        m_matrixDrillBucket = m_swimlaneTimeBucket;
        m_matrixDrillHorizon = TaskLogic::matrixHorizon(m_swimlaneTimeBucket, m_swimlaneHorizon, true);
        m_matrixDrillIncludeCompleted = true;
    }
    m_matrixDrillSource = source;
    m_matrixDrillLane = laneKey;
    m_matrixDrillTime = timeKey;
    m_matrixDrillLabel = label;
    m_matrixDrillActive = true;
    scheduleRebuild();
    Q_EMIT matrixDrillChanged();
}

void TaskController::clearMatrixDrilldown()
{
    if (!m_matrixDrillActive) {
        return;
    }
    m_matrixDrillActive = false;
    m_matrixDrillLane.clear();
    m_matrixDrillTime.clear();
    m_matrixDrillLabel.clear();
    scheduleRebuild();
    Q_EMIT matrixDrillChanged();
}

void TaskController::requestMainPaneMode(const QString &mode)
{
    selectMainPaneMode(mode);
}

QList<TaskEntry> TaskController::visibleTasks() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_taskModel.count());
    for (int i = 0; i < m_taskModel.count(); ++i) {
        tasks.append(m_taskModel.taskAt(i));
    }
    return tasks;
}

QVariantMap TaskController::planMatrixForVisibleTasks() const
{
    return TaskLogic::planMatrixCounts(visibleTasks(), QDate::currentDate());
}

bool TaskController::moveSeriesOccurrence(qint64 itemId, qint64 days)
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (days == 0 || it == m_shared.tasks().cend() || !it->todo || !it->todo->recurs()) {
        return false;
    }
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return false;
    }
    const TaskLogic::UndoRecord record = TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache);
    if (!TaskCalendar::moveOccurrence(cache->todo, days)) {
        return false;
    }
    m_undo->push(record);
    persistTodo(cache->item, cache->todo);
    return true;
}

void TaskController::detachSeriesOccurrence(qint64 itemId, const QDateTime &start, const QDateTime &due)
{
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache || !cache->todo || !cache->todo->recurs()) {
        return;
    }
    const KCalendarCore::Todo::Ptr detached = TaskCalendar::detachOccurrence(cache->todo, start, due);
    if (!detached) {
        return;
    }
    TaskLogic::UndoRecord record = TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Detach, *cache);
    record.detachedUid = detached->uid();
    const Akonadi::Collection collection = cache->item.parentCollection();

    // The series skips this occurrence like a completed one, without counting as done.
    TaskCalendar::completeTodo(cache->todo, TaskCalendar::CompleteAction::Mark, QDateTime::currentDateTime());
    persistTodo(cache->item, cache->todo);

    Akonadi::Item jobItem;
    jobItem.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    jobItem.setPayload<KCalendarCore::Todo::Ptr>(detached);
    const qint64 tempId = m_shared.nextTempId();
    SharedTasks::Entry cached;
    cached.item = jobItem;
    cached.item.setId(tempId);
    cached.item.setParentCollection(collection);
    cached.todo = detached;
    cached.syncing = true;
    cached.inflight = 1;
    m_shared.tasks().insert(tempId, cached);
    m_shared.notifyTasksChanged();
    submitCreate(jobItem, collection, tempId);

    m_undo->push(record);
}

// Undo of a detach: the task made from the occurrence goes. Still being created, it goes as
// soon as its create lands (onStoreFinished).
void TaskController::deleteDetached(const QString &uid)
{
    if (uid.isEmpty()) {
        return;
    }
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (!it->todo || it->todo->uid() != uid) {
            continue;
        }
        if (it.key() < 0) {
            m_undo->deleteAfterCreate(uid);
            return;
        }
        deleteTask(it.key());
        return;
    }
}

void TaskController::agendaAddTask(const QString &summary, qint64 collectionId, const QDate &day, int start, int end)
{
    if (!day.isValid()) {
        return;
    }
    createQuickTask(summary, collectionId, day, start, end);
}

QVariantList TaskController::eventCalendars() const
{
    QVariantList result;
    result.reserve(m_shared.eventCollections().size());
    for (const Akonadi::Collection &collection : m_shared.eventCollections()) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), collection.id());
        row.insert(QStringLiteral("name"), collection.displayName());
        row.insert(QStringLiteral("enabled"), TaskLogic::isEnabledCsv(m_busyCalendarIds, collection.id()));
        result.append(row);
    }
    return result;
}

void TaskController::toggleBusyCalendar(qint64 calendarId)
{
    QList<qint64> allIds;
    allIds.reserve(m_shared.eventCollections().size());
    for (const Akonadi::Collection &collection : m_shared.eventCollections()) {
        allIds.append(collection.id());
    }
    const QString csv = TaskLogic::toggleEnabledCsv(m_busyCalendarIds, calendarId, allIds);
    setBusyCalendarIds(csv);
    persist(Key::BusyCalendarIds, csv);
}

void TaskController::selectAgendaMode(const QString &mode)
{
    persist(Key::AgendaMode, AgendaLogic::normalizeMode(mode));
    setAgendaMode(mode);
}

void TaskController::selectAgendaWeekend(bool show)
{
    persist(Key::AgendaWeekend, show);
    setAgendaWeekend(show);
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
        SharedTasks::Entry *cache = prepareEdit(id.toLongLong());
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

void TaskController::rescheduleOverdueToToday()
{
    const QDate today = QDate::currentDate();
    QVariantList ids;
    for (const TaskEntry &task : std::as_const(m_deferredAllTasks)) {
        if (TaskLogic::matchesView(task, QStringLiteral("overdue"), today)) {
            ids.append(task.itemId);
        }
    }
    bulkRescheduleTasks(ids, TaskLogic::ReschedulePreset::Today);
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
    m_writer->reload(itemId);
}

void TaskController::dismissConflict()
{
    m_writer->dismissConflict();
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

QVariant TaskController::liveSetting(const QString &key) const
{
    // Straight from kurrentrc: views rebuild while the configuration updates, before
    // loadSettings() has run.
    return SharedSettings::instance()->values().value(key);
}

bool TaskController::isProjectHidden(qint64 collectionId) const
{
    return TaskLogic::tokenSetContains(liveSetting(Key::HiddenProjects).toString(),
                                       QString::number(collectionId), kIdSeparator);
}

QStringList TaskController::shownKanbanColumns() const
{
    return TaskLogic::shownKanbanColumns(m_kanbanColumnKeys, m_kanbanColumnSource, m_canceledColumn);
}

void TaskController::setTaskStatus(qint64 itemId, int status)
{
    updateTaskFull(itemId, TaskLogic::statusChangeFields(status));
}

void TaskController::setTaskProgressBand(qint64 itemId, const QString &band)
{
    updateTaskFull(itemId, {{QStringLiteral("percentComplete"), TaskLogic::progressMidpoint(band)}});
}

QVariantMap TaskController::blockedFilters() const
{
    return TaskLogic::blockedSidebarFilters(m_mainPaneMode, m_kanbanColumnSource, m_swimlaneLaneAxis);
}

int TaskController::badgeCount() const
{
    return TaskLogic::panelBadgeCount(liveSetting(Key::PanelBadge).toString(), m_pendingCount, m_viewTaskCounts);
}

bool TaskController::badgeAlert() const
{
    return TaskLogic::panelBadgeAlert(liveSetting(Key::PanelBadge).toString(),
                                      liveSetting(Key::PanelBadgeOverdueColor).toString(), m_viewTaskCounts);
}

QVariantList TaskController::sidebarProjects() const
{
    const bool showEmpty = liveSetting(Key::ShowEmptyProjects).toBool();
    QVariantList out;
    for (int row = 0; row < m_collectionModel.count(); ++row) {
        const qint64 id = m_collectionModel.collectionIdAt(row);
        const int taskCount = m_collectionModel.taskCountAt(row);
        if ((!showEmpty && taskCount <= 0) || isProjectHidden(id)) {
            continue;
        }
        out.append(QVariantMap{
            {QStringLiteral("collectionId"), id},
            {QStringLiteral("name"), m_collectionModel.nameAt(row)},
            {QStringLiteral("taskCount"), taskCount},
        });
    }
    return out;
}

namespace
{
QStringList withoutTokens(const QStringList &items, const QString &hiddenRaw, const QString &separator)
{
    QStringList out;
    for (const QString &item : items) {
        if (TaskLogic::tokenSetContains(hiddenRaw, item, separator)) {
            continue;
        }
        out.append(item);
    }
    return out;
}
} // namespace

QStringList TaskController::sidebarLabels() const
{
    return withoutTokens(m_availableLabels, liveSetting(Key::HiddenLabels).toString(), kNameSeparator);
}

QStringList TaskController::sidebarLocations() const
{
    return withoutTokens(m_availableLocations, liveSetting(Key::HiddenLocations).toString(), kNameSeparator);
}

QVariantList TaskController::writableProjects() const
{
    QVariantList out;
    for (int row = 0; row < m_collectionModel.count(); ++row) {
        const qint64 id = m_collectionModel.collectionIdAt(row);
        if (!m_collectionModel.enabledAt(row) || isProjectHidden(id) || !m_collectionModel.writableAt(row)) {
            continue;
        }
        out.append(QVariantMap{
            {QStringLiteral("collectionId"), id},
            {QStringLiteral("name"), m_collectionModel.nameAt(row)},
        });
    }
    return out;
}

QVariantMap TaskController::newTaskTarget() const
{
    // The rule's inputs: a usable selection, the first sidebar project, a usable default.
    const qint64 selected = m_collectionModel.writableForId(m_selectedCollectionId) ? m_selectedCollectionId : -1;

    QList<TaskLogic::ProjectCandidate> candidates;
    QSet<qint64> hidden;
    for (int row = 0; row < m_collectionModel.count(); ++row) {
        TaskLogic::ProjectCandidate candidate;
        candidate.id = m_collectionModel.collectionIdAt(row);
        candidate.enabled = m_collectionModel.enabledAt(row);
        candidate.taskCount = m_collectionModel.taskCountAt(row);
        candidate.writable = m_collectionModel.writableAt(row);
        candidates.append(candidate);
        if (isProjectHidden(candidate.id)) {
            hidden.insert(candidate.id);
        }
    }

    const qint64 defaultId = liveSetting(Key::NewTaskDefaultCollection).toString().toLongLong();
    const int defaultRow = m_collectionModel.rowForCollectionId(defaultId);
    const bool defaultUsable = defaultRow >= 0 && m_collectionModel.enabledAt(defaultRow)
            && m_collectionModel.writableForId(defaultId);
    const TaskLogic::NewTaskTarget target = TaskLogic::resolveNewTaskTarget(
            selected, liveSetting(Key::NewTaskProjectMode).toString(), defaultId,
            defaultUsable ? TaskLogic::DefaultCollection::Exists : TaskLogic::DefaultCollection::Missing,
            TaskLogic::firstSidebarProjectId(candidates, hidden));

    QVariantMap out{{QStringLiteral("collectionId"), target.collectionId}, {QStringLiteral("ask"), false}};
    if (!target.ask) {
        return out;
    }

    // Ask only when there is a choice; no writable project → Akonadi's default (-1).
    const QVariantList choices = writableProjects();
    if (choices.size() <= 1) {
        out.insert(QStringLiteral("collectionId"),
                   choices.isEmpty() ? -1 : choices.first().toMap().value(QStringLiteral("collectionId")));
        return out;
    }
    out.insert(QStringLiteral("ask"), true);
    out.insert(QStringLiteral("choices"), choices);
    return out;
}

QVariantList TaskController::projectChoices(qint64 currentId, const QString &scope) const
{
    const bool all = scope == kScopeAll;
    QVariantList out;
    for (int row = 0; row < m_collectionModel.count(); ++row) {
        if (!m_collectionModel.enabledAt(row)) {
            continue;
        }
        const qint64 id = m_collectionModel.collectionIdAt(row);
        const bool listed = m_collectionModel.writableAt(row)
                && (all || (m_collectionModel.taskCountAt(row) > 0 && !isProjectHidden(id)));
        if (!listed && id != currentId) {
            continue;
        }
        out.append(QVariantMap{
            {QStringLiteral("collectionId"), id},
            {QStringLiteral("name"), m_collectionModel.nameAt(row)},
        });
    }
    return out;
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

void TaskController::setBusyCalendarIds(const QString &ids)
{
    if (m_busyCalendarIds == ids) {
        return;
    }
    m_busyCalendarIds = ids;
    if (!m_demo) {
        AkonadiLoader::instance().setBusyCalendarIds(ids);
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
    if (!m_demo) {
        AkonadiLoader::instance().setEnabledCollectionIds(enabled);
    }
}

void TaskController::startSession(QObject *configuration)
{
    if (m_session) {
        return;
    }
    m_bridge->bind(configuration);
    loadSettings();

    // Start view: the default view, or the last one when "remember last view" is on.
    QString view = setting(Key::DefaultView);
    if (view.isEmpty()) {
        view = TaskLogic::ViewId::Inbox;
    }
    const QString lastView = setting(Key::LastView);
    if (m_settings.value(Key::RememberLastView).toBool() && !lastView.isEmpty()) {
        view = lastView;
    }
    setCurrentView(view);
    loadEnabledCollections();

    m_session = true;
    applyViewSort();
    connect(SharedSettings::instance(), &SharedSettings::changed, this, &TaskController::onSettingsStored);
    QTimer::singleShot(0, this, &TaskController::refresh);
}

void TaskController::loadEnabledCollections()
{
    const QString csv = SharedSettings::instance()->values().value(Key::EnabledCollections).toString();
    const QList<qint64> ids = TaskLogic::collectionIdsFromCsv(csv);
    if (ids.isEmpty()) {
        return;
    }
    QVariantList list;
    for (qint64 id : ids) {
        list.append(id);
    }
    setEnabledCollectionIds(list);
}

void TaskController::onSettingsStored()
{
    m_bridge->applyStored();
    loadSettings();
    Q_EMIT settingsChanged();
}

QString TaskController::setting(const QString &key) const
{
    return m_settings.value(key).toString();
}

void TaskController::loadSettings()
{
    const QVariantMap before = m_settings;
    m_settings = SharedSettings::instance()->values();
    const QVariantMap &now = m_settings;
    auto text = [&now](const QString &key, const QString &fallback) {
        const QString value = now.value(key).toString();
        return value.isEmpty() ? fallback : value;
    };
    auto number = [&now](const QString &key) {
        return now.value(key).toInt();
    };
    auto flag = [&now](const QString &key) {
        return now.value(key).toBool();
    };

    // Mirror every setting into its property; nothing is written back meanwhile.
    {
        const QScopedValueRollback<bool> guard(m_loadingSettings, true);
        setShowCompleted(flag(Key::ShowCompleted));
        setCatchUpEnabled(flag(Key::CatchUpEnabled));
        const int catchUpDays = number(Key::CatchUpDays);
        setCatchUpDays(catchUpDays != 0 ? catchUpDays : kDefaultCatchUpDays);
        setMorningHour(number(Key::MorningHour));
        setAfternoonHour(number(Key::AfternoonHour));
        setEveningHour(number(Key::EveningHour));
        setDefaultDueMode(text(Key::DefaultDueMode, QStringLiteral("none")));
        setSearchTitleOnly(flag(Key::SearchTitleOnly));
        setSearchCaseSensitive(flag(Key::SearchCaseSensitive));
        setCompleteChildren(flag(Key::CompleteChildren));
        setCountsExcludeCollapsed(flag(Key::CountsExcludeCollapsed));
        setNotificationsEnabled(flag(Key::NotificationsEnabled));
        setDefaultReminderMinutes(number(Key::DefaultReminderMinutes));
        setQuietHoursEnabled(flag(Key::QuietHoursEnabled));
        setQuietHoursStart(number(Key::QuietHoursStart));
        setQuietHoursEnd(number(Key::QuietHoursEnd));
        setSuppressRemindersDuringEvents(flag(Key::SuppressReminders));
        setBusyCalendarIds(now.value(Key::BusyCalendarIds).toString());
        setSmartViewsJson(text(Key::SmartViews, QStringLiteral("[]")));
        setKanbanColumnSource(text(Key::KanbanColumnSource, TaskLogic::KanbanSource::Status));
        setKanbanWriteMode(text(Key::KanbanWriteMode, QStringLiteral("fields")));
        setKanbanManualOrderJson(text(Key::KanbanManualOrder, QStringLiteral("{}")));
        setSwimlaneLaneAxis(text(Key::SwimlaneLaneAxis, QStringLiteral("project")));
        setSwimlaneTimeBucket(text(Key::SwimlaneTimeBucket, QStringLiteral("week")));
        setSwimlaneHorizon(number(Key::SwimlaneHorizon));
        setPlanTimeBucket(text(Key::PlanTimeBucket, QStringLiteral("week")));
        setPlanHorizon(number(Key::PlanHorizon));
        setPlanShowUndated(flag(Key::PlanShowUndated));
        setPlanShowCompleted(flag(Key::PlanShowCompleted));
        setAgendaMode(text(Key::AgendaMode, AgendaLogic::Mode::Day));
        setAgendaWeekend(flag(Key::AgendaWeekend));
        setAgendaWorkMinutes(number(Key::AgendaWorkMinutes));
        setMultiSelectEnabled(flag(Key::MultiSelectEnabled));
        setListGroupMode(now.value(Key::ListGroupMode).toString());
        setMainPaneMode(text(Key::MainPaneMode, TaskLogic::MainPaneMode::List));
        const auto canceled = flag(Key::KanbanHideCanceled) ? TaskLogic::CanceledColumn::Hide
                                                             : TaskLogic::CanceledColumn::Show;
        if (canceled != m_canceledColumn) {
            m_canceledColumn = canceled;
            Q_EMIT shownKanbanColumnsChanged();
        }
    }

    // First load: startSession picks the view and sort itself.
    if (before.isEmpty()) {
        return;
    }

    // Changed elsewhere (settings page, other widget): follow like a user choice.
    auto changed = [&before, &now](const QString &key) {
        return before.value(key) != now.value(key);
    };
    if (changed(Key::DefaultView)) {
        setCurrentView(now.value(Key::DefaultView).toString());
    }
    if (changed(Key::EnabledCollections)) {
        loadEnabledCollections();
        refresh();
    }
    if (changed(Key::SortScope) || changed(Key::MainPaneMode) || changed(Key::KanbanColumnSource)) {
        applyViewSort();
    }
}

void TaskController::persist(const QString &key, const QVariant &value)
{
    if (!m_session || m_loadingSettings) {
        return;
    }
    SharedSettings::instance()->store(key, value);
}

const TaskLogic::SmartViewDef *TaskController::smartViewFor(const QString &viewId) const
{
    if (!viewId.startsWith(kSmartPrefix)) {
        return nullptr;
    }
    const QString smartId = viewId.mid(kSmartPrefix.size());
    for (const TaskLogic::SmartViewDef &def : m_smartViews) {
        if (def.id == smartId) {
            return &def;
        }
    }
    return nullptr;
}

void TaskController::followView()
{
    if (m_settings.value(Key::RememberLastView).toBool()) {
        persist(Key::LastView, m_currentView);
    }

    // A smart view may bring its own main-pane mode. (Its "sort" was always overridden by
    // the view's stored sort below, so it is not applied.)
    const TaskLogic::SmartViewDef *smart = smartViewFor(m_currentView);
    if (smart && !smart->defaultMode.isEmpty() && smart->defaultMode != m_mainPaneMode) {
        selectMainPaneMode(smart->defaultMode);
    }
    applyViewSort();
}

void TaskController::applyViewSort()
{
    // Kanban remembers a sort per view and column source (e.g. Custom after a reorder).
    if (m_mainPaneMode == TaskLogic::MainPaneMode::Kanban) {
        const QString remembered = TaskLogic::jsonMapValue(
                setting(Key::KanbanSortByColumn), TaskLogic::kanbanSortKey(m_currentView, m_kanbanColumnSource));
        if (!remembered.isEmpty()) {
            setSortMode(remembered);
            return;
        }
    }
    setSortMode(TaskLogic::sortModeForView(setting(Key::SortScope), setting(Key::SortMode),
                                           setting(Key::SortModeByView), m_currentView));
}

void TaskController::persistSort(const QString &mode)
{
    if (m_mainPaneMode == TaskLogic::MainPaneMode::Kanban) {
        const QString key = TaskLogic::kanbanSortKey(m_currentView, m_kanbanColumnSource);
        persist(Key::KanbanSortByColumn, TaskLogic::jsonMapWith(setting(Key::KanbanSortByColumn), key, mode));
    }
    if (mode == TaskLogic::SortMode::Custom) {
        return;
    }

    // The default is stored as "no entry", so a later default change reaches every view.
    const QString stored = mode == TaskLogic::SortMode::Default ? QString() : mode;
    if (setting(Key::SortScope) == TaskLogic::SortScope::PerView) {
        persist(Key::SortModeByView, TaskLogic::jsonMapWith(setting(Key::SortModeByView), m_currentView, stored));
        return;
    }
    persist(Key::SortMode, stored);
}

void TaskController::selectMainPaneMode(const QString &mode)
{
    persist(Key::MainPaneMode, mode.isEmpty() ? TaskLogic::MainPaneMode::List : mode);
    setMainPaneMode(mode);
    applyViewSort();
}

void TaskController::selectSort(const QString &mode)
{
    setSortMode(mode);
    persistSort(mode);
}

void TaskController::selectSortLevel(int level, const QString &key)
{
    selectSort(TaskLogic::withSortLevel(m_sortMode, level, key));
}

QStringList TaskController::sortKeys() const
{
    return TaskLogic::sortLevels(m_sortMode);
}

QVariantList TaskController::sortLevelOptions() const
{
    const QStringList levels = sortKeys();
    const QStringList allowed = TaskLogic::allowedSortKeys(m_mainPaneMode, m_kanbanColumnSource, m_listGroupMode);
    QVariantList out;
    for (int level = 0; level < TaskLogic::kSortLevels; ++level) {
        out.append(TaskLogic::sortLevelKeys(levels, level, allowed));
    }
    return out;
}

void TaskController::selectListGroup(const QString &mode)
{
    const QString normalized = mode == TaskLogic::ListGroupSource::None ? QString() : mode;
    setListGroupMode(normalized);
    persist(Key::ListGroupMode, normalized);

    // Grouped by a field: sorting by it inside each group would change nothing.
    const QString stripped = TaskLogic::withoutSortFamily(m_sortMode, normalized);
    if (!stripped.isEmpty()) {
        selectSort(stripped);
    }
}

void TaskController::selectKanbanSource(const QString &source)
{
    setKanbanColumnSource(source);

    // Columns now show this field: its sidebar filter would leave one column.
    if (source == TaskLogic::KanbanSource::Label) {
        setSelectedLabel(QString());
    } else if (source == TaskLogic::KanbanSource::Project) {
        setSelectedCollectionId(-1);
    } else if (source == TaskLogic::KanbanSource::Priority) {
        setSelectedPriority(-1);
    } else if (source == TaskLogic::KanbanSource::Status) {
        setSelectedStatus(-1);
    } else if (source == TaskLogic::KanbanSource::Completion) {
        setSelectedProgressBand(QString());
    }
    persist(Key::KanbanColumnSource, source);
    applyViewSort();
}

void TaskController::selectMatrixBucket(const QString &bucket)
{
    const bool swimlane = m_mainPaneMode == TaskLogic::MainPaneMode::Swimlane;
    persist(swimlane ? Key::SwimlaneTimeBucket : Key::PlanTimeBucket, bucket);
}

void TaskController::selectMatrixHorizon(int periods)
{
    const bool swimlane = m_mainPaneMode == TaskLogic::MainPaneMode::Swimlane;
    persist(swimlane ? Key::SwimlaneHorizon : Key::PlanHorizon, periods);
}

void TaskController::storeSetting(const QString &key, const QVariant &value)
{
    persist(key, value);
}

void TaskController::refresh()
{
    if (m_demo) {
        return;
    }
    AkonadiLoader::instance().refresh();
}

void TaskController::syncNow()
{
    if (m_demo) {
        return;
    }
    AkonadiLoader::instance().syncNow();
}

void TaskController::createTask(const QString &summary, qint64 collectionId)
{
    createQuickTask(summary, collectionId, QDate(), -1, -1);
}

void TaskController::createQuickTask(const QString &summary, qint64 collectionId, const QDate &day, int start, int end)
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
        Q_EMIT error(i18n("No writable task list selected."));
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
    // A time without a date stays on the day; a slot keeps its length from that time, cut at
    // the day's end.
    const bool timeOnDay = day.isValid() && parsed.hasDue && !parsed.hasDate && !parsed.allDay;
    const int textMinute = parsed.due.time().hour() * 60 + parsed.due.time().minute();
    if (timeOnDay && start >= 0 && end > start) {
        todo->setDtStart(AgendaLogic::atMinute(day, textMinute));
        todo->setDtDue(AgendaLogic::atMinute(day, qMin(textMinute + (end - start), 24 * 60)));
        todo->setAllDay(false);
    } else if (timeOnDay) {
        todo->setDtDue(AgendaLogic::atMinute(day, textMinute));
        todo->setAllDay(false);
    } else if (parsed.hasDue) {
        todo->setDtDue(parsed.due);
        todo->setAllDay(parsed.allDay);
    } else if (day.isValid() && start >= 0 && end > start) {
        todo->setDtStart(AgendaLogic::atMinute(day, start));
        todo->setDtDue(AgendaLogic::atMinute(day, end));
        todo->setAllDay(false);
    } else if (day.isValid()) {
        todo->setDtDue(QDateTime(day, QTime(0, 0)));
        todo->setAllDay(true);
    } else {
        const QDateTime fallback = TaskLogic::defaultDueForMode(m_defaultDueMode, QDate::currentDate());
        if (fallback.isValid()) {
            todo->setDtDue(fallback);
            todo->setAllDay(true);
        }
    }
    if (todo->hasDueDate() && m_reminders->defaultMinutes() >= 0) {
        TaskCalendar::setReminderMinutes(todo, m_reminders->defaultMinutes());
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

    const qint64 tempId = m_shared.nextTempId();
    Akonadi::Item cacheItem = jobItem;
    cacheItem.setId(tempId);
    cacheItem.setParentCollection(collection);

    SharedTasks::Entry cached;
    cached.item = cacheItem;
    cached.todo = todo;
    cached.syncing = true;
    cached.inflight = 1;
    m_shared.tasks().insert(tempId, cached);
    m_shared.notifyTasksChanged();

    submitCreate(jobItem, collection, tempId);
}

void TaskController::submitCreate(const Akonadi::Item &jobItem, const Akonadi::Collection &collection, qint64 tempId)
{
    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Create;
    req.clientId = tempId;
    req.item = jobItem;
    req.collection = collection;
    m_writer->submit(req);
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
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    const QDateTime currentDue = (todo->hasDueDate() && todo->dtDue().isValid()) ? todo->dtDue() : QDateTime();
    const TaskLogic::DaySpan daySpan = todo->allDay() ? TaskLogic::DaySpan::AllDay : TaskLogic::DaySpan::Timed;
    const QDateTime next = TaskLogic::rescheduleDue(currentDue, daySpan, QDateTime::currentDateTime(), preset);
    if (!next.isValid()) {
        return;
    }
    // A series moves only its current occurrence, by whole days (#29). Hour presets keep
    // the old behaviour: the occurrence has no time of its own apart from the rule.
    if (todo->recurs() && currentDue.isValid()
        && !(preset == QLatin1String("15m") || preset == QLatin1String("1h") || preset == QLatin1String("4h"))) {
        moveSeriesOccurrence(itemId, currentDue.date().daysTo(next.date()));
        return;
    }
    m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Reschedule, *cache));
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

QString TaskController::taskLink(qint64 itemId, TaskLink link) const
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return {};
    }
    const TaskEntry task = makeTaskEntry(*it, 0, false);
    return link == TaskLink::Join ? task.joinUrl : task.geoUrl;
}

bool TaskController::openJoinLink(qint64 itemId) const
{
    const QString url = taskLink(itemId, TaskLink::Join);
    return !url.isEmpty() && QDesktopServices::openUrl(QUrl(url));
}

bool TaskController::openMapLink(qint64 itemId) const
{
    const QString url = taskLink(itemId, TaskLink::Map);
    return !url.isEmpty() && QDesktopServices::openUrl(QUrl(url));
}

SharedTasks::Entry *TaskController::prepareEdit(qint64 itemId)
{
    if (itemId < 0) {
        return nullptr;
    }
    auto it = m_shared.tasks().find(itemId);
    if (it == m_shared.tasks().end() || !it->todo) {
        logAkonadi(QStringLiteral("prepareEdit: no cache for itemId=%1 cacheHit=%2 hasTodo=%3")
                       .arg(itemId)
                       .arg(it != m_shared.tasks().end())
                       .arg(it != m_shared.tasks().end() && bool(it->todo)));
        return nullptr;
    }
    if (!it->revertTodo) {
        it->revertTodo = cloneTodo(it->todo);
        it->revertCollectionId = it->item.parentCollection().id();
    }
    return &*it;
}

void TaskController::onStoreFinished(const AbstractTaskStore::Result &result)
{
    // Modify and Move are settled by the writer.
    switch (result.kind) {
    case AbstractTaskStore::Kind::Create:
        m_shared.tasks().remove(result.clientId);
        if (!result.ok) {
            m_shared.notifyTasksChanged();
            Q_EMIT error(result.errorString);
            return;
        }
        AkonadiLoader::instance().applyItem(result.item, result.collectionId);
        m_shared.notifyTasksChanged();
        if (result.item.hasPayload<KCalendarCore::Todo::Ptr>()
            && m_undo->takeDeleteAfterCreate(result.item.payload<KCalendarCore::Todo::Ptr>()->uid())) {
            TaskUndo::Applying applying(*m_undo);
            deleteTask(result.item.id());
        }
        return;

    case AbstractTaskStore::Kind::Delete:
        if (!result.ok) {
            m_undo->dropRecreate(result.clientId);
            m_writer->finishSync(result.clientId, TaskWriter::SyncResult::Error, result.errorString);
            return;
        }
        m_shared.tasks().remove(result.clientId);
        {
            TaskLogic::UndoRecord record;
            if (m_undo->takeRecreate(result.clientId, record)) {
                recreateTask(record);
                return;
            }
        }
        m_shared.notifyTasksChanged();
        return;

    case AbstractTaskStore::Kind::Modify:
    case AbstractTaskStore::Kind::Move:
        return;
    }
}

void TaskController::persistTodo(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId)
{
    m_writer->persist(item, todo, moveToCollectionId);
}

void TaskController::resolveMergeConflict(const QVariantMap &resolution)
{
    m_writer->resolveMergeConflict(resolution);
}

void TaskController::testMergeConflict()
{
    m_writer->simulateMergeConflict();
}

Akonadi::Collection TaskController::collectionById(qint64 collectionId) const
{
    if (collectionId <= 0) {
        return {};
    }
    for (const Akonadi::Collection &collection : m_shared.collections()) {
        if (collection.id() == collectionId) {
            return collection;
        }
    }
    return {};
}

Akonadi::Collection TaskController::firstWritableCollection() const
{
    const QList<qint64> enabledIds = m_collectionModel.enabledIds();
    for (const Akonadi::Collection &collection : m_shared.collections()) {
        if (!enabledIds.contains(collection.id())) {
            continue;
        }
        if (CollectionListModel::isTaskWritable(collection)) {
            return collection;
        }
    }
    return {};
}

TaskEntry TaskController::makeTaskEntry(const SharedTasks::Entry &cached, int indentLevel, bool hasChildren) const
{
    return TaskEntries::fromShared(m_shared, cached, indentLevel, hasChildren);
}

void TaskController::updateTask(qint64 itemId,
                                const QString &summary,
                                const QString &description,
                                const QDateTime &dueDate,
                                bool clearDue,
                                int priority,
                                const QStringList &categories)
{
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    if (!m_undo->applying()) {
        m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache));
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
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    const Akonadi::Item originalItem = cache->item;

    if (!m_undo->applying()) {
        m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache));
    }

    TaskCalendar::applyEditorFields(todo, fields);

    qint64 moveToCollectionId = -1;
    if (fields.contains(QStringLiteral("collectionId"))) {
        const qint64 targetCollectionId = fields.value(QStringLiteral("collectionId")).toLongLong();
        if (targetCollectionId > 0 && targetCollectionId != originalItem.parentCollection().id()) {
            const Akonadi::Collection destination = collectionById(targetCollectionId);
            if (CollectionListModel::isTaskWritable(destination)) {
                moveToCollectionId = targetCollectionId;
                cache->item.setParentCollection(destination);
            } else {
                Q_EMIT error(i18n("This project cannot accept tasks."));
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
        Q_EMIT error(i18n("No writable task list selected."));
        return;
    }

    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);

    TaskCalendar::applyEditorFields(todo, fields);

    Akonadi::Item jobItem;
    jobItem.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    jobItem.setPayload<KCalendarCore::Todo::Ptr>(todo);

    // Same optimistic path as the quick entry: a temporary row until the store answers.
    const qint64 tempId = m_shared.nextTempId();
    Akonadi::Item cacheItem = jobItem;
    cacheItem.setId(tempId);
    cacheItem.setParentCollection(collection);

    SharedTasks::Entry cached;
    cached.item = cacheItem;
    cached.todo = todo;
    cached.syncing = true;
    cached.inflight = 1;
    m_shared.tasks().insert(tempId, cached);
    m_shared.notifyTasksChanged();

    submitCreate(jobItem, collection, tempId);
}

void TaskController::setTaskParent(qint64 itemId, const QString &parentUid)
{
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    if (!m_undo->applying()) {
        m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache));
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
    const auto selfIt = m_shared.tasks().constFind(itemId);
    if (selfIt != m_shared.tasks().cend() && selfIt->todo) {
        selfUid = selfIt->todo->uid();
    }

    QHash<QString, QString> parentByUid;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
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
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
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
            row.summary = i18n("(Untitled)");
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

bool TaskController::applyParentUid(SharedTasks::Entry *cache, const QString &parentUid, qint64 collectionId)
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
        Q_EMIT error(i18n("A task cannot be its own parent."));
        return false;
    }
    if (wouldCreateParentCycle(cache->item.id(), trimmedParent)) {
        Q_EMIT error(i18n("Cannot create a circular task hierarchy."));
        return false;
    }

    const SharedTasks::Entry *parentCache = nullptr;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (it->todo && it->todo->uid() == trimmedParent) {
            parentCache = &(*it);
            break;
        }
    }
    if (!parentCache) {
        Q_EMIT error(i18n("Parent task not found."));
        return false;
    }
    if (collectionId > 0 && parentCache->item.parentCollection().id() != collectionId) {
        Q_EMIT error(i18n("Parent task must be in the same project."));
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

    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    if (!m_undo->applying()) {
        m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache));
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

    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    const QStringList categories = TaskLogic::removeLabel(todo->categories(), trimmed);
    if (categories == todo->categories()) {
        return;
    }
    if (!m_undo->applying()) {
        m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache));
    }
    todo->setCategories(categories);
    persistTodo(cache->item, todo);
}

void TaskController::setTaskPriority(qint64 itemId, int priority)
{
    const int normalized = TaskLogic::priorityBand(priority);
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    if (TaskLogic::priorityBand(todo->priority()) == normalized) {
        return;
    }
    if (!m_undo->applying()) {
        m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Edit, *cache));
    }
    todo->setPriority(normalized);
    persistTodo(cache->item, todo);
}

void TaskController::moveTaskToCollection(qint64 itemId, qint64 collectionId)
{
    if (collectionId <= 0) {
        return;
    }

    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        Q_EMIT error(i18n("Task not found."));
        return;
    }

    if (cache->item.parentCollection().id() == collectionId) {
        return;
    }

    m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Move, *cache));

    const Akonadi::Collection destination = collectionById(collectionId);
    if (!CollectionListModel::isTaskWritable(destination)) {
        Q_EMIT error(i18n("This project cannot accept tasks."));
        return;
    }

    const Akonadi::Item jobItem = cache->item;
    cache->item.setParentCollection(destination);
    cache->syncing = true;
    cache->inflight += 1;
    m_shared.notifyTasksChanged();

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Move;
    req.clientId = itemId;
    req.item = jobItem;
    req.collection = destination;
    m_writer->submit(req);
}

void TaskController::setTaskCompleted(qint64 itemId, bool completed)
{
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Complete, *cache));
    TaskCalendar::completeTodo(todo, completed ? TaskCalendar::CompleteAction::Mark : TaskCalendar::CompleteAction::Unmark, QDateTime::currentDateTime());
    persistTodo(cache->item, todo);

    if (completed && m_completeChildren && todo) {
        QHash<QString, QString> parentByUid;
        QHash<QString, qint64> idByUid;
        for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
            if (!it->todo) {
                continue;
            }
            parentByUid.insert(it->todo->uid(), it->todo->relatedTo());
            idByUid.insert(it->todo->uid(), it.key());
        }
        const QStringList kids = TaskLogic::descendantUids(todo->uid(), parentByUid);
        TaskUndo::Applying applying(*m_undo);
        for (const QString &uid : kids) {
            const qint64 childId = idByUid.value(uid, -1);
            if (childId < 0) {
                continue;
            }
            SharedTasks::Entry *child = prepareEdit(childId);
            if (!child || !child->todo || child->todo->isCompleted()) {
                continue;
            }
            TaskCalendar::completeTodo(child->todo, TaskCalendar::CompleteAction::Mark, QDateTime::currentDateTime());
            persistTodo(child->item, child->todo);
        }
    }
}

void TaskController::deleteTask(qint64 itemId)
{
    if (itemId < 0) {
        m_shared.tasks().remove(itemId);
        m_shared.notifyTasksChanged();
        return;
    }

    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache) {
        return;
    }

    m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Delete, *cache));

    const Akonadi::Item jobItem = cache->item;
    cache->pendingDelete = true;
    cache->syncing = true;
    cache->inflight += 1;
    m_shared.notifyTasksChanged();

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Delete;
    req.clientId = itemId;
    req.item = jobItem;
    m_writer->submit(req);
}

void TaskController::undo()
{
    if (!m_undo->canUndo()) {
        return;
    }

    const TaskLogic::UndoRecord record = m_undo->take();
    if (record.kind == TaskLogic::UndoRecord::Kind::Batch) {
        for (auto it = record.batch.crbegin(); it != record.batch.crend(); ++it) {
            applyUndoRecord(*it);
        }
        return;
    }
    applyUndoRecord(record);
}

void TaskController::applyUndoRecord(const TaskLogic::UndoRecord &record)
{
    TaskUndo::Applying applying(*m_undo);

    if (record.restoreLayout) {
        setKanbanManualOrderJson(record.kanbanManualOrderJson);
        setSortMode(record.sortMode);
    }

    if (undoNonEdit(record)) {
        return;
    }
    undoFields(record);
}

// Records that do not write fields of an existing task; true when handled.
bool TaskController::undoNonEdit(const TaskLogic::UndoRecord &record)
{
    switch (record.kind) {
    case TaskLogic::UndoRecord::Kind::KanbanLayout:
        return true;

    case TaskLogic::UndoRecord::Kind::Detach: {
        deleteDetached(record.detachedUid);
        TaskLogic::UndoRecord series = record;
        series.kind = TaskLogic::UndoRecord::Kind::Edit;
        applyUndoRecord(series);
        return true;
    }

    case TaskLogic::UndoRecord::Kind::Delete:
        undoDelete(record);
        return true;

    case TaskLogic::UndoRecord::Kind::Move:
        if (record.collectionId > 0) {
            moveTaskToCollection(record.itemId, record.collectionId);
        }
        return true;

    default:
        return false;
    }
}

void TaskController::undoDelete(const TaskLogic::UndoRecord &record)
{
    auto it = m_shared.tasks().find(record.itemId);
    if (it == m_shared.tasks().end() || !it->pendingDelete) {
        recreateTask(record);
        return;
    }

    // The delete is still in flight: recreate once it has finished.
    m_undo->recreateAfterDelete(record.itemId, record);
    it->pendingDelete = false;
    it->syncing = it->inflight > 1;
    m_shared.notifyTasksChanged();
}

void TaskController::undoFields(const TaskLogic::UndoRecord &record)
{
    SharedTasks::Entry *cache = prepareEdit(record.itemId);
    if (!cache || !cache->todo) {
        return;
    }

    const bool isEdit = record.kind == TaskLogic::UndoRecord::Kind::Edit;
    const bool isOther = record.kind == TaskLogic::UndoRecord::Kind::Complete
                         || record.kind == TaskLogic::UndoRecord::Kind::Reschedule;
    if (!isEdit && !isOther) {
        return;
    }

    if (isEdit && record.collectionId > 0 && cache->item.parentCollection().id() != record.collectionId) {
        moveTaskToCollection(record.itemId, record.collectionId);
    }
    TaskUndo::restoreFields(cache->todo, record);
    persistTodo(cache->item, cache->todo);
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

void TaskController::recreateTask(const TaskLogic::UndoRecord &record)
{
    Akonadi::Collection collection = collectionById(record.collectionId);
    if (!CollectionListModel::isTaskWritable(collection)) {
        collection = firstWritableCollection();
    }
    if (!CollectionListModel::isTaskWritable(collection)) {
        Q_EMIT error(i18n("No writable task list selected."));
        return;
    }

    KCalendarCore::Todo::Ptr todo = TaskUndo::rebuild(record);

    Akonadi::Item jobItem;
    jobItem.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    jobItem.setPayload<KCalendarCore::Todo::Ptr>(todo);

    const qint64 tempId = m_shared.nextTempId();
    Akonadi::Item cacheItem = jobItem;
    cacheItem.setId(tempId);
    cacheItem.setParentCollection(collection);

    SharedTasks::Entry cached;
    cached.item = cacheItem;
    cached.todo = todo;
    cached.syncing = true;
    cached.inflight = 1;
    m_shared.tasks().insert(tempId, cached);
    m_shared.notifyTasksChanged();

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
        collectionLines.append(QStringLiteral("%1:%2").arg(id).arg(m_shared.collectionNames().value(id)));
    }
    if (m_collectionModel.rowCount() > 8) {
        collectionLines.append(QStringLiteral("… +%1 more").arg(m_collectionModel.rowCount() - 8));
    }

    QStringList enabledIdStrings;
    for (qint64 id : enabledIds) {
        enabledIdStrings.append(QString::number(id));
    }

    const AkonadiLoader::FetchStats stats = AkonadiLoader::instance().fetchStats();
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
                             .arg(stats.items)
                             .arg(stats.accepted)
                             .arg(stats.rejectedNotTodo)
                             .arg(stats.rejectedNoPayload)
                             .arg(stats.rejectedDisabled)
                             .arg(stats.rejectedNoCollection)
                             .arg(m_shared.tasks().size())
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

void TaskController::scheduleRebuild()
{
    if (!m_rebuildTimer.isActive()) {
        m_rebuildTimer.start();
    }
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
    const int n = m_shared.tasks().size();
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
    allTasks.reserve(m_shared.tasks().size());
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
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
    input.matrixDrillActive = m_matrixDrillActive;
    input.matrixDrillAxis = m_matrixDrillAxis;
    input.matrixDrillLane = m_matrixDrillLane;
    input.matrixDrillBucket = m_matrixDrillBucket;
    input.matrixDrillHorizon = m_matrixDrillHorizon;
    input.matrixDrillTime = m_matrixDrillTime;
    input.matrixDrillIncludeCompleted = m_matrixDrillIncludeCompleted;
    input.countsExcludeCollapsed = m_countsExcludeCollapsed;
    input.extraLabels = m_shared.extraLabels();
    input.hierarchyAware = m_currentView == QLatin1String("completed")
            || !m_searchQuery.trimmed().isEmpty()
            || TaskLogic::hasSidebarFilters(input.filters);
    return input;
}

void TaskController::applyRebuildOutput(const TaskLogic::TaskRebuildOutput &output)
{
    const QList<TaskEntry> &countSource = output.countsExcludeCollapsed ? output.flatForCounts : output.allTasks;
    m_collectionModel.setTaskCounts(TaskLogic::collectionTaskCounts(countSource));
    m_taskModel.setTasks(output.tasks);

    // Defer the remaining updates by one event-loop iteration: the model
    // update renders first and animations (sidebar highlight, view
    // transitions) are not interrupted by the follow-up main-thread work.
    m_deferredCountSource = countSource;
    m_deferredCounts = output.counts;
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
    updateCounts(m_deferredCounts);
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

    // A rebuild requested meanwhile (rebuildTaskList bumped the generation) makes this
    // result stale: drop it and compute the latest state instead.
    const bool stale = m_pendingRebuildGeneration != m_rebuildGeneration;
    if (!stale) {
        applyRebuildOutput(m_rebuildWatcher.result());
        recordRebuildTiming(m_rebuildTiming.elapsed(), m_lastRebuildTaskCount);
    }

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
    const auto draggedIt = m_shared.tasks().constFind(itemId);
    if (draggedIt == m_shared.tasks().cend() || !draggedIt->todo) {
        return true;
    }

    QHash<QString, QString> parentByUid;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
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
    int jobs = AkonadiLoader::instance().fetchStats().pendingJobs;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
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
    const QStringList sorted = TaskLogic::collectAvailableLabels(tasks, m_shared.extraLabels());
    if (m_availableLabels == sorted) {
        return;
    }
    m_availableLabels = sorted;
    Q_EMIT availableLabelsChanged();
}

void TaskController::updateAvailableLocations(const QList<TaskEntry> &tasks)
{
    const QStringList sorted = TaskLogic::collectAvailableLocations(tasks, m_shared.extraLocations());
    if (m_availableLocations == sorted) {
        return;
    }
    m_availableLocations = sorted;
    Q_EMIT availableLocationsChanged();
}

void TaskController::updateCounts(const TaskLogic::SidebarCounts &counts)
{
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

bool TaskController::hydrateFromCache()
{
    if (m_shared.isEmpty()) {
        return false;
    }
    if (!m_shared.collections().isEmpty()) {
        m_collectionModel.setCollections(m_shared.collections());
    }
    if (!m_shared.eventCollections().isEmpty()) {
        m_eventCalendarModel.setCollections(m_shared.eventCollections());
    }
    scheduleRebuild();
    return true;
}

void TaskController::createLabel(const QString &name)
{
    if (!TaskLogic::canCreateLabel(name, m_availableLabels, m_shared.extraLabels())) {
        return;
    }
    m_shared.extraLabels().append(name.trimmed());
    m_shared.notifyTasksChanged();
}

void TaskController::deleteLabel(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    m_shared.extraLabels().removeAll(trimmed);

    if (!m_akonadiAvailable) {
        AkonadiLoader::instance().refresh();
    }

    QList<qint64> toUpdate;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (it->todo && it->todo->categories().contains(trimmed)) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        SharedTasks::Entry *cache = prepareEdit(itemId);
        if (!cache) {
            continue;
        }
        QStringList categories = cache->todo->categories();
        categories.removeAll(trimmed);
        cache->todo->setCategories(categories);
        persistTodo(cache->item, cache->todo);
    }

    m_shared.notifyTasksChanged();
}

void TaskController::renameLabel(const QString &from, const QString &to)
{
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (!TaskLogic::canRenameLabel(source, dest, m_availableLabels, m_shared.extraLabels())) {
        return;
    }

    for (int i = 0; i < m_shared.extraLabels().size(); ++i) {
        if (m_shared.extraLabels().at(i) == source) {
            m_shared.extraLabels()[i] = dest;
        }
    }
    m_shared.extraLabels().removeAll(source);
    if (!m_shared.extraLabels().contains(dest)) {
        m_shared.extraLabels().append(dest);
    }

    QList<qint64> toUpdate;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (it->todo && it->todo->categories().contains(source)) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        SharedTasks::Entry *cache = prepareEdit(itemId);
        if (!cache) {
            continue;
        }
        cache->todo->setCategories(TaskLogic::renameLabel(cache->todo->categories(), source, dest));
        persistTodo(cache->item, cache->todo);
    }
    m_shared.notifyTasksChanged();
}

void TaskController::createLocation(const QString &name)
{
    if (!TaskLogic::canCreateLabel(name, m_availableLocations, m_shared.extraLocations())) {
        return;
    }
    m_shared.extraLocations().append(name.trimmed());
    m_shared.notifyTasksChanged();
}

void TaskController::deleteLocation(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    m_shared.extraLocations().removeAll(trimmed);

    if (!m_akonadiAvailable) {
        AkonadiLoader::instance().refresh();
    }

    QList<qint64> toUpdate;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (it->todo && it->todo->location().trimmed() == trimmed) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        SharedTasks::Entry *cache = prepareEdit(itemId);
        if (!cache || !cache->todo) {
            continue;
        }
        cache->todo->setLocation(QString());
        persistTodo(cache->item, cache->todo);
    }

    m_shared.notifyTasksChanged();
}

void TaskController::renameLocation(const QString &from, const QString &to)
{
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (!TaskLogic::canRenameLabel(source, dest, m_availableLocations, m_shared.extraLocations())) {
        return;
    }

    for (int i = 0; i < m_shared.extraLocations().size(); ++i) {
        if (m_shared.extraLocations().at(i) == source) {
            m_shared.extraLocations()[i] = dest;
        }
    }
    m_shared.extraLocations().removeAll(source);
    if (!m_shared.extraLocations().contains(dest)) {
        m_shared.extraLocations().append(dest);
    }

    QList<qint64> toUpdate;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (it->todo && it->todo->location().trimmed() == source) {
            toUpdate.append(it.key());
        }
    }
    for (qint64 itemId : toUpdate) {
        SharedTasks::Entry *cache = prepareEdit(itemId);
        if (!cache || !cache->todo) {
            continue;
        }
        cache->todo->setLocation(dest);
        persistTodo(cache->item, cache->todo);
    }
    m_shared.notifyTasksChanged();
}

void TaskController::snoozeTask(qint64 itemId, const QString &preset)
{
    SharedTasks::Entry *cache = prepareEdit(itemId);
    if (!cache || !cache->todo) {
        return;
    }
    m_undo->push(TaskUndo::snapshot(TaskLogic::UndoRecord::Kind::Reschedule, *cache));
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
    if (!bus.registerService(QStringLiteral("io.github.shrippen.Kurrent"))) {
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
    showAction->setText(i18n("Show Kurrent"));
    KGlobalAccel::self()->setDefaultShortcut(showAction, {QKeySequence(QStringLiteral("Meta+Shift+K"))});
    KGlobalAccel::self()->setShortcut(showAction, {QKeySequence(QStringLiteral("Meta+Shift+K"))});
    connect(showAction, &QAction::triggered, this, []() {
        TaskController::broadcastDbusShow();
    });

    auto *addAction = new QAction(this);
    addAction->setObjectName(QStringLiteral("add-kurrent-task"));
    addAction->setText(i18n("Add Kurrent task"));
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

namespace {
// Task apps the settings can open, preferred first: {executable, display name}.
QPair<QString, QString> findTaskApp()
{
    static const QList<QPair<QString, QString>> apps = {
        {QStringLiteral("korganizer"), QStringLiteral("KOrganizer")},
        {QStringLiteral("merkuro-calendar"), QStringLiteral("Merkuro")},
    };
    for (const auto &app : apps) {
        if (!QStandardPaths::findExecutable(app.first).isEmpty()) {
            return app;
        }
    }
    return {};
}
}

QString TaskController::taskAppName() const
{
    return findTaskApp().second;
}

bool TaskController::launchTaskApp() const
{
    const auto app = findTaskApp();
    return !app.first.isEmpty() && QProcess::startDetached(app.first, {});
}
