#include "akonadiloader.h"
#include "sharedtasks.h"

#include <Akonadi/Collection>
#include <Akonadi/Item>

#include <KCalendarCore/Event>
#include <KCalendarCore/Todo>

#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

namespace {

constexpr qint64 kInbox = 10;
constexpr qint64 kWork = 20;
constexpr qint64 kUnknownList = 99;
constexpr qint64 kTaskId = 7;

}

// Which version of a task wins when one arrives from Akonadi, without Akonadi.
class AkonadiLoaderTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void init();
    void cleanup();

    void takesNewItem();
    void rejectsOlderRevision();
    void takesNewerRevision();
    void rejectsSameRevisionOtherSummary();
    void revisionZeroKeepsRevision();
    void rejectsNonTodo();
    void rejectsUnknownList();
    void emptyEnabledMeansAll();
    void disabledListRemovesTask();
    void replacesTempRow();
    void keepsWriteUnderWay_data();
    void keepsWriteUnderWay();
    void removeItemDropsTask();
    void emptyEnabledIsAll();
    void notifiesOncePerItem();
    void silentDuringWave();
    void notifiesOnceAtWaveEnd();
    void resetForTestClears();

private:
    Akonadi::Item makeItem(qint64 id, qint64 collectionId, int revision, const QString &summary) const;
    void apply(const Akonadi::Item &item);
    QString summaryOf(qint64 id) const;
    bool exists(qint64 id) const { return shared().tasks().contains(id); }

    AkonadiLoader &loader() const { return AkonadiLoader::instance(); }
    SharedTasks &shared() const { return SharedTasks::instance(); }
};

Akonadi::Item AkonadiLoaderTest::makeItem(qint64 id, qint64 collectionId, int revision, const QString &summary) const
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setUid(QStringLiteral("uid-%1").arg(id));
    todo->setSummary(summary);

    Akonadi::Item item(id);
    item.setMimeType(QString::fromLatin1(KCalendarCore::Todo::todoMimeType()));
    item.setRevision(revision);
    item.setParentCollection(Akonadi::Collection(collectionId));
    item.setPayload(todo);
    return item;
}

void AkonadiLoaderTest::apply(const Akonadi::Item &item)
{
    loader().applyItem(item);
}

QString AkonadiLoaderTest::summaryOf(qint64 id) const
{
    const auto it = shared().tasks().constFind(id);
    return it == shared().tasks().cend() ? QString() : it->todo->summary();
}

void AkonadiLoaderTest::initTestCase()
{
    // SharedSettings::instance() then lives in ~/.qttest, never the user's kurrentrc.
    QStandardPaths::setTestModeEnabled(true);
}

void AkonadiLoaderTest::init()
{
    shared().reset();
    loader().resetForTest(false);

    QList<Akonadi::Collection> lists;
    for (qint64 id : {kInbox, kWork}) {
        Akonadi::Collection collection(id);
        collection.setName(QStringLiteral("List %1").arg(id));
        collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
        lists.append(collection);
    }
    QHash<qint64, QString> names;
    for (const Akonadi::Collection &collection : lists) {
        names.insert(collection.id(), collection.displayName());
    }
    shared().setCollections(lists, {}, names);
}

void AkonadiLoaderTest::cleanup()
{
    shared().reset();
    loader().resetForTest(false);
}

void AkonadiLoaderTest::takesNewItem()
{
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha")));

    QVERIFY(exists(kTaskId));
    QCOMPARE(summaryOf(kTaskId), QStringLiteral("alpha"));
    QCOMPARE(shared().tasks().value(kTaskId).item.parentCollection().id(), kInbox);
}

void AkonadiLoaderTest::rejectsOlderRevision()
{
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("new")));
    apply(makeItem(kTaskId, kInbox, 4, QStringLiteral("old")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("new"));
    QCOMPARE(shared().tasks().value(kTaskId).item.revision(), 5);
}

void AkonadiLoaderTest::takesNewerRevision()
{
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("old")));
    apply(makeItem(kTaskId, kInbox, 6, QStringLiteral("new")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("new"));
    QCOMPARE(shared().tasks().value(kTaskId).item.revision(), 6);
}

void AkonadiLoaderTest::rejectsSameRevisionOtherSummary()
{
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("ours")));
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("stale echo")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("ours"));
}

void AkonadiLoaderTest::revisionZeroKeepsRevision()
{
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("ours")));
    apply(makeItem(kTaskId, kInbox, 0, QStringLiteral("unversioned")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("ours"));
    QCOMPARE(shared().tasks().value(kTaskId).item.revision(), 5);
}

void AkonadiLoaderTest::rejectsNonTodo()
{
    Akonadi::Item event = makeItem(kTaskId, kInbox, 1, QStringLiteral("meeting"));
    event.setMimeType(QString::fromLatin1(KCalendarCore::Event::eventMimeType()));
    apply(event);

    QVERIFY(!exists(kTaskId));
}

void AkonadiLoaderTest::rejectsUnknownList()
{
    apply(makeItem(kTaskId, kUnknownList, 1, QStringLiteral("lost")));

    QVERIFY(!exists(kTaskId));
}

void AkonadiLoaderTest::emptyEnabledMeansAll()
{
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("a")));
    apply(makeItem(kTaskId + 1, kWork, 1, QStringLiteral("b")));

    QVERIFY(exists(kTaskId));
    QVERIFY(exists(kTaskId + 1));
}

