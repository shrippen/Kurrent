#include "memorytaskstore.h"
#include "sharedsettings.h"
#include "taskcontroller.h"

#include <Akonadi/Collection>

#include <KCalendarCore/Todo>

#include <QCoreApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QQmlPropertyMap>
#include <QStandardPaths>
#include <QSignalSpy>
#include <QScopeGuard>
#include <QSemaphore>
#include <QTest>
#include <QThreadPool>

class TaskControllerEditorTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void init();
    void cleanup();

    void editorCreateGoesThroughStore();

private:
    Akonadi::Collection makeCollection(qint64 id, const QString &name) const;
    void waitStore(QSignalSpy &spy, int count = 1);

    TaskController *m_controller = nullptr;
    MemoryTaskStore *m_store = nullptr;
};

Akonadi::Collection TaskControllerEditorTest::makeCollection(qint64 id, const QString &name) const
{
    Akonadi::Collection collection(id);
    collection.setName(name);
    collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
    collection.setRights(Akonadi::Collection::CanCreateItem
                         | Akonadi::Collection::CanChangeItem
                         | Akonadi::Collection::CanDeleteItem);
    return collection;
}

void TaskControllerEditorTest::waitStore(QSignalSpy &spy, int count)
{
    while (spy.size() < count) {
        QVERIFY(spy.wait(1000));
    }
}

void TaskControllerEditorTest::initTestCase()
{
    // SharedSettings::instance() then lives in ~/.qttest, never the user's kurrentrc.
    QStandardPaths::setTestModeEnabled(true);
}

void TaskControllerEditorTest::init()
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

void TaskControllerEditorTest::cleanup()
{
    if (m_controller) {
        m_controller->resetSharedStateForTest();
        delete m_controller;
        m_controller = nullptr;
        m_store = nullptr;
    }
}

void TaskControllerEditorTest::editorCreateGoesThroughStore()
{
    const QDate today = QDate::currentDate();
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    m_controller->createTaskFull({
        {QStringLiteral("summary"), QStringLiteral("  from editor  ")},
        {QStringLiteral("description"), QStringLiteral("notes")},
        {QStringLiteral("location"), QStringLiteral("Office")},
        {QStringLiteral("priority"), 3},
        {QStringLiteral("categories"), QStringList{QStringLiteral("a"), QStringLiteral("b")}},
        {QStringLiteral("startDate"), QDateTime(today, QTime(8, 0))},
        {QStringLiteral("dueDate"), QDateTime(today, QTime(9, 30))},
        {QStringLiteral("allDay"), false},
        {QStringLiteral("status"), static_cast<int>(KCalendarCore::Incidence::StatusInProcess)},
        {QStringLiteral("secrecy"), static_cast<int>(KCalendarCore::Incidence::SecrecyPrivate)},
        {QStringLiteral("percentComplete"), 40},
        {QStringLiteral("recurrencePreset"), QStringLiteral("weekly")},
        {QStringLiteral("section"), QStringLiteral("Phase 1")},
        {QStringLiteral("reminderMinutes"), 15},
        {QStringLiteral("collectionId"), 20},
    });

    waitStore(spy);
    QVERIFY(spy.size() == 1);
    auto result = spy.takeFirst().at(0).value<AbstractTaskStore::Result>();
    QVERIFY(result.ok);
    QCOMPARE(result.kind, AbstractTaskStore::Kind::Create);
    const qint64 id = result.item.id();
    QVERIFY(id > 0);
    QVERIFY(m_controller->testTaskExists(id));
    QCOMPARE(m_controller->testTaskCollectionId(id), 20);
    QCOMPARE(m_controller->testTaskSummary(id), QStringLiteral("from editor"));
    QCOMPARE(m_controller->testTaskLocation(id), QStringLiteral("Office"));
    QCOMPARE(m_controller->testTaskPriority(id), 3);
    QCOMPARE(m_controller->testTaskCategories(id), (QStringList{QStringLiteral("a"), QStringLiteral("b")}));
    QCOMPARE(m_controller->testTaskStatus(id), static_cast<int>(KCalendarCore::Incidence::StatusInProcess));
    QCOMPARE(m_controller->testTaskSecrecy(id), static_cast<int>(KCalendarCore::Incidence::SecrecyPrivate));
    QCOMPARE(m_controller->testTaskDue(id).toLocalTime(), QDateTime(today, QTime(9, 30)));

    const QVariantMap snap = m_controller->taskSnapshotById(id);
    QCOMPARE(snap.value(QStringLiteral("description")).toString(), QStringLiteral("notes"));
    QCOMPARE(snap.value(QStringLiteral("startDate")).toDateTime().toLocalTime(), QDateTime(today, QTime(8, 0)));
    QCOMPARE(snap.value(QStringLiteral("percentComplete")).toInt(), 40);
    QCOMPARE(snap.value(QStringLiteral("recurrencePreset")).toString(), QStringLiteral("weekly"));
    QCOMPARE(snap.value(QStringLiteral("section")).toString(), QStringLiteral("Phase 1"));
    QCOMPARE(snap.value(QStringLiteral("reminderMinutes")).toInt(), 15);
}

QTEST_MAIN(TaskControllerEditorTest)
#include "taskcontroller_editor_test.moc"
