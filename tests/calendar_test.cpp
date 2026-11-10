#include "taskcalendar.h"

#include <KCalendarCore/Event>
#include <KCalendarCore/ICalFormat>
#include <KCalendarCore/Todo>

#include <QDate>
#include <QDateTime>
#include <QBitArray>
#include <QTime>
#include <QTimeZone>
#include <QtTest>

class CalendarTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void presetNoneWithoutRecurrence();
    void detachKeepsEveryAlarm();
    void applyAndReadPresets();
    void clearPresetRemovesRecurrence();
    void sectionPrefersKurrentThenVCalendar();
    void setSectionWritesKurrentList();
    void columnRoundTrip();
    void kanbanSortOrderRoundTrip();
    void completeNonRecurringMarksDone();
    void completeDailyAdvancesDatesAndKeepsRrule();
    void otherPresetDoesNotClearCustomRrule();
    void nullTodoIsSafe();
    void reminderOffAtDueAndBefore();
    void snoozeSetsAbsoluteTime();
    void dueAndStartFromTodo();
    void busyIntervalsAndIsBusyAt();
    void moveOccurrenceKeepsRule_data();
    void moveOccurrenceKeepsRule();
    void completeAfterMovingEarlierContinuesFromOrigin();
    void completeAfterMovingLaterContinuesFromOrigin();
    void moveBackToOriginClearsMark();
    void completeClearsStaleOccurrence();
    void completeAllDayDailyKeepsDayAcrossDst();
    void completeAfterMovingLaterSkipsPastOccurrences();
    void staleOriginIsIgnored();
    void moveOccurrenceWithoutStart();
};

namespace
{
KCalendarCore::Todo::Ptr icsRoundTrip(const KCalendarCore::Todo::Ptr &todo)
{
    KCalendarCore::ICalFormat format;
    return format.fromString(format.toICalString(todo)).dynamicCast<KCalendarCore::Todo>();
}

QString rruleOf(const KCalendarCore::Todo::Ptr &todo)
{
    KCalendarCore::ICalFormat format;
    const QStringList lines = format.toICalString(todo).split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        if (line.startsWith(QLatin1String("RRULE"))) {
            return line.trimmed();
        }
    }
    return {};
}

KCalendarCore::Todo::Ptr seriesTodo(const QDateTime &start, const QDateTime &due)
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    todo->setUid(QStringLiteral("series"));
    todo->setSummary(QStringLiteral("Series"));
    todo->setDtStart(start);
    todo->setDtDue(due, true);
    return todo;
}
} // namespace

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

void CalendarTest::columnRoundTrip()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    QCOMPARE(TaskCalendar::columnFromTodo(todo), QString());
    TaskCalendar::setColumn(todo, QStringLiteral("doing"));
    QCOMPARE(TaskCalendar::columnFromTodo(todo), QStringLiteral("doing"));
    TaskCalendar::setColumn(todo, QString());
    QCOMPARE(TaskCalendar::columnFromTodo(todo), QString());
}

