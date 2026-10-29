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
#include <QTest>

class TaskControllerStoreTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
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
    void matrixDropWritesLaneAndDue();
    void inspectorSnapshotAndChildren();
    void heatmapTasksForDay();
    void agendaPlacesTasksInFreeTime();
    void agendaBoardsShiftAndCount();
    void agendaQuickAddParsesAndTakesTheSlot();
    void demoModeLoadsWorldTasks();
    void sessionBridgesConfiguration();
    void sessionRemembersSorts();
    void sessionFollowsSmartViewMode();
    void newTaskTargetAndProjectLists();

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

void TaskControllerStoreTest::initTestCase()
{
    // SharedSettings::instance() then lives in ~/.qttest, never the user's kurrentrc.
    QStandardPaths::setTestModeEnabled(true);
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

void TaskControllerStoreTest::matrixDropWritesLaneAndDue()
{
    m_controller->setSwimlaneTimeBucket(QStringLiteral("week"));
    m_controller->setSwimlaneLaneAxis(QStringLiteral("priority"));
    m_controller->installTestTask(31, QStringLiteral("swim"), 10);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    const QDate today = QDate::currentDate();
    const QString nextWeek = TaskLogic::matrixBucketKey(today.addDays(7), QStringLiteral("week"));

    // Priority lane + next week in one drop: both fields change, no due date before.
    m_controller->moveTaskToMatrixCell(31, QString::number(TaskLogic::PriorityBand::High), nextWeek);
    waitStore(spy, 1);
    QCOMPARE(m_controller->testTaskPriority(31), TaskLogic::PriorityBand::High);
    QVERIFY(m_controller->testTaskDue(31).isValid());
    QCOMPARE(TaskLogic::matrixBucketKey(m_controller->testTaskDue(31).date(), QStringLiteral("week")), nextWeek);

    // One undo step restores both.
    m_controller->undo();
    waitStore(spy, 2);
    QCOMPARE(m_controller->testTaskPriority(31), 0);
    QVERIFY(!m_controller->testTaskDue(31).isValid());

    // "unscheduled" clears an existing due date.
    m_controller->moveTaskToMatrixCell(31, QString::number(TaskLogic::PriorityBand::None), nextWeek);
    waitStore(spy, 3);
    QVERIFY(m_controller->testTaskDue(31).isValid());
    m_controller->moveTaskToMatrixCell(31, QString::number(TaskLogic::PriorityBand::None), QStringLiteral("unscheduled"));
    waitStore(spy, 4);
    QVERIFY(!m_controller->testTaskDue(31).isValid());

    // Overdue / Later are not drop targets.
    m_controller->moveTaskToMatrixCell(31, QString::number(TaskLogic::PriorityBand::None), QStringLiteral("overdue"));
    QVERIFY(!m_controller->testTaskDue(31).isValid());

    // Label axis: the target lane becomes the first label.
    m_controller->setSwimlaneLaneAxis(QStringLiteral("label"));
    m_controller->moveTaskToMatrixCell(31, QStringLiteral("work"), QStringLiteral("unscheduled"));
    waitStore(spy, 5);
    QCOMPARE(m_controller->testTaskCategories(31), QStringList({QStringLiteral("work")}));
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

void TaskControllerStoreTest::inspectorSnapshotAndChildren()
{
    m_controller->installTestTask(1, QStringLiteral("parent"), 10);
    m_controller->installTestTask(2, QStringLiteral("child"), 10);
    m_controller->installTestTask(3, QStringLiteral("other"), 10);

    // Snapshot by item id: current cache state, empty for unknown ids.
    const QVariantMap parent = m_controller->taskSnapshotById(1);
    QCOMPARE(parent.value(QStringLiteral("summary")).toString(), QStringLiteral("parent"));
    QVERIFY(m_controller->taskSnapshotById(999).isEmpty());
    // Same fields as a list row snapshot, so the full editor can open from it.
    for (const QString &key : {QStringLiteral("allDay"), QStringLiteral("recurrencePreset"),
                               QStringLiteral("reminderMinutes"), QStringLiteral("hasChildren")}) {
        QVERIFY2(parent.contains(key), qPrintable(key));
    }

    // Direct children only.
    const QString parentUid = parent.value(QStringLiteral("uid")).toString();
    QVERIFY(!parentUid.isEmpty());
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);
    m_controller->setTaskParent(2, parentUid);
    waitStore(spy);

    const QVariantList children = m_controller->childTasks(parentUid);
    QCOMPARE(children.size(), 1);
    QCOMPARE(children.first().toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("child"));
    QVERIFY(m_controller->childTasks(QString()).isEmpty());
}

void TaskControllerStoreTest::heatmapTasksForDay()
{
    m_controller->installTestTask(1, QStringLiteral("b done"), 10);
    m_controller->installTestTask(2, QStringLiteral("a done"), 20);
    m_controller->installTestTask(3, QStringLiteral("open"), 10);

    QSignalSpy spy(m_store, &AbstractTaskStore::finished);
    m_controller->setTaskCompleted(1, true);
    m_controller->setTaskCompleted(2, true);
    waitStore(spy, 2);

    // Completions today, across projects, sorted by summary; open tasks stay out.
    const QVariantList done = m_controller->heatmapTasksForDay(QDate::currentDate(), QStringLiteral("completed"));
    QCOMPARE(done.size(), 2);
    QCOMPARE(done.at(0).toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("a done"));
    QCOMPARE(done.at(1).toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("b done"));
    QVERIFY(m_controller->heatmapTasksForDay(QDate::currentDate().addDays(-1), QStringLiteral("completed")).isEmpty());
    QVERIFY(m_controller->heatmapTasksForDay(QDate(), QStringLiteral("completed")).isEmpty());
}

void TaskControllerStoreTest::agendaPlacesTasksInFreeTime()
{
    m_controller->installTestTask(1, QStringLiteral("first"), 10);
    m_controller->installTestTask(2, QStringLiteral("second"), 10);
    const QDate day = QDate::currentDate().addDays(3);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    // 10:05 snaps to 10:00; 30 minutes without priority.
    m_controller->agendaPlaceTask(1, day, 10 * 60 + 5);
    waitStore(spy);
    // The second one does not overlap the first.
    m_controller->agendaPlaceTask(2, day, 10 * 60 + 10);
    waitStore(spy, 2);

    QVariantList days = m_controller->agendaDays(day, 1);
    QCOMPARE(days.size(), 1);
    QVariantMap agenda = days.first().toMap();
    QCOMPARE(agenda.value(QStringLiteral("planFrom")).toInt(), 8 * 60);
    QVariantList items = agenda.value(QStringLiteral("items")).toList();
    QCOMPARE(items.size(), 2);
    QHash<QString, QVariantMap> bySummary;
    for (const QVariant &value : items) {
        bySummary.insert(value.toMap().value(QStringLiteral("summary")).toString(), value.toMap());
    }
    QCOMPARE(bySummary[QStringLiteral("first")].value(QStringLiteral("start")).toInt(), 10 * 60);
    QCOMPARE(bySummary[QStringLiteral("first")].value(QStringLiteral("end")).toInt(), 10 * 60 + 30);
    QCOMPARE(bySummary[QStringLiteral("second")].value(QStringLiteral("start")).toInt(), 10 * 60 + 30);
    // The first may grow up to the second, not into it.
    QCOMPARE(bySummary[QStringLiteral("first")].value(QStringLiteral("hi")).toInt(), 10 * 60 + 30);
    // Free time 08:00–10:00 and 11:00–18:00.
    const QVariantList free = agenda.value(QStringLiteral("free")).toList();
    QCOMPARE(free.size(), 2);
    QCOMPARE(free.at(1).toMap().value(QStringLiteral("start")).toInt(), 11 * 60);

    // Resize, then back to the day without a time.
    m_controller->agendaSetBlock(1, day, 9 * 60, 10 * 60 + 30);
    waitStore(spy, 3);
    m_controller->agendaMoveToDay(2, day);
    waitStore(spy, 4);
    agenda = m_controller->agendaDays(day, 1).first().toMap();
    items = agenda.value(QStringLiteral("items")).toList();
    QCOMPARE(items.size(), 1);
    QCOMPARE(items.first().toMap().value(QStringLiteral("start")).toInt(), 9 * 60);
    const QVariantList loose = agenda.value(QStringLiteral("loose")).toList();
    QCOMPARE(loose.size(), 1);
    QCOMPARE(loose.first().toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("second"));
    QVERIFY(loose.first().toMap().value(QStringLiteral("allDay")).toBool());

    // Suggestions for the day before: "second" is due the day after.
    const QVariantList suggestions = m_controller->agendaSuggestions(day.addDays(-1));
    bool found = false;
    for (const QVariant &value : suggestions) {
        const QVariantMap row = value.toMap();
        if (row.value(QStringLiteral("task")).toMap().value(QStringLiteral("summary")) == QStringLiteral("second")) {
            found = true;
            QCOMPARE(row.value(QStringLiteral("reasons")).toList().first().toMap().value(QStringLiteral("kind")).toString(),
                     QStringLiteral("dueSoon"));
        }
    }
    QVERIFY(found);
}

void TaskControllerStoreTest::agendaQuickAddParsesAndTakesTheSlot()
{
    const QDate day = QDate::currentDate().addDays(2);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);

    // Like the list's Quick Add: priority and label from the text; the slot gives the time.
    m_controller->agendaAddTask(QStringLiteral("Call the harbour !high #calls"), 10, day, 10 * 60, 10 * 60 + 45);
    // No time: an all-day task on the day.
    m_controller->agendaAddTask(QStringLiteral("Whole day"), 10, day);
    // A date in the text wins over the day.
    m_controller->agendaAddTask(QStringLiteral("Elsewhere tomorrow"), 10, day);
    waitStore(spy, 3);

    const QVariantMap board = m_controller->agendaDays(day, 1).first().toMap();
    const QVariantList items = board.value(QStringLiteral("items")).toList();
    QCOMPARE(items.size(), 1);
    const QVariantMap timed = items.first().toMap();
    QCOMPARE(timed.value(QStringLiteral("summary")).toString(), QStringLiteral("Call the harbour"));
    QCOMPARE(timed.value(QStringLiteral("start")).toInt(), 10 * 60);
    QCOMPARE(timed.value(QStringLiteral("end")).toInt(), 10 * 60 + 45);
    QCOMPARE(timed.value(QStringLiteral("priority")).toInt(), 1);
    QCOMPARE(timed.value(QStringLiteral("categories")).toStringList(), QStringList{QStringLiteral("calls")});
    const QVariantList loose = board.value(QStringLiteral("loose")).toList();
    QCOMPARE(loose.size(), 1);
    QCOMPARE(loose.first().toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("Whole day"));
    const QVariantMap tomorrow = m_controller->agendaDays(QDate::currentDate().addDays(1), 1).first().toMap();
    QCOMPARE(tomorrow.value(QStringLiteral("loose")).toList().size(), 1);
}

