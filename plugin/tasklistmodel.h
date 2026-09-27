#pragma once

#include <QAbstractListModel>
#include <QDate>
#include <QDateTime>
#include <QTimer>

struct TaskEntry {
    qint64 itemId = 0;
    QString uid;
    QString parentUid;
    QString summary;
    QString description;
    QDateTime dueDate;
    QDateTime startDate;
    int priority = 0;
    bool completed = false;
    QDateTime completedDate;
    bool recurring = false;
    bool allDay = false;
    int percentComplete = 0;
    QString location;
    int status = 0;
    int secrecy = 0;
    QString recurrencePreset;
    QString joinUrl;
    QStringList categories;
    qint64 collectionId = 0;
    QString collectionName;
    int indentLevel = 0;
    bool hasChildren = false;
    bool treeCollapsed = false;
    bool treeHidden = false;
    int reminderMinutes = -1;
    QString section;
    QString bucket;
    QString column;
    QStringList attendees;
    int kanbanSortOrder = 0;
    QString geoUrl;
    bool syncing = false;
    bool pendingDelete = false;
};

class TaskListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        ItemIdRole = Qt::UserRole + 1,
        UidRole,
        ParentUidRole,
        SummaryRole,
        DescriptionRole,
        DueDateRole,
        StartDateRole,
        PriorityRole,
        CompletedRole,
        CompletedDateRole,
        RecurringRole,
        AllDayRole,
        PercentCompleteRole,
        LocationRole,
        StatusRole,
        SecrecyRole,
        RecurrencePresetRole,
        JoinUrlRole,
        CategoriesRole,
        CollectionIdRole,
        CollectionNameRole,
        IndentLevelRole,
        HasChildrenRole,
        TreeCollapsedRole,
        TreeHiddenRole,
        ReminderMinutesRole,
        SectionRole,
        BucketRole,
        ColumnRole,
        AttendeesRole,
        KanbanSortOrderRole,
        GeoUrlRole,
        SyncingRole,
        PendingDeleteRole,
    };
    Q_ENUM(Roles)

    explicit TaskListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setTasks(const QList<TaskEntry> &tasks, bool forceReset = false);
    TaskEntry taskAt(int row) const;
    Q_INVOKABLE QString uidAt(int row) const;
    Q_INVOKABLE int rowForUid(const QString &uid) const;
    Q_INVOKABLE int rowForItemId(qint64 itemId) const;
    int count() const { return m_tasks.size(); }

    /// True while chunked row operations are being applied across event-loop
    /// iterations.  The controller should defer non-critical updates until
    /// this returns false.
    Q_PROPERTY(bool chunksActive READ chunksActive NOTIFY chunksActiveChanged)
    Q_INVOKABLE bool chunksActive() const { return m_chunkPhase != ChunkPhase::None; }

signals:
    void countChanged();
    void chunksActiveChanged();

private:
    enum class ChunkPhase { None, Removing, Inserting, Data };

    void applyGranularSync(const QList<TaskEntry> &tasks, int prefix,
                           int oldRemoveStart, int oldRemoveEnd,
                           int newInsertStart, int newInsertEnd,
                           const QVector<QPair<int, QPair<int, QVector<int>>>> &pendingData);
    void chunkStep();
    void processQueuedSetTasks();
    void setChunkPhase(ChunkPhase phase);

    QList<TaskEntry> m_tasks;

    // Chunking state ---------------------------------------------------
    ChunkPhase m_chunkPhase = ChunkPhase::None;
    quint64 m_chunkGeneration = 0;
    QList<TaskEntry> m_chunkTarget;
    int m_rmPos = 0;
    int m_rmEnd = -1;
    int m_inPos = 0;
    int m_inEnd = -1;
    int m_dataIdx = 0;
    QVector<QPair<int, QPair<int, QVector<int>>>> m_pendingDataChanges;
    QTimer m_chunkTimer;

    // Queued setTasks: if setTasks() is called while chunking is active,
    // the new target is stored here and applied once the running chunk
    // finishes.  This eliminates re-entrant cancellation (the root cause
    // of the previous SIGSEGV).
    bool m_queuedPending = false;
    QList<TaskEntry> m_queuedTarget;
    // -------------------------------------------------------------------

    static bool taskDataDiffers(const TaskEntry &a, const TaskEntry &b);
    static QVector<int> dataDiffRoles(const TaskEntry &a, const TaskEntry &b);
};
