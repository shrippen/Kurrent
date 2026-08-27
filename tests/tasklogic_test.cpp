#include "tasklogic.h"

#include <QDate>
#include <QDateTime>
#include <QTime>
#include <QtTest>

namespace
{
TaskEntry makeTask(const QString &summary)
{
    TaskEntry task;
    task.summary = summary;
    return task;
}
} // namespace

class TaskLogicTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void priorityBand_data();
    void priorityBand();

    void matchesSearch_data();
    void matchesSearch();

    void matchesViewTodayIncludesOverdueIncomplete();
    void matchesViewTodayExcludesOverdueComplete();
    void matchesViewTomorrowAndAnytime();

    void matchesFiltersByProjectLabelPriority();

    void compareTasksPriorityThenTitle();
    void compareTasksDuePutsUndatedLast();
    void compareTasksDescending();

    void parentCycleDetection();

    void searchFiltersViewCounts();
    void completedViewCountIgnoresShowCompletedFlag();

    void firstSidebarProjectPrefersNonEmpty();
    void resolveNewTaskTargetModes();

    void dragProxyGapAndClamp();

    void flattenTreeParentsAndOrphans();
    void flattenTreeSortsSiblings();
    void flattenTreeSkipsCycles();
    void flattenTreeHidesCollapsedChildren();

    void emptyKindStates();
    void panelBadgeAndDefaultDue();
    void sidebarWidthAndOverlayDim();
    void undoStackReplacesPrevious();

    void filterVisibleTasksCompletedAndSearch();
    void filterVisibleTasksCompletedView();
    void filterVisibleTasksKeepsHierarchy();

    void collectionCountsPendingAndLabels();
    void labelMutationsAndCreateGuard();
    void renameLabelAndHiddenTokens();
    void descendantUidsWalkChildren();
    void colorMapRoundTrip();
    void searchTitleOnlyIgnoresDescription();
    void searchCaseSensitiveMatch();
    void orderedKeysQuietHoursAndRelativeDue();

    void hiddenTokensAndEnabledCsv();
    void sidebarVisibilityAndLayout();
    void viewIconsStatusRecurrencePriority();
    void cursorAndDragLimits();
    void dateTimeTokensAndIsoParse();

    void todayCatchUpIncludesAllOverdue();
    void catchUpMatchesOverdueAndDisabled();
    void dayPartsAndListBuckets();
    void reschedulePresets();
    void joinUrlExtraction();
    void parseQuickAddTokens();
    void parseQuickAddFuzzyLanguageAndProjects();
    void suggestQuickAddScoresAndTypos();
};

void TaskLogicTest::priorityBand_data()
{
    QTest::addColumn<int>("priority");
    QTest::addColumn<int>("band");

    QTest::newRow("none") << 0 << 0;
    QTest::newRow("negative") << -1 << 0;
    QTest::newRow("high-1") << 1 << 1;
    QTest::newRow("high-3") << 3 << 1;
    QTest::newRow("medium-4") << 4 << 5;
    QTest::newRow("medium-6") << 6 << 5;
    QTest::newRow("low-7") << 7 << 9;
    QTest::newRow("low-9") << 9 << 9;
    QTest::newRow("out-of-range") << 12 << 0;
}

void TaskLogicTest::priorityBand()
{
    QFETCH(int, priority);
    QFETCH(int, band);
    QCOMPARE(TaskLogic::priorityBand(priority), band);
}

void TaskLogicTest::matchesSearch_data()
{
    QTest::addColumn<QString>("summary");
    QTest::addColumn<QString>("description");
    QTest::addColumn<QString>("collection");
    QTest::addColumn<QStringList>("labels");
    QTest::addColumn<QString>("query");
    QTest::addColumn<bool>("matches");

    QTest::newRow("empty-query")
        << QStringLiteral("Buy milk") << QString() << QString() << QStringList() << QString() << true;
    QTest::newRow("summary-case")
        << QStringLiteral("Buy Milk") << QString() << QString() << QStringList()
        << QStringLiteral("milk") << true;
    QTest::newRow("description")
        << QStringLiteral("Errand") << QStringLiteral("Need oat milk") << QString() << QStringList()
        << QStringLiteral("oat") << true;
    QTest::newRow("project")
        << QStringLiteral("Errand") << QString() << QStringLiteral("Groceries") << QStringList()
        << QStringLiteral("groc") << true;
    QTest::newRow("label")
        << QStringLiteral("Errand") << QString() << QString() << QStringList{QStringLiteral("home")}
        << QStringLiteral("HOME") << true;
    QTest::newRow("no-match")
        << QStringLiteral("Call dentist") << QString() << QString() << QStringList()
        << QStringLiteral("milk") << false;
}

void TaskLogicTest::matchesSearch()
{
    QFETCH(QString, summary);
    QFETCH(QString, description);
    QFETCH(QString, collection);
    QFETCH(QStringList, labels);
    QFETCH(QString, query);
    QFETCH(bool, matches);

    TaskEntry task = makeTask(summary);
    task.description = description;
    task.collectionName = collection;
    task.categories = labels;
    QCOMPARE(TaskLogic::matchesSearch(task, query, 
        TaskLogic::SearchScope::All, TaskLogic::SearchCase::Insensitive), matches);
}

void TaskLogicTest::matchesViewTodayIncludesOverdueIncomplete()
{
    const QDate today(2026, 8, 13);
    TaskEntry overdue = makeTask(QStringLiteral("Overdue"));
    overdue.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    overdue.completed = false;
    QVERIFY(!TaskLogic::matchesView(overdue, QStringLiteral("today"), today));
    QVERIFY(TaskLogic::matchesView(overdue, QStringLiteral("overdue"), today));
    QVERIFY(TaskLogic::matchesView(overdue, QStringLiteral("scheduled"), today));
}

void TaskLogicTest::matchesViewTodayExcludesOverdueComplete()
{
    const QDate today(2026, 8, 13);
    TaskEntry done = makeTask(QStringLiteral("Done yesterday"));
    done.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    done.completed = true;
    QVERIFY(!TaskLogic::matchesView(done, QStringLiteral("today"), today));
    QVERIFY(TaskLogic::matchesView(done, QStringLiteral("completed"), today));
}

void TaskLogicTest::matchesViewTomorrowAndAnytime()
{
    const QDate today(2026, 8, 13);
    TaskEntry tomorrow = makeTask(QStringLiteral("Tomorrow"));
    tomorrow.dueDate = QDateTime(QDate(2026, 8, 14), QTime(12, 0));
    QVERIFY(TaskLogic::matchesView(tomorrow, QStringLiteral("tomorrow"), today));
    QVERIFY(!TaskLogic::matchesView(tomorrow, QStringLiteral("today"), today));

    TaskEntry undated = makeTask(QStringLiteral("Someday"));
    QVERIFY(TaskLogic::matchesView(undated, QStringLiteral("anytime"), today));
    QVERIFY(!TaskLogic::matchesView(undated, QStringLiteral("scheduled"), today));
    QVERIFY(TaskLogic::matchesView(undated, QStringLiteral("inbox"), today));
}

void TaskLogicTest::matchesFiltersByProjectLabelPriority()
{
    TaskEntry task = makeTask(QStringLiteral("Work item"));
    task.collectionId = 7;
    task.categories = QStringList{QStringLiteral("office")};
    task.priority = 2;

    QVERIFY(TaskLogic::matchesFilters(task, -1, QString(), -1));
    QVERIFY(TaskLogic::matchesFilters(task, 7, QStringLiteral("office"), 1));
    QVERIFY(!TaskLogic::matchesFilters(task, 8, QString(), -1));
    QVERIFY(!TaskLogic::matchesFilters(task, -1, QStringLiteral("home"), -1));
    QVERIFY(!TaskLogic::matchesFilters(task, -1, QString(), 5));
}

