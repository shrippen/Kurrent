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

    void filterVisibleTasksCompletedAndSearch();
    void filterVisibleTasksCompletedView();

    void collectionCountsPendingAndLabels();
    void labelMutationsAndCreateGuard();

    void hiddenTokensAndEnabledCsv();
    void sidebarVisibilityAndLayout();
    void viewIconsStatusRecurrencePriority();
    void cursorAndDragLimits();
    void dateTimeTokensAndIsoParse();
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
    QCOMPARE(TaskLogic::matchesSearch(task, query), matches);
}

void TaskLogicTest::matchesViewTodayIncludesOverdueIncomplete()
{
    const QDate today(2026, 8, 13);
    TaskEntry overdue = makeTask(QStringLiteral("Overdue"));
    overdue.dueDate = QDateTime(QDate(2026, 8, 10), QTime(9, 0));
    overdue.completed = false;
    QVERIFY(TaskLogic::matchesView(overdue, QStringLiteral("today"), today));
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

    QVERIFY(TaskLogic::compareTasks(late, early, QStringLiteral("dueDesc")) < 0);
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
    const auto selected = TaskLogic::resolveNewTaskTarget(42, QStringLiteral("ask"), 7, true, 3);
    QCOMPARE(selected.ask, false);
    QCOMPARE(selected.collectionId, qint64(42));

    const auto first = TaskLogic::resolveNewTaskTarget(-1, QStringLiteral("first"), 7, true, 3);
    QCOMPARE(first.ask, false);
    QCOMPARE(first.collectionId, qint64(3));

    const auto fixed = TaskLogic::resolveNewTaskTarget(-1, QStringLiteral("fixed"), 7, true, 3);
    QCOMPARE(fixed.ask, false);
    QCOMPARE(fixed.collectionId, qint64(7));

    const auto ask = TaskLogic::resolveNewTaskTarget(-1, QStringLiteral("ask"), 7, true, 3);
    QVERIFY(ask.ask);
}

void TaskLogicTest::dragProxyGapAndClamp()
{
    const QPointF hand = TaskLogic::dragProxyGap(24, false);
    QCOMPARE(hand, QPointF(14, 14));
    const QPointF arrow = TaskLogic::dragProxyGap(24, true);
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

void TaskLogicTest::filterVisibleTasksCompletedAndSearch()
{
    const QDate today(2026, 8, 13);
    TaskEntry openTask = makeTask(QStringLiteral("Open milk"));
    TaskEntry doneTask = makeTask(QStringLiteral("Done milk"));
    doneTask.completed = true;
    TaskEntry other = makeTask(QStringLiteral("Call dentist"));

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("inbox");
    filters.searchQuery = QStringLiteral("milk");

    const auto hiddenCompleted = TaskLogic::filterVisibleTasks({openTask, doneTask, other}, filters, today);
    QCOMPARE(hiddenCompleted.tasks.size(), 1);
    QCOMPARE(hiddenCompleted.filteredOutCompleted, 1);
    QCOMPARE(hiddenCompleted.filteredOutSearch, 1);

    filters.showCompleted = true;
    const auto shown = TaskLogic::filterVisibleTasks({openTask, doneTask, other}, filters, today);
    QCOMPARE(shown.tasks.size(), 2);
    QCOMPARE(shown.filteredOutCompleted, 0);
}

void TaskLogicTest::filterVisibleTasksCompletedView()
{
    const QDate today(2026, 8, 13);
    TaskEntry openTask = makeTask(QStringLiteral("Open"));
    TaskEntry doneTask = makeTask(QStringLiteral("Done"));
    doneTask.completed = true;

    TaskLogic::FilterState filters;
    filters.currentView = QStringLiteral("completed");

    const auto result = TaskLogic::filterVisibleTasks({openTask, doneTask}, filters, today);
    QCOMPARE(result.tasks.size(), 1);
    QCOMPARE(result.tasks.at(0).summary, QStringLiteral("Done"));
    QCOMPARE(result.filteredOutView, 1);
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

    QCOMPARE(TaskLogic::naturalListHeight(3, true, 10, 20, 1), 10 + 60 + 3);
    QCOMPARE(TaskLogic::naturalListHeight(0, false, 10, 20, 1), 0);

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
    QCOMPARE(TaskLogic::resolveCursorSize(48, true, 24), 48);
    QCOMPARE(TaskLogic::resolveCursorSize(0, true, 32), 32);
    QCOMPARE(TaskLogic::resolveCursorSize(48, false, 0), 24);
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

QTEST_GUILESS_MAIN(TaskLogicTest)
#include "tasklogic_test.moc"
