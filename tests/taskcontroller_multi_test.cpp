#include "akonadiloader.h"
#include "memorytaskstore.h"
#include "sharedsettings.h"
#include "taskcontroller.h"

#include <Akonadi/Collection>

#include <KCalendarCore/Todo>
#include <KJob>

#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

namespace {

constexpr int kInbox = 10;
constexpr int kWork = 20;
constexpr int kTimeoutMs = 3000;

// A job that never runs: onBusyEventsFetched only reads its error.
class IdleJob : public KJob
{
public:
    void start() override {}
};

}

// Widgets A and B and a config page C in one process, sharing SharedTasks.
class TaskControllerMultiTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void init();
    void cleanup();

    void collectionsReachOthers();
    void laterControllerHydrates();
    void writesReachOtherModels();
    void busyIntervalsReachOthers();
    void destroyedWriterLeavesOthersWorking();

private:
    Akonadi::Collection makeCollection(qint64 id, const QString &name) const;
    QList<Akonadi::Collection> collections() const;
    // Own store per controller: one store on two controllers would finish every write twice.
    MemoryTaskStore *attachStore(TaskController *controller);
    void waitStore(QSignalSpy &spy);
    int rowOf(TaskController *controller, qint64 id) const;

    TaskController *m_a = nullptr;
    TaskController *m_b = nullptr;
    TaskController *m_c = nullptr;
    MemoryTaskStore *m_storeA = nullptr;
    MemoryTaskStore *m_storeB = nullptr;
};

Akonadi::Collection TaskControllerMultiTest::makeCollection(qint64 id, const QString &name) const
{
    Akonadi::Collection collection(id);
    collection.setName(name);
    collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
    collection.setRights(Akonadi::Collection::CanCreateItem
                         | Akonadi::Collection::CanChangeItem
                         | Akonadi::Collection::CanDeleteItem);
    return collection;
}

QList<Akonadi::Collection> TaskControllerMultiTest::collections() const
{
    return {makeCollection(kInbox, QStringLiteral("Inbox")), makeCollection(kWork, QStringLiteral("Work"))};
}

MemoryTaskStore *TaskControllerMultiTest::attachStore(TaskController *controller)
{
    auto *store = new MemoryTaskStore;
    controller->setTaskStore(store);
    controller->setAkonadiAvailableForTest(true);
    return store;
}

void TaskControllerMultiTest::waitStore(QSignalSpy &spy)
{
    if (spy.isEmpty()) {
        QVERIFY(spy.wait(kTimeoutMs));
    }
}

int TaskControllerMultiTest::rowOf(TaskController *controller, qint64 id) const
{
    return controller->taskModel()->rowForItemId(id);
}

void TaskControllerMultiTest::initTestCase()
{
    // SharedSettings::instance() then lives in ~/.qttest, never the user's kurrentrc.
    QStandardPaths::setTestModeEnabled(true);
}

void TaskControllerMultiTest::init()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    TaskController::setSessionServices(TaskController::SessionServices::On);
    m_a = new TaskController;
    m_b = new TaskController;
    m_a->resetSharedStateForTest();
    m_b->resetSharedStateForTest();
    m_storeA = attachStore(m_a);
    m_storeB = attachStore(m_b);

    // The widgets register their session services; a config page does not.
    QCoreApplication::processEvents();
    TaskController::setSessionServices(TaskController::SessionServices::Off);
    m_c = new TaskController;
    m_c->resetSharedStateForTest();
    attachStore(m_c);
    TaskController::setSessionServices(TaskController::SessionServices::On);

    for (TaskController *controller : {m_a, m_b, m_c}) {
        controller->installTestCollections(collections());
    }
}

void TaskControllerMultiTest::cleanup()
{
    for (TaskController *controller : {m_a, m_b, m_c}) {
        if (controller) {
            controller->resetSharedStateForTest();
        }
    }
    delete m_a;
    delete m_b;
    delete m_c;
    m_a = m_b = m_c = nullptr;
    m_storeA = m_storeB = nullptr;
}

void TaskControllerMultiTest::collectionsReachOthers()
{
    // A fetch result: a task list, an event calendar, and a calendar that holds both.
    Akonadi::Collection events(30);
    events.setName(QStringLiteral("Events"));
    events.setContentMimeTypes({QStringLiteral("application/x-vnd.akonadi.calendar.event")});
    const QList<Akonadi::Collection> tasks = {makeCollection(kInbox, QStringLiteral("Inbox"))};
    const QHash<qint64, QString> names = {{kInbox, QStringLiteral("Inbox")}, {30, QStringLiteral("Events")}};

    QSignalSpy changed(m_c, &TaskController::eventBusySettingsChanged);
    SharedTasks::instance().setCollections(tasks, {events}, names);

    for (TaskController *controller : {m_a, m_b, m_c}) {
        QCOMPARE(controller->collectionModel()->rowCount(), 1);
        QCOMPARE(controller->collectionModel()->nameAt(0), QStringLiteral("Inbox"));
        QCOMPARE(controller->eventCalendarModel()->rowCount(), 1);
        QCOMPARE(controller->eventCalendarModel()->nameAt(0), QStringLiteral("Events"));
    }
    QCOMPARE(SharedTasks::instance().collectionNames(), names);
    QCOMPARE(changed.size(), 1);
}

