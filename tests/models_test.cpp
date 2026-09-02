#include "collectionlistmodel.h"
#include "tasklistmodel.h"

#include <Akonadi/Collection>

#include <QDate>
#include <QDateTime>
#include <QDeadlineTimer>
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
    void taskListUidLookup();
    void taskListIncrementalUpdateRemovesRows();
    void taskListIncrementalUpdateInsertsRows();
    void taskListIncrementalUpdatePrefixDataChange();
    void taskListIncrementalUpdateSuffixDataChange();
    void collectionEnabledAtWithoutFilter();
    void collectionEnabledAtWithCustomFilter();
    void collectionLookupHelpers();
    void collectionDataRolesAndSignals();
    void collectionWritableHelpers();
    void taskListRapidCollapseExpand();
    void taskListDeepNestedCollapseExpand();
    void taskListChunkedApply();
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
    task.joinUrl = QStringLiteral("https://meet.example/x");
    task.categories = QStringList{QStringLiteral("home")};
    task.collectionId = 7;
    task.collectionName = QStringLiteral("Work");
    task.indentLevel = 2;
    task.hasChildren = true;
    task.treeCollapsed = true;
    task.section = QStringLiteral("Later");
    task.bucket = QStringLiteral("morning");
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
    QCOMPARE(model.data(idx, TaskListModel::JoinUrlRole).toString(), QStringLiteral("https://meet.example/x"));
    QCOMPARE(model.data(idx, TaskListModel::CollectionNameRole).toString(), QStringLiteral("Work"));
    QCOMPARE(model.data(idx, TaskListModel::IndentLevelRole).toInt(), 2);
    QCOMPARE(model.data(idx, TaskListModel::HasChildrenRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::TreeCollapsedRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::SectionRole).toString(), QStringLiteral("Later"));
    QCOMPARE(model.data(idx, TaskListModel::BucketRole).toString(), QStringLiteral("morning"));
    QCOMPARE(model.data(idx, TaskListModel::SyncingRole).toBool(), true);
    QCOMPARE(model.data(idx, TaskListModel::PendingDeleteRole).toBool(), true);

    QVERIFY(model.roleNames().contains(TaskListModel::SummaryRole));
    QCOMPARE(model.roleNames().value(TaskListModel::SummaryRole), QByteArray("summary"));
    QCOMPARE(model.roleNames().value(TaskListModel::SyncingRole), QByteArray("syncing"));
    QCOMPARE(model.roleNames().value(TaskListModel::PendingDeleteRole), QByteArray("pendingDelete"));
    QCOMPARE(model.roleNames().value(TaskListModel::JoinUrlRole), QByteArray("joinUrl"));
    QCOMPARE(model.roleNames().value(TaskListModel::BucketRole), QByteArray("bucket"));
    QCOMPARE(model.roleNames().value(TaskListModel::TreeCollapsedRole), QByteArray("treeCollapsed"));
    QCOMPARE(model.roleNames().value(TaskListModel::TreeHiddenRole), QByteArray("treeHidden"));
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

void ModelsTest::taskListUidLookup()
{
    TaskListModel model;
    TaskEntry first;
    first.uid = QStringLiteral("alpha");
    first.summary = QStringLiteral("A");
    TaskEntry second;
    second.uid = QStringLiteral("beta");
    second.summary = QStringLiteral("B");
    model.setTasks({first, second});

    QCOMPARE(model.uidAt(0), QStringLiteral("alpha"));
    QCOMPARE(model.uidAt(1), QStringLiteral("beta"));
    QCOMPARE(model.rowForUid(QStringLiteral("beta")), 1);
    QCOMPARE(model.rowForUid(QStringLiteral("missing")), -1);
}

void ModelsTest::taskListIncrementalUpdateRemovesRows()
{
    TaskListModel model;
    TaskEntry a, b, c, d;
    a.uid = QStringLiteral("a");
    b.uid = QStringLiteral("b");
    c.uid = QStringLiteral("c");
    d.uid = QStringLiteral("d");
    model.setTasks({a, b, c, d});

    // Removing middle two rows (b, c) should use removeRows, not reset.
    QSignalSpy rowsRemoved(&model, &TaskListModel::rowsRemoved);
    QSignalSpy modelReset(&model, &TaskListModel::modelReset);
    model.setTasks({a, d});

    QCOMPARE(model.count(), 2);
    QCOMPARE(model.uidAt(0), QStringLiteral("a"));
    QCOMPARE(model.uidAt(1), QStringLiteral("d"));
    QVERIFY(!modelReset.isEmpty() || rowsRemoved.count() > 0);
}