void CalendarTest::kanbanSortOrderRoundTrip()
{
    KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
    QCOMPARE(TaskCalendar::kanbanSortOrderFromTodo(todo), 0);
    TaskCalendar::setKanbanSortOrder(todo, 42);
    QCOMPARE(TaskCalendar::appleSortOrderFromTodo(todo), 42);
    QCOMPARE(TaskCalendar::columnOrderFromTodo(todo), 42);
    QCOMPARE(TaskCalendar::kanbanSortOrderFromTodo(todo), 42);
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

void CalendarTest::dueAndStartFromTodo()
{
    KCalendarCore::Todo::Ptr empty(new KCalendarCore::Todo);
    QVERIFY(!TaskCalendar::dueDateFromTodo(empty).isValid());
    QVERIFY(!TaskCalendar::startDateFromTodo(empty).isValid());
    QVERIFY(!TaskCalendar::dueDateFromTodo({}).isValid());

    KCalendarCore::Todo::Ptr timed(new KCalendarCore::Todo);
    const QDateTime due(QDate(2026, 8, 27), QTime(14, 30));
    const QDateTime start(QDate(2026, 8, 26), QTime(9, 0));
    timed->setDtDue(due);
    timed->setDtStart(start);
    QVERIFY(timed->hasDueDate());
    QVERIFY(timed->hasStartDate());
    QCOMPARE(TaskCalendar::dueDateFromTodo(timed), due);
    QCOMPARE(TaskCalendar::startDateFromTodo(timed), start);

    KCalendarCore::Todo::Ptr allDay(new KCalendarCore::Todo);
    allDay->setDtDue(QDateTime(QDate(2026, 8, 28), QTime(0, 0)));
    allDay->setAllDay(true);
    QVERIFY(allDay->hasDueDate());
    QCOMPARE(TaskCalendar::dueDateFromTodo(allDay).date(), QDate(2026, 8, 28));
}

void CalendarTest::busyIntervalsAndIsBusyAt()
{
    const QDateTime rangeStart(QDate(2026, 8, 29), QTime(0, 0));
    const QDateTime rangeEnd(QDate(2026, 8, 31), QTime(0, 0));
    const QDateTime during(QDate(2026, 8, 29), QTime(10, 30));
    const QDateTime outside(QDate(2026, 8, 29), QTime(12, 30));

    KCalendarCore::Event::Ptr busy(new KCalendarCore::Event);
    busy->setDtStart(QDateTime(QDate(2026, 8, 29), QTime(10, 0)));
    busy->setDtEnd(QDateTime(QDate(2026, 8, 29), QTime(11, 0)));

    KCalendarCore::Event::Ptr free(new KCalendarCore::Event);
    free->setDtStart(QDateTime(QDate(2026, 8, 29), QTime(10, 0)));
    free->setDtEnd(QDateTime(QDate(2026, 8, 29), QTime(11, 0)));
    free->setTransparency(KCalendarCore::Event::Transparent);

    QVector<TaskCalendar::BusyInterval> intervals;
    TaskCalendar::appendBusyIntervals(busy, rangeStart, rangeEnd, &intervals);
    TaskCalendar::appendBusyIntervals(free, rangeStart, rangeEnd, &intervals);
    QCOMPARE(intervals.size(), 1);
    QVERIFY(TaskCalendar::isBusyAt(during, intervals));
    QVERIFY(!TaskCalendar::isBusyAt(outside, intervals));
    QVERIFY(!TaskCalendar::isBusyAt({}, intervals));
}

// #29: moving one occurrence changes only the current occurrence; rule, DTSTART and DUE stay.
void CalendarTest::moveOccurrenceKeepsRule_data()
{
    QTest::addColumn<QString>("kind");
    QTest::newRow("daily") << QStringLiteral("daily");
    QTest::newRow("weekly") << QStringLiteral("weekly");
    QTest::newRow("weekly-byday") << QStringLiteral("weekly-byday");
    QTest::newRow("monthly") << QStringLiteral("monthly");
    QTest::newRow("yearly") << QStringLiteral("yearly");
}

void CalendarTest::moveOccurrenceKeepsRule()
{
    QFETCH(QString, kind);
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0)); // a Monday
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    KCalendarCore::Recurrence *rule = todo->recurrence();
    if (kind == QLatin1String("daily")) {
        rule->setDaily(1);
    } else if (kind == QLatin1String("weekly")) {
        rule->setWeekly(1);
    } else if (kind == QLatin1String("weekly-byday")) {
        QBitArray days(7);
        days.setBit(0); // Monday
        days.setBit(3); // Thursday
        rule->setWeekly(1, days);
    } else if (kind == QLatin1String("monthly")) {
        rule->setMonthly(1);
        rule->addMonthlyDate(2);
    } else {
        rule->setYearly(1);
        rule->addYearlyDate(2);
        rule->addYearlyMonth(11);
    }
    const QString rrule = rruleOf(todo);
    QVERIFY(!rrule.isEmpty());

    QVERIFY(TaskCalendar::moveOccurrence(todo, -3)); // to the Friday before
    const KCalendarCore::Todo::Ptr back = icsRoundTrip(todo);
    QCOMPARE(rruleOf(back), rrule);
    QCOMPARE(back->dtStart(true), start);
    QCOMPARE(back->dtDue(true), start.addSecs(3600));
    QCOMPARE(back->dtStart(), QDateTime(QDate(2026, 10, 30), QTime(9, 0)));
    QCOMPARE(back->dtDue(), QDateTime(QDate(2026, 10, 30), QTime(10, 0)));
    QCOMPARE(TaskCalendar::occurrenceOrigin(back), QDate(2026, 11, 2));
}

