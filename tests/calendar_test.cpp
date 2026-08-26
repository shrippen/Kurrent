#include "taskcalendar.h"

#include <KCalendarCore/Todo>

#include <QDate>
#include <QDateTime>
#include <QTime>
#include <QtTest>

class CalendarTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void presetNoneWithoutRecurrence();
    void applyAndReadPresets();
    void clearPresetRemovesRecurrence();
    void sectionPrefersKurrentThenVCalendar();
    void setSectionWritesKurrentList();
    void completeNonRecurringMarksDone();
    void completeDailyAdvancesDatesAndKeepsRrule();
    void otherPresetDoesNotClearCustomRrule();
    void nullTodoIsSafe();
    void reminderOffAtDueAndBefore();
    void snoozeSetsAbsoluteTime();
};

void CalendarTest::presetNoneWithoutRecurrence()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("none"));
}

void CalendarTest::applyAndReadPresets()
{
    const QDate today(2026, 8, 13);
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setDtStart(QDateTime(today, QTime(9, 0)));

    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("daily"), today);
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("daily"));
    QVERIFY(todo->recurs());

    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("weekly"), today);
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("weekly"));

    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("monthly"), today);
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("monthly"));

    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("yearly"), today);
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("yearly"));
}

void CalendarTest::clearPresetRemovesRecurrence()
{
    const QDate today(2026, 8, 13);
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("daily"), today);
    QVERIFY(todo->hasStartDate());
    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("none"), today);
    QVERIFY(!todo->recurs());
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("none"));
}

void CalendarTest::sectionPrefersKurrentThenVCalendar()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    QCOMPARE(TaskCalendar::sectionFromTodo(todo), QString());

    todo->setCustomProperty(QByteArray("VCALENDAR"), QByteArray("LIST"), QStringLiteral("generic"));
    QCOMPARE(TaskCalendar::sectionFromTodo(todo), QStringLiteral("generic"));

    todo->setCustomProperty(QByteArray("KURRENT"), QByteArray("LIST"), QStringLiteral("kurrent"));
    QCOMPARE(TaskCalendar::sectionFromTodo(todo), QStringLiteral("kurrent"));
}

void CalendarTest::setSectionWritesKurrentList()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    TaskCalendar::setSection(todo, QStringLiteral(" Morning "));
    QCOMPARE(TaskCalendar::sectionFromTodo(todo), QStringLiteral("Morning"));
    TaskCalendar::setSection(todo, QString());
    QCOMPARE(TaskCalendar::sectionFromTodo(todo), QString());
}

void CalendarTest::completeNonRecurringMarksDone()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(QStringLiteral("Once"));
    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 8, 13), QTime(10, 0))));
    QVERIFY(todo->isCompleted());
    QCOMPARE(todo->percentComplete(), 100);
    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Unmark, QDateTime(QDate(2026, 8, 13), QTime(10, 0))));
    QVERIFY(!todo->isCompleted());
}

void CalendarTest::completeDailyAdvancesDatesAndKeepsRrule()
{
    const QDate today(2026, 8, 13);
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setDtStart(QDateTime(today, QTime(9, 0)));
    todo->setDtDue(QDateTime(today, QTime(10, 0)));
    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("daily"), today);
    QVERIFY(todo->recurs());

    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(today, QTime(11, 0))));
    QVERIFY(!todo->isCompleted());
    QCOMPARE(todo->percentComplete(), 0);
    QVERIFY(todo->recurs());
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("daily"));
    QCOMPARE(todo->dtStart().date(), QDate(2026, 8, 14));
    QCOMPARE(todo->dtDue().date(), QDate(2026, 8, 14));
    QCOMPARE(todo->dtStart().time(), QTime(9, 0));
    QCOMPARE(todo->dtDue().time(), QTime(10, 0));
}

void CalendarTest::otherPresetDoesNotClearCustomRrule()
{
    const QDate today(2026, 8, 13);
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setDtStart(QDateTime(today, QTime(9, 0)));
    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("weekly"), today);
    QVERIFY(todo->recurs());
    TaskCalendar::applyRecurrencePreset(todo, QStringLiteral("other"), today);
    QVERIFY(todo->recurs());
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo(todo), QStringLiteral("weekly"));
}

void CalendarTest::nullTodoIsSafe()
{
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo({}), QStringLiteral("none"));
    QCOMPARE(TaskCalendar::sectionFromTodo({}), QString());
    TaskCalendar::applyRecurrencePreset({}, QStringLiteral("daily"), QDate(2026, 8, 13));
    TaskCalendar::setSection({}, QStringLiteral("x"));
    QVERIFY(!TaskCalendar::completeTodo({}, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 8, 13), QTime(10, 0))));
}

void CalendarTest::reminderOffAtDueAndBefore()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(QStringLiteral("Call"));
    todo->setDtDue(QDateTime(QDate(2026, 8, 17), QTime(18, 0)));
    QCOMPARE(TaskCalendar::reminderMinutesFromTodo(todo), -1);

    TaskCalendar::setReminderMinutes(todo, 0);
    QCOMPARE(TaskCalendar::reminderMinutesFromTodo(todo), 0);
    QVERIFY(todo->alarms().size() >= 1);

    TaskCalendar::setReminderMinutes(todo, 15);
    QCOMPARE(TaskCalendar::reminderMinutesFromTodo(todo), 15);

    const QDateTime now(QDate(2026, 8, 17), QTime(17, 40));
    const QDateTime next = TaskCalendar::nextReminderTime(todo, now);
    QVERIFY(next.isValid());
    QCOMPARE(next, QDateTime(QDate(2026, 8, 17), QTime(17, 45)));

    TaskCalendar::setReminderMinutes(todo, -1);
    QCOMPARE(TaskCalendar::reminderMinutesFromTodo(todo), -1);
    QVERIFY(todo->alarms().isEmpty());
}

void CalendarTest::snoozeSetsAbsoluteTime()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setSummary(QStringLiteral("Call"));
    todo->setDtDue(QDateTime(QDate(2026, 8, 17), QTime(18, 0)));
    TaskCalendar::setReminderMinutes(todo, 0);
    const QDateTime now(QDate(2026, 8, 17), QTime(17, 50));
    TaskCalendar::snoozeReminder(todo, QStringLiteral("15m"), now);
    QCOMPARE(TaskCalendar::nextReminderTime(todo, now), now.addSecs(15 * 60));
    TaskCalendar::snoozeReminder(todo, QStringLiteral("tomorrow"), now);
    QCOMPARE(TaskCalendar::nextReminderTime(todo, now).date(), QDate(2026, 8, 18));
}

QTEST_GUILESS_MAIN(CalendarTest)
#include "calendar_test.moc"