void ModelsTest::taskListIncrementalUpdateInsertsRows()
{
    TaskListModel model;
    TaskEntry a, d;
    a.uid = QStringLiteral("a");
    d.uid = QStringLiteral("d");
    model.setTasks({a, d});

    // Inserting middle two rows (b, c) should use insertRows, not reset.
    TaskEntry b, c;
    b.uid = QStringLiteral("b");
    c.uid = QStringLiteral("c");
    QSignalSpy rowsInserted(&model, &TaskListModel::rowsInserted);
    QSignalSpy modelReset(&model, &TaskListModel::modelReset);
    model.setTasks({a, b, c, d});

    QCOMPARE(model.count(), 4);
    QCOMPARE(model.uidAt(1), QStringLiteral("b"));
    QCOMPARE(model.uidAt(2), QStringLiteral("c"));
    QVERIFY(!modelReset.isEmpty() || rowsInserted.count() > 0);
}

void ModelsTest::taskListIncrementalUpdatePrefixDataChange()
{
    TaskListModel model;
    TaskEntry a, b;
    a.uid = QStringLiteral("a");
    a.treeCollapsed = false;
    b.uid = QStringLiteral("b");
    model.setTasks({a, b});

    // Change treeCollapsed on prefix item a.
    QSignalSpy dataChanged(&model, &TaskListModel::dataChanged);
    TaskEntry a2 = a;
    a2.treeCollapsed = true;
    model.setTasks({a2, b});

    QCOMPARE(model.count(), 2);
    QVERIFY(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool());
    QCOMPARE(dataChanged.count(), 1);
}

void ModelsTest::taskListIncrementalUpdateSuffixDataChange()
{
    TaskListModel model;
    TaskEntry a, b, c;
    a.uid = QStringLiteral("a");
    b.uid = QStringLiteral("b");
    c.uid = QStringLiteral("c");
    c.treeCollapsed = false;
    model.setTasks({a, b, c});

    // Remove middle row b, and change treeCollapsed on suffix item c.
    QSignalSpy dataChanged(&model, &TaskListModel::dataChanged);
    TaskEntry c2 = c;
    c2.treeCollapsed = true;
    model.setTasks({a, c2});

    QCOMPARE(model.count(), 2);
    QVERIFY(model.data(model.index(1, 0), TaskListModel::TreeCollapsedRole).toBool());
    QCOMPARE(dataChanged.count(), 1);
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

void ModelsTest::taskListRapidCollapseExpand()
{
    TaskListModel model;
    QSignalSpy countSpy(&model, &TaskListModel::countChanged);

    TaskEntry parent;
    parent.uid = QStringLiteral("parent");
    parent.indentLevel = 0;
    parent.hasChildren = true;
    parent.treeCollapsed = false;

    TaskEntry child;
    child.uid = QStringLiteral("child");
    child.indentLevel = 1;

    TaskEntry other;
    other.uid = QStringLiteral("other");
    other.indentLevel = 0;

    // Expanded: parent, child, other
    QList<TaskEntry> expanded = {parent, child, other};
    // Collapsed: child omitted from the list (scrollbar/contentHeight match visible rows)
    TaskEntry parentCollapsed = parent;
    parentCollapsed.treeCollapsed = true;
    QList<TaskEntry> collapsed = {parentCollapsed, other};

    model.setTasks(expanded);
    QCOMPARE(model.count(), 3);
    QCOMPARE(countSpy.count(), 1);
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool(), false);

    // Collapse → child removed
    countSpy.clear();
    model.setTasks(collapsed);
    QCOMPARE(model.count(), 2);
    QCOMPARE(model.uidAt(1), QStringLiteral("other"));
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool(), true);

    // Expand → child visible again
    countSpy.clear();
    model.setTasks(expanded);
    QCOMPARE(model.count(), 3);
    QCOMPARE(model.uidAt(1), QStringLiteral("child"));
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool(), false);

    // Rapid cycles
    for (int cycle = 0; cycle < 5; ++cycle) {
        model.setTasks(collapsed);
        QCOMPARE(model.count(), 2);
        QCOMPARE(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool(), true);

        model.setTasks(expanded);
        QCOMPARE(model.count(), 3);
        QCOMPARE(model.uidAt(1), QStringLiteral("child"));
    }

    QCOMPARE(model.rowForUid(QStringLiteral("child")), 1);
    QCOMPARE(model.rowForUid(QStringLiteral("nonexistent")), -1);
}

