#pragma once

#include "collectionlistmodel.h"
#include "tasklistmodel.h"

#include <Akonadi/Item>
#include <Akonadi/Monitor>

#include <KCalendarCore/Todo>

#include <QHash>
#include <QObject>
#include <QPointF>
#include <QTimer>
#include <QVariantMap>

namespace Akonadi
{
class CollectionFetchJob;
}

class KJob;

class TaskController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int buildNumber READ buildNumber CONSTANT)
    Q_PROPERTY(bool devBuild READ devBuild CONSTANT)
    Q_PROPERTY(bool smokeTest READ smokeTest CONSTANT)
    Q_PROPERTY(bool akonadiAvailable READ akonadiAvailable NOTIFY akonadiAvailableChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString currentView READ currentView WRITE setCurrentView NOTIFY currentViewChanged)
    Q_PROPERTY(QString managementView READ managementView WRITE setManagementView NOTIFY managementViewChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(bool showCompleted READ showCompleted WRITE setShowCompleted NOTIFY showCompletedChanged)
    Q_PROPERTY(qint64 selectedCollectionId READ selectedCollectionId WRITE setSelectedCollectionId NOTIFY selectedCollectionIdChanged)
    Q_PROPERTY(QString selectedLabel READ selectedLabel WRITE setSelectedLabel NOTIFY selectedLabelChanged)
    Q_PROPERTY(int selectedPriority READ selectedPriority WRITE setSelectedPriority NOTIFY selectedPriorityChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(bool catchUpEnabled READ catchUpEnabled WRITE setCatchUpEnabled NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int catchUpDays READ catchUpDays WRITE setCatchUpDays NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int morningHour READ morningHour WRITE setMorningHour NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int afternoonHour READ afternoonHour WRITE setAfternoonHour NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int eveningHour READ eveningHour WRITE setEveningHour NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)
    Q_PROPERTY(QStringList availableLabels READ availableLabels NOTIFY availableLabelsChanged)
    Q_PROPERTY(QVariantMap labelTaskCounts READ labelTaskCounts NOTIFY labelTaskCountsChanged)
    Q_PROPERTY(QVariantMap viewTaskCounts READ viewTaskCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarProjectCounts READ sidebarProjectCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarLabelCounts READ sidebarLabelCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarPriorityCounts READ sidebarPriorityCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(TaskListModel *taskModel READ taskModel CONSTANT)
    Q_PROPERTY(CollectionListModel *collectionModel READ collectionModel CONSTANT)
    Q_PROPERTY(QString debugInfo READ debugInfo NOTIFY debugInfoChanged)

public:
    explicit TaskController(QObject *parent = nullptr);
    ~TaskController() override;

    int buildNumber() const;
    bool devBuild() const;
    bool smokeTest() const;

    bool akonadiAvailable() const { return m_akonadiAvailable; }
    bool loading() const { return m_loading; }
    QString errorMessage() const { return m_errorMessage; }
    QString currentView() const { return m_currentView; }
    QString managementView() const { return m_managementView; }
    QString searchQuery() const { return m_searchQuery; }
    bool showCompleted() const { return m_showCompleted; }
    qint64 selectedCollectionId() const { return m_selectedCollectionId; }
    QString selectedLabel() const { return m_selectedLabel; }
    int selectedPriority() const { return m_selectedPriority; }
    QString sortMode() const { return m_sortMode; }
    bool catchUpEnabled() const { return m_catchUpEnabled; }
    int catchUpDays() const { return m_catchUpDays; }
    int morningHour() const { return m_morningHour; }
    int afternoonHour() const { return m_afternoonHour; }
    int eveningHour() const { return m_eveningHour; }
    int pendingCount() const { return m_pendingCount; }
    QStringList availableLabels() const { return m_availableLabels; }
    QVariantMap labelTaskCounts() const { return m_labelTaskCounts; }
    QVariantMap viewTaskCounts() const { return m_viewTaskCounts; }
    QVariantMap sidebarProjectCounts() const { return m_sidebarProjectCounts; }
    QVariantMap sidebarLabelCounts() const { return m_sidebarLabelCounts; }
    QVariantMap sidebarPriorityCounts() const { return m_sidebarPriorityCounts; }
    TaskListModel *taskModel() { return &m_taskModel; }
    CollectionListModel *collectionModel() { return &m_collectionModel; }
    QString debugInfo() const { return m_debugInfo; }

    Q_INVOKABLE QString collectionNameForId(qint64 collectionId) const;
    Q_INVOKABLE int systemCursorSize() const;
    Q_INVOKABLE QVariantMap dragScreenLimits() const;
    Q_INVOKABLE QPointF dragProxyGap(int cursorSize, int cursorShape) const;
    Q_INVOKABLE QPointF clampDragProxyOffset(qreal cursorX,
                                            qreal cursorY,
                                            qreal gapX,
                                            qreal gapY,
                                            qreal width,
                                            qreal height,
                                            qreal limitRight,
                                            qreal limitBottom) const;
    Q_INVOKABLE void smokeTrace(const QString &message) const;

    void setCurrentView(const QString &view);
    void setManagementView(const QString &view);
    void setSearchQuery(const QString &query);
    void setShowCompleted(bool show);
    void setSelectedCollectionId(qint64 id);
    void setSelectedLabel(const QString &label);
    void setSelectedPriority(int priority);
    void setSortMode(const QString &mode);
    void setCatchUpEnabled(bool enabled);
    void setCatchUpDays(int days);
    void setMorningHour(int hour);
    void setAfternoonHour(int hour);
    void setEveningHour(int hour);
    Q_INVOKABLE void setEnabledCollectionIds(const QVariantList &ids);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void syncNow();
    Q_INVOKABLE void createTask(const QString &summary, qint64 collectionId);
    Q_INVOKABLE QVariantMap parseQuickAdd(const QString &text) const;
    Q_INVOKABLE void rescheduleTask(qint64 itemId, const QString &preset);
    Q_INVOKABLE QString joinUrlFor(const QString &description, const QString &location) const;
    Q_INVOKABLE void updateTask(qint64 itemId,
                                const QString &summary,
                                const QString &description,
                                const QDateTime &dueDate,
                                bool clearDue,
                                int priority,
                                const QStringList &categories);
    Q_INVOKABLE void updateTaskFull(qint64 itemId, const QVariantMap &fields);
    Q_INVOKABLE void setTaskParent(qint64 itemId, const QString &parentUid);
    Q_INVOKABLE void addTaskCategory(qint64 itemId, const QString &category);
    Q_INVOKABLE void setTaskPriority(qint64 itemId, int priority);
    Q_INVOKABLE void moveTaskToCollection(qint64 itemId, qint64 collectionId);
    Q_INVOKABLE void setTaskCompleted(qint64 itemId, bool completed);
    Q_INVOKABLE void deleteTask(qint64 itemId);
    Q_INVOKABLE void createLabel(const QString &name);
    Q_INVOKABLE void deleteLabel(const QString &name);
    Q_INVOKABLE bool hydrateFromCache();

signals:
    void akonadiAvailableChanged();
    void loadingChanged();
    void errorMessageChanged();
    void currentViewChanged();
    void managementViewChanged();
    void searchQueryChanged();
    void showCompletedChanged();
    void selectedCollectionIdChanged();
    void selectedLabelChanged();
    void selectedPriorityChanged();
    void sortModeChanged();
    void catchUpSettingsChanged();
    void pendingCountChanged();
    void availableLabelsChanged();
    void labelTaskCountsChanged();
    void sidebarCountsChanged();
    void debugInfoChanged();
    void error(const QString &message);

private:
    struct CachedTask {
        Akonadi::Item item;
        KCalendarCore::Todo::Ptr todo;
        bool syncing = false;
        bool pendingDelete = false;
        int inflight = 0;
        KCalendarCore::Todo::Ptr revertTodo;
        qint64 revertCollectionId = -1;
    };

    void setLoading(bool loading);
    void setErrorMessage(const QString &message);
    bool initializeAkonadi();
    void scheduleAkonadiRetry();
    void loadCollections();
    void scheduleLoadCollections();
    void loadTasks();
    void scheduleRebuild();
    void rebuildTaskList();
    bool wouldCreateParentCycle(qint64 itemId, const QString &parentUid) const;
    bool taskMatchesView(const TaskEntry &task) const;
    bool taskMatchesViewId(const TaskEntry &task, const QString &viewId) const;
    bool taskMatchesFilters(const TaskEntry &task) const;
    bool taskMatchesSearch(const TaskEntry &task) const;
    bool isCollectionEnabled(qint64 collectionId) const;
    QList<Akonadi::Collection> enabledCollections() const;
    void upsertTask(const Akonadi::Item &item, qint64 fallbackCollectionId = -1);
    void removeTask(Akonadi::Item::Id itemId);
    Akonadi::Item itemById(qint64 itemId) const;
    KCalendarCore::Todo::Ptr todoFromItem(const Akonadi::Item &item) const;
    QString sectionFromTodo(const KCalendarCore::Todo::Ptr &todo) const;
    TaskEntry makeTaskEntry(const CachedTask &cached, int indentLevel, bool hasChildren) const;
    static QString recurrencePresetFromTodo(const KCalendarCore::Todo::Ptr &todo);
    static void applyRecurrencePreset(const KCalendarCore::Todo::Ptr &todo, const QString &preset);
    CachedTask *prepareEdit(qint64 itemId);
    void finishSync(qint64 itemId, bool ok, KJob *job);
    void persistTodo(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId = -1);
    Akonadi::Collection collectionById(qint64 collectionId) const;
    Akonadi::Collection firstWritableCollection() const;
    void updatePendingCount();
    void updateAvailableLabels(const QList<TaskEntry> &tasks);
    void updateCounts(const QList<TaskEntry> &tasks);
    void publishSharedCache();
    void scheduleRebuildAll();
    void onItemsFetched(KJob *job, qint64 collectionId);
    void logDebug(const QString &message);
    void updateDebugInfo(int builtTasks, int filteredTasks, int filteredOutCompleted, int filteredOutView, int filteredOutSearch);

    bool m_akonadiAvailable = false;
    bool m_loading = false;
    QString m_errorMessage;
    QString m_debugInfo;
    QString m_currentView = QStringLiteral("inbox");
    QString m_managementView = QString();
    QString m_searchQuery;
    bool m_showCompleted = false;
    qint64 m_selectedCollectionId = -1;
    QString m_selectedLabel;
    int m_selectedPriority = -1;
    QString m_sortMode = QStringLiteral("default");
    bool m_catchUpEnabled = true;
    int m_catchUpDays = 14;
    int m_morningHour = 6;
    int m_afternoonHour = 12;
    int m_eveningHour = 18;
    int m_pendingCount = 0;
    QStringList m_availableLabels;
    QVariantMap m_labelTaskCounts;
    QVariantMap m_viewTaskCounts;
    QVariantMap m_sidebarProjectCounts;
    QVariantMap m_sidebarLabelCounts;
    QVariantMap m_sidebarPriorityCounts;

    Akonadi::Monitor *m_monitor = nullptr;
    Akonadi::CollectionFetchJob *m_collectionFetchJob = nullptr;
    bool m_collectionsReloadPending = false;
    int m_pendingFetchJobs = 0;

    int m_lastFetchItemCount = 0;
    int m_lastFetchAccepted = 0;
    int m_lastFetchRejectedNotTodo = 0;
    int m_lastFetchRejectedNoPayload = 0;
    int m_lastFetchRejectedDisabled = 0;
    int m_lastFetchRejectedNoCollection = 0;

    TaskListModel m_taskModel;
    CollectionListModel m_collectionModel;
    QHash<qint64, QString> m_collectionNames;
    QHash<Akonadi::Item::Id, CachedTask> m_tasks;
    QTimer m_rebuildTimer;
    QTimer m_collectionsTimer;
    QTimer m_akonadiRetryTimer;

    static QHash<Akonadi::Item::Id, CachedTask> s_tasks;
    static QList<Akonadi::Collection> s_collections;
    static QHash<qint64, QString> s_collectionNames;
    static QStringList s_extraLabels;
    static QList<TaskController *> s_instances;
    static qint64 s_nextTempId;
};
