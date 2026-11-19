#include "boardlogic.h"

#include "taskcalendar.h"
#include "tasklogic.h"

#include <QDate>
#include <QDateTime>
#include <QtTest>

using BoardLogic::Effect;
using BoardLogic::Outcome;

namespace
{
const QDateTime Now(QDate(2026, 5, 20), QTime(10, 0));
const QDate Today(2026, 5, 20);
const QString NoMode = QStringLiteral("fields");

KCalendarCore::Todo::Ptr makeTodo()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(QStringLiteral("t"));
    return todo;
}

Outcome kanban(const KCalendarCore::Todo::Ptr &todo, const QString &source, const QString &key,
               const QString &mode = NoMode)
{
    return BoardLogic::applyKanbanColumn(todo, source, mode, key, Now);
}
} // namespace

class BoardLogicTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void customModeWritesColumnForAnySource();
    void columnSourceWritesColumn();
    void bothModeFallsBackToColumn();
    void unknownSourceWithoutModeDoesNothing();
    void completionMarksAndUnmarks();
    void completionUnchangedDoesNotPersist();
    void completionRecurringKeepsPercent();
    void statusChangesAndCompletes();
    void statusUnchangedDoesNotPersist();
    void statusLeavingCompletedClearsCompletion();
    void statusInvalidKeyDoesNothing();
    void secrecyChangesAndSkipsUnchanged();
    void projectAsksForMove();
    void projectInboxAndInvalidDoNothing();
    void dueNoDateClearsDue();
    void duePresets_data();
    void duePresets();
    void dueUnknownKeyDoesNothing();
    void priorityChangesAndSkipsUnchanged();
    void labelMovesToFront();
    void labelNoneClears();
    void daySectionSetsAndClears();

    void laneLabel();
    void lanePriority();
    void laneParent();
    void laneProject();
    void timeUnscheduledClearsDue();
    void timeUnscheduledWithoutDueUnchanged();
    void timeBucketSetsDueAndAllDay();
    void timeBucketKeepsAllDayWithDue();
};

void BoardLogicTest::customModeWritesColumnForAnySource()
{
    auto todo = makeTodo();
    const Outcome out = kanban(todo, TaskLogic::KanbanSource::Priority, QStringLiteral("high"),
                               BoardLogic::WriteMode::Custom);
    QCOMPARE(out.effect, Effect::Persist);
    QCOMPARE(TaskCalendar::columnFromTodo(todo), QStringLiteral("high"));
    QCOMPARE(todo->priority(), 0);
}

void BoardLogicTest::columnSourceWritesColumn()
{
    auto todo = makeTodo();
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Column, QStringLiteral("doing")).effect, Effect::Persist);
    QCOMPARE(TaskCalendar::columnFromTodo(todo), QStringLiteral("doing"));
}

void BoardLogicTest::bothModeFallsBackToColumn()
{
    auto todo = makeTodo();
    const Outcome out = kanban(todo, QStringLiteral("other"), QStringLiteral("x"), BoardLogic::WriteMode::Both);
    QCOMPARE(out.effect, Effect::Persist);
    QCOMPARE(TaskCalendar::columnFromTodo(todo), QStringLiteral("x"));
}

void BoardLogicTest::unknownSourceWithoutModeDoesNothing()
{
    auto todo = makeTodo();
    QCOMPARE(kanban(todo, QStringLiteral("other"), QStringLiteral("x")).effect, Effect::Nothing);
    QVERIFY(TaskCalendar::columnFromTodo(todo).isEmpty());
}

void BoardLogicTest::completionMarksAndUnmarks()
{
    auto todo = makeTodo();
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Completion, QStringLiteral("done")).effect, Effect::Persist);
    QVERIFY(todo->isCompleted());
    QCOMPARE(todo->percentComplete(), 100);

    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Completion, QStringLiteral("open")).effect, Effect::Persist);
    QVERIFY(!todo->isCompleted());
    QCOMPARE(todo->percentComplete(), 0);
}

void BoardLogicTest::completionUnchangedDoesNotPersist()
{
    auto todo = makeTodo();
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Completion, QStringLiteral("open")).effect, Effect::Nothing);
    QVERIFY(!todo->isCompleted());
}

void BoardLogicTest::completionRecurringKeepsPercent()
{
    auto todo = makeTodo();
    todo->setDtStart(Now);
    todo->setDtDue(Now);
    todo->recurrence()->setDaily(1);
    todo->setPercentComplete(30);

    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Completion, QStringLiteral("done")).effect, Effect::Persist);
    QVERIFY(todo->recurs());
    QVERIFY(todo->percentComplete() != 100);
}

void BoardLogicTest::statusChangesAndCompletes()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::Status;

    QCOMPARE(kanban(todo, src, QStringLiteral("in-process")).effect, Effect::Persist);
    QCOMPARE(static_cast<int>(todo->status()), 6);

    QCOMPARE(kanban(todo, src, QStringLiteral("completed")).effect, Effect::Persist);
    QCOMPARE(static_cast<int>(todo->status()), 3);
    QVERIFY(todo->isCompleted());
    QCOMPARE(todo->percentComplete(), 100);
}

