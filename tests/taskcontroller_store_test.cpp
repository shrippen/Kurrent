#include "memorytaskstore.h"
#include "taskcontroller.h"

#include <Akonadi/Collection>

#include <KCalendarCore/Todo>

#include <QCoreApplication>
#include <QSignalSpy>
#include <QTest>

class TaskControllerStoreTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void init();
    void cleanup();

    void modifyOkClearsSyncing();
    void modifyFailRollsBack();
    void deleteFailClearsPending();
    void createReplacesTempId();
    void moveFailRollsBackCollection();
    void inflightTwoEdits();
    void undoAfterComplete();
    void labelAddRemoveRepeatIgnoresStaleMonitor();
    void coalescedAddThenRemove();
    void kanbanPriorityRoundTrip();
    void kanbanStatusAndSecrecyDrop();
    void kanbanLabelColumnDrop();
    void sidebarPriorityAndLocationMutations();

private:
    Akonadi::Collection makeCollection(qint64 id, const QString &name) const;
    void waitStore(QSignalSpy &spy, int count = 1);

    TaskController *m_controller = nullptr;
    MemoryTaskStore *m_store = nullptr;
};

Akonadi::Collection TaskControllerStoreTest::makeCollection(qint64 id, const QString &name) const
{
    Akonadi::Collection collection(id);
    collection.setName(name);
    collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
    collection.setRights(Akonadi::Collection::CanCreateItem
                         | Akonadi::Collection::CanChangeItem
                         | Akonadi::Collection::CanDeleteItem);
    return collection;
}

void TaskControllerStoreTest::waitStore(QSignalSpy &spy, int count)
{
    while (spy.size() < count) {
        QVERIFY(spy.wait(1000));
    }
}

void TaskControllerStoreTest::init()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    m_controller = new TaskController;
    m_controller->resetSharedStateForTest();
    m_store = new MemoryTaskStore;
    m_controller->setTaskStore(m_store);
    m_controller->setAkonadiAvailableForTest(true);
    m_controller->installTestCollections({
        makeCollection(10, QStringLiteral("Inbox")),
        makeCollection(20, QStringLiteral("Work")),
    });
}

void TaskControllerStoreTest::cleanup()
{
    if (m_controller) {
        m_controller->resetSharedStateForTest();
        delete m_controller;
        m_controller = nullptr;
        m_store = nullptr;
    }
}

