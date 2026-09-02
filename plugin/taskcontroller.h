#pragma once

#include "collectionlistmodel.h"
#include "taskcalendar.h"
#include "tasklistmodel.h"
#include "tasklogic.h"
#include "taskstore.h"

#include <Akonadi/Item>
#include <Akonadi/Monitor>

#include <KCalendarCore/Todo>

#include <QElapsedTimer>
#include <QFutureWatcher>
#include <QHash>
#include <QObject>
#include <QPointF>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

namespace Akonadi
{
class CollectionFetchJob;
class ItemFetchJob;
}

class KJob;

class TaskController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int buildNumber READ buildNumber CONSTANT)
    Q_PROPERTY(QString pluginVersion READ pluginVersion CONSTANT)
    Q_PROPERTY(bool devBuild READ devBuild CONSTANT)
    Q_PROPERTY(bool smokeTest READ smokeTest CONSTANT)
    // Process-wide smoke progress so a recreated FullView continues instead of restarting.
    Q_PROPERTY(int smokeStep READ smokeStep WRITE setSmokeStep NOTIFY smokeStepChanged)
    Q_PROPERTY(bool smokeFinished READ smokeFinished NOTIFY smokeFinishedChanged)
    Q_PROPERTY(bool smokeLeader READ smokeLeader NOTIFY smokeLeaderChanged)
    Q_PROPERTY(bool akonadiAvailable READ akonadiAvailable NOTIFY akonadiAvailableChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool listReorganizing READ listReorganizing NOTIFY listReorganizingChanged)
    Q_PROPERTY(int estimatedRebuildMs READ estimatedRebuildMs NOTIFY rebuildPerfChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString emptyKind READ emptyKind NOTIFY emptyKindChanged)
    Q_PROPERTY(QString currentView READ currentView WRITE setCurrentView NOTIFY currentViewChanged)
    Q_PROPERTY(QString managementView READ managementView WRITE setManagementView NOTIFY managementViewChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(bool showCompleted READ showCompleted WRITE setShowCompleted NOTIFY showCompletedChanged)
    Q_PROPERTY(qint64 selectedCollectionId READ selectedCollectionId WRITE setSelectedCollectionId NOTIFY selectedCollectionIdChanged)
    Q_PROPERTY(QString selectedLabel READ selectedLabel WRITE setSelectedLabel NOTIFY selectedLabelChanged)
    Q_PROPERTY(int selectedPriority READ selectedPriority WRITE setSelectedPriority NOTIFY selectedPriorityChanged)
    Q_PROPERTY(QString selectedProgressBand READ selectedProgressBand WRITE setSelectedProgressBand NOTIFY selectedProgressBandChanged)
    Q_PROPERTY(int selectedStatus READ selectedStatus WRITE setSelectedStatus NOTIFY selectedStatusChanged)
    Q_PROPERTY(int selectedSecrecy READ selectedSecrecy WRITE setSelectedSecrecy NOTIFY selectedSecrecyChanged)
    Q_PROPERTY(QString selectedLocation READ selectedLocation WRITE setSelectedLocation NOTIFY selectedLocationChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(QString listGroupMode READ listGroupMode WRITE setListGroupMode NOTIFY listGroupModeChanged)
    Q_PROPERTY(QString mainPaneMode READ mainPaneMode WRITE setMainPaneMode NOTIFY mainPaneModeChanged)
    Q_PROPERTY(QString kanbanColumnSource READ kanbanColumnSource WRITE setKanbanColumnSource NOTIFY kanbanColumnSourceChanged)
    Q_PROPERTY(QString kanbanWriteMode READ kanbanWriteMode WRITE setKanbanWriteMode NOTIFY kanbanWriteModeChanged)
    Q_PROPERTY(QString kanbanManualOrderJson READ kanbanManualOrderJson WRITE setKanbanManualOrderJson NOTIFY kanbanManualOrderJsonChanged)
    Q_PROPERTY(QStringList kanbanColumnKeys READ kanbanColumnKeys NOTIFY kanbanLayoutChanged)
    Q_PROPERTY(int kanbanRevision READ kanbanRevision NOTIFY kanbanLayoutChanged)
    Q_PROPERTY(QString swimlaneLaneAxis READ swimlaneLaneAxis WRITE setSwimlaneLaneAxis NOTIFY swimlaneSettingsChanged)
    Q_PROPERTY(QString swimlaneTimeBucket READ swimlaneTimeBucket WRITE setSwimlaneTimeBucket NOTIFY swimlaneSettingsChanged)
    Q_PROPERTY(bool multiSelectEnabled READ multiSelectEnabled WRITE setMultiSelectEnabled NOTIFY multiSelectEnabledChanged)
    Q_PROPERTY(QStringList selectedTaskIds READ selectedTaskIds NOTIFY selectedTaskIdsChanged)
    Q_PROPERTY(QString smartViewsJson READ smartViewsJson WRITE setSmartViewsJson NOTIFY smartViewsJsonChanged)
    Q_PROPERTY(qint64 conflictItemId READ conflictItemId NOTIFY conflictItemIdChanged)
    Q_PROPERTY(bool catchUpEnabled READ catchUpEnabled WRITE setCatchUpEnabled NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int catchUpDays READ catchUpDays WRITE setCatchUpDays NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int morningHour READ morningHour WRITE setMorningHour NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int afternoonHour READ afternoonHour WRITE setAfternoonHour NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(int eveningHour READ eveningHour WRITE setEveningHour NOTIFY catchUpSettingsChanged)
    Q_PROPERTY(QString defaultDueMode READ defaultDueMode WRITE setDefaultDueMode NOTIFY defaultDueModeChanged)
    Q_PROPERTY(bool searchTitleOnly READ searchTitleOnly WRITE setSearchTitleOnly NOTIFY searchSettingsChanged)
    Q_PROPERTY(bool searchCaseSensitive READ searchCaseSensitive WRITE setSearchCaseSensitive NOTIFY searchSettingsChanged)
    Q_PROPERTY(bool completeChildren READ completeChildren WRITE setCompleteChildren NOTIFY completeChildrenChanged)
    Q_PROPERTY(bool countsExcludeCollapsed READ countsExcludeCollapsed WRITE setCountsExcludeCollapsed NOTIFY countsExcludeCollapsedChanged)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled WRITE setNotificationsEnabled NOTIFY notificationsEnabledChanged)
    Q_PROPERTY(int defaultReminderMinutes READ defaultReminderMinutes WRITE setDefaultReminderMinutes NOTIFY defaultReminderMinutesChanged)
    Q_PROPERTY(bool quietHoursEnabled READ quietHoursEnabled WRITE setQuietHoursEnabled NOTIFY quietHoursChanged)
    Q_PROPERTY(int quietHoursStart READ quietHoursStart WRITE setQuietHoursStart NOTIFY quietHoursChanged)
    Q_PROPERTY(int quietHoursEnd READ quietHoursEnd WRITE setQuietHoursEnd NOTIFY quietHoursChanged)
    Q_PROPERTY(bool suppressRemindersDuringEvents READ suppressRemindersDuringEvents WRITE setSuppressRemindersDuringEvents NOTIFY eventBusySettingsChanged)
    Q_PROPERTY(QString busyCalendarIds READ busyCalendarIds WRITE setBusyCalendarIds NOTIFY eventBusySettingsChanged)
    Q_PROPERTY(QVariantList eventCalendars READ eventCalendars NOTIFY eventBusySettingsChanged)
    Q_PROPERTY(QDate agendaSelectedDate READ agendaSelectedDate WRITE setAgendaSelectedDate NOTIFY agendaSelectedDateChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoChanged)
    Q_PROPERTY(QString undoKind READ undoKind NOTIFY undoChanged)
    Q_PROPERTY(QString undoLabel READ undoLabel NOTIFY undoChanged)
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)
    Q_PROPERTY(int syncingCount READ syncingCount NOTIFY syncingCountChanged)
    Q_PROPERTY(QStringList availableLabels READ availableLabels NOTIFY availableLabelsChanged)
    Q_PROPERTY(QVariantMap labelTaskCounts READ labelTaskCounts NOTIFY labelTaskCountsChanged)
    Q_PROPERTY(QVariantMap viewTaskCounts READ viewTaskCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarProjectCounts READ sidebarProjectCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarLabelCounts READ sidebarLabelCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarPriorityCounts READ sidebarPriorityCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarProgressCounts READ sidebarProgressCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarStatusCounts READ sidebarStatusCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarSecrecyCounts READ sidebarSecrecyCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QVariantMap sidebarLocationCounts READ sidebarLocationCounts NOTIFY sidebarCountsChanged)
    Q_PROPERTY(QStringList availableLocations READ availableLocations NOTIFY availableLocationsChanged)
    Q_PROPERTY(TaskListModel *taskModel READ taskModel CONSTANT)
    Q_PROPERTY(CollectionListModel *collectionModel READ collectionModel CONSTANT)
    Q_PROPERTY(CollectionListModel *eventCalendarModel READ eventCalendarModel CONSTANT)
    Q_PROPERTY(QString debugInfo READ debugInfo NOTIFY debugInfoChanged)

public:
    explicit TaskController(QObject *parent = nullptr);
    ~TaskController() override;

    int buildNumber() const;
    QString pluginVersion() const;
    bool devBuild() const;
    bool smokeTest() const;
    int smokeStep() const;
    void setSmokeStep(int step);
    bool smokeFinished() const;
    bool smokeLeader();

    bool akonadiAvailable() const { return m_akonadiAvailable; }
    bool loading() const { return m_loading; }
    bool listReorganizing() const { return m_listReorganizing; }
    int estimatedRebuildMs() const;
    Q_INVOKABLE int estimatedViewSwitchMs(bool coldLoader) const;
    QString errorMessage() const { return m_errorMessage; }
    QString emptyKind() const { return m_emptyKind; }
    QString currentView() const { return m_currentView; }
    QString managementView() const { return m_managementView; }
    QString searchQuery() const { return m_searchQuery; }
    bool showCompleted() const { return m_showCompleted; }
    qint64 selectedCollectionId() const { return m_selectedCollectionId; }
    QString selectedLabel() const { return m_selectedLabel; }
    int selectedPriority() const { return m_selectedPriority; }
    QString selectedProgressBand() const { return m_selectedProgressBand; }
    int selectedStatus() const { return m_selectedStatus; }
    int selectedSecrecy() const { return m_selectedSecrecy; }
    QString selectedLocation() const { return m_selectedLocation; }
    QString sortMode() const { return m_sortMode; }
    QString listGroupMode() const { return m_listGroupMode; }
    QString mainPaneMode() const { return m_mainPaneMode; }
    QString kanbanColumnSource() const { return m_kanbanColumnSource; }
    QString kanbanWriteMode() const { return m_kanbanWriteMode; }
    QString kanbanManualOrderJson() const { return m_kanbanManualOrderJson; }
    QStringList kanbanColumnKeys() const { return m_kanbanColumnKeys; }
    int kanbanRevision() const { return m_kanbanRevision; }
    QString swimlaneLaneAxis() const { return m_swimlaneLaneAxis; }
    QString swimlaneTimeBucket() const { return m_swimlaneTimeBucket; }
    bool multiSelectEnabled() const { return m_multiSelectEnabled; }
    QStringList selectedTaskIds() const { return m_selectedTaskIds; }
    QString smartViewsJson() const { return m_smartViewsJson; }
    qint64 conflictItemId() const { return m_conflictItemId; }
    bool catchUpEnabled() const { return m_catchUpEnabled; }
    int catchUpDays() const { return m_catchUpDays; }
    int morningHour() const { return m_morningHour; }
    int afternoonHour() const { return m_afternoonHour; }
    int eveningHour() const { return m_eveningHour; }
    QString defaultDueMode() const { return m_defaultDueMode; }
    bool searchTitleOnly() const { return m_searchTitleOnly; }
    bool searchCaseSensitive() const { return m_searchCaseSensitive; }
    bool completeChildren() const { return m_completeChildren; }
    bool countsExcludeCollapsed() const { return m_countsExcludeCollapsed; }
    bool notificationsEnabled() const { return m_notificationsEnabled; }
    int defaultReminderMinutes() const { return m_defaultReminderMinutes; }
    bool quietHoursEnabled() const { return m_quietHoursEnabled; }
    int quietHoursStart() const { return m_quietHoursStart; }
    int quietHoursEnd() const { return m_quietHoursEnd; }
    bool suppressRemindersDuringEvents() const { return m_suppressRemindersDuringEvents; }
    QString busyCalendarIds() const { return m_busyCalendarIds; }
    QVariantList eventCalendars() const;
    QDate agendaSelectedDate() const { return m_agendaSelectedDate; }
    void setAgendaSelectedDate(const QDate &date);
    bool canUndo() const { return m_undo.canUndo(); }
    QString undoKind() const { return TaskLogic::undoKindName(m_undo.peek().kind); }
    QString undoLabel() const;
    int pendingCount() const { return m_pendingCount; }
    int syncingCount() const { return m_syncingCount; }
    QStringList availableLabels() const { return m_availableLabels; }
    QVariantMap labelTaskCounts() const { return m_labelTaskCounts; }
    QVariantMap viewTaskCounts() const { return m_viewTaskCounts; }
    QVariantMap sidebarProjectCounts() const { return m_sidebarProjectCounts; }
    QVariantMap sidebarLabelCounts() const { return m_sidebarLabelCounts; }
    QVariantMap sidebarPriorityCounts() const { return m_sidebarPriorityCounts; }
    QVariantMap sidebarProgressCounts() const { return m_sidebarProgressCounts; }
    QVariantMap sidebarStatusCounts() const { return m_sidebarStatusCounts; }
    QVariantMap sidebarSecrecyCounts() const { return m_sidebarSecrecyCounts; }
    QVariantMap sidebarLocationCounts() const { return m_sidebarLocationCounts; }
    QStringList availableLocations() const { return m_availableLocations; }
    TaskListModel *taskModel() { return &m_taskModel; }
    CollectionListModel *collectionModel() { return &m_collectionModel; }
    CollectionListModel *eventCalendarModel() { return &m_eventCalendarModel; }
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
    void setSelectedProgressBand(const QString &band);
    void setSelectedStatus(int status);
    void setSelectedSecrecy(int secrecy);
    void setSelectedLocation(const QString &location);
    void setSortMode(const QString &mode);
    void setListGroupMode(const QString &mode);
    void setMainPaneMode(const QString &mode);
    void setKanbanColumnSource(const QString &source);
    void setKanbanWriteMode(const QString &mode);
    void setKanbanManualOrderJson(const QString &json);
    void setSwimlaneLaneAxis(const QString &axis);
    void setSwimlaneTimeBucket(const QString &bucket);
    void setMultiSelectEnabled(bool enabled);
    void setSmartViewsJson(const QString &json);
    Q_INVOKABLE void setSelectedTaskIds(const QStringList &ids);
    Q_INVOKABLE void toggleTaskSelection(qint64 itemId, bool ctrl, bool shift);
    Q_INVOKABLE void clearTaskSelection();
    Q_INVOKABLE QString kanbanColumnKeyForTask(qint64 itemId) const;
    Q_INVOKABLE QString kanbanColumnLabelForKey(const QString &key) const;
    Q_INVOKABLE QString listGroupLabelForKey(const QString &key) const;
    Q_INVOKABLE QStringList kanbanColumnKeysForVisibleTasks() const;
    Q_INVOKABLE QVariantList kanbanTaskIndicesForColumn(const QString &columnKey) const;
    Q_INVOKABLE QVariantList kanbanTasksForColumn(const QString &columnKey) const;
    Q_INVOKABLE QVariantMap taskRowSnapshot(int row) const;
    Q_INVOKABLE void moveTaskToKanbanColumn(qint64 itemId, const QString &columnKey);
    Q_INVOKABLE void finishKanbanDrop(qint64 itemId, const QString &columnKey, int targetGap,
                                        const QString &sourceColumnKey, int sourceIndex);
    Q_INVOKABLE void reorderKanbanCard(qint64 itemId, const QString &columnKey, int targetIndex);
    Q_INVOKABLE QVariantMap swimlaneMatrixForVisibleTasks() const;
    Q_INVOKABLE QVariantMap planMatrixGridForVisibleTasks() const;
    Q_INVOKABLE QStringList busyDayStripForVisibleTasks() const;
    Q_INVOKABLE QString swimlaneLaneLabelForKey(const QString &key) const;
    Q_INVOKABLE QString swimlaneTimeLabelForKey(const QString &key) const;
    Q_INVOKABLE void setPlanPreviewFilter(qint64 collectionId, const QString &weekKey);
    Q_INVOKABLE void clearPlanPreviewFilter();
    Q_INVOKABLE QVariantMap heatmapCountsForMonth(const QDate &monthStart, const QString &mode) const;
    Q_INVOKABLE QVariantMap planMatrixForVisibleTasks() const;
    Q_INVOKABLE QVariantList agendaEventsForDay(const QDate &day) const;
    Q_INVOKABLE QVariantList agendaTasksForRange(const QDate &from, const QDate &to) const;
    Q_INVOKABLE QVariantMap heatmapCountsForYear(int year, const QString &mode) const;
    Q_INVOKABLE QVariantMap heatmapCountsAll(const QDate &start, const QDate &end, const QString &mode) const;
    Q_INVOKABLE void bulkCompleteTasks(const QVariantList &itemIds, bool completed);
    Q_INVOKABLE void bulkDeleteTasks(const QVariantList &itemIds);
    Q_INVOKABLE void bulkMoveTasks(const QVariantList &itemIds, qint64 collectionId);
    Q_INVOKABLE void bulkAddLabel(const QVariantList &itemIds, const QString &label);
    Q_INVOKABLE void bulkRemoveLabel(const QVariantList &itemIds, const QString &label);
    Q_INVOKABLE void bulkSetPriority(const QVariantList &itemIds, int priority);
    Q_INVOKABLE void bulkRescheduleTasks(const QVariantList &itemIds, const QString &preset);
    Q_INVOKABLE QString bulkExportUids(const QVariantList &itemIds) const;
    Q_INVOKABLE void reloadTask(qint64 itemId);
    Q_INVOKABLE void dismissConflict();
    Q_INVOKABLE QVariantList smartViewsList() const;
    void setCatchUpEnabled(bool enabled);
    void setCatchUpDays(int days);
    void setMorningHour(int hour);
    void setAfternoonHour(int hour);
    void setEveningHour(int hour);
    void setDefaultDueMode(const QString &mode);
    void setSearchTitleOnly(bool titleOnly);
    void setSearchCaseSensitive(bool sensitive);
    void setCompleteChildren(bool complete);
    void setCountsExcludeCollapsed(bool exclude);
    void setNotificationsEnabled(bool enabled);
    void setDefaultReminderMinutes(int minutes);
    void setQuietHoursEnabled(bool enabled);
    void setQuietHoursStart(int hour);
    void setQuietHoursEnd(int hour);
    void setSuppressRemindersDuringEvents(bool enabled);
    void setBusyCalendarIds(const QString &ids);
    Q_INVOKABLE void setEnabledCollectionIds(const QVariantList &ids);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void syncNow();
    Q_INVOKABLE void createTask(const QString &summary, qint64 collectionId);
    Q_INVOKABLE QVariantMap parseQuickAdd(const QString &text,
                                          const QString &uiLanguage = QString(),
                                          const QVariantList &projects = QVariantList()) const;
    Q_INVOKABLE QVariantMap suggestQuickAdd(const QString &text,
                                            int cursor,
                                            const QString &uiLanguage,
                                            const QVariantList &projects) const;
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
    Q_INVOKABLE void createTaskFull(const QVariantMap &fields);
    Q_INVOKABLE void setTaskParent(qint64 itemId, const QString &parentUid);
    /** Same-project parent options for the full editor (excludes self and descendants). */
    Q_INVOKABLE QVariantList parentCandidates(qint64 itemId, qint64 collectionId) const;
    Q_INVOKABLE void addTaskCategory(qint64 itemId, const QString &category);
    Q_INVOKABLE void removeTaskCategory(qint64 itemId, const QString &category);
    Q_INVOKABLE void setTaskPriority(qint64 itemId, int priority);
    Q_INVOKABLE void moveTaskToCollection(qint64 itemId, qint64 collectionId);
    Q_INVOKABLE void setTaskCompleted(qint64 itemId, bool completed);
    Q_INVOKABLE void deleteTask(qint64 itemId);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void toggleTreeCollapsed(const QString &uid);
    Q_INVOKABLE void createLabel(const QString &name);
    Q_INVOKABLE void deleteLabel(const QString &name);
    Q_INVOKABLE void renameLabel(const QString &from, const QString &to);
    Q_INVOKABLE void createLocation(const QString &name);
    Q_INVOKABLE void deleteLocation(const QString &name);
    Q_INVOKABLE void renameLocation(const QString &from, const QString &to);
    Q_INVOKABLE void snoozeTask(qint64 itemId, const QString &preset);
    Q_INVOKABLE QString renameSeparatedList(const QString &raw, const QString &from, const QString &to, const QString &separator) const;
    Q_INVOKABLE QString setColorOverride(const QString &raw, const QString &key, const QString &color) const;
    Q_INVOKABLE QString moveColorKey(const QString &raw, const QString &from, const QString &to) const;
    Q_INVOKABLE QStringList mergeOrderedKeys(const QString &raw, const QString &defaultsCsv, const QString &separator) const;
    Q_INVOKABLE QStringList visibleOrderedKeys(const QString &orderRaw, const QString &hiddenRaw, const QString &defaultsCsv, const QString &orderSep, const QString &hiddenSep) const;
    Q_INVOKABLE QString moveOrderedKey(const QString &raw, const QString &key, int delta, const QString &defaultsCsv, const QString &separator) const;
    Q_INVOKABLE QString toggleToken(const QString &raw, const QString &token, const QString &separator) const;
    Q_INVOKABLE bool hydrateFromCache();

    // Merge conflict resolution
    Q_PROPERTY(QVariantList mergeFields READ mergeFields NOTIFY mergeConflictAvailable)
    QVariantList mergeFields() const { return m_pendingMergeFields; }
    Q_INVOKABLE void resolveMergeConflict(const QVariantMap &resolution);
    Q_INVOKABLE void testMergeConflict(); // Debug: simulate a conflict

    // Test hooks: swap MemoryTaskStore and seed cache without Akonadi server.
    void setTaskStore(AbstractTaskStore *store);
    void resetSharedStateForTest();
    void setAkonadiAvailableForTest(bool available);
    void installTestCollections(const QList<Akonadi::Collection> &collections);
    qint64 installTestTask(qint64 id, const QString &summary, qint64 collectionId);
    bool testTaskExists(qint64 id) const;
    bool testTaskSyncing(qint64 id) const;
    bool testTaskPendingDelete(qint64 id) const;
    bool testTaskCompleted(qint64 id) const;
    QString testTaskSummary(qint64 id) const;
    QStringList testTaskCategories(qint64 id) const;
    int testTaskPriority(qint64 id) const;
    int testTaskStatus(qint64 id) const;
    int testTaskSecrecy(qint64 id) const;
    QString testTaskLocation(qint64 id) const;
    QString testKanbanColumnKey(qint64 id) const;
    int testTaskRevision(qint64 id) const;
    qint64 testTaskCollectionId(qint64 id) const;
    int testInflight(qint64 id) const;
    void testApplyExternalItem(const Akonadi::Item &item);

    static void broadcastDbusShow();
    static void broadcastDbusAddTask(const QString &summary);
    static void broadcastDbusOpenView(const QString &view);
    static void broadcastDbusSearchAndShow(const QString &query);

signals:
    void akonadiAvailableChanged();
    void loadingChanged();
    void listReorganizingChanged();
    void rebuildPerfChanged();
    void errorMessageChanged();
    void emptyKindChanged();
    void smokeStepChanged();
    void smokeFinishedChanged();
    void smokeLeaderChanged();
    void currentViewChanged();
    void managementViewChanged();
    void searchQueryChanged();
    void agendaSelectedDateChanged();
    void showCompletedChanged();
    void selectedCollectionIdChanged();
    void selectedLabelChanged();
    void selectedPriorityChanged();
    void selectedProgressBandChanged();
    void selectedStatusChanged();
    void selectedSecrecyChanged();
    void selectedLocationChanged();
    void sortModeChanged();
    void listGroupModeChanged();
    void mainPaneModeChanged();
    void kanbanColumnSourceChanged();
    void kanbanWriteModeChanged();
    void kanbanManualOrderJsonChanged();
    void kanbanLayoutChanged();
    void swimlaneSettingsChanged();
    void multiSelectEnabledChanged();
    void selectedTaskIdsChanged();
    void smartViewsJsonChanged();
    void conflictItemIdChanged();
    void mergeConflictAvailable(QVariantList fields, qint64 itemId);
    void catchUpSettingsChanged();
    void defaultDueModeChanged();
    void searchSettingsChanged();
    void completeChildrenChanged();
    void countsExcludeCollapsedChanged();
    void notificationsEnabledChanged();
    void defaultReminderMinutesChanged();
    void quietHoursChanged();
    void eventBusySettingsChanged();
    void undoChanged();
    void pendingCountChanged();
    void syncingCountChanged();
    void availableLabelsChanged();
    void availableLocationsChanged();
    void labelTaskCountsChanged();
    void sidebarCountsChanged();
    void debugInfoChanged();
    void error(const QString &message);
    void dbusShowRequested();
    void dbusAddTaskRequested(const QString &summary);
    void dbusOpenViewRequested(const QString &view);
    void dbusSearchRequested(const QString &query);

private:
enum class SyncResult { Error, Ok };

    struct CachedTask {
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

    TaskLogic::QuickAddContext quickAddContext(const QString &uiLanguage, const QVariantList &projects) const;
    QVariantMap quickAddToVariant(const TaskLogic::QuickAdd &parsed) const;
    void setLoading(bool loading);
    void setErrorMessage(const QString &message);
    void updateEmptyKind();
    TaskLogic::UndoRecord snapshotUndo(TaskLogic::UndoRecord::Kind kind, const CachedTask &cache) const;
    void pushUndo(TaskLogic::UndoRecord record);
    void applyTaskUndo(const TaskLogic::UndoRecord &record);
    void recreateTask(const TaskLogic::UndoRecord &record);
    void checkReminders();
    void notifyReminder(qint64 itemId, const QString &summary, const QDateTime &when);
    void refreshBusyEvents();
    void scheduleRefreshBusyEvents();
    bool isInBusyEvent(const QDateTime &when) const;
    QList<Akonadi::Collection> busyEventCollections() const;
    void onBusyEventsFetched(KJob *job, const QDateTime &rangeStart, const QDateTime &rangeEnd);
    void registerSessionInterface();
    void registerGlobalShortcuts();
    void ensureServerWatch();
    bool initializeAkonadi();
    bool attachAkonadiMonitor();
    void scheduleAkonadiRetry();
    void loadCollections();
    void scheduleLoadCollections();
    void loadTasks();
    void scheduleRebuild();
    void rebuildTaskList();
    void onRebuildFinished();
    void setListReorganizing(bool reorganizing);
    TaskLogic::TaskRebuildInput buildRebuildInput(const QList<TaskEntry> &allTasks) const;
    TaskLogic::ListGroupOrderContext buildListGroupOrderContext() const;
    void applyRebuildOutput(const TaskLogic::TaskRebuildOutput &output);
    void applyDeferredRebuildTail();
    void startAsyncRebuild(const TaskLogic::TaskRebuildInput &input);
    void maybeShowReorganizing();
    void loadRebuildPerfProfile();
    void persistRebuildPerfProfile();
    void recordRebuildTiming(qint64 elapsedMs, int taskCount);
    void maybePersistRebuildPerfWeekly();
    void initRebuildPerfDefaults();
    QList<TaskEntry> snapshotAllTasks() const;
    bool wouldCreateParentCycle(qint64 itemId, const QString &parentUid) const;
    /** Validate and apply RELATED-TO; returns false if rejected (error already emitted). */
    bool applyParentUid(CachedTask *cache, const QString &parentUid, qint64 collectionId);
    bool taskMatchesView(const TaskEntry &task) const;
    TaskLogic::FilterState filterState() const;
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
    void finishSync(qint64 itemId, SyncResult ok, const QString &errorString = {}, const Akonadi::Item &ackedItem = {});
    void onStoreFinished(const AbstractTaskStore::Result &result);
    void persistTodo(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId = -1);
    void submitModify(CachedTask &cached, qint64 moveToCollectionId);
    void autoResolveConflict(qint64 itemId);
    QVariantList computeMergeDiff(const KCalendarCore::Todo::Ptr &base,
                                   const KCalendarCore::Todo::Ptr &user,
                                   const KCalendarCore::Todo::Ptr &server) const;
    void submitCreate(const Akonadi::Item &jobItem, const Akonadi::Collection &collection, qint64 tempId);
    Akonadi::Collection collectionById(qint64 collectionId) const;
    Akonadi::Collection firstWritableCollection() const;
    void updatePendingCount(const QList<TaskEntry> &tasks);
    void updateSyncingCount();
    void updateKanbanLayout();
    QVariantMap taskEntryToVariantMap(const TaskEntry &task) const;
    void updateAvailableLabels(const QList<TaskEntry> &tasks);
    void updateAvailableLocations(const QList<TaskEntry> &tasks);
    void updateCounts(const QList<TaskEntry> &tasks);
    void publishSharedCache();
    void scheduleRebuildAll();
    void onItemsFetched(KJob *job, qint64 collectionId);
    void logDebug(const QString &message);
    void updateDebugInfo(int builtTasks, int filteredTasks, int filteredOutCompleted, int filteredOutView, int filteredOutSearch);

    bool m_akonadiAvailable = false;
    bool m_loading = false;
    bool m_listReorganizing = false;
    double m_rebuildMsPerTask = 0.08;
    int m_rebuildBaseMs = 12;
    int m_viewColdLoadMs = 90;
    qint64 m_rebuildPerfUpdatedAt = 0;
    double m_rebuildSampleSumPerTask = 0.0;
    int m_rebuildSampleCount = 0;
    int m_lastRebuildTaskCount = 0;
    QElapsedTimer m_rebuildTiming;
    bool m_rebuildAgainPending = false;
    // Deferred rebuild tail (counts, labels/locations, kanban layout, ...)
    // applied one event-loop iteration after setTasks so the model update
    // renders first and animations stay uninterrupted.
    bool m_deferredTailPending = false;
    QList<TaskEntry> m_deferredCountSource;
    QList<TaskEntry> m_deferredAllTasks;
    int m_deferredFlatCount = 0;
    int m_deferredVisibleCount = 0;
    int m_deferredOutCompleted = 0;
    int m_deferredOutView = 0;
    int m_deferredOutSearch = 0;
    quint64 m_rebuildGeneration = 0;
    quint64 m_pendingRebuildGeneration = 0;
    QFutureWatcher<TaskLogic::TaskRebuildOutput> m_rebuildWatcher;
    QString m_errorMessage;
    QString m_debugInfo;
    QString m_currentView = QStringLiteral("inbox");
    QString m_managementView = QString();
    QString m_searchQuery;
    bool m_showCompleted = false;
    qint64 m_selectedCollectionId = -1;
    QString m_selectedLabel;
    int m_selectedPriority = -1;
    QString m_selectedProgressBand;
    int m_selectedStatus = -1;
    int m_selectedSecrecy = -1;
    QString m_selectedLocation;
    QString m_sortMode = QStringLiteral("priority,due,title");
    QString m_listGroupMode;
    QString m_mainPaneMode = TaskLogic::MainPaneMode::List;
    QString m_kanbanColumnSource = TaskLogic::KanbanSource::Status;
    QString m_kanbanWriteMode = QStringLiteral("fields");
    QString m_kanbanManualOrderJson = QStringLiteral("{}");
    QVariantMap m_kanbanManualOrder;
    QStringList m_kanbanColumnKeys;
    int m_kanbanRevision = 0;
    QString m_swimlaneLaneAxis = QStringLiteral("project");
    QString m_swimlaneTimeBucket = QStringLiteral("day");
    bool m_multiSelectEnabled = false;
    QStringList m_selectedTaskIds;
    QString m_smartViewsJson = QStringLiteral("[]");
    QList<TaskLogic::SmartViewDef> m_smartViews;
    qint64 m_conflictItemId = -1;
    QString m_planPreviewWeek;
    QString m_planPreviewProject;
    bool m_catchUpEnabled = true;
    int m_catchUpDays = 14;
    int m_morningHour = 6;
    int m_afternoonHour = 12;
    int m_eveningHour = 18;
    QString m_defaultDueMode = QStringLiteral("none");
    bool m_searchTitleOnly = false;
    bool m_searchCaseSensitive = false;
    bool m_completeChildren = false;
    bool m_countsExcludeCollapsed = false;
    bool m_notificationsEnabled = true;
    int m_defaultReminderMinutes = -1;
    bool m_quietHoursEnabled = false;
    int m_quietHoursStart = 22;
    int m_quietHoursEnd = 7;
    bool m_suppressRemindersDuringEvents = false;
    QString m_busyCalendarIds;
    QDateTime m_lastReminderScan;
    QHash<qint64, QDateTime> m_lastNotifiedReminder;
    QString m_emptyKind;
    TaskLogic::UndoStack m_undo;
    bool m_applyingUndo = false;
    bool m_batchUndo = false;
    QSet<QString> m_collapsedUids;
    QHash<qint64, TaskLogic::UndoRecord> m_recreateAfterDelete;
    int m_pendingCount = 0;
    int m_syncingCount = 0;
    QStringList m_availableLabels;
    QStringList m_availableLocations;
    QVariantMap m_labelTaskCounts;
    QVariantMap m_viewTaskCounts;
    QVariantMap m_sidebarProjectCounts;
    QVariantMap m_sidebarLabelCounts;
    QVariantMap m_sidebarPriorityCounts;
    QVariantMap m_sidebarProgressCounts;
    QVariantMap m_sidebarStatusCounts;
    QVariantMap m_sidebarSecrecyCounts;
    QVariantMap m_sidebarLocationCounts;

    Akonadi::Monitor *m_monitor = nullptr;
    // Merge conflict state
    qint64 m_pendingMergeItemId = -1;
    QVariantList m_pendingMergeFields;
    KCalendarCore::Todo::Ptr m_pendingMergeFreshTodo;
    bool m_serverWatchConnected = false;
    Akonadi::CollectionFetchJob *m_collectionFetchJob = nullptr;
    bool m_collectionsReloadPending = false;
    int m_pendingFetchJobs = 0;
    // IDs / collections seen during the in-flight loadTasks wave (cache-preserving fetch).
    QSet<Akonadi::Item::Id> m_fetchSeenIds;
    QSet<qint64> m_fetchOkCollections;

    int m_lastFetchItemCount = 0;
    int m_lastFetchAccepted = 0;
    int m_lastFetchRejectedNotTodo = 0;
    int m_lastFetchRejectedNoPayload = 0;
    int m_lastFetchRejectedDisabled = 0;
    int m_lastFetchRejectedNoCollection = 0;

    TaskListModel m_taskModel;
    CollectionListModel m_collectionModel;
    CollectionListModel m_eventCalendarModel;
    QVector<TaskCalendar::BusyInterval> m_busyIntervals;
    QHash<qint64, QString> m_collectionNames;
    QHash<Akonadi::Item::Id, CachedTask> m_tasks;
    AbstractTaskStore *m_store = nullptr;
    QTimer m_rebuildTimer;
    QTimer m_collectionsTimer;
    QTimer m_akonadiRetryTimer;
    QTimer m_reminderTimer;
    QTimer m_busyEventTimer;
    int m_pendingBusyFetchJobs = 0;
    QVector<TaskCalendar::BusyInterval> m_busyFetchIntervals;
    QDate m_agendaSelectedDate = QDate::currentDate();

    static QHash<Akonadi::Item::Id, CachedTask> s_tasks;
    static QList<Akonadi::Collection> s_collections;
    static QList<Akonadi::Collection> s_eventCollections;
    static QHash<qint64, QString> s_collectionNames;
    static QStringList s_extraLabels;
    static QStringList s_extraLocations;
    static QList<TaskController *> s_instances;
    static qint64 s_nextTempId;
    static int s_smokeStep;
    static bool s_smokeFinished;
    static TaskController *s_smokeLeader;
};