void TaskControllerStoreTest::agendaBoardsShiftAndCount()
{
    m_controller->installTestTask(1, QStringLiteral("block"), 10);
    m_controller->installTestTask(2, QStringLiteral("loose"), 10);
    m_controller->installTestTask(3, QStringLiteral("late"), 10);
    const QDate day = QDate::currentDate().addDays(2);
    QSignalSpy spy(m_store, &AbstractTaskStore::finished);
    m_controller->agendaSetBlock(1, day, 9 * 60, 10 * 60);
    m_controller->agendaMoveToDay(2, day);
    m_controller->agendaMoveToDay(3, QDate::currentDate().addDays(-3));
    waitStore(spy, 3);

    // Board fields: open tasks with the block first, load 60 + 30 minutes.
    QVariantMap board = m_controller->agendaDays(day, 1).first().toMap();
    QVariantList open = board.value(QStringLiteral("open")).toList();
    QCOMPARE(open.size(), 2);
    QCOMPARE(open.first().toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("block"));
    QCOMPARE(open.first().toMap().value(QStringLiteral("start")).toInt(), 9 * 60);
    QCOMPARE(board.value(QStringLiteral("load")).toInt(), 90);

    // Moving a day on keeps the time; a task without a date becomes all-day there.
    m_controller->agendaShiftToDay(1, day.addDays(1));
    waitStore(spy, 4);
    const QVariantMap moved = m_controller->agendaDays(day.addDays(1), 1).first().toMap();
    QCOMPARE(moved.value(QStringLiteral("items")).toList().size(), 1);
    QCOMPARE(moved.value(QStringLiteral("items")).toList().first().toMap().value(QStringLiteral("start")).toInt(), 9 * 60);
    m_controller->installTestTask(4, QStringLiteral("undated"), 10);
    m_controller->agendaShiftToDay(4, day);
    waitStore(spy, 5);
    board = m_controller->agendaDays(day, 1).first().toMap();
    QCOMPARE(board.value(QStringLiteral("loose")).toList().size(), 2);

    // Overdue tray holds the late task only.
    const QVariantList overdue = m_controller->agendaOverdue();
    QCOMPARE(overdue.size(), 1);
    QCOMPARE(overdue.first().toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("late"));

    // Month: six weeks, or six times five workdays; counts include open tasks.
    QCOMPARE(m_controller->agendaMonth(day, true).size(), 42);
    const QVariantList workdays = m_controller->agendaMonth(day, false);
    QCOMPARE(workdays.size(), 30);
    for (const QVariant &value : m_controller->agendaMonth(day, true)) {
        const QVariantMap cell = value.toMap();
        if (cell.value(QStringLiteral("date")).toDate() == day) {
            QCOMPARE(cell.value(QStringLiteral("count")).toInt(), 2);
            QVERIFY(cell.value(QStringLiteral("tint")).toDouble() > 0);
        }
    }
}

