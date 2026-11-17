#include "sharedtasks.h"
#include "taskcontroller.h"

#include <Akonadi/Collection>
#include <Akonadi/Item>

#include <KCalendarCore/Event>
#include <KCalendarCore/Todo>

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

private:
    Akonadi::Item makeItem(qint64 id, qint64 collectionId, int revision, const QString &summary) const;
    void apply(const Akonadi::Item &item);
    QString summaryOf(qint64 id) const;

    TaskController *m_controller = nullptr;
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
    m_controller->testApplyExternalItem(item);
}

QString AkonadiLoaderTest::summaryOf(qint64 id) const
{
    return m_controller->testTaskSummary(id);
}

void AkonadiLoaderTest::initTestCase()
{
    // SharedSettings::instance() then lives in ~/.qttest, never the user's kurrentrc.
    QStandardPaths::setTestModeEnabled(true);
}

void AkonadiLoaderTest::init()
{
    m_controller = new TaskController;
    m_controller->resetSharedStateForTest();

    QList<Akonadi::Collection> lists;
    for (qint64 id : {kInbox, kWork}) {
        Akonadi::Collection collection(id);
        collection.setName(QStringLiteral("List %1").arg(id));
        collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
        lists.append(collection);
    }
    m_controller->installTestCollections(lists);
}

void AkonadiLoaderTest::cleanup()
{
    m_controller->resetSharedStateForTest();
    delete m_controller;
    m_controller = nullptr;
}

void AkonadiLoaderTest::takesNewItem()
{
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("alpha")));

    QVERIFY(m_controller->testTaskExists(kTaskId));
    QCOMPARE(summaryOf(kTaskId), QStringLiteral("alpha"));
    QCOMPARE(m_controller->testTaskCollectionId(kTaskId), kInbox);
}

void AkonadiLoaderTest::rejectsOlderRevision()
{
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("new")));
    apply(makeItem(kTaskId, kInbox, 4, QStringLiteral("old")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("new"));
    QCOMPARE(m_controller->testTaskRevision(kTaskId), 5);
}

void AkonadiLoaderTest::takesNewerRevision()
{
    apply(makeItem(kTaskId, kInbox, 5, QStringLiteral("old")));
    apply(makeItem(kTaskId, kInbox, 6, QStringLiteral("new")));

    QCOMPARE(summaryOf(kTaskId), QStringLiteral("new"));
    QCOMPARE(m_controller->testTaskRevision(kTaskId), 6);
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
    QCOMPARE(m_controller->testTaskRevision(kTaskId), 5);
}

void AkonadiLoaderTest::rejectsNonTodo()
{
    Akonadi::Item event = makeItem(kTaskId, kInbox, 1, QStringLiteral("meeting"));
    event.setMimeType(QString::fromLatin1(KCalendarCore::Event::eventMimeType()));
    apply(event);

    QVERIFY(!m_controller->testTaskExists(kTaskId));
}

void AkonadiLoaderTest::rejectsUnknownList()
{
    apply(makeItem(kTaskId, kUnknownList, 1, QStringLiteral("lost")));

    QVERIFY(!m_controller->testTaskExists(kTaskId));
}

void AkonadiLoaderTest::emptyEnabledMeansAll()
{
    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("a")));
    apply(makeItem(kTaskId + 1, kWork, 1, QStringLiteral("b")));

    QVERIFY(m_controller->testTaskExists(kTaskId));
    QVERIFY(m_controller->testTaskExists(kTaskId + 1));
}

void AkonadiLoaderTest::disabledListRemovesTask()
{
    apply(makeItem(kTaskId, kWork, 1, QStringLiteral("work task")));
    QVERIFY(m_controller->testTaskExists(kTaskId));

    m_controller->setEnabledCollectionIds({QVariant::fromValue(kInbox)});
    apply(makeItem(kTaskId, kWork, 2, QStringLiteral("work task")));
    apply(makeItem(kTaskId + 1, kWork, 1, QStringLiteral("other")));

    QVERIFY(!m_controller->testTaskExists(kTaskId));
    QVERIFY(!m_controller->testTaskExists(kTaskId + 1));
}

void AkonadiLoaderTest::replacesTempRow()
{
    // A create on its way to the store: a temporary id with the UID the store will return.
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setUid(QStringLiteral("uid-%1").arg(kTaskId));
    todo->setSummary(QStringLiteral("typed"));
    m_controller->installTestTodo(-2, todo, kInbox);
    QVERIFY(m_controller->testTaskExists(-2));

    apply(makeItem(kTaskId, kInbox, 1, QStringLiteral("typed")));

    QVERIFY(!m_controller->testTaskExists(-2));
    QVERIFY(m_controller->testTaskExists(kTaskId));
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
    QCOMPARE(m_controller->testTaskRevision(kTaskId), 1);
}

QTEST_MAIN(AkonadiLoaderTest)
#include "akonadiloader_test.moc"
