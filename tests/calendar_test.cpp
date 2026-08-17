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
    void nullTodoIsSafe();
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

void CalendarTest::nullTodoIsSafe()
{
    QCOMPARE(TaskCalendar::recurrencePresetFromTodo({}), QStringLiteral("none"));
    QCOMPARE(TaskCalendar::sectionFromTodo({}), QString());
    TaskCalendar::applyRecurrencePreset({}, QStringLiteral("daily"), QDate(2026, 8, 13));
}

QTEST_GUILESS_MAIN(CalendarTest)
#include "calendar_test.moc"