void TaskControllerStoreTest::demoModeLoadsWorldTasks()
{
    qputenv("KURRENT_DEMO", "en");
    qputenv("KURRENT_DEMO_WORLD", KURRENT_TEST_DEMO_WORLD);
    qputenv("DEMO_TODAY", "2026-09-16");
    auto *demo = new TaskController;

    QVERIFY(demo->demoMode());
    QVERIFY(demo->testTaskExists(20));
    QCOMPARE(demo->testTaskSummary(2), QStringLiteral("Send episode 4 rough cut to Northlight"));
    QVERIFY(demo->testTaskCompleted(5));
    QVERIFY(demo->testTaskCategories(10).contains(QStringLiteral("Calls")));
    // Monday 2026-09-14 is the anchor; the planning call is on the Monday.
    const QVariantList events = demo->agendaEventsForDay(QDate(2026, 9, 14));
    QCOMPARE(events.size(), 2);
    QCOMPARE(events.first().toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("Weekly planning"));

    // The agenda opens on the demo day; "time" gives a block on the due day (Thursday 10–11).
    QCOMPARE(demo->agendaSelectedDate(), QDate(2026, 9, 16));
    const QVariantList thursday = demo->agendaDays(QDate(2026, 9, 17), 1).first().toMap()
                                      .value(QStringLiteral("items")).toList();
    bool block = false;
    for (const QVariant &value : thursday) {
        const QVariantMap item = value.toMap();
        if (item.value(QStringLiteral("summary")) == QStringLiteral("Match September receipts")) {
            block = item.value(QStringLiteral("start")).toInt() == 10 * 60 && item.value(QStringLiteral("end")).toInt() == 11 * 60;
        }
    }
    QVERIFY(block);

    // Agenda by day: done tasks on their completion day, open ones first.
    const QVariantMap byDay = demo->agendaTasksByDay(QDate(2026, 9, 7), QDate(2026, 9, 27));
    QVERIFY(!byDay.isEmpty());
    for (auto it = byDay.cbegin(); it != byDay.cend(); ++it) {
        bool seenDone = false;
        for (const QVariant &value : it.value().toList()) {
            const QVariantMap task = value.toMap();
            const bool done = task.value(QStringLiteral("completed")).toBool();
            QVERIFY(!(seenDone && !done));
            seenDone = seenDone || done;
            const QDateTime completedAt = task.value(QStringLiteral("completedDate")).toDateTime();
            const QDateTime when = done && completedAt.isValid() ? completedAt
                                                                 : task.value(QStringLiteral("due")).toDateTime();
            QCOMPARE(when.toLocalTime().date().toString(Qt::ISODate), it.key());
        }
    }

    // Heatmap period: counts and figures together.
    const QVariantMap period = demo->heatmapPeriod(QDate(2026, 9, 1), {}, QStringLiteral("completed"));
    int total = 0;
    const QVariantMap counts = period.value(QStringLiteral("counts")).toMap();
    for (const QVariant &n : counts) {
        total += n.toInt();
    }
    QCOMPARE(period.value(QStringLiteral("total")).toInt(), total);

    demo->resetSharedStateForTest();
    delete demo;
    qunsetenv("KURRENT_DEMO");
    qunsetenv("KURRENT_DEMO_WORLD");
    qunsetenv("DEMO_TODAY");
}