void BoardLogicTest::statusUnchangedDoesNotPersist()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::Status;
    kanban(todo, src, QStringLiteral("completed"));

    QCOMPARE(kanban(todo, src, QStringLiteral("completed")).effect, Effect::Nothing);
}

void BoardLogicTest::statusLeavingCompletedClearsCompletion()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::Status;
    kanban(todo, src, QStringLiteral("completed"));

    QCOMPARE(kanban(todo, src, QStringLiteral("in-process")).effect, Effect::Persist);
    QVERIFY(!todo->isCompleted());
}

void BoardLogicTest::statusInvalidKeyDoesNothing()
{
    auto todo = makeTodo();
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Status, QStringLiteral("bogus")).effect, Effect::Nothing);
}

void BoardLogicTest::secrecyChangesAndSkipsUnchanged()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::Secrecy;

    QCOMPARE(kanban(todo, src, QStringLiteral("private")).effect, Effect::Persist);
    QCOMPARE(static_cast<int>(todo->secrecy()), 1);
    QCOMPARE(kanban(todo, src, QStringLiteral("private")).effect, Effect::Nothing);
    QCOMPARE(kanban(todo, src, QStringLiteral("confidential")).effect, Effect::Persist);
    QCOMPARE(static_cast<int>(todo->secrecy()), 2);
    QCOMPARE(kanban(todo, src, QStringLiteral("public")).effect, Effect::Persist);
    QCOMPARE(static_cast<int>(todo->secrecy()), 0);
    QCOMPARE(kanban(todo, src, QStringLiteral("public")).effect, Effect::Nothing);
}

void BoardLogicTest::projectAsksForMove()
{
    auto todo = makeTodo();
    const Outcome out = kanban(todo, TaskLogic::KanbanSource::Project, QStringLiteral("42"));
    QCOMPARE(out.effect, Effect::MoveCollection);
    QCOMPARE(out.collectionId, qint64(42));
}

void BoardLogicTest::projectInboxAndInvalidDoNothing()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::Project;
    QCOMPARE(kanban(todo, src, QStringLiteral("inbox")).effect, Effect::Nothing);
    QCOMPARE(kanban(todo, src, QStringLiteral("-3")).effect, Effect::Nothing);
}

void BoardLogicTest::dueNoDateClearsDue()
{
    auto todo = makeTodo();
    todo->setDtDue(Now);
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Due, QStringLiteral("no-date")).effect, Effect::Persist);
    QVERIFY(!todo->hasDueDate());
}

void BoardLogicTest::duePresets_data()
{
    QTest::addColumn<QString>("key");
    QTest::addColumn<QString>("preset");
    QTest::newRow("today") << "today" << TaskLogic::ReschedulePreset::Today;
    QTest::newRow("overdue") << "overdue" << TaskLogic::ReschedulePreset::Today;
    QTest::newRow("tomorrow") << "tomorrow" << TaskLogic::ReschedulePreset::Tomorrow;
    QTest::newRow("this-week") << "this-week" << TaskLogic::ReschedulePreset::NextWeek;
    QTest::newRow("later") << "later" << TaskLogic::ReschedulePreset::NextWeek;
}

void BoardLogicTest::duePresets()
{
    QFETCH(QString, key);
    QFETCH(QString, preset);

    auto todo = makeTodo();
    todo->setDtDue(Now);
    const Outcome out = kanban(todo, TaskLogic::KanbanSource::Due, key);
    QCOMPARE(out.effect, Effect::Reschedule);
    QCOMPARE(out.preset, preset);
    QCOMPARE(todo->dtDue(), Now);
}

void BoardLogicTest::dueUnknownKeyDoesNothing()
{
    auto todo = makeTodo();
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Due, QStringLiteral("nope")).effect, Effect::Nothing);
}

void BoardLogicTest::priorityChangesAndSkipsUnchanged()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::Priority;

    QCOMPARE(kanban(todo, src, QStringLiteral("high")).effect, Effect::Persist);
    QCOMPARE(todo->priority(), TaskLogic::PriorityBand::High);
    QCOMPARE(kanban(todo, src, QStringLiteral("high")).effect, Effect::Nothing);
    QCOMPARE(kanban(todo, src, QStringLiteral("medium")).effect, Effect::Persist);
    QCOMPARE(todo->priority(), TaskLogic::PriorityBand::Medium);
    QCOMPARE(kanban(todo, src, QStringLiteral("low")).effect, Effect::Persist);
    QCOMPARE(todo->priority(), TaskLogic::PriorityBand::Low);
    QCOMPARE(kanban(todo, src, QStringLiteral("none")).effect, Effect::Persist);
    QCOMPARE(todo->priority(), TaskLogic::PriorityBand::None);
    QCOMPARE(kanban(todo, src, QStringLiteral("none")).effect, Effect::Nothing);
}

