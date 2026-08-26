#include "tasklistmodel.h"

TaskListModel::TaskListModel(QObject *parent)
    : QAbstractListModel(parent)
{
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
        {SyncingRole, "syncing"},
        {PendingDeleteRole, "pendingDelete"},
    };
}

void TaskListModel::setTasks(const QList<TaskEntry> &tasks)
{
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

    // Complete model change (e.g., view switch): use reset so ListView transitions
    // don't overlap and create duplicate-looking delegates.
    // When neither the first nor the last item matches, all items have changed.
    if (prefix == 0 && oldSuf == m_tasks.size() - 1 && newSuf == tasks.size() - 1) {
        beginResetModel();
        m_tasks = tasks;
        endResetModel();
        Q_EMIT countChanged();
        return;
    }

    const int oldRemoveStart = prefix;
    const int oldRemoveEnd = oldSuf;
    const int newInsertStart = prefix;
    const int newInsertEnd = newSuf;
    const int insertCount = (newInsertEnd >= newInsertStart) ? (newInsertEnd - newInsertStart + 1) : 0;

    // Capture data changes BEFORE we mutate m_tasks.
    QVector<QPair<int, QVector<int>>> prefixChanges;
    for (int i = 0; i < prefix; ++i) {
        QVector<int> roles = dataDiffRoles(m_tasks[i], tasks[i]);
        if (!roles.isEmpty()) {
            prefixChanges.append(qMakePair(i, roles));
        }
    }

    // For suffix, record {destIndex, roles}. destIndex is where the item lands after insert.
    QVector<QPair<int, QVector<int>>> suffixChanges;
    const int suffixCount = tasks.size() - (newInsertEnd + 1);
    for (int s = 0; s < suffixCount; ++s) {
        const int newIdx = newInsertEnd + 1 + s;
        const int oldIdx = oldRemoveEnd + 1 + s;
        if (oldIdx >= 0 && oldIdx < m_tasks.size()) {
            QVector<int> roles = dataDiffRoles(m_tasks[oldIdx], tasks[newIdx]);
            if (!roles.isEmpty()) {
                const int destIndex = prefix + insertCount + (oldIdx - (oldRemoveEnd + 1));
                suffixChanges.append(qMakePair(destIndex, roles));
            }
        }
    }

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

    // Step 3: Apply saved prefix changes
    for (const auto &change : prefixChanges) {
        const int idx = change.first;
        m_tasks[idx] = tasks[idx];
        emit dataChanged(index(idx), index(idx), change.second);
    }

    // Step 4: Apply saved suffix changes
    for (const auto &change : suffixChanges) {
        const int destIdx = change.first;
        if (destIdx >= 0 && destIdx < m_tasks.size()) {
            // Map destIdx back to tasks index to get the new data
            const int tasksIdx = newInsertEnd + 1 + (destIdx - (prefix + insertCount));
            if (tasksIdx >= 0 && tasksIdx < tasks.size()) {
                m_tasks[destIdx] = tasks[tasksIdx];
                emit dataChanged(index(destIdx), index(destIdx), change.second);
            }
        }
    }

    Q_EMIT countChanged();
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