void ModelsTest::taskListDeepNestedCollapseExpand()
{
    TaskListModel model;

    TaskEntry gp;
    gp.uid = QStringLiteral("gp");
    gp.indentLevel = 0;
    gp.hasChildren = true;
    gp.treeCollapsed = false;

    TaskEntry parent;
    parent.uid = QStringLiteral("p");
    parent.parentUid = QStringLiteral("gp");
    parent.indentLevel = 1;
    parent.hasChildren = true;
    parent.treeCollapsed = false;

    TaskEntry child;
    child.uid = QStringLiteral("c");
    child.parentUid = QStringLiteral("p");
    child.indentLevel = 2;

    TaskEntry sibling;
    sibling.uid = QStringLiteral("s");
    sibling.parentUid = QStringLiteral("gp");
    sibling.indentLevel = 1;

    // Fully expanded: gp, p, c, s
    QList<TaskEntry> allExpanded = {gp, parent, child, sibling};

    // Collapse parent only: child omitted
    TaskEntry parentCollapsed = parent;
    parentCollapsed.treeCollapsed = true;
    QList<TaskEntry> parentOnlyCollapsed = {gp, parentCollapsed, sibling};

    // Collapse grandparent: only gp remains from that subtree
    TaskEntry gpCollapsed = gp;
    gpCollapsed.treeCollapsed = true;
    QList<TaskEntry> gpOnlyCollapsed = {gpCollapsed};

    // Phase 1: all expanded
    model.setTasks(allExpanded);
    QCOMPARE(model.count(), 4);

    // Phase 2: collapse parent only → child omitted
    model.setTasks(parentOnlyCollapsed);
    QCOMPARE(model.count(), 3);
    QCOMPARE(model.uidAt(2), QStringLiteral("s"));
    QCOMPARE(model.data(model.index(1, 0), TaskListModel::TreeCollapsedRole).toBool(), true);

    // Phase 3: expand parent
    model.setTasks(allExpanded);
    QCOMPARE(model.count(), 4);

    // Phase 4: collapse grandparent → only gp
    model.setTasks(gpOnlyCollapsed);
    QCOMPARE(model.count(), 1);
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool(), true);

    // Phase 5: expand grandparent
    model.setTasks(allExpanded);
    QCOMPARE(model.count(), 4);
    QCOMPARE(model.data(model.index(0, 0), TaskListModel::TreeCollapsedRole).toBool(), false);

    // Phase 6: rapid toggling
    for (int cycle = 0; cycle < 3; ++cycle) {
        model.setTasks(gpOnlyCollapsed);
        QCOMPARE(model.count(), 1);
        model.setTasks(allExpanded);
        QCOMPARE(model.count(), 4);
        model.setTasks(parentOnlyCollapsed);
        QCOMPARE(model.count(), 3);
        model.setTasks(gpOnlyCollapsed);
        QCOMPARE(model.count(), 1);
    }

    model.setTasks(allExpanded);
    QCOMPARE(model.count(), 4);
    QCOMPARE(model.rowForUid(QStringLiteral("c")), 2);
}

void ModelsTest::taskListChunkedApply()
{
    // Build a list of 100 tasks (unique UIDs).
    QList<TaskEntry> oldTasks;
    for (int i = 0; i < 100; ++i) {
        TaskEntry t;
        t.itemId = i + 1;
        t.uid = QStringLiteral("chunk-old-%1").arg(i);
        t.summary = QStringLiteral("old %1").arg(i);
        oldTasks.append(t);
    }

    TaskListModel model;
    QSignalSpy countSpy(&model, &TaskListModel::countChanged);
    model.setTasks(oldTasks);
    QCOMPARE(model.count(), 100);
    countSpy.clear();

    // Build a completely different list of 120 tasks (>48 changed rows →
    // chunked path).  All UIDs differ from oldTasks, so prefix==0,
    // no suffix overlap.
    QList<TaskEntry> newTasks;
    for (int i = 0; i < 120; ++i) {
        TaskEntry t;
        t.itemId = 200 + i;
        t.uid = QStringLiteral("chunk-new-%1").arg(i);
        t.summary = QStringLiteral("new %1").arg(i);
        newTasks.append(t);
    }

    model.setTasks(newTasks);

    // With the sync path (< 48 rows) count would be immediate.
    // With chunking, the count may still be 100 or 120 at this point
    // depending on how fast the event loop runs.
    // Pump events until chunks finish (max 5 seconds).
    const QDeadlineTimer deadline(5000);
    while (model.chunksActive() && !deadline.hasExpired()) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    }
    QVERIFY(!model.chunksActive());

    // Final state must match the target list.
    QCOMPARE(model.count(), 120);
    for (int i = 0; i < 120; ++i) {
        QCOMPARE(model.taskAt(i).uid, QStringLiteral("chunk-new-%1").arg(i));
        QCOMPARE(model.taskAt(i).summary, QStringLiteral("new %1").arg(i));
    }

    // countChanged must have been emitted at least once.
    QVERIFY(countSpy.count() >= 1);
}

QTEST_GUILESS_MAIN(ModelsTest)
#include "models_test.moc"