void BoardLogicTest::labelMovesToFront()
{
    auto todo = makeTodo();
    todo->setCategories({QStringLiteral("a"), QStringLiteral("b")});

    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Label, QStringLiteral("b")).effect, Effect::Persist);
    QCOMPARE(todo->categories(), (QStringList{QStringLiteral("b"), QStringLiteral("a")}));

    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Label, QStringLiteral("c")).effect, Effect::Persist);
    QCOMPARE(todo->categories(), (QStringList{QStringLiteral("c"), QStringLiteral("b"), QStringLiteral("a")}));
}

void BoardLogicTest::labelNoneClears()
{
    auto todo = makeTodo();
    todo->setCategories({QStringLiteral("a")});
    QCOMPARE(kanban(todo, TaskLogic::KanbanSource::Label, QStringLiteral("none")).effect, Effect::Persist);
    QVERIFY(todo->categories().isEmpty());
}

void BoardLogicTest::daySectionSetsAndClears()
{
    auto todo = makeTodo();
    const QString src = TaskLogic::KanbanSource::DaySection;

    QCOMPARE(kanban(todo, src, QStringLiteral("morning")).effect, Effect::Persist);
    QCOMPARE(TaskCalendar::sectionFromTodo(todo), QStringLiteral("morning"));
    QCOMPARE(kanban(todo, src, QStringLiteral("unscheduled")).effect, Effect::Persist);
    QVERIFY(TaskCalendar::sectionFromTodo(todo).isEmpty());
}

void BoardLogicTest::laneLabel()
{
    auto todo = makeTodo();
    todo->setCategories({QStringLiteral("a")});
    const QString axis = QStringLiteral("label");

    QCOMPARE(BoardLogic::applyMatrixLane(todo, axis, QStringLiteral("b")).effect, Effect::Persist);
    QCOMPARE(todo->categories(), (QStringList{QStringLiteral("b"), QStringLiteral("a")}));
    QCOMPARE(BoardLogic::applyMatrixLane(todo, axis, QStringLiteral("none")).effect, Effect::Persist);
    QVERIFY(todo->categories().isEmpty());
}

void BoardLogicTest::lanePriority()
{
    auto todo = makeTodo();
    QCOMPARE(BoardLogic::applyMatrixLane(todo, QStringLiteral("priority"), QStringLiteral("5")).effect,
             Effect::Persist);
    QCOMPARE(todo->priority(), 5);
}

void BoardLogicTest::laneParent()
{
    auto todo = makeTodo();
    const QString axis = QStringLiteral("parent");

    Outcome out = BoardLogic::applyMatrixLane(todo, axis, QStringLiteral("uid-1"));
    QCOMPARE(out.effect, Effect::SetParent);
    QCOMPARE(out.parentUid, QStringLiteral("uid-1"));

    out = BoardLogic::applyMatrixLane(todo, axis, QStringLiteral("none"));
    QCOMPARE(out.effect, Effect::SetParent);
    QVERIFY(out.parentUid.isEmpty());
}

void BoardLogicTest::laneProject()
{
    auto todo = makeTodo();
    const QString axis = QStringLiteral("project");

    const Outcome out = BoardLogic::applyMatrixLane(todo, axis, QStringLiteral("7"));
    QCOMPARE(out.effect, Effect::MoveCollection);
    QCOMPARE(out.collectionId, qint64(7));
    QCOMPARE(BoardLogic::applyMatrixLane(todo, axis, QStringLiteral("inbox")).effect, Effect::Nothing);
}

void BoardLogicTest::timeUnscheduledClearsDue()
{
    auto todo = makeTodo();
    todo->setDtDue(Now);
    QVERIFY(BoardLogic::applyMatrixTime(todo, Now, QStringLiteral("unscheduled"), QStringLiteral("week"), Today));
    QVERIFY(!todo->hasDueDate());
}

void BoardLogicTest::timeUnscheduledWithoutDueUnchanged()
{
    auto todo = makeTodo();
    QVERIFY(!BoardLogic::applyMatrixTime(todo, QDateTime(), QStringLiteral("unscheduled"), QStringLiteral("week"), Today));
}

void BoardLogicTest::timeBucketSetsDueAndAllDay()
{
    auto todo = makeTodo();
    const QString target = QStringLiteral("2026-W22");
    const QDateTime expected = TaskLogic::dueForBucketDrop(QDateTime(), target, QStringLiteral("week"), Today);
    QVERIFY(expected.isValid());

    QVERIFY(BoardLogic::applyMatrixTime(todo, QDateTime(), target, QStringLiteral("week"), Today));
    QCOMPARE(todo->dtDue(), expected);
    QVERIFY(todo->allDay());
}

void BoardLogicTest::timeBucketKeepsAllDayWithDue()
{
    auto todo = makeTodo();
    todo->setDtDue(Now);
    todo->setAllDay(false);
    const QString target = QStringLiteral("2026-W22");

    QVERIFY(BoardLogic::applyMatrixTime(todo, Now, target, QStringLiteral("week"), Today));
    QVERIFY(!todo->allDay());
}

QTEST_GUILESS_MAIN(BoardLogicTest)
#include "boardlogic_test.moc"