void TaskControllerStoreTest::modifyOkClearsSyncing()
{
    m_controller->installTestTask(1, QStringLiteral("alpha"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->setTaskPriority(1, 9);
    QVERIFY(m_controller->testTaskSyncing(1));
    QCOMPARE(m_controller->testInflight(1), 1);

    waitStore(spy);
    QVERIFY(!m_controller->testTaskSyncing(1));
    QCOMPARE(m_controller->testInflight(1), 0);
    QCOMPARE(m_controller->testTaskSummary(1), QStringLiteral("alpha"));
}

void TaskControllerStoreTest::modifyFailRollsBack()
{
    m_controller->installTestTask(2, QStringLiteral("before"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);
    QSignalSpy err(m_controller, &TaskController::error);

    m_store->failNext(QStringLiteral("boom"));
    m_controller->updateTask(2, QStringLiteral("after"), QString(), QDateTime(), true, 0, {});
    QCOMPARE(m_controller->testTaskSummary(2), QStringLiteral("after"));
    QVERIFY(m_controller->testTaskSyncing(2));

    waitStore(spy);
    QCOMPARE(m_controller->testTaskSummary(2), QStringLiteral("before"));
    QVERIFY(!m_controller->testTaskSyncing(2));
    QVERIFY(err.size() >= 1);
}

void TaskControllerStoreTest::deleteFailClearsPending()
{
    m_controller->installTestTask(3, QStringLiteral("keep"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_store->failNext(QStringLiteral("nope"));
    m_controller->deleteTask(3);
    QVERIFY(m_controller->testTaskPendingDelete(3));

    waitStore(spy);
    QVERIFY(m_controller->testTaskExists(3));
    QVERIFY(!m_controller->testTaskPendingDelete(3));
    QVERIFY(!m_controller->testTaskSyncing(3));
}

void TaskControllerStoreTest::createReplacesTempId()
{
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);
    m_controller->createTask(QStringLiteral("fresh"), 10);

    waitStore(spy);
    auto result = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(result.ok);
    QCOMPARE(result.kind, AbstractTaskStore::Kind::Create);
    QVERIFY(result.clientId < 0);
    QVERIFY(result.item.id() > 0);
    QVERIFY(!m_controller->testTaskExists(result.clientId));
    QVERIFY(m_controller->testTaskExists(result.item.id()));
    QCOMPARE(m_controller->testTaskSummary(result.item.id()), QStringLiteral("fresh"));
}

void TaskControllerStoreTest::moveFailRollsBackCollection()
{
    m_controller->installTestTask(4, QStringLiteral("move-me"), 10);
    QCOMPARE(m_controller->testTaskCollectionId(4), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_store->failNext(QStringLiteral("move-denied"));
    m_controller->moveTaskToCollection(4, 20);
    QCOMPARE(m_controller->testTaskCollectionId(4), 20);

    waitStore(spy);
    QCOMPARE(m_controller->testTaskCollectionId(4), 10);
    QVERIFY(!m_controller->testTaskSyncing(4));
}

void TaskControllerStoreTest::inflightTwoEdits()
{
    m_controller->installTestTask(5, QStringLiteral("twice"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->setTaskPriority(5, 1);
    m_controller->setTaskPriority(5, 9);
    QCOMPARE(m_controller->testInflight(5), 1);
    QVERIFY(m_controller->testTaskSyncing(5));

    waitStore(spy, 2);
    QCOMPARE(m_controller->testInflight(5), 0);
    QVERIFY(!m_controller->testTaskSyncing(5));
}

void TaskControllerStoreTest::undoAfterComplete()
{
    m_controller->installTestTask(6, QStringLiteral("undo-me"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->setTaskCompleted(6, true);
    waitStore(spy);
    QVERIFY(m_controller->testTaskCompleted(6));
    QVERIFY(m_controller->canUndo());
    QVERIFY(m_controller->undoLabel().contains(QStringLiteral("undo-me")));

    m_controller->undo();
    waitStore(spy, 2);
    QVERIFY(!m_controller->testTaskCompleted(6));
}

void TaskControllerStoreTest::labelAddRemoveRepeatIgnoresStaleMonitor()
{
    m_controller->installTestTask(7, QStringLiteral("tagged"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->addTaskCategory(7, QStringLiteral("work"));
    waitStore(spy, 1);
    QCOMPARE(m_controller->testTaskCategories(7), QStringList({QStringLiteral("work")}));

    m_controller->removeTaskCategory(7, QStringLiteral("work"));
    waitStore(spy, 2);
    QVERIFY(m_controller->testTaskCategories(7).isEmpty());

    m_controller->addTaskCategory(7, QStringLiteral("work"));
    waitStore(spy, 3);
    QCOMPARE(m_controller->testTaskCategories(7), QStringList({QStringLiteral("work")}));
    const int secondAddRevision = m_controller->testTaskRevision(7);
    QVERIFY(secondAddRevision > 0);

    m_controller->removeTaskCategory(7, QStringLiteral("work"));
    waitStore(spy, 4);
    QVERIFY(m_controller->testTaskCategories(7).isEmpty());
    QVERIFY(m_controller->testTaskRevision(7) > secondAddRevision);

    Akonadi::Item stale(7);
    stale.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    stale.setRevision(secondAddRevision);
    stale.setParentCollection(Akonadi::Collection(10));
    KCalendarCore::Todo::Ptr echo(new KCalendarCore::Todo);
    echo->setUid(QStringLiteral("test-uid-7"));
    echo->setSummary(QStringLiteral("tagged"));
    echo->setCategories({QStringLiteral("work")});
    stale.setPayload(echo);

    m_controller->testApplyExternalItem(stale);
    QVERIFY(m_controller->testTaskCategories(7).isEmpty());

    m_controller->removeTaskCategory(7, QStringLiteral("work"));
    QVERIFY(m_controller->testTaskCategories(7).isEmpty());
}

void TaskControllerStoreTest::coalescedAddThenRemove()
{
    m_controller->installTestTask(8, QStringLiteral("burst"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->addTaskCategory(8, QStringLiteral("home"));
    m_controller->removeTaskCategory(8, QStringLiteral("home"));
    QCOMPARE(m_controller->testInflight(8), 1);
    QVERIFY(m_controller->testTaskCategories(8).isEmpty());

    waitStore(spy, 2);
    QVERIFY(m_controller->testTaskCategories(8).isEmpty());
    QVERIFY(!m_controller->testTaskSyncing(8));
}

void TaskControllerStoreTest::kanbanPriorityRoundTrip()
{
    m_controller->installTestTask(20, QStringLiteral("prio"), 10);
    m_controller->setKanbanColumnSource(QStringLiteral("priority"));
    m_controller->setTaskPriority(20, 9);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);
    waitStore(spy, 1);
    QCOMPARE(m_controller->testTaskPriority(20), 9);
    QCOMPARE(m_controller->testKanbanColumnKey(20), QStringLiteral("low"));

    // Low → None
    m_controller->finishKanbanDrop(20, QStringLiteral("none"), 0, QStringLiteral("low"), 0);
    waitStore(spy, 2);
    QCOMPARE(m_controller->testTaskPriority(20), 0);
    QCOMPARE(m_controller->testKanbanColumnKey(20), QStringLiteral("none"));

    // None → Low (previously snapped back)
    m_controller->finishKanbanDrop(20, QStringLiteral("low"), 0, QStringLiteral("none"), 0);
    waitStore(spy, 3);
    QCOMPARE(m_controller->testTaskPriority(20), 9);
    QCOMPARE(m_controller->testKanbanColumnKey(20), QStringLiteral("low"));

    // High → Medium → High
    m_controller->finishKanbanDrop(20, QStringLiteral("high"), 0, QStringLiteral("low"), 0);
    waitStore(spy, 4);
    QCOMPARE(m_controller->testTaskPriority(20), 1);
    m_controller->finishKanbanDrop(20, QStringLiteral("medium"), 0, QStringLiteral("high"), 0);
    waitStore(spy, 5);
    QCOMPARE(m_controller->testTaskPriority(20), 5);
    m_controller->finishKanbanDrop(20, QStringLiteral("high"), 0, QStringLiteral("medium"), 0);
    waitStore(spy, 6);
    QCOMPARE(m_controller->testTaskPriority(20), 1);
}

void TaskControllerStoreTest::kanbanStatusAndSecrecyDrop()
{
    m_controller->installTestTask(21, QStringLiteral("stat"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->setKanbanColumnSource(QStringLiteral("status"));
    m_controller->finishKanbanDrop(21, QStringLiteral("6"), 0, QStringLiteral("4"), 0);
    waitStore(spy, 1);
    QCOMPARE(m_controller->testTaskStatus(21), 6);
    QCOMPARE(m_controller->testKanbanColumnKey(21), QStringLiteral("6"));

    m_controller->finishKanbanDrop(21, QStringLiteral("4"), 0, QStringLiteral("6"), 0);
    waitStore(spy, 2);
    QCOMPARE(m_controller->testTaskStatus(21), 4);
    QCOMPARE(m_controller->testKanbanColumnKey(21), QStringLiteral("4"));

    m_controller->finishKanbanDrop(21, QStringLiteral("in-process"), 0, QStringLiteral("4"), 0);
    waitStore(spy, 3);
    QCOMPARE(m_controller->testTaskStatus(21), 6);
    QCOMPARE(m_controller->testKanbanColumnKey(21), QStringLiteral("6"));

    m_controller->setKanbanColumnSource(QStringLiteral("secrecy"));
    m_controller->finishKanbanDrop(21, QStringLiteral("private"), 0, QStringLiteral("public"), 0);
    waitStore(spy, 4);
    QCOMPARE(m_controller->testTaskSecrecy(21), 1);
    QCOMPARE(m_controller->testKanbanColumnKey(21), QStringLiteral("private"));

    m_controller->finishKanbanDrop(21, QStringLiteral("confidential"), 0, QStringLiteral("private"), 0);
    waitStore(spy, 5);
    QCOMPARE(m_controller->testTaskSecrecy(21), 2);
    m_controller->finishKanbanDrop(21, QStringLiteral("public"), 0, QStringLiteral("confidential"), 0);
    waitStore(spy, 6);
    QCOMPARE(m_controller->testTaskSecrecy(21), 0);
}

void TaskControllerStoreTest::kanbanLabelColumnDrop()
{
    m_controller->installTestTask(22, QStringLiteral("labs"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->setKanbanColumnSource(QStringLiteral("label"));
    m_controller->finishKanbanDrop(22, QStringLiteral("work"), 0, QStringLiteral("none"), 0);
    waitStore(spy, 1);
    QCOMPARE(m_controller->testTaskCategories(22), QStringList({QStringLiteral("work")}));
    QCOMPARE(m_controller->testKanbanColumnKey(22), QStringLiteral("work"));

    m_controller->finishKanbanDrop(22, QStringLiteral("home"), 0, QStringLiteral("work"), 0);
    waitStore(spy, 2);
    QCOMPARE(m_controller->testTaskCategories(22).first(), QStringLiteral("home"));
    QCOMPARE(m_controller->testKanbanColumnKey(22), QStringLiteral("home"));

    m_controller->finishKanbanDrop(22, QStringLiteral("none"), 0, QStringLiteral("home"), 0);
    waitStore(spy, 3);
    QVERIFY(m_controller->testTaskCategories(22).isEmpty());
    QCOMPARE(m_controller->testKanbanColumnKey(22), QStringLiteral("none"));
}

void TaskControllerStoreTest::sidebarPriorityAndLocationMutations()
{
    m_controller->installTestTask(23, QStringLiteral("side"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->setTaskPriority(23, 1);
    waitStore(spy, 1);
    QCOMPARE(m_controller->testTaskPriority(23), 1);

    m_controller->setTaskPriority(23, 0);
    waitStore(spy, 2);
    QCOMPARE(m_controller->testTaskPriority(23), 0);

    m_controller->setTaskPriority(23, 9);
    waitStore(spy, 3);
    QCOMPARE(m_controller->testTaskPriority(23), 9);

    m_controller->updateTaskFull(23, {{QStringLiteral("location"), QStringLiteral("Office")}});
    waitStore(spy, 4);
    QCOMPARE(m_controller->testTaskLocation(23), QStringLiteral("Office"));

    m_controller->updateTaskFull(23, {{QStringLiteral("location"), QString()}});
    waitStore(spy, 5);
    QVERIFY(m_controller->testTaskLocation(23).isEmpty());

    m_controller->updateTaskFull(23, {
        {QStringLiteral("secrecy"), 2},
        {QStringLiteral("status"), 6},
        {QStringLiteral("percentComplete"), 40},
    });
    waitStore(spy, 6);
    QCOMPARE(m_controller->testTaskSecrecy(23), 2);
    QCOMPARE(m_controller->testTaskStatus(23), 6);
}

QTEST_MAIN(TaskControllerStoreTest)
#include "taskcontroller_store_test.moc"