void TaskLogicTest::compareTasksPriorityThenTitle()
{
    TaskEntry alpha = makeTask(QStringLiteral("Alpha"));
    alpha.priority = 5;
    TaskEntry beta = makeTask(QStringLiteral("Beta"));
    beta.priority = 1;
    TaskEntry none = makeTask(QStringLiteral("None"));
    none.priority = 0;

    QVERIFY(TaskLogic::compareTasks(beta, alpha, QStringLiteral("priority,title")) < 0);
    QVERIFY(TaskLogic::compareTasks(alpha, none, QStringLiteral("priority")) < 0);
    QVERIFY(TaskLogic::compareTasks(makeTask(QStringLiteral("a")), makeTask(QStringLiteral("B")), QStringLiteral("title")) < 0);
}

void TaskLogicTest::compareTasksDuePutsUndatedLast()
{
    TaskEntry dated = makeTask(QStringLiteral("Dated"));
    dated.dueDate = QDateTime(QDate(2026, 8, 13), QTime(9, 0));
    TaskEntry undated = makeTask(QStringLiteral("Undated"));

    QVERIFY(TaskLogic::compareTasks(dated, undated, QStringLiteral("due")) < 0);
}

void TaskLogicTest::compareTasksDescending()
{
    TaskEntry early = makeTask(QStringLiteral("Early"));
    early.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    TaskEntry late = makeTask(QStringLiteral("Late"));
    late.dueDate = QDateTime(QDate(2026, 8, 20), QTime(9, 0));
    TaskEntry undated = makeTask(QStringLiteral("Undated"));

    QVERIFY(TaskLogic::compareTasks(late, early, QStringLiteral("dueDesc")) < 0);
    // Undated stays last even for latest-first due.
    QVERIFY(TaskLogic::compareTasks(late, undated, QStringLiteral("dueDesc")) < 0);

    TaskEntry withReminder = makeTask(QStringLiteral("Alarm"));
    withReminder.reminderMinutes = 15;
    TaskEntry noReminder = makeTask(QStringLiteral("Quiet"));
    QVERIFY(TaskLogic::compareTasks(withReminder, noReminder, QStringLiteral("reminder")) < 0);
    QVERIFY(TaskLogic::compareTasks(noReminder, withReminder, QStringLiteral("reminderDesc")) < 0);

    TaskEntry recur = makeTask(QStringLiteral("Weekly"));
    recur.recurring = true;
    TaskEntry once = makeTask(QStringLiteral("Once"));
    QVERIFY(TaskLogic::compareTasks(recur, once, QStringLiteral("recurring")) < 0);
    QVERIFY(TaskLogic::compareTasks(once, recur, QStringLiteral("recurringDesc")) < 0);

    TaskEntry low = makeTask(QStringLiteral("Low"));
    low.percentComplete = 10;
    TaskEntry high = makeTask(QStringLiteral("High"));
    high.percentComplete = 90;
    QVERIFY(TaskLogic::compareTasks(low, high, QStringLiteral("progress")) < 0);
    QVERIFY(TaskLogic::compareTasks(high, low, QStringLiteral("progressDesc")) < 0);

    TaskEntry started = makeTask(QStringLiteral("Started"));
    started.startDate = QDateTime(QDate(2026, 8, 1), QTime(9, 0));
    TaskEntry notStarted = makeTask(QStringLiteral("Later"));
    QVERIFY(TaskLogic::compareTasks(started, notStarted, QStringLiteral("start")) < 0);
}

void TaskLogicTest::parentCycleDetection()
{
    QHash<QString, QString> parents;
    parents.insert(QStringLiteral("child"), QStringLiteral("parent"));
    parents.insert(QStringLiteral("parent"), QString());

    QVERIFY(!TaskLogic::wouldCreateParentCycle(QStringLiteral("child"), QStringLiteral("parent"), parents));
    QVERIFY(TaskLogic::wouldCreateParentCycle(QStringLiteral("parent"), QStringLiteral("child"), parents));
    QVERIFY(!TaskLogic::wouldCreateParentCycle(QStringLiteral("child"), QString(), parents));
    QVERIFY(TaskLogic::wouldCreateParentCycle(QString(), QStringLiteral("parent"), parents));
}

void TaskLogicTest::searchFiltersViewCounts()
{
    const QDate today(2026, 8, 13);
    TaskEntry milk = makeTask(QStringLiteral("Buy milk"));
    milk.collectionId = 1;
    TaskEntry dentist = makeTask(QStringLiteral("Call dentist"));
    dentist.collectionId = 1;

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("inbox");
    filters.searchQuery = QStringLiteral("milk");

    const TaskLogic::SidebarCounts counts = TaskLogic::computeCounts({milk, dentist}, filters, {}, today);
    QCOMPARE(counts.viewCounts.value(QStringLiteral("inbox")).toInt(), 1);
    QCOMPARE(counts.sidebarProjects.value(QStringLiteral("1")).toInt(), 1);
}

void TaskLogicTest::completedViewCountIgnoresShowCompletedFlag()
{
    const QDate today(2026, 8, 13);
    TaskEntry openTask = makeTask(QStringLiteral("Open"));
    TaskEntry doneTask = makeTask(QStringLiteral("Done"));
    doneTask.completed = true;

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("inbox");
    filters.showCompleted = false;

    const TaskLogic::SidebarCounts counts = TaskLogic::computeCounts({openTask, doneTask}, filters, {}, today);
    QCOMPARE(counts.viewCounts.value(QStringLiteral("inbox")).toInt(), 1);
    QCOMPARE(counts.viewCounts.value(QStringLiteral("completed")).toInt(), 1);
}

void TaskLogicTest::firstSidebarProjectPrefersNonEmpty()
{
    const QList<TaskLogic::ProjectCandidate> projects = {
        {10, true, 0},
        {20, true, 3},
        {30, false, 9},
    };
    QCOMPARE(TaskLogic::firstSidebarProjectId(projects, {}), qint64(20));
    QCOMPARE(TaskLogic::firstSidebarProjectId(projects, QSet<qint64>{20}), qint64(10));
}

void TaskLogicTest::resolveNewTaskTargetModes()
{
    const auto selected = TaskLogic::resolveNewTaskTarget(42, QStringLiteral("ask"), 7, TaskLogic::DefaultCollection::Exists, 3);
    QCOMPARE(selected.ask, false);
    QCOMPARE(selected.collectionId, qint64(42));

    const auto first = TaskLogic::resolveNewTaskTarget(-1, QStringLiteral("first"), 7, TaskLogic::DefaultCollection::Exists, 3);
    QCOMPARE(first.ask, false);
    QCOMPARE(first.collectionId, qint64(3));

    const auto fixed = TaskLogic::resolveNewTaskTarget(-1, QStringLiteral("fixed"), 7, TaskLogic::DefaultCollection::Exists, 3);
    QCOMPARE(fixed.ask, false);
    QCOMPARE(fixed.collectionId, qint64(7));

    const auto ask = TaskLogic::resolveNewTaskTarget(-1, QStringLiteral("ask"), 7, TaskLogic::DefaultCollection::Exists, 3);
    QVERIFY(ask.ask);
}