void TaskControllerMultiTest::laterControllerHydrates()
{
    m_a->installTestTask(1, QStringLiteral("alpha"), kInbox);

    TaskController late;
    QVERIFY(late.hydrateFromCache());

    QCOMPARE(late.collectionModel()->rowCount(), 2);
    QCOMPARE(late.collectionModel()->nameAt(0), QStringLiteral("Inbox"));
    QCOMPARE(late.collectionModel()->nameAt(1), QStringLiteral("Work"));
    QTRY_COMPARE_WITH_TIMEOUT(late.taskModel()->rowCount(), 1, kTimeoutMs);
    QVERIFY(late.testTaskExists(1));
}

void TaskControllerMultiTest::writesReachOtherModels()
{
    m_a->installTestTask(1, QStringLiteral("alpha"), kInbox);
    m_b->hydrateFromCache();
    QTRY_VERIFY_WITH_TIMEOUT(rowOf(m_b, 1) >= 0, kTimeoutMs);

    // Edit
    QSignalSpy edited(m_storeA, &AbstractTaskStore::finished);
    m_a->setTaskPriority(1, 9);
    waitStore(edited);
    QTRY_COMPARE_WITH_TIMEOUT(m_b->testTaskPriority(1), 9, kTimeoutMs);
    QTRY_COMPARE_WITH_TIMEOUT(
        m_b->taskModel()->data(m_b->taskModel()->index(rowOf(m_b, 1)), TaskListModel::PriorityRole).toInt(), 9,
        kTimeoutMs);

    // Create
    QSignalSpy created(m_storeA, &AbstractTaskStore::finished);
    m_a->createTask(QStringLiteral("fresh"), kWork);
    waitStore(created);
    const auto result = created.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(result.ok);
    const qint64 newId = result.item.id();
    QTRY_VERIFY_WITH_TIMEOUT(rowOf(m_b, newId) >= 0, kTimeoutMs);
    QCOMPARE(m_b->testTaskSummary(newId), QStringLiteral("fresh"));
    QTRY_VERIFY_WITH_TIMEOUT(rowOf(m_c, newId) >= 0, kTimeoutMs);
    QTRY_COMPARE_WITH_TIMEOUT(m_b->taskModel()->rowCount(), 2, kTimeoutMs);
    QTRY_COMPARE_WITH_TIMEOUT(m_c->taskModel()->rowCount(), 2, kTimeoutMs);

    // Delete
    QSignalSpy deleted(m_storeA, &AbstractTaskStore::finished);
    m_a->deleteTask(1);
    waitStore(deleted);
    QTRY_COMPARE_WITH_TIMEOUT(rowOf(m_b, 1), -1, kTimeoutMs);
    QVERIFY(!m_b->testTaskExists(1));
    QCOMPARE(m_b->taskModel()->rowCount(), 1);
}

void TaskControllerMultiTest::busyIntervalsReachOthers()
{
    QCOMPARE(SharedTasks::instance().busyIntervals().size(), 0);

    TaskCalendar::BusyInterval interval;
    interval.start = QDateTime::currentDateTime();
    interval.end = interval.start.addSecs(3600);
    interval.collectionId = kInbox;
    IdleJob job;
    AkonadiLoader &loader = AkonadiLoader::instance();
    loader.m_pendingBusyFetchJobs = 1;
    loader.m_busyFetchIntervals = {interval, interval};
    loader.onBusyEventsFetched(&job, QDateTime(), QDateTime());

    QCOMPARE(SharedTasks::instance().busyIntervals().size(), 2);
    QVERIFY(!m_c->agendaEventsForDay(interval.start.date()).isEmpty());
}

void TaskControllerMultiTest::destroyedWriterLeavesOthersWorking()
{
    m_a->installTestTask(1, QStringLiteral("alpha"), kInbox);
    m_b->hydrateFromCache();
    QTRY_VERIFY_WITH_TIMEOUT(rowOf(m_b, 1) >= 0, kTimeoutMs);

    // A's write is in flight when A goes away.
    m_a->setTaskPriority(1, 7);
    delete m_a;
    m_a = nullptr;
    m_storeA = nullptr;

    QSignalSpy created(m_storeB, &AbstractTaskStore::finished);
    m_b->createTask(QStringLiteral("after"), kWork);
    waitStore(created);
    const auto result = created.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(result.ok);
    QTRY_VERIFY_WITH_TIMEOUT(rowOf(m_b, result.item.id()) >= 0, kTimeoutMs);
    QTRY_VERIFY_WITH_TIMEOUT(rowOf(m_c, result.item.id()) >= 0, kTimeoutMs);
    QVERIFY(rowOf(m_b, 1) >= 0);
    QVERIFY(rowOf(m_c, 1) >= 0);
}

QTEST_MAIN(TaskControllerMultiTest)
#include "taskcontroller_multi_test.moc"
