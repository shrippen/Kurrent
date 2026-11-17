#include "focusorder.h"

#include <QtTest>

namespace
{
const QDate kToday(2026, 10, 29);

TaskEntry task(const QString &summary, const QDate &due = QDate(), int priority = 0)
{
    TaskEntry t;
    t.summary = summary;
    t.priority = priority;
    if (due.isValid()) {
        t.dueDate = QDateTime(due, QTime(0, 0));
    }
    return t;
}

QStringList titles(const QList<TaskEntry> &tasks)
{
    QStringList out;
    for (const TaskEntry &t : tasks) {
        out.append(t.summary);
    }
    return out;
}
} // namespace

class FocusOrderTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void openDropsDoneAndDeleted();
    void openKeepsListOrderAndFiltersBySearch();
    void orderNowSoonSomeday();
    void orderDueThenPriorityThenTitle();
};

void FocusOrderTest::openDropsDoneAndDeleted()
{
    TaskEntry done = task(QStringLiteral("done"));
    done.completed = true;
    TaskEntry gone = task(QStringLiteral("gone"));
    gone.pendingDelete = true;

    const QList<TaskEntry> open = TaskLogic::openTasks({done, task(QStringLiteral("open")), gone}, QString());
    QCOMPARE(titles(open), QStringList{QStringLiteral("open")});
}

void FocusOrderTest::openKeepsListOrderAndFiltersBySearch()
{
    const QList<TaskEntry> in = {task(QStringLiteral("b milk")), task(QStringLiteral("a bread")), task(QStringLiteral("c MILK"))};
    QCOMPARE(titles(TaskLogic::openTasks(in, QStringLiteral("milk"))), (QStringList{QStringLiteral("b milk"), QStringLiteral("c MILK")}));
    QCOMPARE(titles(TaskLogic::openTasks(in, QString())), (QStringList{QStringLiteral("b milk"), QStringLiteral("a bread"), QStringLiteral("c MILK")}));
}

void FocusOrderTest::orderNowSoonSomeday()
{
    const QList<TaskEntry> in = {
        task(QStringLiteral("someday")),
        task(QStringLiteral("soon"), kToday.addDays(2)),
        task(QStringLiteral("today"), kToday),
        task(QStringLiteral("late"), kToday.addDays(-3)),
    };
    QCOMPARE(titles(TaskLogic::focusOrder(in, kToday)),
             (QStringList{QStringLiteral("late"), QStringLiteral("today"), QStringLiteral("soon"), QStringLiteral("someday")}));
}

// Same due date: High (1) before Medium (5) before Low (9) before none (0), then title.
void FocusOrderTest::orderDueThenPriorityThenTitle()
{
    const QList<TaskEntry> in = {
        task(QStringLiteral("none"), kToday, 0),
        task(QStringLiteral("low"), kToday, 9),
        task(QStringLiteral("b high"), kToday, 1),
        task(QStringLiteral("a high"), kToday, 2),
        task(QStringLiteral("mid"), kToday, 5),
        task(QStringLiteral("earlier"), kToday.addDays(-1), 0),
        task(QStringLiteral("z someday low"), QDate(), 9),
        task(QStringLiteral("y someday high"), QDate(), 1),
    };
    QCOMPARE(titles(TaskLogic::focusOrder(in, kToday)),
             (QStringList{QStringLiteral("earlier"), QStringLiteral("a high"), QStringLiteral("b high"), QStringLiteral("mid"),
                          QStringLiteral("low"), QStringLiteral("none"), QStringLiteral("y someday high"), QStringLiteral("z someday low")}));
}

QTEST_MAIN(FocusOrderTest)
#include "focusorder_test.moc"
