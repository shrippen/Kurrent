#include "tasklistmodel.h"

#include <QElapsedTimer>

namespace {
constexpr int kSyncRowThreshold = 48;
constexpr int kChunkRowsPerCall = 64;
constexpr int kChunkBudgetMs = 6;
}

TaskListModel::TaskListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_chunkTimer.setSingleShot(true);
    m_chunkTimer.setInterval(0);
    connect(&m_chunkTimer, &QTimer::timeout, this, &TaskListModel::chunkStep);
}

void TaskListModel::setChunkPhase(ChunkPhase phase)
{
    if (phase == m_chunkPhase) {
        return;
    }
    const bool wasActive = (m_chunkPhase != ChunkPhase::None);
    m_chunkPhase = phase;
    const bool isActive = (phase != ChunkPhase::None);
    if (wasActive != isActive) {
        Q_EMIT chunksActiveChanged();
    }
}

int TaskListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_tasks.size();
}

QVariant TaskListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tasks.size()) {
        return {};
    }

    const TaskEntry &task = m_tasks.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case SummaryRole:
        return task.summary;
    case ItemIdRole:
        return task.itemId;
    case UidRole:
        return task.uid;
    case ParentUidRole:
        return task.parentUid;
    case DescriptionRole:
        return task.description;
    case DueDateRole:
        return task.dueDate.isValid() ? task.dueDate : QVariant();
    case StartDateRole:
        return task.startDate.isValid() ? task.startDate : QVariant();
    case PriorityRole:
        return task.priority;
    case CompletedRole:
        return task.completed;
    case CompletedDateRole:
        return task.completedDate.isValid() ? task.completedDate : QVariant();
    case RecurringRole:
        return task.recurring;
    case AllDayRole:
        return task.allDay;
    case PercentCompleteRole:
        return task.percentComplete;
    case LocationRole:
        return task.location;
    case StatusRole:
        return task.status;
    case SecrecyRole:
        return task.secrecy;
    case RecurrencePresetRole:
        return task.recurrencePreset;
    case JoinUrlRole:
        return task.joinUrl;
    case CategoriesRole:
        return task.categories;
    case CollectionIdRole:
        return task.collectionId;
    case CollectionNameRole:
        return task.collectionName;
    case IndentLevelRole:
        return task.indentLevel;
    case HasChildrenRole:
        return task.hasChildren;
    case TreeCollapsedRole:
        return task.treeCollapsed;
    case TreeHiddenRole:
        return task.treeHidden;
    case ReminderMinutesRole:
        return task.reminderMinutes;
    case SectionRole:
        return task.section;
    case BucketRole:
        return task.bucket;
    case ColumnRole:
        return task.column;
    case AttendeesRole:
        return task.attendees;
    case KanbanSortOrderRole:
        return task.kanbanSortOrder;
    case GeoUrlRole:
        return task.geoUrl;
    case SyncingRole:
        return task.syncing;
    case PendingDeleteRole:
        return task.pendingDelete;
    default:
        return {};
    }
}

QHash<int, QByteArray> TaskListModel::roleNames() const
{
    return {
        {ItemIdRole, "itemId"},
        {UidRole, "uid"},
        {ParentUidRole, "parentUid"},
        {SummaryRole, "summary"},
        {DescriptionRole, "description"},
        {DueDateRole, "dueDate"},
        {StartDateRole, "startDate"},
        {PriorityRole, "priority"},
        {CompletedRole, "completed"},
        {CompletedDateRole, "completedDate"},
        {RecurringRole, "recurring"},
        {AllDayRole, "allDay"},
        {PercentCompleteRole, "percentComplete"},
        {LocationRole, "location"},
        {StatusRole, "status"},
        {SecrecyRole, "secrecy"},
        {RecurrencePresetRole, "recurrencePreset"},
        {JoinUrlRole, "joinUrl"},
        {CategoriesRole, "categories"},
        {CollectionIdRole, "collectionId"},
        {CollectionNameRole, "collectionName"},
        {IndentLevelRole, "indentLevel"},
        {HasChildrenRole, "hasChildren"},
        {TreeCollapsedRole, "treeCollapsed"},
        {TreeHiddenRole, "treeHidden"},
        {ReminderMinutesRole, "reminderMinutes"},
        {SectionRole, "section"},
        {BucketRole, "bucket"},
        {ColumnRole, "column"},
        {AttendeesRole, "attendees"},
        {KanbanSortOrderRole, "kanbanSortOrder"},
        {GeoUrlRole, "geoUrl"},
        {SyncingRole, "syncing"},
        {PendingDeleteRole, "pendingDelete"},
    };
}

