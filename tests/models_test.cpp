#include "collectionlistmodel.h"
#include "tasklistmodel.h"

#include <Akonadi/Collection>

#include <QDate>
#include <QDateTime>
#include <QSignalSpy>
#include <QTime>
#include <QtTest>

class ModelsTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void taskListExposesRolesAndCount();
    void taskListExposesAllRoles();
    void taskListIgnoresInvalidIndexes();
    void taskListResetSignal();
    void collectionEnabledAtWithoutFilter();
    void collectionEnabledAtWithCustomFilter();
    void collectionLookupHelpers();
    void collectionDataRolesAndSignals();
    void collectionWritableHelpers();
};

void ModelsTest::taskListExposesRolesAndCount()
{
    TaskListModel model;
    QCOMPARE(model.count(), 0);

    TaskEntry task;
    task.itemId = 9;
    task.summary = QStringLiteral("Write tests");
    task.collectionId = 4;
    task.collectionName = QStringLiteral("Inbox");
    task.categories = QStringList{QStringLiteral("dev")};
    model.setTasks({task});

    QCOMPARE(model.count(), 1);
    QCOMPARE(model.taskAt(0).summary, QStringLiteral("Write tests"));
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::SummaryRole).toString(), QStringLiteral("Write tests"));
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::CollectionIdRole).toLongLong(), qint64(4));
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::CategoriesRole).toStringList(), QStringList{QStringLiteral("dev")});
    QVERIFY(!model.taskAt(5).itemId);
}

void ModelsTest::taskListExposesAllRoles()
{
    TaskListModel model;
    TaskEntry task;
    task.itemId = 42;
    task.uid = QStringLiteral("uid-1");
    task.parentUid = QStringLiteral("parent");
    task.summary = QStringLiteral("Summary");
    task.description = QStringLiteral("Desc");
    task.dueDate = QDateTime(QDate(2026, 8, 13), QTime(9, 0));
    task.startDate = QDateTime(QDate(2026, 8, 12), QTime(8, 0));
    task.priority = 5;
    task.completed = true;
    task.recurring = true;
    task.allDay = true;
    task.percentComplete = 80;
    task.location = QStringLiteral("Office");
    task.status = 4;
    task.secrecy = 1;
    task.recurrencePreset = QStringLiteral("weekly");
    task.categories = QStringList{QStringLiteral("home")};
    task.collectionId = 7;
    task.collectionName = QStringLiteral("Work");
    task.indentLevel = 2;
    task.hasChildren = true;
    task.section = QStringLiteral("Later");
    task.syncing = true;
    task.pendingDelete = true;
    model.setTasks({task});

    const QModelIndex idx = model.index(0, 0);
    QCOMPARE(model.data(idx, Qt::DisplayRole).toString(), QStringLiteral("Summary"));
    QCOMPARE(model.data(idx, TaskListModel::ItemIdRole).toLongLong(), qint64(42));
    QCOMPARE(model.data(idx, TaskListModel::UidRole).toString(), QStringLiteral("uid-1"));
    QCOMPARE(model.data(idx, TaskListModel::ParentUidRole).toString(), QStringLiteral("parent"));
    QCOMPARE(model.data(idx, TaskListModel::DescriptionRole).toString(), QStringLiteral("Desc"));
    QCOMPARE(model.data(idx, TaskListModel::DueDateRole).toDateTime().date(), QDate(2026, 8, 13));
    QCOMPARE(model.data(idx, TaskListModel::StartDateRole).toDateTime().date(), QDate(2026, 8, 12));
    QCOMPARE(model.data(idx, TaskListModel::PriorityRole).toInt(), 5);
    QCOMPARE(model.data(idx, TaskListModel::CompletedRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::RecurringRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::AllDayRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::PercentCompleteRole).toInt(), 80);
    QCOMPARE(model.data(idx, TaskListModel::LocationRole).toString(), QStringLiteral("Office"));
    QCOMPARE(model.data(idx, TaskListModel::StatusRole).toInt(), 4);
    QCOMPARE(model.data(idx, TaskListModel::SecrecyRole).toInt(), 1);
    QCOMPARE(model.data(idx, TaskListModel::RecurrencePresetRole).toString(), QStringLiteral("weekly"));
    QCOMPARE(model.data(idx, TaskListModel::CollectionNameRole).toString(), QStringLiteral("Work"));
    QCOMPARE(model.data(idx, TaskListModel::IndentLevelRole).toInt(), 2);
    QCOMPARE(model.data(idx, TaskListModel::HasChildrenRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::SectionRole).toString(), QStringLiteral("Later"));
    QCOMPARE(model.data(idx, TaskListModel::SyncingRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::PendingDeleteRole).toBool(), true);

    QVERIFY(model.roleNames().contains(TaskListModel::SummaryRole));
    QCOMPARE(model.roleNames().value(TaskListModel::SummaryRole), QByteArray("summary"));
    QCOMPARE(model.roleNames().value(TaskListModel::SyncingRole), QByteArray("syncing"));
    QCOMPARE(model.roleNames().value(TaskListModel::PendingDeleteRole), QByteArray("pendingDelete"));
}