void TaskLogicTest::dragProxyGapAndClamp()
{
    const QPointF hand = TaskLogic::dragProxyGap(24, TaskLogic::CursorKind::Other);
    QCOMPARE(hand, QPointF(14, 14));
    const QPointF arrow = TaskLogic::dragProxyGap(24, TaskLogic::CursorKind::Arrow);
    QCOMPARE(arrow, QPointF(21, 5));

    const QPointF unclamped = TaskLogic::clampDragProxyOffset(100, 100, 14, 14, 180, 48, 1920, 1080);
    QCOMPARE(unclamped, QPointF(14, 14));

    const QPointF clampRight = TaskLogic::clampDragProxyOffset(1900, 100, 14, 14, 180, 48, 1920, 1080);
    QCOMPARE(clampRight.x(), 1920 - 180 - 1900);
    QCOMPARE(clampRight.y(), 14);

    const QPointF clampBottom = TaskLogic::clampDragProxyOffset(100, 1060, 14, 14, 180, 48, 1920, 1080);
    QCOMPARE(clampBottom.x(), 14);
    QCOMPARE(clampBottom.y(), 1080 - 48 - 1060);
}

void TaskLogicTest::flattenTreeParentsAndOrphans()
{
    TaskEntry root = makeTask(QStringLiteral("Root"));
    root.uid = QStringLiteral("root");
    root.itemId = 1;
    TaskEntry child = makeTask(QStringLiteral("Child"));
    child.uid = QStringLiteral("child");
    child.parentUid = QStringLiteral("root");
    child.itemId = 2;
    TaskEntry grandchild = makeTask(QStringLiteral("Grand"));
    grandchild.uid = QStringLiteral("grand");
    grandchild.parentUid = QStringLiteral("child");
    grandchild.itemId = 3;

    const QList<TaskEntry> flat = TaskLogic::flattenTree({child, grandchild, root}, QStringLiteral("default"));
    QCOMPARE(flat.size(), 3);
    QCOMPARE(flat.at(0).uid, QStringLiteral("root"));
    QCOMPARE(flat.at(0).indentLevel, 0);
    QVERIFY(flat.at(0).hasChildren);
    QCOMPARE(flat.at(1).uid, QStringLiteral("child"));
    QCOMPARE(flat.at(1).indentLevel, 1);
    QVERIFY(flat.at(1).hasChildren);
    QCOMPARE(flat.at(2).uid, QStringLiteral("grand"));
    QCOMPARE(flat.at(2).indentLevel, 2);
    QVERIFY(!flat.at(2).hasChildren);

    TaskEntry orphan = makeTask(QStringLiteral("Orphan"));
    orphan.uid = QStringLiteral("orphan");
    orphan.parentUid = QStringLiteral("missing");
    const QList<TaskEntry> orphans = TaskLogic::flattenTree({orphan}, QStringLiteral("default"));
    QCOMPARE(orphans.size(), 1);
    QCOMPARE(orphans.at(0).indentLevel, 0);
}

void TaskLogicTest::flattenTreeSortsSiblings()
{
    TaskEntry parent = makeTask(QStringLiteral("Parent"));
    parent.uid = QStringLiteral("p");
    parent.itemId = 1;
    TaskEntry b = makeTask(QStringLiteral("B"));
    b.uid = QStringLiteral("b");
    b.parentUid = QStringLiteral("p");
    b.itemId = 2;
    TaskEntry a = makeTask(QStringLiteral("A"));
    a.uid = QStringLiteral("a");
    a.parentUid = QStringLiteral("p");
    a.itemId = 3;

    const QList<TaskEntry> flat = TaskLogic::flattenTree({parent, b, a}, QStringLiteral("title"));
    QCOMPARE(flat.at(1).summary, QStringLiteral("A"));
    QCOMPARE(flat.at(2).summary, QStringLiteral("B"));
}

void TaskLogicTest::flattenTreeSkipsCycles()
{
    TaskEntry a = makeTask(QStringLiteral("A"));
    a.uid = QStringLiteral("a");
    a.parentUid = QStringLiteral("b");
    TaskEntry b = makeTask(QStringLiteral("B"));
    b.uid = QStringLiteral("b");
    b.parentUid = QStringLiteral("a");
    const QList<TaskEntry> flat = TaskLogic::flattenTree({a, b}, QStringLiteral("default"));
    QVERIFY(flat.size() <= 2);
}

void TaskLogicTest::flattenTreeHidesCollapsedChildren()
{
    TaskEntry root = makeTask(QStringLiteral("Root"));
    root.uid = QStringLiteral("root");
    TaskEntry child = makeTask(QStringLiteral("Child"));
    child.uid = QStringLiteral("child");
    child.parentUid = QStringLiteral("root");
    TaskEntry grand = makeTask(QStringLiteral("Grand"));
    grand.uid = QStringLiteral("grand");
    grand.parentUid = QStringLiteral("child");
    TaskEntry sibling = makeTask(QStringLiteral("Zebra"));
    sibling.uid = QStringLiteral("other");

    const QList<TaskEntry> collapsed = TaskLogic::flattenTree({root, child, grand, sibling},
                                                              QStringLiteral("title"),
                                                              {QStringLiteral("root")});
    QCOMPARE(collapsed.size(), 2);
    QCOMPARE(collapsed.at(0).uid, QStringLiteral("root"));
    QVERIFY(collapsed.at(0).hasChildren);
    QVERIFY(collapsed.at(0).treeCollapsed);
    QVERIFY(!collapsed.at(0).treeHidden);
    QCOMPARE(collapsed.at(1).uid, QStringLiteral("other"));
    QVERIFY(!collapsed.at(1).treeCollapsed);
    QVERIFY(!collapsed.at(1).treeHidden);

    const QList<TaskEntry> open = TaskLogic::flattenTree({root, child, grand, sibling},
                                                         QStringLiteral("title"),
                                                         {});
    QCOMPARE(open.size(), 4);
    QVERIFY(!open.at(0).treeCollapsed);
    QVERIFY(!open.at(1).treeHidden);
}

void TaskLogicTest::emptyKindStates()
{
    using LS = TaskLogic::LoadState;
    using BS = TaskLogic::BackendState;
    using EP = TaskLogic::ErrorPresence;
    QCOMPARE(TaskLogic::emptyKind(LS::Idle, BS::Online, 2, 3, EP::None), QString());
    QCOMPARE(TaskLogic::emptyKind(LS::Loading, BS::Offline, 0, 0, EP::Present), QStringLiteral("loading"));
    QCOMPARE(TaskLogic::emptyKind(LS::Loading, BS::Online, 0, 0, EP::None), QStringLiteral("loading"));
    QCOMPARE(TaskLogic::emptyKind(LS::Idle, BS::Offline, 0, 0, EP::None), QStringLiteral("offline"));
    QCOMPARE(TaskLogic::emptyKind(LS::Idle, BS::Online, 0, 0, EP::None), QStringLiteral("no-collections"));
    QCOMPARE(TaskLogic::emptyKind(LS::Idle, BS::Online, 2, 0, EP::Present), QStringLiteral("error"));
    QCOMPARE(TaskLogic::emptyKind(LS::Idle, BS::Online, 2, 0, EP::None), QStringLiteral("empty"));
}

