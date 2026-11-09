// Performance benchmark for the task-list pipeline (not part of ctest).
//
//   cmake -B build -DKURRENT_BUILD_BENCH=ON && cmake --build build --target kurrent-perf-bench
//   build/tests/kurrent-perf-bench rebuildPhases   # each rebuild phase, fastest of 21 runs
//   build/tests/kurrent-perf-bench endToEnd        # four view switches until the list settles
//   build/tests/kurrent-perf-bench outputDigest    # one hash per view x sort x grouping
//
// Main-thread phases and the worker part (TaskLogic::computeTaskRebuild) are measured
// separately. Tasks are synthetic and deterministic: eight projects, a third subtasks,
// labels, due dates around today, some completed. For a before/after comparison build an
// older commit with this file in a second worktree, run both alternately (the machine is
// often busy) and diff the outputDigest lines: an optimisation must not change them.

#include "memorytaskstore.h"
#include "sharedsettings.h"
#include "taskcalendar.h"
#include "taskcontroller.h"
#include "tasklogic.h"

#include <Akonadi/Collection>

#include <KCalendarCore/Todo>

#include <QCryptographicHash>
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

class TaskControllerBench : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void init();
    void cleanup();

    void rebuildPhases_data();
    void rebuildPhases();
    void endToEnd_data();
    void endToEnd();
    void outputDigest();

private:
    void populate(int count);
    TaskController *m_controller = nullptr;
    MemoryTaskStore *m_store = nullptr;
};

void TaskControllerBench::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);
    qRegisterMetaType<AbstractTaskStore::Result>();
}

void TaskControllerBench::init()
{
    m_controller = new TaskController;
    m_controller->resetSharedStateForTest();
    m_store = new MemoryTaskStore;
    m_controller->setTaskStore(m_store);
    m_controller->setAkonadiAvailableForTest(true);
}

void TaskControllerBench::cleanup()
{
    m_controller->resetSharedStateForTest();
    delete m_controller;
    m_controller = nullptr;
}

void TaskControllerBench::populate(int count)
{
    QList<Akonadi::Collection> collections;
    for (int c = 0; c < 8; ++c) {
        Akonadi::Collection collection(100 + c);
        collection.setName(QStringLiteral("Project %1").arg(c));
        collection.setContentMimeTypes({QString::fromLatin1(KCalendarCore::Todo::todoMimeType())});
        collection.setRights(Akonadi::Collection::CanCreateItem | Akonadi::Collection::CanChangeItem
                             | Akonadi::Collection::CanDeleteItem);
        collections.append(collection);
    }
    m_controller->installTestCollections(collections);

    QRandomGenerator rng(42);
    const QDate today = QDate::currentDate();
    for (int i = 1; i <= count; ++i) {
        KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
        todo->setUid(QStringLiteral("bench-%1").arg(i));
        todo->setSummary(QStringLiteral("Task %1 about something important").arg(i));
        if (i % 4 == 0) {
            todo->setDescription(QStringLiteral("Notes for %1, call https://meet.example.org/r%1 later.").arg(i));
        }
        if (i > 10 && i % 3 == 0) {
            todo->setRelatedTo(QStringLiteral("bench-%1").arg(i - 1 - int(rng.bounded(5))));
        }
        if (rng.bounded(10) < 7) {
            todo->setDtDue(QDateTime(today.addDays(int(rng.bounded(120)) - 40), QTime(9 + int(rng.bounded(8)), 0)));
        }
        todo->setPriority(int(rng.bounded(10)));
        QStringList labels;
        for (int l = int(rng.bounded(4)); l > 0; --l) {
            const QString label = QStringLiteral("label-%1").arg(rng.bounded(20));
            if (!labels.contains(label)) {
                labels.append(label);
            }
        }
        todo->setCategories(labels);
        if (rng.bounded(5) == 0) {
            todo->setLocation(QStringLiteral("Room %1").arg(rng.bounded(6)));
        }
        if (rng.bounded(5) == 0) {
            todo->setCompleted(QDateTime::currentDateTime().addDays(-int(rng.bounded(30))));
        } else {
            todo->setPercentComplete(int(rng.bounded(5)) * 25 % 100);
        }
        m_controller->installTestTodo(i, todo, 100 + int(rng.bounded(8)));
    }
}