namespace
{
// A Plasmoid.configuration stand-in holding every kurrentrc key with its default.
void fillDefaults(QQmlPropertyMap *config)
{
    SharedSettings::instance()->resetToDefaults();
    const QVariantMap defaults = SharedSettings::instance()->defaults();
    for (auto it = defaults.cbegin(); it != defaults.cend(); ++it) {
        config->insert(it.key(), it.value());
    }
}

// Writes like a settings page does on Apply (from QML, so change signals fire).
void writeFromQml(QQmlPropertyMap *config, const QString &assignment)
{
    QQmlEngine engine;
    QQmlContext context(engine.rootContext());
    context.setContextProperty(QStringLiteral("cfg"), config);
    QQmlExpression expression(&context, nullptr, QStringLiteral("cfg.") + assignment);
    expression.evaluate();
    QVERIFY(!expression.hasError());
}

QVariant stored(const QString &key)
{
    return SharedSettings::instance()->values().value(key);
}
} // namespace

void TaskControllerStoreTest::sessionBridgesConfiguration()
{
    QQmlPropertyMap config;
    fillDefaults(&config);
    SharedSettings::instance()->store(QStringLiteral("defaultView"), QStringLiteral("today"));
    m_controller->startSession(&config);

    // Start view restored; the configuration mirrors kurrentrc.
    QCOMPARE(m_controller->currentView(), QStringLiteral("today"));
    QCOMPARE(config.value(QStringLiteral("defaultView")).toString(), QStringLiteral("today"));

    // Settings page → configuration → kurrentrc → controller.
    QSignalSpy settingsChanged(m_controller, &TaskController::settingsChanged);
    writeFromQml(&config, QStringLiteral("swimlaneLaneAxis = 'label'"));
    QCOMPARE(stored(QStringLiteral("swimlaneLaneAxis")).toString(), QStringLiteral("label"));
    QCOMPARE(m_controller->swimlaneLaneAxis(), QStringLiteral("label"));
    QVERIFY(settingsChanged.count() >= 1);

    // Elsewhere (other widget) → kurrentrc → configuration and controller.
    SharedSettings::instance()->store(QStringLiteral("planHorizon"), 4);
    QCOMPARE(m_controller->planHorizon(), 4);
    QCOMPARE(config.value(QStringLiteral("planHorizon")).toInt(), 4);

    // A view choice persists through the controller.
    m_controller->storeSetting(QStringLiteral("planShowUndated"), false);
    QCOMPARE(m_controller->planShowUndated(), false);
    QCOMPARE(config.value(QStringLiteral("planShowUndated")).toBool(), false);
    m_controller->selectAgendaMode(QStringLiteral("month"));
    m_controller->selectAgendaWeekend(false);
    QCOMPARE(stored(QStringLiteral("agendaMode")).toString(), QStringLiteral("month"));
    QCOMPARE(stored(QStringLiteral("agendaWeekend")).toBool(), false);
    QCOMPARE(m_controller->agendaMode(), QStringLiteral("month"));
    QVERIFY(!m_controller->agendaWeekend());
    m_controller->selectAgendaMode(QStringLiteral("nonsense"));
    QCOMPARE(m_controller->agendaMode(), QStringLiteral("day"));
    // Workday length from the settings page; unset or nonsense means 8 hours.
    QCOMPARE(m_controller->agendaWorkMinutes(), 480);
    SharedSettings::instance()->store(QStringLiteral("agendaWorkMinutes"), 450);
    QCOMPARE(m_controller->agendaWorkMinutes(), 450);
    SharedSettings::instance()->store(QStringLiteral("agendaWorkMinutes"), 0);
    QCOMPARE(m_controller->agendaWorkMinutes(), 480);

    // Kanban columns: the matching sidebar filter is cleared.
    m_controller->setSelectedLabel(QStringLiteral("work"));
    m_controller->selectKanbanSource(TaskLogic::KanbanSource::Label);
    QVERIFY(m_controller->selectedLabel().isEmpty());
    QCOMPARE(stored(QStringLiteral("kanbanColumnSource")).toString(), TaskLogic::KanbanSource::Label);

    // The settings page changes the default view: the widget follows.
    writeFromQml(&config, QStringLiteral("defaultView = 'overdue'"));
    QCOMPARE(m_controller->currentView(), QStringLiteral("overdue"));

    // Remember last view.
    writeFromQml(&config, QStringLiteral("rememberLastView = true"));
    m_controller->setCurrentView(QStringLiteral("tomorrow"));
    QCOMPARE(stored(QStringLiteral("lastView")).toString(), QStringLiteral("tomorrow"));
}

