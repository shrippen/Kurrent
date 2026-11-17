#include "sharedtasks.h"

#include <QSignalSpy>
#include <QtTest>

class SharedTasksTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void init();
    void instanceIsOne();
    void collectionsStoreAndEmitOnce();
    void busyStores();
    void tempIdsCountDown();
    void busyRefreshRules();
    void notifyEmitsTasksChanged();
    void isEmptyFollowsData();
    void resetClearsAll();
};

void SharedTasksTest::init()
{
    SharedTasks::instance().reset();
}

void SharedTasksTest::instanceIsOne()
{
    QCOMPARE(&SharedTasks::instance(), &SharedTasks::instance());
}

void SharedTasksTest::collectionsStoreAndEmitOnce()
{
    SharedTasks &shared = SharedTasks::instance();
    QSignalSpy spy(&shared, &SharedTasks::collectionsChanged);

    Akonadi::Collection tasks(7);
    Akonadi::Collection events(8);
    shared.setCollections({tasks}, {events}, {{7, QStringLiteral("Tasks")}, {8, QStringLiteral("Events")}});

    QCOMPARE(spy.count(), 1);
    QCOMPARE(shared.collections().size(), 1);
    QCOMPARE(shared.collections().first().id(), qint64(7));
    QCOMPARE(shared.eventCollections().first().id(), qint64(8));
    QCOMPARE(shared.collectionNames().value(8), QStringLiteral("Events"));
}

void SharedTasksTest::busyStores()
{
    SharedTasks &shared = SharedTasks::instance();

    TaskCalendar::BusyInterval interval;
    interval.summary = QStringLiteral("Meeting");
    shared.setBusyIntervals({interval});

    QCOMPARE(shared.busyIntervals().size(), 1);
    QCOMPARE(shared.busyIntervals().first().summary, QStringLiteral("Meeting"));
}

void SharedTasksTest::tempIdsCountDown()
{
    SharedTasks &shared = SharedTasks::instance();
    QCOMPARE(shared.nextTempId(), qint64(-2));
    QCOMPARE(shared.nextTempId(), qint64(-3));
}

void SharedTasksTest::busyRefreshRules()
{
    SharedTasks &shared = SharedTasks::instance();
    const QDate today(2026, 11, 17);

    // Fresh: changed, so due.
    QVERIFY(shared.busyRefreshDue(today));

    shared.markBusyFetched(today);
    QVERIFY(!shared.busyRefreshDue(today));
    QVERIFY(shared.busyRefreshDue(today.addDays(1)));

    shared.markBusyChanged();
    QVERIFY(shared.busyRefreshDue(today));
}

void SharedTasksTest::notifyEmitsTasksChanged()
{
    SharedTasks &shared = SharedTasks::instance();
    QSignalSpy spy(&shared, &SharedTasks::tasksChanged);
    shared.notifyTasksChanged();
    QCOMPARE(spy.count(), 1);
}

void SharedTasksTest::isEmptyFollowsData()
{
    SharedTasks &shared = SharedTasks::instance();
    QVERIFY(shared.isEmpty());

    shared.extraLabels().append(QStringLiteral("x"));
    QVERIFY(!shared.isEmpty());
    shared.extraLabels().clear();
    QVERIFY(shared.isEmpty());

    shared.tasks().insert(5, SharedTasks::Entry());
    QVERIFY(!shared.isEmpty());
}

void SharedTasksTest::resetClearsAll()
{
    SharedTasks &shared = SharedTasks::instance();
    shared.tasks().insert(5, SharedTasks::Entry());
    shared.setCollections({Akonadi::Collection(1)}, {Akonadi::Collection(2)}, {{1, QStringLiteral("a")}});
    shared.extraLabels().append(QStringLiteral("l"));
    shared.extraLocations().append(QStringLiteral("p"));
    shared.setBusyIntervals({TaskCalendar::BusyInterval()});
    shared.markBusyFetched(QDate(2026, 11, 17));
    shared.nextTempId();

    shared.reset();

    QVERIFY(shared.isEmpty());
    QVERIFY(shared.eventCollections().isEmpty());
    QVERIFY(shared.collectionNames().isEmpty());
    QVERIFY(shared.extraLocations().isEmpty());
    QVERIFY(shared.busyIntervals().isEmpty());
    QVERIFY(shared.busyRefreshDue(QDate(2026, 11, 17)));
    QCOMPARE(shared.nextTempId(), qint64(-2));
}

QTEST_GUILESS_MAIN(SharedTasksTest)
#include "sharedtasks_test.moc"