static void addSizes()
{
    QTest::addColumn<int>("count");
    QTest::newRow("500") << 500;
    QTest::newRow("2000") << 2000;
    QTest::newRow("5000") << 5000;
}

void TaskControllerBench::rebuildPhases_data()
{
    addSizes();
}

// Prints one line per phase: the fastest of 21 runs.
void TaskControllerBench::rebuildPhases()
{
    QFETCH(int, count);
    populate(count);
    m_controller->setListGroupMode(QStringLiteral("project"));
    TaskController &c = *m_controller;

    constexpr int runs = 21;
    // Minimum of many runs: robust against a busy machine.
    auto best = [](const QList<double> &v) { return *std::min_element(v.begin(), v.end()); };
    auto measure = [&](const char *name, const std::function<void()> &fn) {
        QList<double> samples;
        for (int r = 0; r < runs; ++r) {
            QElapsedTimer t;
            t.start();
            fn();
            samples.append(t.nsecsElapsed() / 1e6);
        }
        qInfo().noquote() << QStringLiteral("  %1 tasks  %2 %3 ms")
                                     .arg(count, 5)
                                     .arg(QString::fromLatin1(name), -28)
                                     .arg(best(samples), 8, 'f', 2);
    };

    QList<TaskEntry> all;
    measure("main: snapshotAllTasks", [&] { all = c.snapshotAllTasks(); });
    TaskLogic::TaskRebuildInput input;
    measure("main: buildRebuildInput", [&] { input = c.buildRebuildInput(all); });
    const QDate today = QDate::currentDate();
    TaskLogic::TaskRebuildOutput output;
    measure("worker: computeTaskRebuild", [&] { output = TaskLogic::computeTaskRebuild(input, today); });
    measure("  filterVisibleTasks", [&] { (void)TaskLogic::filterVisibleTasks(input.allTasks, input.filters, today); });
    measure("  flattenTree(all)", [&] { (void)TaskLogic::flattenTree(input.allTasks, input.sortMode, input.collapsedUids); });
    measure("main: collectionTaskCounts", [&] { (void)TaskLogic::collectionTaskCounts(output.allTasks); });
    measure("main: setTasks (reset)", [&] {
        c.m_taskModel.setTasks({}, true);
        c.m_taskModel.setTasks(output.tasks, true);
    });
    measure("main: setTasks (unchanged)", [&] { c.m_taskModel.setTasks(output.tasks); });
    measure("main: pendingRootCount", [&] { (void)TaskLogic::pendingRootCount(output.allTasks); });
    measure("main: collectAvailableLabels", [&] { (void)TaskLogic::collectAvailableLabels(output.allTasks, {}); });
    measure("main: collectAvailableLocations", [&] { (void)TaskLogic::collectAvailableLocations(output.allTasks, {}); });
    measure("worker: computeCounts", [&] { (void)TaskLogic::computeCounts(output.allTasks, input.filters, {}, today); });
    measure("main: updateCounts (apply)", [&] { c.updateCounts(output.counts); });
    measure("main: updateKanbanLayout", [&] { c.updateKanbanLayout(); });
    measure("main: updateEmptyKind", [&] { c.updateEmptyKind(); });
    measure("main: updateSyncingCount", [&] { c.updateSyncingCount(); });
}

void TaskControllerBench::endToEnd_data()
{
    addSizes();
}