void CalendarTest::completeAfterMovingEarlierContinuesFromOrigin()
{
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0));
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    todo->recurrence()->setWeekly(1);
    QVERIFY(TaskCalendar::moveOccurrence(todo, -3));
    todo = icsRoundTrip(todo);

    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 10, 30), QTime(12, 0))));
    todo = icsRoundTrip(todo);
    // Not 2 November again: the moved occurrence was that one.
    QCOMPARE(todo->dtStart(), QDateTime(QDate(2026, 11, 9), QTime(9, 0)));
    QCOMPARE(todo->dtDue(), QDateTime(QDate(2026, 11, 9), QTime(10, 0)));
    QVERIFY(!TaskCalendar::occurrenceOrigin(todo).isValid());
    QVERIFY(!todo->isCompleted());
}

void CalendarTest::completeAfterMovingLaterContinuesFromOrigin()
{
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0));
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    todo->recurrence()->setWeekly(1);
    QVERIFY(TaskCalendar::moveOccurrence(todo, 2));
    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 11, 4), QTime(12, 0))));
    QCOMPARE(todo->dtStart(), QDateTime(QDate(2026, 11, 9), QTime(9, 0)));
    QCOMPARE(todo->dtDue(), QDateTime(QDate(2026, 11, 9), QTime(10, 0)));
}

void CalendarTest::moveBackToOriginClearsMark()
{
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0));
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    todo->recurrence()->setDaily(1);
    QVERIFY(TaskCalendar::moveOccurrence(todo, 1));
    QVERIFY(TaskCalendar::moveOccurrence(todo, -1));
    QCOMPARE(todo->dtStart(), start);
    QVERIFY(!TaskCalendar::occurrenceOrigin(todo).isValid());
    QVERIFY(!TaskCalendar::moveOccurrence(todo, 0));
    KCalendarCore::Todo::Ptr single(new KCalendarCore::Todo);
    single->setDtStart(start);
    QVERIFY(!TaskCalendar::moveOccurrence(single, 1)); // only series
}

// A DTRECURRENCE from another client (KOrganizer) must not stay behind when DTSTART moves on.
void CalendarTest::completeClearsStaleOccurrence()
{
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0));
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    todo->recurrence()->setDaily(1);
    todo->setDtRecurrence(QDateTime(QDate(2026, 11, 4), QTime(9, 0)));
    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 11, 4), QTime(12, 0))));
    QCOMPARE(todo->dtStart(), QDateTime(QDate(2026, 11, 5), QTime(9, 0)));
    QCOMPARE(todo->dtDue(), QDateTime(QDate(2026, 11, 5), QTime(10, 0)));
}

void CalendarTest::completeAllDayDailyKeepsDayAcrossDst()
{
    const QTimeZone berlin("Europe/Berlin");
    // 25 October 2026: clocks go back in Berlin.
    const QDateTime start(QDate(2026, 10, 24), QTime(0, 0), berlin);
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start);
    todo->setAllDay(true);
    todo->recurrence()->setDaily(1);
    for (int i = 0; i < 3; ++i) {
        QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark,
                                           QDateTime(QDate(2026, 10, 24 + i), QTime(12, 0), berlin)));
        QCOMPARE(todo->dtDue().date(), QDate(2026, 10, 25 + i));
        QCOMPARE(todo->dtStart().date(), QDate(2026, 10, 25 + i));
    }
}

// Moved later than the next occurrence: the series continues after the moved day.
void CalendarTest::completeAfterMovingLaterSkipsPastOccurrences()
{
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0));
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    todo->recurrence()->setDaily(1);
    QVERIFY(TaskCalendar::moveOccurrence(todo, 3)); // Monday -> Thursday
    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 11, 5), QTime(12, 0))));
    QCOMPARE(todo->dtStart(), QDateTime(QDate(2026, 11, 6), QTime(9, 0)));

    KCalendarCore::Todo::Ptr weekly = seriesTodo(start, start.addSecs(3600));
    weekly->recurrence()->setWeekly(1);
    QVERIFY(TaskCalendar::moveOccurrence(weekly, 7)); // onto the next occurrence
    QVERIFY(TaskCalendar::completeTodo(weekly, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 11, 9), QTime(12, 0))));
    QCOMPARE(weekly->dtStart(), QDateTime(QDate(2026, 11, 16), QTime(9, 0)));
}

