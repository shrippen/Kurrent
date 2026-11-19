#include "memorytaskstore.h"
#include "sharedsettings.h"
#include "taskcontroller.h"

#include <Akonadi/Collection>

#include <KCalendarCore/Todo>

#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

namespace
{
const qint64 kTaskId = 1;
const qint64 kCollectionId = 10;
const QString kConflictError = QStringLiteral("Concurrent modification conflict");
const int kUserPriority = 1;
const int kServerPriority = 9;
const int kServerRevision = 5;
}

// The write pipeline's refetch paths (conflict, revision 0, reload) against the memory store.
class TaskControllerConflictTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void init();
    void cleanup();

    void conflictWithoutFieldClashResubmits();
    void fieldClashAsksTheUser();
    void resolveUserChoiceWritesUserValue();
    void resolveServerChoiceKeepsServerValue();
    void resolveEditChoiceDoesNotSubmit();
    void resolveUserChoiceSetsEachField();
    void refetchFailureSurfacesConflict();
    void reloadAppliesFreshItem();
    void reloadClearsConflict();
    void revisionZeroRefetchesBeforeSubmit();
    void revisionZeroRefetchFailureSubmitsAnyway();

private:
    // Detaches the store's copy from the controller's (they share one Todo), so a
    // change of the server side is not a change of the cache.
    void detachServer();
    // The cache learns the store's revision (a fresh test task has none, -1).
    void knowRevision(int revision = kServerRevision);
    void changeServer(int priority, int revision);
    int serverPriority() const;
    void provokeFieldClash(QSignalSpy &merge);
    void waitFinished(QSignalSpy &spy, int count);

    TaskController *m_controller = nullptr;
    MemoryTaskStore *m_store = nullptr;
};

void TaskControllerConflictTest::init()
{
    QStandardPaths::setTestModeEnabled(true);
    qRegisterMetaType<AbstractTaskStore::Result>();
    qRegisterMetaType<QVariantList>();
    m_controller = new TaskController;
    m_controller->resetSharedStateForTest();
    m_store = new MemoryTaskStore;
    m_controller->setTaskStore(m_store);
    m_controller->setAkonadiAvailableForTest(true);

    Akonadi::Collection collection(kCollectionId);
    collection.setName(QStringLiteral("Inbox"));
    collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
    collection.setRights(Akonadi::Collection::CanCreateItem | Akonadi::Collection::CanChangeItem
                         | Akonadi::Collection::CanDeleteItem);
    m_controller->installTestCollections({collection});
    m_controller->installTestTask(kTaskId, QStringLiteral("alpha"), kCollectionId);
    detachServer();
}

void TaskControllerConflictTest::cleanup()
{
    m_controller->resetSharedStateForTest();
    delete m_controller;
    m_controller = nullptr;
    m_store = nullptr;
}

void TaskControllerConflictTest::detachServer()
{
    Akonadi::Item item = m_store->item(kTaskId);
    item.setPayload<KCalendarCore::Todo::Ptr>(KCalendarCore::Todo::Ptr(new KCalendarCore::Todo(*item.payload<KCalendarCore::Todo::Ptr>())));
    m_store->seedItem(item);
}

void TaskControllerConflictTest::knowRevision(int revision)
{
    Akonadi::Item item = m_store->item(kTaskId);
    item.setRevision(revision);
    m_store->seedItem(item);
    m_controller->testApplyExternalItem(item);
    detachServer();
}

void TaskControllerConflictTest::changeServer(int priority, int revision)
{
    detachServer();
    Akonadi::Item item = m_store->item(kTaskId);
    item.payload<KCalendarCore::Todo::Ptr>()->setPriority(priority);
    item.setRevision(revision);
    m_store->seedItem(item);
}

int TaskControllerConflictTest::serverPriority() const
{
    return m_store->item(kTaskId).payload<KCalendarCore::Todo::Ptr>()->priority();
}

void TaskControllerConflictTest::waitFinished(QSignalSpy &spy, int count)
{
    QTRY_COMPARE_WITH_TIMEOUT(spy.size(), count, 2000);
}

// The user's edit is rejected, the server changed another field only.
void TaskControllerConflictTest::conflictWithoutFieldClashResubmits()
{
    knowRevision();
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);

    m_store->failNext(kConflictError);
    m_controller->setTaskPriority(kTaskId, kUserPriority);
    waitFinished(finished, 2);

    QCOMPARE(merge.size(), 0);
    QCOMPARE(m_controller->conflictItemId(), -1);
    QCOMPARE(serverPriority(), m_controller->testTaskPriority(kTaskId));
    QVERIFY(serverPriority() != 0);
    QVERIFY(!m_controller->testTaskSyncing(kTaskId));
}

void TaskControllerConflictTest::provokeFieldClash(QSignalSpy &merge)
{
    knowRevision();
    changeServer(kServerPriority, kServerRevision + 1);
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_store->failNext(kConflictError);
    m_controller->setTaskPriority(kTaskId, kUserPriority);
    QTRY_COMPARE_WITH_TIMEOUT(merge.size(), 1, 2000);
}