void ModelsTest::taskListIgnoresInvalidIndexes()
{
    TaskListModel model;
    TaskEntry task;
    task.summary = QStringLiteral("Only");
    model.setTasks({task});

    QVERIFY(!model.index(0, 0).parent().isValid());
    QCOMPARE(model.rowCount(model.index(0, 0)), 0);
    QVERIFY(!model.data(QModelIndex(), TaskListModel::SummaryRole).isValid());
    QVERIFY(!model.data(model.index(3, 0), TaskListModel::SummaryRole).isValid());
    QVERIFY(!model.data(model.index(0, 0), Qt::UserRole + 99).isValid());

    TaskEntry emptyDue;
    emptyDue.summary = QStringLiteral("No due");
    model.setTasks({emptyDue});
    QVERIFY(!model.data(model.index(0, 0), TaskListModel::DueDateRole).isValid());
}

void ModelsTest::taskListResetSignal()
{
    TaskListModel model;
    QSignalSpy spy(&model, &TaskListModel::countChanged);
    model.setTasks({TaskEntry()});
    QCOMPARE(spy.count(), 1);
    QCOMPARE(model.count(), 1);
    model.setTasks({});
    QCOMPARE(spy.count(), 2);
    QCOMPARE(model.count(), 0);
}

void ModelsTest::collectionEnabledAtWithoutFilter()
{
    CollectionListModel model;
    Akonadi::Collection inbox(11);
    inbox.setName(QStringLiteral("Inbox"));
    Akonadi::Collection work(22);
    work.setName(QStringLiteral("Work"));
    model.setCollections({inbox, work});

    QVERIFY(model.enabledAt(0));
    QVERIFY(model.enabledAt(1));
    QVERIFY(!model.enabledAt(-1));
    QVERIFY(!model.enabledAt(9));
    QCOMPARE(model.enabledIds().size(), 2);
}

void ModelsTest::collectionEnabledAtWithCustomFilter()
{
    CollectionListModel model;
    Akonadi::Collection inbox(11);
    inbox.setName(QStringLiteral("Inbox"));
    Akonadi::Collection work(22);
    work.setName(QStringLiteral("Work"));
    model.setCollections({inbox, work});
    model.setEnabledIds({22});

    QVERIFY(!model.enabledAt(0));
    QVERIFY(model.enabledAt(1));
    QCOMPARE(model.enabledIds(), QList<qint64>{22});
}

void ModelsTest::collectionLookupHelpers()
{
    CollectionListModel model;
    Akonadi::Collection inbox(11);
    inbox.setName(QStringLiteral("Inbox"));
    Akonadi::Collection work(22);
    work.setName(QStringLiteral("Work"));
    model.setCollections({inbox, work});
    model.setTaskCounts({{11, 4}, {22, 0}});

    QCOMPARE(model.rowForCollectionId(22), 1);
    QCOMPARE(model.rowForCollectionId(99), -1);
    QCOMPARE(model.collectionIdAt(0), qint64(11));
    QCOMPARE(model.nameAt(1), QStringLiteral("Work"));
    QCOMPARE(model.taskCountAt(0), 4);
    QCOMPARE(model.taskCountAt(1), 0);
}

