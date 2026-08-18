#include "taskcontroller.h"
#include "taskcalendar.h"
#include "tasklogic.h"

#include <Akonadi/AgentManager>
#include <Akonadi/Collection>
#include <Akonadi/CollectionFetchJob>
#include <Akonadi/CollectionFetchScope>
#include <Akonadi/ItemCreateJob>
#include <Akonadi/ItemDeleteJob>
#include <Akonadi/ItemFetchJob>
#include <Akonadi/ItemFetchScope>
#include <Akonadi/ItemModifyJob>
#include <Akonadi/ItemMoveJob>
#include <Akonadi/ServerManager>

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
QHash<qint64, QString> TaskController::s_collectionNames;
QStringList TaskController::s_extraLabels;
QList<TaskController *> TaskController::s_instances;
qint64 TaskController::s_nextTempId = -2;

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
}

int TaskController::buildNumber() const
{
#ifndef KURRENT_BUILD_NUMBER
    return 0;
#else
    return KURRENT_BUILD_NUMBER;
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

void TaskController::smokeTrace(const QString &message) const
{
    qWarning().noquote() << message;
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
    return TaskLogic::dragProxyGap(cursorSize, cursorShape == static_cast<int>(Qt::ArrowCursor));
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
    const QString normalized = mode.isEmpty() ? QStringLiteral("default") : mode;
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
    const TaskLogic::QuickAdd parsed = TaskLogic::parseQuickAdd(summary, QDate::currentDate(), QTime::currentTime());
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

    auto *job = new Akonadi::ItemCreateJob(jobItem, collection, this);
    connect(job, &Akonadi::ItemCreateJob::result, this, [this, tempId, collectionId = collection.id()](KJob *kjob) {
        s_tasks.remove(tempId);
        auto *createJob = qobject_cast<Akonadi::ItemCreateJob *>(kjob);
        if (kjob->error() || !createJob) {
            scheduleRebuildAll();
            setErrorMessage(kjob->errorString());
            Q_EMIT error(kjob->errorString());
            return;
        }
        upsertTask(createJob->item(), collectionId);
        scheduleRebuildAll();
    });
}

QVariantMap TaskController::parseQuickAdd(const QString &text) const
{
    const TaskLogic::QuickAdd parsed = TaskLogic::parseQuickAdd(text, QDate::currentDate(), QTime::currentTime());
    QVariantMap out;
    out.insert(QStringLiteral("summary"), parsed.summary);
    out.insert(QStringLiteral("hasDue"), parsed.hasDue);
    out.insert(QStringLiteral("allDay"), parsed.allDay);
    out.insert(QStringLiteral("due"), parsed.due);
    out.insert(QStringLiteral("priority"), parsed.priority);
    out.insert(QStringLiteral("labels"), parsed.labels);
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
    const QDateTime next = TaskLogic::rescheduleDue(currentDue, todo->allDay(), QDateTime::currentDateTime(), preset);
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

void TaskController::finishSync(qint64 itemId, bool ok, KJob *job)
{
    auto it = s_tasks.find(itemId);
    if (it == s_tasks.end()) {
        if (!ok && job) {
            setErrorMessage(job->errorString());
            Q_EMIT error(job->errorString());
        }
        return;
    }

    it->inflight = qMax(0, it->inflight - 1);
    if (it->inflight > 0) {
        if (!ok && job) {
            setErrorMessage(job->errorString());
            Q_EMIT error(job->errorString());
        }
        return;
    }

    if (!ok) {
        if (it->revertTodo) {
            it->todo = it->revertTodo;
            it->item.setPayload<KCalendarCore::Todo::Ptr>(it->todo);
            if (it->revertCollectionId > 0) {
                it->item.setParentCollection(Akonadi::Collection(it->revertCollectionId));
            }
        }
        it->pendingDelete = false;
        if (job) {
            setErrorMessage(job->errorString());
            Q_EMIT error(job->errorString());
        }
    }

    it->revertTodo.clear();
    it->revertCollectionId = -1;
    it->syncing = false;
    it->inflight = 0;
    scheduleRebuildAll();
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

    auto *job = new Akonadi::ItemModifyJob(modifiedItem, this);
    connect(job, &Akonadi::ItemModifyJob::result, this, [this, itemId, moveToCollectionId](KJob *kjob) {
        if (kjob->error()) {
            finishSync(itemId, false, kjob);
            return;
        }
        if (moveToCollectionId > 0) {
            auto *moveJob = new Akonadi::ItemMoveJob(Akonadi::Item(itemId), Akonadi::Collection(moveToCollectionId), this);
            connect(moveJob, &Akonadi::ItemMoveJob::result, this, [this, itemId](KJob *moveKjob) {
                finishSync(itemId, !moveKjob->error(), moveKjob);
            });
            return;
        }
        finishSync(itemId, true, nullptr);
    });
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
    entry.dueDate = (todo->hasDueDate() && todo->dtDue().isValid()) ? todo->dtDue() : QDateTime();
    entry.startDate = (todo->hasStartDate() && todo->dtStart().isValid()) ? todo->dtStart() : QDateTime();
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
        TaskCalendar::completeTodo(todo, completed, QDateTime::currentDateTime());
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

    KCalendarCore::Todo::Ptr todo = cache->todo;
    const QString trimmedParent = parentUid.trimmed();
    if (!trimmedParent.isEmpty()) {
        if (trimmedParent == todo->uid()) {
            setErrorMessage(tr("A task cannot be its own parent."));
            Q_EMIT error(m_errorMessage);
            return;
        }
        if (wouldCreateParentCycle(itemId, trimmedParent)) {
            setErrorMessage(tr("Cannot create a circular task hierarchy."));
            Q_EMIT error(m_errorMessage);
            return;
        }

        bool parentFound = false;
        for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
            if (it->todo && it->todo->uid() == trimmedParent) {
                parentFound = true;
                break;
            }
        }
        if (!parentFound) {
            setErrorMessage(tr("Parent task not found."));
            Q_EMIT error(m_errorMessage);
            return;
        }
    }

    if (todo->relatedTo() == trimmedParent) {
        return;
    }

    todo->setRelatedTo(trimmedParent);
    persistTodo(cache->item, todo);
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

    auto *moveJob = new Akonadi::ItemMoveJob(jobItem, destination, this);
    connect(moveJob, &Akonadi::ItemMoveJob::result, this, [this, itemId](KJob *kjob) {
        finishSync(itemId, !kjob->error(), kjob);
    });
}

void TaskController::setTaskCompleted(qint64 itemId, bool completed)
{
    CachedTask *cache = prepareEdit(itemId);
    if (!cache) {
        return;
    }

    KCalendarCore::Todo::Ptr todo = cache->todo;
    pushUndo(snapshotUndo(TaskLogic::UndoRecord::Kind::Complete, *cache));
    TaskCalendar::completeTodo(todo, completed, QDateTime::currentDateTime());
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
            TaskCalendar::completeTodo(child->todo, true, QDateTime::currentDateTime());
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

    auto *job = new Akonadi::ItemDeleteJob(jobItem, this);
    connect(job, &Akonadi::ItemDeleteJob::result, this, [this, itemId](KJob *kjob) {
        if (kjob->error()) {
            m_recreateAfterDelete.remove(itemId);
            finishSync(itemId, false, kjob);
            return;
        }
        s_tasks.remove(itemId);
        if (m_recreateAfterDelete.contains(itemId)) {
            const TaskLogic::UndoRecord record = m_recreateAfterDelete.take(itemId);
            recreateTask(record);
            return;
        }
        scheduleRebuildAll();
    });
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

    auto *job = new Akonadi::ItemCreateJob(jobItem, collection, this);
    connect(job, &Akonadi::ItemCreateJob::result, this, [this, tempId, collectionId = collection.id()](KJob *kjob) {
        s_tasks.remove(tempId);
        auto *createJob = qobject_cast<Akonadi::ItemCreateJob *>(kjob);
        if (kjob->error() || !createJob) {
            scheduleRebuildAll();
            setErrorMessage(kjob->errorString());
            Q_EMIT error(kjob->errorString());
            return;
        }
        upsertTask(createJob->item(), collectionId);
        scheduleRebuildAll();
    });
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
    const QString kind = TaskLogic::emptyKind(m_loading,
                                              m_akonadiAvailable,
                                              m_collectionModel.count(),
                                              m_taskModel.count(),
                                              !m_errorMessage.isEmpty());
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
    scope.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
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
        collections.reserve(fetched.size());
        logDebug(QStringLiteral("loadCollections: found %1 todo collections").arg(fetched.size()));
        for (const Akonadi::Collection &collection : fetched) {
            logDebug(QStringLiteral("  collection id=%1 name=\"%2\" mimes=%3 rights=%4")
                         .arg(collection.id())
                         .arg(collection.displayName())
                         .arg(collection.contentMimeTypes().join(QLatin1Char(',')))
                         .arg(static_cast<int>(collection.rights())));
            if (!CollectionListModel::isTaskCollection(collection)) {
                continue;
            }
            collections.append(collection);
            m_collectionNames.insert(collection.id(), collection.displayName());
        }
        logDebug(QStringLiteral("loadCollections: keeping %1 task collections").arg(collections.size()));

        s_collections = collections;
        s_collectionNames = m_collectionNames;
        m_collectionModel.setCollections(collections);
        for (TaskController *other : s_instances) {
            if (other != this) {
                other->m_collectionNames = s_collectionNames;
                other->m_collectionModel.setCollections(s_collections);
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

        loadTasks();
    });
}

void TaskController::loadTasks()
{
    if (!m_akonadiAvailable) {
        return;
    }

    const QList<Akonadi::Collection> collections = enabledCollections();
    s_tasks.clear();

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
            for (const Akonadi::Item &item : fetchJob->items()) {
                upsertTask(item, collectionId);
            }
        } else if (m_errorMessage.isEmpty()) {
            setErrorMessage(job->errorString());
        }
    }

    if (m_pendingFetchJobs <= 0) {
        m_pendingFetchJobs = 0;
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
    QList<TaskEntry> tasks;
    tasks.reserve(s_tasks.size());
    for (auto it = s_tasks.cbegin(); it != s_tasks.cend(); ++it) {
        if (!it->todo) {
            continue;
        }
        tasks.append(makeTaskEntry(it.value(), 0, false));
    }
    tasks = TaskLogic::flattenTree(tasks, m_sortMode, m_collapsedUids);

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
    filters.searchTitleOnly = m_searchTitleOnly;
    filters.searchCaseSensitive = m_searchCaseSensitive;

    const TaskLogic::VisibleFilterResult filtered = TaskLogic::filterVisibleTasks(tasks, filters, QDate::currentDate());

    m_collectionModel.setTaskCounts(TaskLogic::collectionTaskCounts(tasks));
    m_taskModel.setTasks(filtered.tasks);
    updatePendingCount(tasks);
    updateAvailableLabels(tasks);
    updateCounts(tasks);
    publishSharedCache();
    updateEmptyKind();
    updateDebugInfo(tasks.size(),
                    filtered.tasks.size(),
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
    return TaskLogic::matchesSearch(task, m_searchQuery, m_searchTitleOnly, m_searchCaseSensitive);
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
    filters.searchTitleOnly = m_searchTitleOnly;
    filters.searchCaseSensitive = m_searchCaseSensitive;

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

void TaskController::checkReminders()
{
    if (!m_notificationsEnabled || !m_akonadiAvailable) {
        return;
    }
    const QDateTime now = QDateTime::currentDateTime();
    if (TaskLogic::inQuietHours(now.time(), m_quietHoursStart, m_quietHoursEnd, m_quietHoursEnabled)) {
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