void TaskLogicTest::panelBadgeAndDefaultDue()
{
    QCOMPARE(TaskLogic::panelBadgeCount(QStringLiteral("off"), 4, 2, 1), 0);
    QCOMPARE(TaskLogic::panelBadgeCount(QStringLiteral("open"), 4, 2, 1), 4);
    QCOMPARE(TaskLogic::panelBadgeCount(QStringLiteral("today"), 4, 2, 1), 2);
    QCOMPARE(TaskLogic::panelBadgeCount(QStringLiteral("overdue"), 4, 2, 1), 1);
    QCOMPARE(TaskLogic::panelBadgeCount(QStringLiteral("unknown"), 4, 2, 1), 4);

    const QDate today(2026, 8, 17);
    QVERIFY(!TaskLogic::defaultDueForMode(QStringLiteral("none"), today).isValid());
    QCOMPARE(TaskLogic::defaultDueForMode(QStringLiteral("today"), today).date(), today);
    QCOMPARE(TaskLogic::defaultDueForMode(QStringLiteral("tomorrow"), today).date(), QDate(2026, 8, 18));
}

void TaskLogicTest::sidebarWidthAndOverlayDim()
{
    QCOMPARE(TaskLogic::clampSidebarWidthUnits(3), 6);
    QCOMPARE(TaskLogic::clampSidebarWidthUnits(10), 10);
    QCOMPARE(TaskLogic::clampSidebarWidthUnits(99), 20);
    QCOMPARE(TaskLogic::overlayDimForStep(0), 0.25);
    QCOMPARE(TaskLogic::overlayDimForStep(1), 0.40);
    QCOMPARE(TaskLogic::overlayDimForStep(2), 0.55);
}

void TaskLogicTest::undoStackReplacesPrevious()
{
    TaskLogic::UndoStack stack;
    QVERIFY(!stack.canUndo());
    QCOMPARE(TaskLogic::undoKindName(TaskLogic::UndoRecord::Kind::None), QString());

    TaskLogic::UndoRecord complete;
    complete.kind = TaskLogic::UndoRecord::Kind::Complete;
    complete.itemId = 7;
    complete.completed = false;
    stack.push(complete);
    QVERIFY(stack.canUndo());
    QCOMPARE(stack.peek().itemId, qint64(7));
    QCOMPARE(TaskLogic::undoKindName(stack.peek().kind), QStringLiteral("complete"));

    TaskLogic::UndoRecord reschedule;
    reschedule.kind = TaskLogic::UndoRecord::Kind::Reschedule;
    reschedule.itemId = 9;
    reschedule.hadDue = true;
    stack.push(reschedule);
    QCOMPARE(stack.peek().itemId, qint64(9));
    QCOMPARE(TaskLogic::undoKindName(stack.peek().kind), QStringLiteral("reschedule"));

    const TaskLogic::UndoRecord taken = stack.take();
    QCOMPARE(taken.itemId, qint64(9));
    QVERIFY(!stack.canUndo());
    QVERIFY(stack.take().kind == TaskLogic::UndoRecord::Kind::None);
}

void TaskLogicTest::filterVisibleTasksCompletedAndSearch()
{
    const QDate today(2026, 8, 13);
    TaskEntry openTask = makeTask(QStringLiteral("Open milk"));
    openTask.uid = QStringLiteral("open");
    TaskEntry doneTask = makeTask(QStringLiteral("Done milk"));
    doneTask.uid = QStringLiteral("done");
    doneTask.completed = true;
    TaskEntry other = makeTask(QStringLiteral("Call dentist"));
    other.uid = QStringLiteral("other");

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("inbox");
    filters.searchQuery = QStringLiteral("milk");

    const auto hiddenCompleted = TaskLogic::filterVisibleTasks({openTask, doneTask, other}, filters, today);
    QCOMPARE(hiddenCompleted.tasks.size(), 1);
    QCOMPARE(hiddenCompleted.filteredOutCompleted, 1);
    QCOMPARE(hiddenCompleted.filteredOutSearch, 1);

    // showCompleted must not mix done tasks into non-Completed views.
    filters.showCompleted = true;
    const auto stillHidden = TaskLogic::filterVisibleTasks({openTask, doneTask, other}, filters, today);
    QCOMPARE(stillHidden.tasks.size(), 1);
    QCOMPARE(stillHidden.filteredOutCompleted, 1);
}

void TaskLogicTest::filterVisibleTasksCompletedView()
{
    const QDate today(2026, 8, 13);
    TaskEntry openTask = makeTask(QStringLiteral("Open"));
    openTask.uid = QStringLiteral("open");
    TaskEntry doneTask = makeTask(QStringLiteral("Done"));
    doneTask.uid = QStringLiteral("done");
    doneTask.completed = true;

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("completed");

    const auto result = TaskLogic::filterVisibleTasks({openTask, doneTask}, filters, today);
    QCOMPARE(result.tasks.size(), 1);
    QCOMPARE(result.tasks.at(0).summary, QStringLiteral("Done"));
    QCOMPARE(result.filteredOutView, 1);
}

void TaskLogicTest::filterVisibleTasksKeepsHierarchy()
{
    const QDate today(2026, 8, 13);
    TaskEntry parent = makeTask(QStringLiteral("IT für Freunde"));
    parent.uid = QStringLiteral("parent");
    parent.itemId = 1;
    TaskEntry alem = makeTask(QStringLiteral("Alem"));
    alem.uid = QStringLiteral("alem");
    alem.itemId = 2;
    alem.parentUid = QStringLiteral("parent");
    alem.completed = true;
    TaskEntry sofia = makeTask(QStringLiteral("Sofia IT"));
    sofia.uid = QStringLiteral("sofia");
    sofia.itemId = 3;
    sofia.parentUid = QStringLiteral("parent");
    TaskEntry other = makeTask(QStringLiteral("Unrelated"));
    other.uid = QStringLiteral("other");
    other.itemId = 4;

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("inbox");

    filters.searchQuery = QStringLiteral("Freunde");
    auto byParent = TaskLogic::filterVisibleTasks({parent, alem, sofia, other}, filters, today);
    QCOMPARE(byParent.tasks.size(), 2);
    QStringList byParentUids;
    for (const TaskEntry &t : byParent.tasks) {
        byParentUids.append(t.uid);
    }
    QVERIFY(byParentUids.contains(QStringLiteral("parent")));
    QVERIFY(byParentUids.contains(QStringLiteral("sofia")));
    QVERIFY(!byParentUids.contains(QStringLiteral("alem")));
    QVERIFY(!byParentUids.contains(QStringLiteral("other")));

    filters.searchQuery = QStringLiteral("Sofia");
    auto byChild = TaskLogic::filterVisibleTasks({parent, alem, sofia, other}, filters, today);
    QCOMPARE(byChild.tasks.size(), 2);
    QStringList byChildUids;
    for (const TaskEntry &t : byChild.tasks) {
        byChildUids.append(t.uid);
    }
    QVERIFY(byChildUids.contains(QStringLiteral("parent")));
    QVERIFY(byChildUids.contains(QStringLiteral("sofia")));
    QVERIFY(!byChildUids.contains(QStringLiteral("alem")));

    filters.currentView = QStringLiteral("completed");
    filters.searchQuery.clear();
    auto completed = TaskLogic::filterVisibleTasks({parent, alem, sofia, other}, filters, today);
    QCOMPARE(completed.tasks.size(), 2);
    QStringList completedUids;
    for (const TaskEntry &t : completed.tasks) {
        completedUids.append(t.uid);
    }
    QVERIFY(completedUids.contains(QStringLiteral("alem")));
    QVERIFY(completedUids.contains(QStringLiteral("parent")));
    QVERIFY(!completedUids.contains(QStringLiteral("sofia")));
    QVERIFY(!completedUids.contains(QStringLiteral("other")));
}