void TaskControllerStoreTest::sessionRemembersSorts()
{
    QQmlPropertyMap config;
    fillDefaults(&config);
    SharedSettings::instance()->store(QStringLiteral("sortScope"), TaskLogic::SortScope::PerView);
    m_controller->startSession(&config);

    // Per-view scope: each view keeps its own sort; the default is stored as no entry.
    m_controller->setCurrentView(QStringLiteral("today"));
    m_controller->selectSort(QStringLiteral("due,title"));
    QCOMPARE(TaskLogic::jsonMapValue(stored(QStringLiteral("sortModeByView")).toString(), QStringLiteral("today")),
             QStringLiteral("due,title"));
    m_controller->setCurrentView(QStringLiteral("inbox"));
    QCOMPARE(m_controller->sortMode(), TaskLogic::SortMode::Default);
    m_controller->setCurrentView(QStringLiteral("today"));
    QCOMPARE(m_controller->sortMode(), QStringLiteral("due,title"));
    m_controller->selectSort(TaskLogic::SortMode::Default);
    QVERIFY(TaskLogic::jsonMapValue(stored(QStringLiteral("sortModeByView")).toString(), QStringLiteral("today")).isEmpty());

    // Kanban remembers Custom (set by a reorder) per view and column source.
    m_controller->selectMainPaneMode(TaskLogic::MainPaneMode::Kanban);
    QCOMPARE(stored(QStringLiteral("mainPaneMode")).toString(), TaskLogic::MainPaneMode::Kanban);
    m_controller->setSortMode(TaskLogic::SortMode::Custom);
    QCOMPARE(TaskLogic::jsonMapValue(stored(QStringLiteral("kanbanSortModeByViewColumn")).toString(),
                                     QStringLiteral("today|status")),
             TaskLogic::SortMode::Custom);
    m_controller->requestMainPaneMode(TaskLogic::MainPaneMode::List);
    QCOMPARE(m_controller->sortMode(), TaskLogic::SortMode::Default);
    QCOMPARE(stored(QStringLiteral("mainPaneMode")).toString(), TaskLogic::MainPaneMode::List);
    m_controller->selectMainPaneMode(TaskLogic::MainPaneMode::Kanban);
    QCOMPARE(m_controller->sortMode(), TaskLogic::SortMode::Custom);

    // Sort menu and list groups: the group's field leaves the sort.
    m_controller->selectSortLevel(0, QStringLiteral("priority"));
    QCOMPARE(m_controller->sortKeys(), (QStringList{"priority", "none", "none"}));
    m_controller->selectMainPaneMode(TaskLogic::MainPaneMode::List);
    m_controller->selectListGroup(QStringLiteral("priority"));
    QCOMPARE(m_controller->sortMode(), QStringLiteral("due,title"));
    QCOMPARE(stored(QStringLiteral("listGroupMode")).toString(), QStringLiteral("priority"));
    QVERIFY(!m_controller->sortLevelOptions().first().toStringList().contains(QStringLiteral("priority")));

    // Global scope: one stored sort.
    m_controller->selectMainPaneMode(TaskLogic::MainPaneMode::List);
    SharedSettings::instance()->store(QStringLiteral("sortScope"), TaskLogic::SortScope::Global);
    m_controller->selectSort(QStringLiteral("title"));
    QCOMPARE(stored(QStringLiteral("sortMode")).toString(), QStringLiteral("title"));
}

