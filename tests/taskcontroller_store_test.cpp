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
    QCOMPARE(m_controller->testInflight(5), 2);
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

    m_controller->undo();
    waitStore(spy, 2);
    QVERIFY(!m_controller->testTaskCompleted(6));
}

QTEST_MAIN(TaskControllerStoreTest)
#include "taskcontroller_store_test.moc"