void TaskListModel::setTasks(const QList<TaskEntry> &tasks, bool /*forceReset*/)
{
    // If chunking is still active, queue the new target instead of cancelling
    // mid-flight.  This completely eliminates the re-entrant cancellation that
    // caused the previous SIGSEGV (destruction of m_chunkTarget during an
    // active endRemoveRows/endInsertRows call chain).
    if (m_chunkPhase != ChunkPhase::None) {
        m_queuedTarget = tasks;
        m_queuedPending = true;
        return;
    }

    // Fast path: first population or empty model
    if (m_tasks.isEmpty()) {
        if (!tasks.isEmpty()) {
            beginInsertRows(QModelIndex(), 0, tasks.size() - 1);
            m_tasks = tasks;
            endInsertRows();
            Q_EMIT countChanged();
        }
        return;
    }
    if (tasks.isEmpty()) {
        beginRemoveRows(QModelIndex(), 0, m_tasks.size() - 1);
        m_tasks.clear();
        endRemoveRows();
        Q_EMIT countChanged();
        return;
    }

    // Find longest common prefix (by uid)
    int prefix = 0;
    const int minLen = qMin(m_tasks.size(), tasks.size());
    while (prefix < minLen && m_tasks[prefix].uid == tasks[prefix].uid) {
        prefix++;
    }

    // Find longest common suffix (by uid), not overlapping prefix
    int oldSuf = m_tasks.size() - 1;
    int newSuf = tasks.size() - 1;
    while (oldSuf >= prefix && newSuf >= prefix && m_tasks[oldSuf].uid == tasks[newSuf].uid) {
        oldSuf--;
        newSuf--;
    }

    const int oldRemoveStart = prefix;
    const int oldRemoveEnd = oldSuf;
    const int newInsertStart = prefix;
    const int newInsertEnd = newSuf;
    const int insertCount = (newInsertEnd >= newInsertStart) ? (newInsertEnd - newInsertStart + 1) : 0;

    // Capture data changes BEFORE we mutate m_tasks.
    QVector<QPair<int, QPair<int, QVector<int>>>> pendingData;
    for (int i = 0; i < prefix; ++i) {
        QVector<int> roles = dataDiffRoles(m_tasks[i], tasks[i]);
        if (!roles.isEmpty()) {
            pendingData.append(qMakePair(i, qMakePair(i, roles)));
        }
    }

    // For suffix, record {destIndex, {targetIndex, roles}}. destIndex is where
    // the item lands after the insert phase.
    const int suffixCount = tasks.size() - (newInsertEnd + 1);
    for (int sIdx = 0; sIdx < suffixCount; ++sIdx) {
        const int newIdx = newInsertEnd + 1 + sIdx;
        const int oldIdx = oldRemoveEnd + 1 + sIdx;
        if (oldIdx >= 0 && oldIdx < m_tasks.size()) {
            QVector<int> roles = dataDiffRoles(m_tasks[oldIdx], tasks[newIdx]);
            if (!roles.isEmpty()) {
                const int destIndex = prefix + insertCount + (oldIdx - (oldRemoveEnd + 1));
                pendingData.append(qMakePair(destIndex, qMakePair(newIdx, roles)));
            }
        }
    }

    const int removeCount = qMax(0, oldRemoveEnd - oldRemoveStart + 1);
    const int changedRows = removeCount + qMax(0, insertCount)
            + pendingData.size();

    // Small changes apply synchronously — keeps unit tests deterministic.
    if (changedRows <= kSyncRowThreshold) {
        applyGranularSync(tasks, prefix, oldRemoveStart, oldRemoveEnd,
                          newInsertStart, newInsertEnd, pendingData);
        Q_EMIT countChanged();
        return;
    }

    // Large change: chunked apply across event-loop iterations so the
    // animation driver keeps producing frames while the list updates.
    ++m_chunkGeneration;
    m_chunkTarget = tasks;
    m_rmPos = oldRemoveStart;
    m_rmEnd = oldRemoveEnd;
    m_inPos = newInsertStart;
    m_inEnd = newInsertEnd;
    m_pendingDataChanges = pendingData;
    m_dataIdx = 0;
    setChunkPhase((m_rmEnd >= m_rmPos) ? ChunkPhase::Removing
                 : (m_inEnd >= m_inPos) ? ChunkPhase::Inserting
                 : ChunkPhase::Data);
    m_chunkTimer.start();
}

void TaskListModel::processQueuedSetTasks()
{
    if (!m_queuedPending) {
        return;
    }
    m_queuedPending = false;
    QList<TaskEntry> queued = m_queuedTarget;
    m_queuedTarget.clear();
    setTasks(queued);
}