void ModelsTest::collectionDataRolesAndSignals()
{
    CollectionListModel model;
    QSignalSpy countSpy(&model, &CollectionListModel::countChanged);

    Akonadi::Collection inbox(11);
    inbox.setName(QStringLiteral("Inbox"));
    Akonadi::Collection work(22);
    work.setName(QStringLiteral("Work"));
    model.setCollections({inbox, work});
    QCOMPARE(countSpy.count(), 1);
    QCOMPARE(model.count(), 2);
    QCOMPARE(model.rowCount(), 2);
    QCOMPARE(model.rowCount(model.index(0, 0)), 0);
    QVERIFY(!model.hasCustomEnabledFilter());

    const QModelIndex idx = model.index(0, 0);
    QCOMPARE(model.data(idx, Qt::DisplayRole).toString(), QStringLiteral("Inbox"));
    QCOMPARE(model.data(idx, CollectionListModel::NameRole).toString(), QStringLiteral("Inbox"));
    QCOMPARE(model.data(idx, CollectionListModel::CollectionIdRole).toLongLong(), qint64(11));
    QCOMPARE(model.data(idx, CollectionListModel::EnabledRole).toBool(), true);
    QCOMPARE(model.data(idx, CollectionListModel::TaskCountRole).toInt(), 0);
    QVERIFY(!model.data(QModelIndex(), CollectionListModel::NameRole).isValid());
    QVERIFY(!model.data(idx, Qt::UserRole + 99).isValid());

    model.setEnabledIds({11});
    QVERIFY(model.hasCustomEnabledFilter());
    QCOMPARE(model.data(idx, CollectionListModel::EnabledRole).toBool(), true);
    QCOMPARE(model.data(model.index(1, 0), CollectionListModel::EnabledRole).toBool(), false);

    model.setEnabledIds({});
    QVERIFY(!model.hasCustomEnabledFilter());
    QVERIFY(model.enabledAt(1));

    model.setTaskCounts({{11, 8}});
    QCOMPARE(model.data(idx, CollectionListModel::TaskCountRole).toInt(), 8);
    QCOMPARE(model.collectionIdAt(-1), qint64(-1));
    QVERIFY(model.nameAt(9).isEmpty());
    QCOMPARE(model.taskCountAt(-1), 0);

    QCOMPARE(model.roleNames().value(CollectionListModel::NameRole), QByteArray("name"));
    QCOMPARE(model.roleNames().value(CollectionListModel::WritableRole), QByteArray("writable"));
}

void ModelsTest::collectionWritableHelpers()
{
    const QString todoMime = QStringLiteral("application/x-vnd.akonadi.calendar.todo");

    Akonadi::Collection writable(11);
    writable.setName(QStringLiteral("Arbeit"));
    writable.setContentMimeTypes({todoMime});
    writable.setRights(Akonadi::Collection::CanCreateItem | Akonadi::Collection::CanChangeItem
                       | Akonadi::Collection::CanDeleteItem);

    Akonadi::Collection readOnly(22);
    readOnly.setName(QStringLiteral("Kimai"));
    readOnly.setContentMimeTypes({todoMime, QStringLiteral("application/x-vnd.akonadi.calendar.event")});
    readOnly.setRights(Akonadi::Collection::CanChangeCollection);

    Akonadi::Collection folder(33);
    folder.setName(QStringLiteral("Davis"));
    folder.setContentMimeTypes({QStringLiteral("inode/directory")});
    folder.setRights(Akonadi::Collection::CanChangeCollection | Akonadi::Collection::CanCreateCollection
                     | Akonadi::Collection::CanDeleteCollection);

    QVERIFY(CollectionListModel::isTaskCollection(writable));
    QVERIFY(CollectionListModel::isTaskWritable(writable));
    QVERIFY(CollectionListModel::isTaskCollection(readOnly));
    QVERIFY(!CollectionListModel::isTaskWritable(readOnly));
    QVERIFY(!CollectionListModel::isTaskCollection(folder));
    QVERIFY(!CollectionListModel::isTaskWritable(folder));

    CollectionListModel model;
    model.setCollections({writable, readOnly, folder});
    QVERIFY(model.writableAt(0));
    QVERIFY(!model.writableAt(1));
    QVERIFY(!model.writableAt(2));
    QVERIFY(model.writableForId(11));
    QVERIFY(!model.writableForId(22));
    QVERIFY(!model.writableForId(33));
    QVERIFY(!model.writableAt(-1));
    QVERIFY(!model.writableForId(99));
    QCOMPARE(model.data(model.index(0, 0), CollectionListModel::WritableRole).toBool(), true);
    QCOMPARE(model.data(model.index(1, 0), CollectionListModel::WritableRole).toBool(), false);
}

QTEST_GUILESS_MAIN(ModelsTest)
#include "models_test.moc"