void TaskLogicTest::collectionCountsPendingAndLabels()
{
    TaskEntry root = makeTask(QStringLiteral("Root"));
    root.collectionId = 1;
    root.categories = QStringList{QStringLiteral("home"), QStringLiteral("work")};
    TaskEntry child = makeTask(QStringLiteral("Child"));
    child.collectionId = 1;
    child.indentLevel = 1;
    TaskEntry other = makeTask(QStringLiteral("Other"));
    other.collectionId = 2;
    other.completed = true;
    other.categories = QStringList{QStringLiteral("home")};

    const QHash<qint64, int> counts = TaskLogic::collectionTaskCounts({root, child, other});
    QCOMPARE(counts.value(1), 2);
    QCOMPARE(counts.value(2), 1);
    // Collapsed list omits the child — used when countsExcludeCollapsed is on.
    QCOMPARE(TaskLogic::collectionTaskCounts({root, other}).value(1), 1);
    QCOMPARE(TaskLogic::pendingRootCount({root, child, other}), 1);

    const QStringList labels = TaskLogic::collectAvailableLabels({root, other}, {QStringLiteral("extra"), QString()});
    QCOMPARE(labels, QStringList({QStringLiteral("extra"), QStringLiteral("home"), QStringLiteral("work")}));
}

void TaskLogicTest::labelMutationsAndCreateGuard()
{
    QVERIFY(TaskLogic::canCreateLabel(QStringLiteral("new"), {}, {}));
    QVERIFY(!TaskLogic::canCreateLabel(QStringLiteral("  "), {}, {}));
    QVERIFY(!TaskLogic::canCreateLabel(QStringLiteral("home"), {QStringLiteral("home")}, {}));
    QVERIFY(!TaskLogic::canCreateLabel(QStringLiteral("home"), {}, {QStringLiteral("home")}));

    const QStringList added = TaskLogic::addLabel({QStringLiteral("a")}, QStringLiteral(" b "));
    QCOMPARE(added, QStringList({QStringLiteral("a"), QStringLiteral("b")}));
    QCOMPARE(TaskLogic::addLabel(added, QStringLiteral("a")), added);
    QCOMPARE(TaskLogic::removeLabel(added, QStringLiteral("a")), QStringList({QStringLiteral("b")}));
    QVERIFY(TaskLogic::containsLabel(added, QStringLiteral("a")));
}

void TaskLogicTest::renameLabelAndHiddenTokens()
{
    QCOMPARE(TaskLogic::renameLabel({QStringLiteral("home"), QStringLiteral("work")},
                                    QStringLiteral("home"), QStringLiteral("errands")),
             QStringList({QStringLiteral("work"), QStringLiteral("errands")}));
    QCOMPARE(TaskLogic::renameLabel({QStringLiteral("home")}, QStringLiteral("missing"), QStringLiteral("x")),
             QStringList({QStringLiteral("home")}));
    QCOMPARE(TaskLogic::renameLabel({QStringLiteral("a"), QStringLiteral("b")}, QStringLiteral("a"), QStringLiteral("b")),
             QStringList({QStringLiteral("b")}));
    QVERIFY(TaskLogic::canRenameLabel(QStringLiteral("home"), QStringLiteral("errands"),
                                      {QStringLiteral("home")}, {}));
    QVERIFY(!TaskLogic::canRenameLabel(QStringLiteral("home"), QStringLiteral("home"),
                                       {QStringLiteral("home")}, {}));
    QCOMPARE(TaskLogic::renameToken(QStringLiteral("home||work"), QStringLiteral("home"),
                                    QStringLiteral("errands"), QStringLiteral("||")),
             QStringLiteral("work||errands"));
}

void TaskLogicTest::descendantUidsWalkChildren()
{
    QHash<QString, QString> parentByUid;
    parentByUid.insert(QStringLiteral("child"), QStringLiteral("root"));
    parentByUid.insert(QStringLiteral("grand"), QStringLiteral("child"));
    parentByUid.insert(QStringLiteral("other"), QString());
    const QStringList kids = TaskLogic::descendantUids(QStringLiteral("root"), parentByUid);
    QVERIFY(kids.contains(QStringLiteral("child")));
    QVERIFY(kids.contains(QStringLiteral("grand")));
    QVERIFY(!kids.contains(QStringLiteral("other")));
    QCOMPARE(TaskLogic::descendantUids(QStringLiteral("missing"), parentByUid).size(), 0);
}

void TaskLogicTest::colorMapRoundTrip()
{
    QVERIFY(TaskLogic::isHexColor(QStringLiteral("#aabbcc")));
    QVERIFY(!TaskLogic::isHexColor(QStringLiteral("aabbcc")));
    QVERIFY(!TaskLogic::isHexColor(QStringLiteral("#gg0000")));
    const QString stored = TaskLogic::setColorOverride(QString(), QStringLiteral("11"), QStringLiteral("#CC3333"));
    QCOMPARE(TaskLogic::parseColorMap(stored).value(QStringLiteral("11")).toString(), QStringLiteral("#cc3333"));
    const QString cleared = TaskLogic::setColorOverride(stored, QStringLiteral("11"), QString());
    QVERIFY(cleared.isEmpty());
}

void TaskLogicTest::searchTitleOnlyIgnoresDescription()
{
    TaskEntry task = makeTask(QStringLiteral("Errand"));
    task.description = QStringLiteral("Need oat milk");
    QVERIFY(TaskLogic::matchesSearch(task, QStringLiteral("oat"), TaskLogic::SearchScope::All, TaskLogic::SearchCase::Insensitive));
    QVERIFY(!TaskLogic::matchesSearch(task, QStringLiteral("oat"), TaskLogic::SearchScope::TitleOnly, TaskLogic::SearchCase::Insensitive));
    QVERIFY(TaskLogic::matchesSearch(task, QStringLiteral("errand"), TaskLogic::SearchScope::TitleOnly, TaskLogic::SearchCase::Insensitive));
}

void TaskLogicTest::searchCaseSensitiveMatch()
{
    TaskEntry task = makeTask(QStringLiteral("Buy Milk"));
    QVERIFY(TaskLogic::matchesSearch(task, QStringLiteral("milk"), TaskLogic::SearchScope::All, TaskLogic::SearchCase::Insensitive));
    QVERIFY(!TaskLogic::matchesSearch(task, QStringLiteral("milk"), TaskLogic::SearchScope::All, TaskLogic::SearchCase::Sensitive));
    QVERIFY(TaskLogic::matchesSearch(task, QStringLiteral("Milk"), TaskLogic::SearchScope::All, TaskLogic::SearchCase::Sensitive));
}

