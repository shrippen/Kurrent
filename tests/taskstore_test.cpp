#include "memorytaskstore.h"

#include <KCalendarCore/Todo>

#include <QCoreApplication>
#include <QSignalSpy>
#include <QTest>

class TaskStoreTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void createModifyMoveDelete();
    void failNextRollsError();
    void modifyWithMoveAfter();
    void unknownIdErrors();
    void createIdsMonotonic();
    void customVendorPropertyPreservedOnModify();
};

static Akonadi::Item makeTodoItem(const QString &summary)
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(summary);
    Akonadi::Item item;
    item.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    item.setPayload(todo);
    return item;
}

void TaskStoreTest::createModifyMoveDelete()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    MemoryTaskStore store;
    QSignalSpy spy(&store, &AbstractTaskStore::finished);

    AbstractTaskStore::Request create;
    create.kind = AbstractTaskStore::Kind::Create;
    create.clientId = -100;
    create.item = makeTodoItem(QStringLiteral("alpha"));
    create.collection = Akonadi::Collection(7);
    store.submit(create);

    QVERIFY(spy.wait(1000));
    QCOMPARE(spy.size(), 1);
    auto created = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(created.ok);
    QCOMPARE(created.kind, AbstractTaskStore::Kind::Create);
    QCOMPARE(created.clientId, -100);
    QVERIFY(created.item.id() > 0);
    QCOMPARE(created.collectionId, 7);
    QCOMPARE(store.itemCount(), 1);

    AbstractTaskStore::Request modify;
    modify.kind = AbstractTaskStore::Kind::Modify;
    modify.clientId = created.item.id();
    auto item = created.item;
    auto todo = item.payload<KCalendarCore::Todo::Ptr>();
    todo->setSummary(QStringLiteral("beta"));
    item.setPayload(todo);
    modify.item = item;
    store.submit(modify);

    QVERIFY(spy.wait(1000));
    auto modified = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(modified.ok);
    QCOMPARE(store.item(created.item.id()).payload<KCalendarCore::Todo::Ptr>()->summary(),
             QStringLiteral("beta"));

    AbstractTaskStore::Request move;
    move.kind = AbstractTaskStore::Kind::Move;
    move.clientId = created.item.id();
    move.item = Akonadi::Item(created.item.id());
    move.collection = Akonadi::Collection(9);
    store.submit(move);

    QVERIFY(spy.wait(1000));
    auto moved = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(moved.ok);
    QCOMPARE(store.item(created.item.id()).parentCollection().id(), 9);

    AbstractTaskStore::Request del;
    del.kind = AbstractTaskStore::Kind::Delete;
    del.clientId = created.item.id();
    del.item = Akonadi::Item(created.item.id());
    store.submit(del);

    QVERIFY(spy.wait(1000));
    auto deleted = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(deleted.ok);
    QCOMPARE(store.itemCount(), 0);
}

void TaskStoreTest::failNextRollsError()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    MemoryTaskStore store;
    QSignalSpy spy(&store, &AbstractTaskStore::finished);

    AbstractTaskStore::Request create;
    create.kind = AbstractTaskStore::Kind::Create;
    create.clientId = -1;
    create.item = makeTodoItem(QStringLiteral("x"));
    create.collection = Akonadi::Collection(1);
    store.submit(create);
    QVERIFY(spy.wait(1000));
    auto created = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();

    store.failNext(QStringLiteral("boom"));
    AbstractTaskStore::Request modify;
    modify.kind = AbstractTaskStore::Kind::Modify;
    modify.clientId = created.item.id();
    modify.item = created.item;
    store.submit(modify);

    QVERIFY(spy.wait(1000));
    auto failed = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(!failed.ok);
    QCOMPARE(failed.errorString, QStringLiteral("boom"));
}

void TaskStoreTest::modifyWithMoveAfter()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    MemoryTaskStore store;
    QSignalSpy spy(&store, &AbstractTaskStore::finished);

    AbstractTaskStore::Request create;
    create.kind = AbstractTaskStore::Kind::Create;
    create.clientId = -2;
    create.item = makeTodoItem(QStringLiteral("parked"));
    create.collection = Akonadi::Collection(1);
    store.submit(create);
    QVERIFY(spy.wait(1000));
    auto created = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();

    AbstractTaskStore::Request modify;
    modify.kind = AbstractTaskStore::Kind::Modify;
    modify.clientId = created.item.id();
    modify.item = created.item;
    modify.moveAfterModifyId = 42;
    store.submit(modify);

    QVERIFY(spy.wait(1000));
    auto modified = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(modified.ok);
    QCOMPARE(store.item(created.item.id()).parentCollection().id(), 42);
}

