#include "collectionlistmodel.h"

namespace
{
const QLatin1String todoMimeType("application/x-vnd.akonadi.calendar.todo");
}

CollectionListModel::CollectionListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int CollectionListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_collections.size();
}

QVariant CollectionListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_collections.size()) {
        return {};
    }

    const Akonadi::Collection &collection = m_collections.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case NameRole:
        return collection.displayName();
    case CollectionIdRole:
        return collection.id();
    case EnabledRole:
        return m_enabledIds.isEmpty() || m_enabledIds.contains(collection.id());
    case TaskCountRole:
        return m_taskCounts.value(collection.id(), 0);
    case WritableRole:
        return isTaskWritable(collection);
    default:
        return {};
    }
}

QHash<int, QByteArray> CollectionListModel::roleNames() const
{
    return {
        {CollectionIdRole, "collectionId"},
        {NameRole, "name"},
        {EnabledRole, "enabled"},
        {TaskCountRole, "taskCount"},
        {WritableRole, "writable"},
    };
}

void CollectionListModel::setCollections(const QList<Akonadi::Collection> &collections)
{
    beginResetModel();
    m_collections = collections;
    endResetModel();
    Q_EMIT countChanged();
}

void CollectionListModel::setEnabledIds(const QList<qint64> &ids)
{
    m_enabledIds.clear();
    for (qint64 id : ids) {
        m_enabledIds.insert(id);
    }
    if (!m_collections.isEmpty()) {
        Q_EMIT dataChanged(index(0), index(m_collections.size() - 1), {EnabledRole});
    }
}

void CollectionListModel::setTaskCounts(const QHash<qint64, int> &counts)
{
    m_taskCounts = counts;
    if (!m_collections.isEmpty()) {
        Q_EMIT dataChanged(index(0), index(m_collections.size() - 1), {TaskCountRole});
    }
}

QList<qint64> CollectionListModel::enabledIds() const
{
    if (m_enabledIds.isEmpty()) {
        QList<qint64> ids;
        ids.reserve(m_collections.size());
        for (const Akonadi::Collection &collection : m_collections) {
            ids.append(collection.id());
        }
        return ids;
    }
    return m_enabledIds.values();
}

int CollectionListModel::rowForCollectionId(qint64 collectionId) const
{
    for (int row = 0; row < m_collections.size(); ++row) {
        if (m_collections.at(row).id() == collectionId) {
            return row;
        }
    }
    return -1;
}

qint64 CollectionListModel::collectionIdAt(int row) const
{
    if (row < 0 || row >= m_collections.size()) {
        return -1;
    }
    return m_collections.at(row).id();
}

QString CollectionListModel::nameAt(int row) const
{
    if (row < 0 || row >= m_collections.size()) {
        return {};
    }
    return m_collections.at(row).displayName();
}

int CollectionListModel::taskCountAt(int row) const
{
    if (row < 0 || row >= m_collections.size()) {
        return 0;
    }
    return m_taskCounts.value(m_collections.at(row).id(), 0);
}

bool CollectionListModel::enabledAt(int row) const
{
    if (row < 0 || row >= m_collections.size()) {
        return false;
    }
    return m_enabledIds.isEmpty() || m_enabledIds.contains(m_collections.at(row).id());
}

bool CollectionListModel::isTaskCollection(const Akonadi::Collection &collection)
{
    if (!collection.isValid() || collection.isVirtual()) {
        return false;
    }
    return collection.contentMimeTypes().contains(todoMimeType);
}

bool CollectionListModel::isTaskWritable(const Akonadi::Collection &collection)
{
    return isTaskCollection(collection) && collection.rights().testFlag(Akonadi::Collection::CanCreateItem);
}

bool CollectionListModel::writableAt(int row) const
{
    if (row < 0 || row >= m_collections.size()) {
        return false;
    }
    return isTaskWritable(m_collections.at(row));
}

bool CollectionListModel::writableForId(qint64 collectionId) const
{
    return writableAt(rowForCollectionId(collectionId));
}