void TaskLogicTest::orderedKeysQuietHoursAndRelativeDue()
{
    const QStringList defaults = TaskLogic::defaultSidebarSections();
    QCOMPARE(TaskLogic::mergeOrderedKeys({QStringLiteral("labels"), QStringLiteral("nope")}, defaults).first(),
             QStringLiteral("labels"));
    QCOMPARE(TaskLogic::mergeOrderedKeys({}, defaults), defaults);
    const QStringList hidden{QStringLiteral("priorities")};
    QVERIFY(!TaskLogic::visibleOrderedKeys(defaults, hidden).contains(QStringLiteral("priorities")));
    QCOMPARE(TaskLogic::moveOrderedKey(defaults, QStringLiteral("views"), 1).first(), QStringLiteral("projects"));

    const QDate today(2026, 8, 17);
    QCOMPARE(TaskLogic::relativeDueKind(today, today), QStringLiteral("today"));
    QCOMPARE(TaskLogic::relativeDueKind(today.addDays(1), today), QStringLiteral("tomorrow"));
    QCOMPARE(TaskLogic::relativeDueKind(today.addDays(-1), today), QStringLiteral("yesterday"));
    QCOMPARE(TaskLogic::relativeDueKind(today.addDays(3), today), QStringLiteral("date"));

    QVERIFY(!TaskLogic::inQuietHours(QTime(21, 0), 22, 7, TaskLogic::QuietHoursMode::Enabled));
    QVERIFY(TaskLogic::inQuietHours(QTime(23, 0), 22, 7, TaskLogic::QuietHoursMode::Enabled));
    QVERIFY(TaskLogic::inQuietHours(QTime(3, 0), 22, 7, TaskLogic::QuietHoursMode::Enabled));
    QVERIFY(!TaskLogic::inQuietHours(QTime(8, 0), 22, 7, TaskLogic::QuietHoursMode::Enabled));
    QVERIFY(!TaskLogic::inQuietHours(QTime(23, 0), 22, 7, TaskLogic::QuietHoursMode::Disabled));
    QVERIFY(!TaskLogic::inQuietHours(QTime(12, 0), 9, 9, TaskLogic::QuietHoursMode::Enabled));
}

void TaskLogicTest::hiddenTokensAndEnabledCsv()
{
    QCOMPARE(TaskLogic::parseTokens(QStringLiteral(" 1, 2,,3 "), QStringLiteral(",")),
             QStringList({QStringLiteral("1"), QStringLiteral("2"), QStringLiteral("3")}));
    QVERIFY(TaskLogic::tokenSetContains(QStringLiteral("11,22"), QStringLiteral("22"), QStringLiteral(",")));
    QVERIFY(!TaskLogic::tokenSetContains(QString(), QStringLiteral("22"), QStringLiteral(",")));
    QCOMPARE(TaskLogic::toggleToken(QStringLiteral("a||b"), QStringLiteral("b"), QStringLiteral("||")),
             QStringLiteral("a"));
    QCOMPARE(TaskLogic::toggleToken(QStringLiteral("a"), QStringLiteral("b"), QStringLiteral("||")),
             QStringLiteral("a||b"));

    const QList<qint64> all = {10, 20, 30};
    QVERIFY(TaskLogic::isEnabledCsv(QString(), 10));
    const QString without20 = TaskLogic::toggleEnabledCsv(QString(), 20, all);
    QCOMPARE(without20, QStringLiteral("10,30"));
    QVERIFY(!TaskLogic::isEnabledCsv(without20, 20));
    QVERIFY(TaskLogic::isEnabledCsv(without20, 10));
    QCOMPARE(TaskLogic::toggleEnabledCsv(without20, 20, all), QString());
    QCOMPARE(TaskLogic::toggleEnabledCsv(QStringLiteral("10,20,30"), 10, all), QStringLiteral("20,30"));
}

void TaskLogicTest::sidebarVisibilityAndLayout()
{
    const QList<TaskLogic::ProjectCandidate> projects = {
        {10, true, 0},
        {20, true, 2},
        {30, true, 4},
    };
    QCOMPARE(TaskLogic::visibleProjectCount(projects, {}), 2);
    QCOMPARE(TaskLogic::visibleProjectCount(projects, QSet<qint64>{20}), 1);
    QCOMPARE(TaskLogic::visibleLabelCount({QStringLiteral("a"), QStringLiteral("b")}, {QStringLiteral("a")}), 1);

    QCOMPARE(TaskLogic::naturalListHeight(3, TaskLogic::ListHeader::Yes, 10, 20, 1), 10 + 60 + 3);
    QCOMPARE(TaskLogic::naturalListHeight(0, TaskLogic::ListHeader::No, 10, 20, 1), 0);

    const QList<int> alloc = TaskLogic::redistributeSections(400, {80, 80, 80, 80});
    QCOMPARE(alloc.size(), 4);
    QCOMPARE(alloc.at(0), 80);
    QCOMPARE(alloc.at(0) + alloc.at(1) + alloc.at(2) + alloc.at(3), 320);

    const QList<int> squeezed = TaskLogic::redistributeSections(100, {80, 80, 80, 80});
    QCOMPARE(squeezed.size(), 4);
    QCOMPARE(squeezed.at(0) + squeezed.at(1) + squeezed.at(2) + squeezed.at(3), 100);
    QCOMPARE(TaskLogic::redistributeSections(2, {10, 10}).size(), 2);
}

void TaskLogicTest::viewIconsStatusRecurrencePriority()
{
    QCOMPARE(TaskLogic::viewIconSource(QStringLiteral("today")), QStringLiteral("view-calendar-day"));
    QCOMPARE(TaskLogic::viewIconSource(QStringLiteral("overdue")), QStringLiteral("chronometer"));
    QCOMPARE(TaskLogic::viewIconSource(QStringLiteral("inbox")), QStringLiteral("mail-folder-inbox"));
    QCOMPARE(TaskLogic::viewIconSource(QStringLiteral("completed")), QStringLiteral("checkmark"));
    QCOMPARE(TaskLogic::indexForValue({1, 5, 9, 0}, 9), 2);
    QCOMPARE(TaskLogic::indexForString({QStringLiteral("a"), QStringLiteral("b")}, QStringLiteral("b")), 1);
    QCOMPARE(TaskLogic::indexForString({QStringLiteral("a")}, QString()), -1);
    QCOMPARE(TaskLogic::normalizeStatus(4), 4);
    QCOMPARE(TaskLogic::normalizeStatus(99), 0);
    QCOMPARE(TaskLogic::recurrenceIndexFor(QStringLiteral("monthly")), 3);
    QCOMPARE(TaskLogic::recurrenceValueFor(2), QStringLiteral("weekly"));
    QCOMPARE(TaskLogic::recurrenceValueFor(0), QStringLiteral("none"));
    QCOMPARE(TaskLogic::priorityLabel(2), QStringLiteral("high"));
    QCOMPARE(TaskLogic::priorityLabel(0), QString());
    QCOMPARE(TaskLogic::priorityToIndex(8), 3);
    QCOMPARE(TaskLogic::indexToPriority(2), 5);
}

void TaskLogicTest::cursorAndDragLimits()
{
    QCOMPARE(TaskLogic::resolveCursorSize(48, TaskLogic::EnvCursor::Valid, 24), 48);
    QCOMPARE(TaskLogic::resolveCursorSize(0, TaskLogic::EnvCursor::Valid, 32), 32);
    QCOMPARE(TaskLogic::resolveCursorSize(48, TaskLogic::EnvCursor::Invalid, 0), 24);
    QCOMPARE(TaskLogic::pickLimitRight(1920, 1800, 4), 1796);
    QCOMPARE(TaskLogic::pickLimitRight(1920, 0, 4), 1916);
    QCOMPARE(TaskLogic::pickLimitBottom({1080, 1040, 2000}, 4), 1036);
}