// Another client (KOrganizer: Todo::setCompleted) moves DTRECURRENCE on and keeps our mark.
void CalendarTest::staleOriginIsIgnored()
{
    const QDateTime start(QDate(2026, 11, 2), QTime(9, 0));
    KCalendarCore::Todo::Ptr todo = seriesTodo(start, start.addSecs(3600));
    todo->recurrence()->setDaily(1);
    QVERIFY(TaskCalendar::moveOccurrence(todo, 2));
    QCOMPARE(TaskCalendar::occurrenceOrigin(todo), QDate(2026, 11, 2));
    todo->setDtRecurrence(QDateTime(QDate(2026, 11, 10), QTime(9, 0)));
    QVERIFY(!TaskCalendar::occurrenceOrigin(todo).isValid());
    QVERIFY(TaskCalendar::completeTodo(todo, TaskCalendar::CompleteAction::Mark, QDateTime(QDate(2026, 11, 10), QTime(12, 0))));
    QCOMPARE(todo->dtStart(), QDateTime(QDate(2026, 11, 11), QTime(9, 0)));
}

// Series from tasks.org or Nextcloud often have DUE but no DTSTART.
void CalendarTest::moveOccurrenceWithoutStart()
{
    // As Akonadi delivers it: an ICS without DTSTART (KCalendarCore reads the DUE as start).
    KCalendarCore::Todo::Ptr seed(new KCalendarCore::Todo);
    seed->setUid(QStringLiteral("no-start"));
    const QDateTime due(QDate(2026, 11, 2), QTime(10, 0));
    seed->setDtDue(due, true);
    seed->recurrence()->setStartDateTime(due, false);
    seed->recurrence()->setDaily(1);
    KCalendarCore::Todo::Ptr todo = icsRoundTrip(seed);
    QVERIFY(TaskCalendar::moveOccurrence(todo, 2));
    const KCalendarCore::Todo::Ptr back = icsRoundTrip(todo);
    QCOMPARE(back->dtDue(), QDateTime(QDate(2026, 11, 4), QTime(10, 0)));
    QCOMPARE(back->dtDue(true), due);
    QCOMPARE(TaskCalendar::occurrenceOrigin(back), QDate(2026, 11, 2));
}

// Detaching copies the series' alarms as they are (review #51): one before the start stays
// before the start, a second one is not lost.
void CalendarTest::detachKeepsEveryAlarm()
{
    KCalendarCore::Todo::Ptr series(new KCalendarCore::Todo);
    series->setSummary(QStringLiteral("standup"));
    series->setDtStart(QDateTime(QDate(2026, 11, 11), QTime(9, 0)));
    series->setDtDue(QDateTime(QDate(2026, 11, 11), QTime(9, 30)), true);
    series->recurrence()->setDaily(1);
    KCalendarCore::Alarm::Ptr beforeStart = series->newAlarm();
    beforeStart->setDisplayAlarm(QStringLiteral("standup"));
    beforeStart->setStartOffset(KCalendarCore::Duration(-15 * 60, KCalendarCore::Duration::Seconds));
    beforeStart->setEnabled(true);
    KCalendarCore::Alarm::Ptr atDue = series->newAlarm();
    atDue->setDisplayAlarm(QStringLiteral("standup"));
    atDue->setEndOffset(KCalendarCore::Duration(0, KCalendarCore::Duration::Seconds));
    atDue->setEnabled(true);

    const KCalendarCore::Todo::Ptr detached = TaskCalendar::detachOccurrence(
        series, QDateTime(QDate(2026, 11, 11), QTime(14, 0)), QDateTime(QDate(2026, 11, 11), QTime(15, 30)));
    QVERIFY(detached);
    QCOMPARE(detached->alarms().size(), 2);
    const KCalendarCore::Alarm::Ptr first = detached->alarms().at(0);
    QVERIFY(first->hasStartOffset());
    QCOMPARE(first->startOffset().asSeconds(), -15 * 60);
    QCOMPARE(first->time(), QDateTime(QDate(2026, 11, 11), QTime(13, 45)));
    QVERIFY(detached->alarms().at(1)->hasEndOffset());
    // The copies belong to the new task, not to the series.
    QCOMPARE(series->alarms().size(), 2);
    QCOMPARE(first->parentUid(), detached->uid());
}

QTEST_GUILESS_MAIN(CalendarTest)
#include "calendar_test.moc"