// Wall time from a view switch until the list and the deferred tail are applied.
void TaskControllerBench::endToEnd()
{
    QFETCH(int, count);
    populate(count);
    QSignalSpy spy(m_controller, &TaskController::sidebarCountsChanged);
    auto settle = [&] {
        m_controller->rebuildTaskList();
        QElapsedTimer guard;
        guard.start();
        while (m_controller->listReorganizing() || m_controller->m_deferredTailPending) {
            QCoreApplication::processEvents(QEventLoop::AllEvents);
            if (guard.elapsed() > 3000) {
                qWarning() << "stuck: reorg" << m_controller->listReorganizing() << "tail"
                           << m_controller->m_deferredTailPending << "chunks" << m_controller->m_taskModel.chunksActive()
                           << "watcher" << m_controller->m_rebuildWatcher.isRunning() << "timer"
                           << m_controller->m_rebuildTimer.isActive() << "gen" << m_controller->m_rebuildGeneration;
                QFAIL("stuck");
            }
        }
    };
    settle();
    const QStringList views = {QStringLiteral("today"), QStringLiteral("inbox"), QStringLiteral("scheduled"),
                               QStringLiteral("completed")};
    QBENCHMARK {
        for (const QString &view : views) {
            m_controller->m_currentView = view;
            settle();
        }
    }
}

// One digest per view × sort × grouping over everything the rebuild produces.
// An optimisation must not change these lines: diff them before and after.
void TaskControllerBench::outputDigest()
{
    populate(1500);
    const QStringList views = {QStringLiteral("inbox"), QStringLiteral("today"), QStringLiteral("scheduled"),
                               QStringLiteral("overdue"), QStringLiteral("completed")};
    const QStringList sorts = {QStringLiteral("priority,due,title"), QStringLiteral("dueDesc,title"),
                               QStringLiteral("project,labelDesc"), QStringLiteral("status,progress,location")};
    const QStringList groups = {QString(), QStringLiteral("project"), QStringLiteral("label"),
                                QStringLiteral("priority"), QStringLiteral("due")};
    const QDate today = QDate::currentDate();
    for (const QString &view : views) {
        for (const QString &sort : sorts) {
            for (const QString &group : groups) {
                m_controller->m_currentView = view;
                m_controller->m_sortMode = sort;
                m_controller->m_listGroupMode = group;
                m_controller->m_collapsedUids = {QStringLiteral("bench-20"), QStringLiteral("bench-41")};
                const TaskLogic::TaskRebuildInput input =
                        m_controller->buildRebuildInput(m_controller->snapshotAllTasks());
                const TaskLogic::TaskRebuildOutput out = TaskLogic::computeTaskRebuild(input, today);
                QCryptographicHash hash(QCryptographicHash::Sha1);
                for (const TaskEntry &t : out.tasks) {
                    hash.addData(QStringLiteral("%1|%2|%3|%4|%5;").arg(t.uid).arg(t.indentLevel).arg(t.bucket)
                                         .arg(t.treeHidden).arg(t.joinUrl).toUtf8());
                }
                hash.addData(QByteArray::number(out.flatForCounts.size()));
                const TaskLogic::SidebarCounts counts = TaskLogic::computeCounts(
                        m_controller->m_countsExcludeCollapsed ? out.flatForCounts : out.allTasks, input.filters, {}, today);
                for (const QVariantMap &map : {counts.viewCounts, counts.sidebarProjects, counts.sidebarLabels,
                                               counts.sidebarPriorities, counts.sidebarProgress, counts.sidebarStatus,
                                               counts.sidebarSecrecy, counts.sidebarLocations, counts.totalLabels}) {
                    hash.addData(QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact));
                }
                qInfo().noquote() << QStringLiteral("digest %1 %2 %3 %4 rows=%5")
                                             .arg(view, sort, group.isEmpty() ? QStringLiteral("-") : group,
                                                  QString::fromLatin1(hash.result().toHex().left(12)))
                                             .arg(out.tasks.size());
            }
        }
    }
}

QTEST_MAIN(TaskControllerBench)
#include "perf_bench.moc"