void TaskControllerStoreTest::sessionFollowsSmartViewMode()
{
    QQmlPropertyMap config;
    fillDefaults(&config);
    SharedSettings::instance()->store(QStringLiteral("smartViews"),
            QStringLiteral(R"([{"id":"w","name":"W","mode":"plan"},{"id":"n","name":"N"}])"));
    m_controller->startSession(&config);

    m_controller->setCurrentView(QStringLiteral("smart:w"));
    QCOMPARE(m_controller->mainPaneMode(), TaskLogic::MainPaneMode::Plan);
    QCOMPARE(stored(QStringLiteral("mainPaneMode")).toString(), TaskLogic::MainPaneMode::Plan);

    // Without a mode the current one stays.
    m_controller->setCurrentView(QStringLiteral("smart:n"));
    QCOMPARE(m_controller->mainPaneMode(), TaskLogic::MainPaneMode::Plan);
}

void TaskControllerStoreTest::newTaskTargetAndProjectLists()
{
    QQmlPropertyMap config;
    fillDefaults(&config);
    SharedSettings *settings = SharedSettings::instance();
    auto ids = [](const QVariantList &rows) {
        QList<qint64> out;
        for (const QVariant &row : rows) {
            out.append(row.toMap().value(QStringLiteral("collectionId")).toLongLong());
        }
        return out;
    };

    // Two writable projects, "ask": the user chooses.
    QVariantMap target = m_controller->newTaskTarget();
    QVERIFY(target.value(QStringLiteral("ask")).toBool());
    QCOMPARE(ids(target.value(QStringLiteral("choices")).toList()), (QList<qint64>{10, 20}));

    // A selected project wins.
    m_controller->setSelectedCollectionId(20);
    QCOMPARE(m_controller->newTaskTarget().value(QStringLiteral("collectionId")).toLongLong(), qint64(20));
    m_controller->setSelectedCollectionId(-1);

    // Fixed default project.
    settings->store(QStringLiteral("newTaskProjectMode"), QStringLiteral("fixed"));
    settings->store(QStringLiteral("newTaskDefaultCollectionId"), QStringLiteral("20"));
    target = m_controller->newTaskTarget();
    QVERIFY(!target.value(QStringLiteral("ask")).toBool());
    QCOMPARE(target.value(QStringLiteral("collectionId")).toLongLong(), qint64(20));

    // Hidden projects leave the lists; the only one left needs no question.
    settings->store(QStringLiteral("newTaskProjectMode"), QStringLiteral("ask"));
    settings->store(QStringLiteral("hiddenProjects"), QStringLiteral("10"));
    QCOMPARE(ids(m_controller->writableProjects()), QList<qint64>{20});
    target = m_controller->newTaskTarget();
    QVERIFY(!target.value(QStringLiteral("ask")).toBool());
    QCOMPARE(target.value(QStringLiteral("collectionId")).toLongLong(), qint64(20));
    QCOMPARE(ids(m_controller->projectChoices(-1, QStringLiteral("all"))), (QList<qint64>{10, 20}));
    // Sidebar scope: no tasks yet, so only the current project stays.
    QCOMPARE(ids(m_controller->projectChoices(10, QStringLiteral("sidebar"))), QList<qint64>{10});

    settings->store(QStringLiteral("showEmptyProjects"), true);
    QCOMPARE(ids(m_controller->sidebarProjects()), QList<qint64>{20});
    settings->resetToDefaults();

    // Links: nothing to open for unknown tasks or tasks without one.
    QVERIFY(!m_controller->openJoinLink(999));
    m_controller->installTestTask(1, QStringLiteral("plain"), 10);
    QVERIFY(!m_controller->openMapLink(1));
}

QTEST_MAIN(TaskControllerStoreTest)
#include "taskcontroller_store_test.moc"