void TaskLogicTest::dateTimeTokensAndIsoParse()
{
    QCOMPARE(TaskLogic::pad2(3), QStringLiteral("03"));
    QCOMPARE(TaskLogic::pad2(12), QStringLiteral("12"));
    QCOMPARE(TaskLogic::digitsOnly(QStringLiteral("12-03-2026")), QStringLiteral("12032026"));

    const auto dateTokens = TaskLogic::parseFormatTokens(QStringLiteral("dd.MM.yyyy"));
    QCOMPARE(TaskLogic::maxDigitsFor(dateTokens), 8);
    QCOMPARE(TaskLogic::formatDigitsWithTokens(QStringLiteral("13082026"), dateTokens), QStringLiteral("13.08.2026"));
    QCOMPARE(TaskLogic::formatDigitsWithTokens(QStringLiteral("13"), dateTokens), QStringLiteral("13"));

    const auto timeTokens = TaskLogic::parseFormatTokens(QStringLiteral("HH:mm"));
    QCOMPARE(TaskLogic::formatDigitsWithTokens(QStringLiteral("0930"), timeTokens), QStringLiteral("09:30"));

    const auto segs = TaskLogic::computeSegments(QStringLiteral("13.08.2026"), dateTokens);
    QCOMPARE(segs.size(), 3);
    QCOMPARE(segs.at(0).kind, QStringLiteral("day"));
    QCOMPARE(TaskLogic::segmentAtPosition(QStringLiteral("13.08.2026"), dateTokens, 0).kind, QStringLiteral("day"));
    QCOMPARE(TaskLogic::segmentAtPosition(QStringLiteral("13.08.2026"), dateTokens, 4).kind, QStringLiteral("month"));

    QCOMPARE(TaskLogic::parseIsoDate(QStringLiteral("2026-08-13")), QDate(2026, 8, 13));
    QVERIFY(!TaskLogic::parseIsoDate(QStringLiteral("13.08.2026")).isValid());

    int hours = -1;
    int minutes = -1;
    QVERIFY(TaskLogic::parseHmsTime(QStringLiteral("9:05"), &hours, &minutes));
    QCOMPARE(hours, 9);
    QCOMPARE(minutes, 5);
    QVERIFY(TaskLogic::parseHmsTime(QString(), &hours, &minutes));
    QCOMPARE(hours, 0);
    QVERIFY(!TaskLogic::parseHmsTime(QStringLiteral("25:00"), &hours, &minutes));
}

void TaskLogicTest::todayCatchUpIncludesAllOverdue()
{
    const QDate today(2026, 8, 13);
    TaskEntry dueToday = makeTask(QStringLiteral("Today"));
    dueToday.dueDate = QDateTime(today, QTime(9, 0));
    TaskEntry overdue = makeTask(QStringLiteral("Late"));
    overdue.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    TaskEntry ancient = makeTask(QStringLiteral("Ancient"));
    ancient.dueDate = QDateTime(QDate(2026, 1, 1), QTime(9, 0));

    QVERIFY(TaskLogic::matchesView(dueToday, QStringLiteral("today"), today));
    QVERIFY(!TaskLogic::matchesView(overdue, QStringLiteral("today"), today));
    QVERIFY(TaskLogic::matchesView(overdue, QStringLiteral("overdue"), today));
    QVERIFY(TaskLogic::matchesView(ancient, QStringLiteral("overdue"), today));

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("today");
    filters.catchUpEnabled = true;
    filters.catchUpDays = 14; // ignored: catch-up = full overdue set

    const TaskLogic::VisibleFilterResult visible = TaskLogic::filterVisibleTasks({dueToday, overdue, ancient}, filters, today);
    QCOMPARE(visible.tasks.size(), 3);

    TaskLogic::FilterState overdueFilters;
    overdueFilters.currentView = QStringLiteral("overdue");
    const TaskLogic::VisibleFilterResult overdueOnly = TaskLogic::filterVisibleTasks({dueToday, overdue, ancient}, overdueFilters, today);
    QCOMPARE(overdueOnly.tasks.size(), 2);

    int catchupCount = 0;
    for (const TaskEntry &task : visible.tasks) {
        if (task.bucket == QLatin1String("catchup")) {
            ++catchupCount;
        }
    }
    QCOMPARE(catchupCount, 2);
    QCOMPARE(catchupCount, overdueOnly.tasks.size());
}

void TaskLogicTest::catchUpMatchesOverdueAndDisabled()
{
    const QDate today(2026, 8, 13);
    TaskEntry recent = makeTask(QStringLiteral("Recent"));
    recent.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    TaskEntry old = makeTask(QStringLiteral("Old"));
    old.dueDate = QDateTime(QDate(2026, 7, 1), QTime(9, 0));
    TaskEntry done = makeTask(QStringLiteral("Done"));
    done.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    done.completed = true;

    QVERIFY(TaskLogic::isCatchUp(recent, today, 14));
    QVERIFY(TaskLogic::isCatchUp(old, today, 14));
    QVERIFY(TaskLogic::isCatchUp(old, today, -1));
    QVERIFY(!TaskLogic::isCatchUp(done, today, 14));
    QCOMPARE(TaskLogic::isCatchUp(recent, today), TaskLogic::matchesView(recent, QStringLiteral("overdue"), today));
    QCOMPARE(TaskLogic::isCatchUp(old, today), TaskLogic::matchesView(old, QStringLiteral("overdue"), today));

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("today");
    filters.catchUpEnabled = false;
    QCOMPARE(TaskLogic::filterVisibleTasks({recent, old}, filters, today).tasks.size(), 0);
}

void TaskLogicTest::dayPartsAndListBuckets()
{
    const QDate today(2026, 8, 13);
    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("today");
    filters.morningHour = 6;
    filters.afternoonHour = 12;
    filters.eveningHour = 18;

    QCOMPARE(TaskLogic::dayPart(QDateTime(today, QTime(7, 0)), filters), QStringLiteral("morning"));
    QCOMPARE(TaskLogic::dayPart(QDateTime(today, QTime(12, 0)), filters), QStringLiteral("afternoon"));
    QCOMPARE(TaskLogic::dayPart(QDateTime(today, QTime(19, 0)), filters), QStringLiteral("evening"));
    QCOMPARE(TaskLogic::dayPart({}, filters), QStringLiteral("unspecified"));

    TaskEntry allDay = makeTask(QStringLiteral("All day"));
    allDay.dueDate = QDateTime(today, QTime(0, 0));
    allDay.allDay = true;
    QCOMPARE(TaskLogic::listBucket(allDay, filters, today), QStringLiteral("unspecified"));

    TaskEntry listed = makeTask(QStringLiteral("Heading"));
    listed.section = QStringLiteral("Later");
    filters.currentView = QStringLiteral("inbox");
    QCOMPARE(TaskLogic::listBucket(listed, filters, today), QStringLiteral("Later"));
}

void TaskLogicTest::reschedulePresets()
{
    const QDateTime now(QDate(2026, 8, 13), QTime(10, 0));
    const QDateTime due(QDate(2026, 8, 13), QTime(15, 0));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::Timed, now, QStringLiteral("15m")).time(), QTime(10, 15));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::Timed, now, QStringLiteral("1h")).time(), QTime(11, 0));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::Timed, now, QStringLiteral("4h")).time(), QTime(14, 0));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::Timed, now, QStringLiteral("tomorrow")).date(), QDate(2026, 8, 14));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::Timed, now, QStringLiteral("tomorrow")).time(), QTime(15, 0));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::AllDay, now, QStringLiteral("tomorrow")).date(), QDate(2026, 8, 14));
    QCOMPARE(TaskLogic::rescheduleDue(due, TaskLogic::DaySpan::Timed, now, QStringLiteral("next-week")).date(), QDate(2026, 8, 20));
}