void TaskListModel::applyGranularSync(
        const QList<TaskEntry> &tasks, int prefix,
        int oldRemoveStart, int oldRemoveEnd,
        int newInsertStart, int newInsertEnd,
        const QVector<QPair<int, QPair<int, QVector<int>>>> &pendingData)
{
    const int insertCount = (newInsertEnd >= newInsertStart) ? (newInsertEnd - newInsertStart + 1) : 0;

    // Step 1: Remove old differing region
    if (oldRemoveEnd >= oldRemoveStart) {
        beginRemoveRows(QModelIndex(), oldRemoveStart, oldRemoveEnd);
        QList<TaskEntry> tmp;
        tmp.reserve(m_tasks.size() - (oldRemoveEnd - oldRemoveStart + 1));
        for (int i = 0; i < oldRemoveStart; ++i) {
            tmp.append(m_tasks[i]);
        }
        for (int i = oldRemoveEnd + 1; i < m_tasks.size(); ++i) {
            tmp.append(m_tasks[i]);
        }
        m_tasks = tmp;
        endRemoveRows();
    }

    // Step 2: Insert new differing region
    if (newInsertEnd >= newInsertStart) {
        beginInsertRows(QModelIndex(), newInsertStart, newInsertStart + insertCount - 1);
        QList<TaskEntry> tmp;
        tmp.reserve(m_tasks.size() + insertCount);
        for (int i = 0; i < newInsertStart; ++i) {
            tmp.append(m_tasks[i]);
        }
        for (int i = newInsertStart; i <= newInsertEnd; ++i) {
            tmp.append(tasks[i]);
        }
        for (int i = newInsertStart; i < m_tasks.size(); ++i) {
            tmp.append(m_tasks[i]);
        }
        m_tasks = tmp;
        endInsertRows();
    }

    // Step 3 + 4: prefix and suffix data changes
    for (const auto &change : pendingData) {
        const int destIdx = change.first;
        const int srcIdx = change.second.first;
        if (destIdx >= 0 && destIdx < m_tasks.size() && srcIdx >= 0 && srcIdx < tasks.size()) {
            m_tasks[destIdx] = tasks[srcIdx];
            emit dataChanged(index(destIdx), index(destIdx), change.second.second);
        }
    }
}

void TaskListModel::chunkStep()
{
    if (m_chunkPhase == ChunkPhase::None) {
        return;
    }

    QElapsedTimer budget;
    budget.start();
    bool finished = false;

    while (budget.elapsed() < kChunkBudgetMs) {
        switch (m_chunkPhase) {
        case ChunkPhase::None:
            return;
        case ChunkPhase::Removing: {
            const int end = m_rmEnd;
            const int start = qMax(m_rmPos, end - kChunkRowsPerCall + 1);
            beginRemoveRows(QModelIndex(), start, end);
            m_tasks.erase(m_tasks.begin() + start, m_tasks.begin() + end + 1);
            endRemoveRows();
            m_rmEnd = start - 1;
            if (m_rmEnd < m_rmPos) {
                setChunkPhase((m_inEnd >= m_inPos) ? ChunkPhase::Inserting : ChunkPhase::Data);
            }
            break;
        }
        case ChunkPhase::Inserting: {
            const int start = m_inPos;
            const int cnt = qMin(kChunkRowsPerCall, m_inEnd - start + 1);
            beginInsertRows(QModelIndex(), start, start + cnt - 1);
            for (int i = 0; i < cnt; ++i) {
                m_tasks.insert(start + i, m_chunkTarget.at(start + i));
            }
            endInsertRows();
            m_inPos = start + cnt;
            if (m_inPos > m_inEnd) {
                setChunkPhase(ChunkPhase::Data);
            }
            break;
        }
        case ChunkPhase::Data: {
            if (m_dataIdx >= m_pendingDataChanges.size()) {
                setChunkPhase(ChunkPhase::None);
                finished = true;
                break;
            }
            const auto &change = m_pendingDataChanges.at(m_dataIdx);
            const int destIdx = change.first;
            const int srcIdx = change.second.first;
            if (destIdx >= 0 && destIdx < m_tasks.size()
                    && srcIdx >= 0 && srcIdx < m_chunkTarget.size()) {
                m_tasks[destIdx] = m_chunkTarget.at(srcIdx);
                emit dataChanged(index(destIdx), index(destIdx), change.second.second);
            }
            ++m_dataIdx;
            break;
        }
        }

        if (finished) {
            break;
        }
    }

    if (finished) {
        Q_EMIT countChanged();
        // Process any setTasks() that arrived while we were chunking.
        processQueuedSetTasks();
        return;
    }
    // Budget exhausted — schedule next tick.
    m_chunkTimer.start();
}

