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
    case SectionRole:
        return task.section;
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
        {CategoriesRole, "categories"},
        {CollectionIdRole, "collectionId"},
        {CollectionNameRole, "collectionName"},
        {IndentLevelRole, "indentLevel"},
        {HasChildrenRole, "hasChildren"},
        {SectionRole, "section"},
        {SyncingRole, "syncing"},
        {PendingDeleteRole, "pendingDelete"},
    };
}

void TaskListModel::setTasks(const QList<TaskEntry> &tasks)
{
    beginResetModel();
    m_tasks = tasks;
    endResetModel();
    Q_EMIT countChanged();
}

TaskEntry TaskListModel::taskAt(int row) const
{
    if (row < 0 || row >= m_tasks.size()) {
        return {};
    }
    return m_tasks.at(row);
}
