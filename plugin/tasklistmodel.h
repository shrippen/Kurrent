#pragma once

#include <QAbstractListModel>
#include <QDate>
#include <QDateTime>

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
    QString section;
    QString bucket;
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
        SectionRole,
        BucketRole,
        SyncingRole,
        PendingDeleteRole,
    };
    Q_ENUM(Roles)

    explicit TaskListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setTasks(const QList<TaskEntry> &tasks);
    TaskEntry taskAt(int row) const;
    int count() const { return m_tasks.size(); }

signals:
    void countChanged();

private:
    QList<TaskEntry> m_tasks;
};