bool TaskListModel::taskDataDiffers(const TaskEntry &a, const TaskEntry &b)
{
    return a.itemId != b.itemId
        || a.uid != b.uid
        || a.parentUid != b.parentUid
        || a.summary != b.summary
        || a.description != b.description
        || a.dueDate != b.dueDate
        || a.startDate != b.startDate
        || a.priority != b.priority
        || a.completed != b.completed
        || a.recurring != b.recurring
        || a.allDay != b.allDay
        || a.percentComplete != b.percentComplete
        || a.location != b.location
        || a.status != b.status
        || a.secrecy != b.secrecy
        || a.recurrencePreset != b.recurrencePreset
        || a.joinUrl != b.joinUrl
        || a.categories != b.categories
        || a.collectionId != b.collectionId
        || a.collectionName != b.collectionName
        || a.indentLevel != b.indentLevel
        || a.hasChildren != b.hasChildren
        || a.treeCollapsed != b.treeCollapsed
        || a.treeHidden != b.treeHidden
        || a.reminderMinutes != b.reminderMinutes
        || a.section != b.section
        || a.bucket != b.bucket
        || a.column != b.column
        || a.attendees != b.attendees
        || a.kanbanSortOrder != b.kanbanSortOrder
        || a.geoUrl != b.geoUrl
        || a.syncing != b.syncing
        || a.pendingDelete != b.pendingDelete;
}

QVector<int> TaskListModel::dataDiffRoles(const TaskEntry &a, const TaskEntry &b)
{
    QVector<int> roles;

    auto add = [&](bool changed, int role) {
        if (changed) {
            roles.append(role);
        }
    };

    add(a.itemId != b.itemId, ItemIdRole);
    add(a.uid != b.uid, UidRole);
    add(a.parentUid != b.parentUid, ParentUidRole);
    add(a.summary != b.summary, SummaryRole);
    add(a.description != b.description, DescriptionRole);
    add(a.dueDate != b.dueDate, DueDateRole);
    add(a.startDate != b.startDate, StartDateRole);
    add(a.priority != b.priority, PriorityRole);
    add(a.completed != b.completed, CompletedRole);
    add(a.completedDate != b.completedDate, CompletedDateRole);
    add(a.recurring != b.recurring, RecurringRole);
    add(a.allDay != b.allDay, AllDayRole);
    add(a.percentComplete != b.percentComplete, PercentCompleteRole);
    add(a.location != b.location, LocationRole);
    add(a.status != b.status, StatusRole);
    add(a.secrecy != b.secrecy, SecrecyRole);
    add(a.recurrencePreset != b.recurrencePreset, RecurrencePresetRole);
    add(a.joinUrl != b.joinUrl, JoinUrlRole);
    add(a.categories != b.categories, CategoriesRole);
    add(a.collectionId != b.collectionId, CollectionIdRole);
    add(a.collectionName != b.collectionName, CollectionNameRole);
    add(a.indentLevel != b.indentLevel, IndentLevelRole);
    add(a.hasChildren != b.hasChildren, HasChildrenRole);
    add(a.treeCollapsed != b.treeCollapsed, TreeCollapsedRole);
    add(a.treeHidden != b.treeHidden, TreeHiddenRole);
    add(a.reminderMinutes != b.reminderMinutes, ReminderMinutesRole);
    add(a.section != b.section, SectionRole);
    add(a.bucket != b.bucket, BucketRole);
    add(a.column != b.column, ColumnRole);
    add(a.attendees != b.attendees, AttendeesRole);
    add(a.kanbanSortOrder != b.kanbanSortOrder, KanbanSortOrderRole);
    add(a.geoUrl != b.geoUrl, GeoUrlRole);
    add(a.syncing != b.syncing, SyncingRole);
    add(a.pendingDelete != b.pendingDelete, PendingDeleteRole);

    return roles;
}

TaskEntry TaskListModel::taskAt(int row) const
{
    if (row < 0 || row >= m_tasks.size()) {
        return {};
    }
    return m_tasks.at(row);
}

QString TaskListModel::uidAt(int row) const
{
    if (row < 0 || row >= m_tasks.size()) {
        return {};
    }
    return m_tasks.at(row).uid;
}

int TaskListModel::rowForUid(const QString &uid) const
{
    if (uid.isEmpty()) {
        return -1;
    }
    for (int row = 0; row < m_tasks.size(); ++row) {
        if (m_tasks.at(row).uid == uid) {
            return row;
        }
    }
    return -1;
}

int TaskListModel::rowForItemId(qint64 itemId) const
{
    if (itemId == 0) {
        return -1;
    }
    for (int row = 0; row < m_tasks.size(); ++row) {
        if (m_tasks.at(row).itemId == itemId) {
            return row;
        }
    }
    return -1;
}