void TaskStoreTest::unknownIdErrors()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    MemoryTaskStore store;
    QSignalSpy spy(&store, &AbstractTaskStore::finished);

    AbstractTaskStore::Request modify;
    modify.kind = AbstractTaskStore::Kind::Modify;
    modify.clientId = 999;
    modify.item = Akonadi::Item(999);
    store.submit(modify);
    QVERIFY(spy.wait(1000));
    QVERIFY(!spy.takeFirst().at(0).value<AbstractTaskStore::Result>().ok);

    AbstractTaskStore::Request del;
    del.kind = AbstractTaskStore::Kind::Delete;
    del.clientId = 999;
    del.item = Akonadi::Item(999);
    store.submit(del);
    QVERIFY(spy.wait(1000));
    QVERIFY(!spy.takeFirst().at(0).value<AbstractTaskStore::Result>().ok);

    AbstractTaskStore::Request move;
    move.kind = AbstractTaskStore::Kind::Move;
    move.clientId = 999;
    move.item = Akonadi::Item(999);
    move.collection = Akonadi::Collection(1);
    store.submit(move);
    QVERIFY(spy.wait(1000));
    QVERIFY(!spy.takeFirst().at(0).value<AbstractTaskStore::Result>().ok);
}

void TaskStoreTest::createIdsMonotonic()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    MemoryTaskStore store;
    QSignalSpy spy(&store, &AbstractTaskStore::finished);

    AbstractTaskStore::Request a;
    a.kind = AbstractTaskStore::Kind::Create;
    a.clientId = -10;
    a.item = makeTodoItem(QStringLiteral("a"));
    a.collection = Akonadi::Collection(1);
    store.submit(a);
    QVERIFY(spy.wait(1000));
    const qint64 idA = spy.takeFirst().at(0).value<AbstractTaskStore::Result>().item.id();

    AbstractTaskStore::Request b;
    b.kind = AbstractTaskStore::Kind::Create;
    b.clientId = -11;
    b.item = makeTodoItem(QStringLiteral("b"));
    b.collection = Akonadi::Collection(1);
    store.submit(b);
    QVERIFY(spy.wait(1000));
    const qint64 idB = spy.takeFirst().at(0).value<AbstractTaskStore::Result>().item.id();

    QVERIFY(idB > idA);
}

void TaskStoreTest::customVendorPropertyPreservedOnModify()
{
    qRegisterMetaType<AbstractTaskStore::Result>();
    MemoryTaskStore store;
    QSignalSpy spy(&store, &AbstractTaskStore::finished);

    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(QStringLiteral("vendor"));
    todo->setNonKDECustomProperty(QByteArray("X-OC-HIDESUBTASKS"), QStringLiteral("1"));
    Akonadi::Item item;
    item.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    item.setPayload(todo);

    AbstractTaskStore::Request create;
    create.kind = AbstractTaskStore::Kind::Create;
    create.clientId = -20;
    create.item = item;
    create.collection = Akonadi::Collection(3);
    store.submit(create);
    QVERIFY(spy.wait(1000));
    const auto created = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(created.ok);

    auto stored = created.item.payload<KCalendarCore::Todo::Ptr>();
    stored->setSummary(QStringLiteral("vendor-updated"));
    Akonadi::Item modified = created.item;
    modified.setPayload(stored);

    AbstractTaskStore::Request modify;
    modify.kind = AbstractTaskStore::Kind::Modify;
    modify.clientId = created.item.id();
    modify.item = modified;
    store.submit(modify);
    QVERIFY(spy.wait(1000));
    const auto modifiedResult = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(modifiedResult.ok);

    const auto roundTrip = store.item(created.item.id()).payload<KCalendarCore::Todo::Ptr>();
    QCOMPARE(roundTrip->summary(), QStringLiteral("vendor-updated"));
    QCOMPARE(roundTrip->nonKDECustomProperty(QByteArray("X-OC-HIDESUBTASKS")), QStringLiteral("1"));
}

QTEST_MAIN(TaskStoreTest)
#include "taskstore_test.moc"