void AkonadiLoaderTest::disabledListRemovesTask()
{
    apply(makeItem(kTaskId, kWork, 1, QStringLiteral("work task")));
    QVERIFY(exists(kTaskId));

    loader().setEnabledCollectionIds({kInbox});
    apply(makeItem(kTaskId, kWork, 2, QStringLiteral("work task")));
    apply(makeItem(kTaskId + 1, kWork, 1, QStringLiteral("other")));

    QVERIFY(!exists(kTaskId));
    QVERIFY(!exists(kTaskId + 1));
}

void AkonadiLoaderTest::replacesTempRow()
{
    // A create on its way to the store: a temporary id with the UID the store will return.
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setUid(QStringLiteral("uid-%1").arg(kTaskId));
    todo->setSummary(QStringLiteral("typed"));
    SharedTasks::Entry temp;
    temp.todo = todo;
    shared().tasks().insert(-2, temp);
    QVERIFY(exists(-2));

    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("typed")));

    QVERIFY(!exists(-2));
    QVERIFY(exists(kTaskId));
}

void AkonadiLoaderTest::keepsWriteUnderWay_data()
{
    QTest::addColumn<int>("flag");
    QTest::newRow("syncing") << 0;
    QTest::newRow("inflight") << 1;
    QTest::newRow("pendingDelete") << 2;
    QTest::newRow("persistQueued") << 3;
}

void AkonadiLoaderTest::keepsWriteUnderWay()
{
    QFETCH(int, flag);
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("ours")));

    SharedTasks::Entry &entry = SharedTasks::instance().tasks()[kTaskId];
    entry.syncing = flag == 0;
    entry.inflight = flag == 1 ? 1 : 0;
    entry.pendingDelete = flag == 2;
    entry.persistQueued = flag == 3;

    apply(makeItem(kTaskId, kInbox, 9, QStringLiteral("theirs")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("ours"));
    QCOMPARE(shared().tasks().value(kTaskId).item.revision(), 1);
}

void AkonadiLoaderTest::removeItemDropsTask()
{
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha")));
    QSignalSpy changed(&shared(), &SharedTasks::tasksChanged);

    loader().removeItem(kTaskId);
    QVERIFY(!exists(kTaskId));
    QCOMPARE(changed.count(), 1);

    loader().removeItem(kTaskId);
    QCOMPARE(changed.count(), 1);
}

void AkonadiLoaderTest::emptyEnabledIsAll()
{
    QVERIFY(loader().isCollectionEnabled(kInbox));
    QVERIFY(loader().isCollectionEnabled(kWork));
    QVERIFY(!loader().isCollectionEnabled(kUnknownList));

    loader().setEnabledCollectionIds({kWork});
    QVERIFY(!loader().isCollectionEnabled(kInbox));
    QVERIFY(loader().isCollectionEnabled(kWork));

    loader().setEnabledCollectionIds({});
    QVERIFY(loader().isCollectionEnabled(kInbox));
}

void AkonadiLoaderTest::notifiesOncePerItem()
{
    QSignalSpy changed(&shared(), &SharedTasks::tasksChanged);

    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha")));
    QCOMPARE(changed.count(), 1);

    // Rejected: nothing changed, nobody rebuilds.
    apply(makeItem(kTaskId, kInbox, 0, QStringLiteral("unversioned")));
    QCOMPARE(changed.count(), 1);
}

void AkonadiLoaderTest::silentDuringWave()
{
    QSignalSpy changed(&shared(), &SharedTasks::tasksChanged);

    // Jobs of a fetch wave are pending: the end of the wave rebuilds, not each item.
    loader().m_pendingFetchJobs = 1;
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha")));
    apply(makeItem(kTaskId + 1, kInbox, 1, QStringLiteral("beta")));
    loader().removeItem(kTaskId + 1);
    loader().m_pendingFetchJobs = 0;

    QVERIFY(exists(kTaskId));
    QCOMPARE(changed.count(), 0);
}

void AkonadiLoaderTest::notifiesOnceAtWaveEnd()
{
    QSignalSpy changed(&shared(), &SharedTasks::tasksChanged);

    // Two lists in the wave: items of both arrive, one rebuild when the last one ends.
    loader().m_pendingFetchJobs = 2;
    loader().onItemsFetched({makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha"))}, QString(), kInbox);
    QCOMPARE(changed.count(), 0);
    loader().onItemsFetched({makeItem(kTaskId + 1, kWork, 1, QStringLiteral("beta"))}, QString(), kWork);

    QVERIFY(exists(kTaskId));
    QVERIFY(exists(kTaskId + 1));
    QCOMPARE(changed.count(), 1);
}

void AkonadiLoaderTest::resetForTestClears()
{
    loader().setEnabledCollectionIds({kWork});
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha")));
    QCOMPARE(loader().fetchStats().rejectedDisabled, 1);

    QSignalSpy available(&loader(), &AkonadiLoader::availableChanged);
    loader().resetForTest(true);

    QVERIFY(loader().available());
    QCOMPARE(available.count(), 1);
    QVERIFY(!loader().loading());
    QVERIFY(loader().errorMessage().isEmpty());
    QCOMPARE(loader().fetchStats().rejectedDisabled, 0);
    QVERIFY(loader().isCollectionEnabled(kInbox));
}

QTEST_MAIN(AkonadiLoaderTest)
#include "akonadiloader_test.moc"
