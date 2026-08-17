#pragma once

#include <Akonadi/Collection>
#include <QAbstractListModel>
#include <QSet>

class CollectionListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        CollectionIdRole = Qt::UserRole + 1,
        NameRole,
        EnabledRole,
        TaskCountRole,
        WritableRole,
    };
    Q_ENUM(Roles)

    explicit CollectionListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setCollections(const QList<Akonadi::Collection> &collections);
    void setEnabledIds(const QList<qint64> &ids);
    void setTaskCounts(const QHash<qint64, int> &counts);
    QList<qint64> enabledIds() const;
    bool hasCustomEnabledFilter() const { return !m_enabledIds.isEmpty(); }

    static bool isTaskCollection(const Akonadi::Collection &collection);
    static bool isTaskWritable(const Akonadi::Collection &collection);

    Q_INVOKABLE int rowForCollectionId(qint64 collectionId) const;
    Q_INVOKABLE qint64 collectionIdAt(int row) const;
    Q_INVOKABLE QString nameAt(int row) const;
    Q_INVOKABLE int taskCountAt(int row) const;
    Q_INVOKABLE bool enabledAt(int row) const;
    Q_INVOKABLE bool writableAt(int row) const;
    Q_INVOKABLE bool writableForId(qint64 collectionId) const;

    int count() const { return m_collections.size(); }

signals:
    void countChanged();

private:
    QList<Akonadi::Collection> m_collections;
    QSet<qint64> m_enabledIds;
    QHash<qint64, int> m_taskCounts;
};