void TaskControllerConflictTest::fieldClashAsksTheUser()
{
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);
    provokeFieldClash(merge);

    const QVariantList fields = merge.at(0).at(0).toList();
    QCOMPARE(merge.at(0).at(1).toLongLong(), kTaskId);
    QCOMPARE(fields.size(), 1);
    const QVariantMap field = fields.at(0).toMap();
    QCOMPARE(field.value(QStringLiteral("key")).toString(), QStringLiteral("priority"));
    QCOMPARE(field.value(QStringLiteral("serverValue")).toInt(), kServerPriority);
    QCOMPARE(m_controller->conflictItemId(), kTaskId);
}

void TaskControllerConflictTest::resolveUserChoiceWritesUserValue()
{
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);
    provokeFieldClash(merge);
    const int userValue = merge.at(0).at(0).toList().at(0).toMap().value(QStringLiteral("userValue")).toInt();
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_controller->resolveMergeConflict({{QStringLiteral("priority"), QStringLiteral("user")}});
    waitFinished(finished, 1);

    QCOMPARE(serverPriority(), userValue);
    QVERIFY(serverPriority() != kServerPriority);
    QCOMPARE(m_controller->conflictItemId(), -1);
}

void TaskControllerConflictTest::resolveServerChoiceKeepsServerValue()
{
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);
    provokeFieldClash(merge);
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_controller->resolveMergeConflict({{QStringLiteral("priority"), QStringLiteral("server")}});
    waitFinished(finished, 1);

    QCOMPARE(serverPriority(), kServerPriority);
    QCOMPARE(m_controller->testTaskPriority(kTaskId), kServerPriority);
    QCOMPARE(m_controller->conflictItemId(), -1);
}

void TaskControllerConflictTest::resolveEditChoiceDoesNotSubmit()
{
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);
    provokeFieldClash(merge);
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_controller->resolveMergeConflict({{QStringLiteral("priority"), QStringLiteral("edit")}});
    QTest::qWait(100);

    QCOMPARE(finished.size(), 0);
    QCOMPARE(serverPriority(), kServerPriority);
    QCOMPARE(m_controller->conflictItemId(), -1);
}

// The debug conflict offers summary and priority; taking the user's side writes both.
void TaskControllerConflictTest::resolveUserChoiceSetsEachField()
{
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);
    m_controller->testMergeConflict();
    QCOMPARE(merge.size(), 1);
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_controller->resolveMergeConflict({{QStringLiteral("summary"), QStringLiteral("user")},
                                        {QStringLiteral("priority"), QStringLiteral("user")}});
    waitFinished(finished, 1);

    const KCalendarCore::Todo::Ptr stored = m_store->item(kTaskId).payload<KCalendarCore::Todo::Ptr>();
    QCOMPARE(stored->summary(), QStringLiteral("alpha (edited)"));
    QCOMPARE(stored->priority(), kUserPriority);
}

void TaskControllerConflictTest::refetchFailureSurfacesConflict()
{
    knowRevision();
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_store->failNext(kConflictError);
    m_store->failNextFetch();
    m_controller->setTaskPriority(kTaskId, kUserPriority);
    QTRY_COMPARE_WITH_TIMEOUT(m_controller->conflictItemId(), kTaskId, 2000);

    QVERIFY(!m_controller->testTaskSyncing(kTaskId));
    QCOMPARE(m_controller->testInflight(kTaskId), 0);
    QCOMPARE(finished.size(), 1);
}

void TaskControllerConflictTest::reloadAppliesFreshItem()
{
    changeServer(kServerPriority, kServerRevision);

    m_controller->reloadTask(kTaskId);

    QTRY_COMPARE_WITH_TIMEOUT(m_controller->testTaskPriority(kTaskId), kServerPriority, 2000);
    QCOMPARE(m_controller->testTaskRevision(kTaskId), kServerRevision);
}

void TaskControllerConflictTest::reloadClearsConflict()
{
    QSignalSpy merge(m_controller, &TaskController::mergeConflictAvailable);
    provokeFieldClash(merge);
    QCOMPARE(m_controller->conflictItemId(), kTaskId);

    m_controller->reloadTask(kTaskId);

    QTRY_COMPARE_WITH_TIMEOUT(m_controller->conflictItemId(), -1, 2000);
}

void TaskControllerConflictTest::revisionZeroRefetchesBeforeSubmit()
{
    knowRevision(0);
    QCOMPARE(m_controller->testTaskRevision(kTaskId), 0);
    changeServer(0, kServerRevision);
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_controller->setTaskPriority(kTaskId, kUserPriority);

    // The submit waits for the fetch.
    QCOMPARE(finished.size(), 0);
    QCOMPARE(m_controller->testInflight(kTaskId), 0);

    waitFinished(finished, 1);
    QCOMPARE(m_store->item(kTaskId).revision(), kServerRevision + 1);
    QCOMPARE(m_controller->testTaskRevision(kTaskId), kServerRevision + 1);
}

void TaskControllerConflictTest::revisionZeroRefetchFailureSubmitsAnyway()
{
    knowRevision(0);
    QSignalSpy finished(m_store, &AbstractTaskStore::finished);

    m_store->failNextFetch();
    m_controller->setTaskPriority(kTaskId, kUserPriority);
    waitFinished(finished, 1);

    QVERIFY(serverPriority() != 0);
}

QTEST_MAIN(TaskControllerConflictTest)
#include "taskcontroller_conflict_test.moc"