void TaskLogicTest::joinUrlExtraction()
{
    QCOMPARE(TaskLogic::joinUrl(QStringLiteral("See https://meet.example/abc."), QString()),
             QStringLiteral("https://meet.example/abc"));
    QCOMPARE(TaskLogic::joinUrl(QStringLiteral("notes"), QStringLiteral("https://zoom.us/j/1")),
             QStringLiteral("https://zoom.us/j/1"));
    QVERIFY(TaskLogic::joinUrl(QStringLiteral("no link"), QString()).isEmpty());
    QCOMPARE(TaskLogic::joinUrl(QStringLiteral("http://example.com/x"), QString()),
             QStringLiteral("http://example.com/x"));
}

void TaskLogicTest::parseQuickAddTokens()
{
    const QDate today(2026, 8, 13);
    const QTime now(9, 0);
    const TaskLogic::QuickAdd parsed = TaskLogic::parseQuickAdd(
        QStringLiteral("Milk tomorrow 18:00 !high #einkauf"), today, now);
    QCOMPARE(parsed.summary, QStringLiteral("Milk"));
    QVERIFY(parsed.hasDue);
    QCOMPARE(parsed.due.date(), QDate(2026, 8, 14));
    QCOMPARE(parsed.due.time(), QTime(18, 0));
    QVERIFY(!parsed.allDay);
    QCOMPARE(parsed.priority, 1);
    QCOMPARE(parsed.labels, QStringList{QStringLiteral("einkauf")});

    TaskLogic::QuickAddContext de;
    de.uiLanguage = QStringLiteral("de");
    const TaskLogic::QuickAdd heute = TaskLogic::parseQuickAdd(QStringLiteral("Call heute"), today, now, de);
    QVERIFY(heute.hasDue);
    QVERIFY(heute.allDay);
    QCOMPARE(heute.due.date(), today);

    const TaskLogic::QuickAdd tonight = TaskLogic::parseQuickAdd(QStringLiteral("Gym 21:00"), today, now);
    QVERIFY(tonight.hasDue);
    QCOMPARE(tonight.due.date(), today);
    QCOMPARE(tonight.due.time(), QTime(21, 0));

    const TaskLogic::QuickAdd late = TaskLogic::parseQuickAdd(QStringLiteral("Gym 08:00"), today, QTime(9, 0));
    QCOMPARE(late.due.date(), QDate(2026, 8, 14));
}

void TaskLogicTest::parseQuickAddFuzzyLanguageAndProjects()
{
    const QDate today(2026, 8, 13);
    const QTime now(9, 0);
    TaskLogic::QuickAddContext ctx;
    ctx.uiLanguage = QStringLiteral("de");
    TaskLogic::QuickAddProject work;
    work.id = 42;
    work.name = QStringLiteral("Work");
    ctx.projects.append(work);
    ctx.labels.append(QStringLiteral("einkauf"));

    const TaskLogic::QuickAdd typo = TaskLogic::parseQuickAdd(QStringLiteral("Milk tommorow !hihg"), today, now, ctx);
    QCOMPARE(typo.summary, QStringLiteral("Milk"));
    QVERIFY(typo.hasDue);
    QCOMPARE(typo.due.date(), QDate(2026, 8, 14));
    QCOMPARE(typo.priority, 1);

    const TaskLogic::QuickAdd title = TaskLogic::parseQuickAdd(QStringLiteral("The high road tomorrow"), today, now, ctx);
    QCOMPARE(title.summary, QStringLiteral("The high road"));
    QCOMPARE(title.priority, 0);

    const TaskLogic::QuickAdd project = TaskLogic::parseQuickAdd(QStringLiteral("Invoice @Work"), today, now, ctx);
    QCOMPARE(project.summary, QStringLiteral("Invoice"));
    QCOMPARE(project.collectionId, qint64(42));

    TaskLogic::QuickAddContext en;
    en.uiLanguage = QStringLiteral("en");
    const TaskLogic::QuickAdd enHeute = TaskLogic::parseQuickAdd(QStringLiteral("Call heute"), today, now, en);
    QCOMPARE(enHeute.summary, QStringLiteral("Call heute"));
    QVERIFY(!enHeute.hasDue);

    const TaskLogic::QuickAdd next = TaskLogic::parseQuickAdd(QStringLiteral("Report next week"), today, now, en);
    QVERIFY(next.hasDue);
    QCOMPARE(next.due.date(), QDate(2026, 8, 20));

    const TaskLogic::QuickAdd fuzzyLabel = TaskLogic::parseQuickAdd(QStringLiteral("Buy #einkuf"), today, now, ctx);
    QCOMPARE(fuzzyLabel.labels, QStringList{QStringLiteral("einkauf")});

    const TaskLogic::QuickAddSuggestResult suggest = TaskLogic::suggestQuickAdd(QStringLiteral("Milk tom"), 8, ctx);
    QVERIFY(!suggest.items.isEmpty());
    QCOMPARE(suggest.items.first().value, QStringLiteral("tomorrow"));

    const TaskLogic::QuickAddSuggestResult projects = TaskLogic::suggestQuickAdd(QStringLiteral("Note @W"), 7, ctx);
    QVERIFY(!projects.items.isEmpty());
    QCOMPARE(projects.items.first().collectionId, qint64(42));
}

void TaskLogicTest::suggestQuickAddScoresAndTypos()
{
    TaskLogic::QuickAddContext ctx;
    ctx.uiLanguage = QStringLiteral("en");
    TaskLogic::QuickAddProject work;
    work.id = 7;
    work.name = QStringLiteral("Work");
    ctx.projects.append(work);
    ctx.labels.append(QStringLiteral("shopping"));

    // Exact date phrase outranks typo; prefix "tom" → tomorrow.
    const auto tom = TaskLogic::suggestQuickAdd(QStringLiteral("x tom"), 4, ctx);
    QVERIFY(!tom.items.isEmpty());
    QCOMPARE(tom.items.first().kind, QStringLiteral("date"));
    QCOMPARE(tom.items.first().value, QStringLiteral("tomorrow"));

    // Prefixed priority: short typo "!hih" can match high (dist 1, len>=3).
    const auto prio = TaskLogic::suggestQuickAdd(QStringLiteral("x !hih"), 6, ctx);
    QVERIFY(!prio.items.isEmpty());
    QCOMPARE(prio.items.first().kind, QStringLiteral("priority"));
    QCOMPARE(prio.items.first().priority, 1);

    // Bare word too short for typo without prefix: "hi" alone is not priority.
    const auto bare = TaskLogic::suggestQuickAdd(QStringLiteral("hi"), 2, ctx);
    for (const auto &item : bare.items) {
        QVERIFY(item.kind != QStringLiteral("priority") || item.priority == 0);
    }

    // Label fuzzy with #: shopping typo.
    const auto label = TaskLogic::suggestQuickAdd(QStringLiteral("#shoping"), 8, ctx);
    QVERIFY(!label.items.isEmpty());
    QCOMPARE(label.items.first().kind, QStringLiteral("label"));
    QCOMPARE(label.items.first().value, QStringLiteral("shopping"));

    // Exact match scores higher than prefix.
    const auto exact = TaskLogic::suggestQuickAdd(QStringLiteral("@Work"), 5, ctx);
    QVERIFY(!exact.items.isEmpty());
    QCOMPARE(exact.items.first().collectionId, qint64(7));
    QVERIFY(exact.items.first().score >= 3000);
}

QTEST_GUILESS_MAIN(TaskLogicTest)
#include "tasklogic_test.moc"
