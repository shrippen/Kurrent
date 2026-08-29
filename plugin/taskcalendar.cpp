#include "taskcalendar.h"

#include <KCalendarCore/Alarm>
#include <KCalendarCore/Duration>
#include <KCalendarCore/Event>
#include <KCalendarCore/MemoryCalendar>
#include <KCalendarCore/OccurrenceIterator>
#include <KCalendarCore/Recurrence>

#include <QDateTime>
#include <QTime>
#include <QTimeZone>

namespace TaskCalendar
{

QString recurrencePresetFromTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo || !todo->recurs()) {
        return QStringLiteral("none");
    }

    switch (todo->recurrence()->recurrenceType()) {
    case KCalendarCore::Recurrence::rDaily:
        return QStringLiteral("daily");
    case KCalendarCore::Recurrence::rWeekly:
        return QStringLiteral("weekly");
    case KCalendarCore::Recurrence::rMonthlyDay:
    case KCalendarCore::Recurrence::rMonthlyPos:
        return QStringLiteral("monthly");
    case KCalendarCore::Recurrence::rYearlyMonth:
    case KCalendarCore::Recurrence::rYearlyDay:
    case KCalendarCore::Recurrence::rYearlyPos:
        return QStringLiteral("yearly");
    default:
        return QStringLiteral("other");
    }
}

void applyRecurrencePreset(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDate &today)
{
    if (!todo) {
        return;
    }
    if (preset == QLatin1String("other")) {
        return;
    }

    KCalendarCore::Recurrence *recurrence = todo->recurrence();
    recurrence->clear();

    if (preset == QLatin1String("none") || preset.isEmpty()) {
        return;
    }

    if (!todo->hasStartDate()) {
        if (todo->hasDueDate()) {
            todo->setDtStart(todo->dtDue());
        } else {
            todo->setDtStart(QDateTime(today, QTime(0, 0)));
        }
    }

    const QDate anchor = todo->dtStart().date();

    if (preset == QLatin1String("daily")) {
        recurrence->setDaily(1);
    } else if (preset == QLatin1String("weekly")) {
        recurrence->setWeekly(1);
    } else if (preset == QLatin1String("monthly")) {
        recurrence->setMonthly(1);
        recurrence->setMonthlyDate({anchor.day()});
    } else if (preset == QLatin1String("yearly")) {
        recurrence->setYearly(1);
        recurrence->setYearlyDate({anchor.day()});
        recurrence->setYearlyMonth({anchor.month()});
    }
}

QString sectionFromTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo) {
        return {};
    }

    const QString kurrentList = todo->customProperty(QByteArray("KURRENT"), QByteArray("LIST"));
    if (!kurrentList.isEmpty()) {
        return kurrentList;
    }

    const QString genericList = todo->customProperty(QByteArray("VCALENDAR"), QByteArray("LIST"));
    if (!genericList.isEmpty()) {
        return genericList;
    }

    return {};
}

void setSection(const KCalendarCore::Todo::Ptr &todo, const QString &section)
{
    if (!todo) {
        return;
    }
    const QString trimmed = section.trimmed();
    if (trimmed.isEmpty()) {
        todo->removeCustomProperty(QByteArray("KURRENT"), QByteArray("LIST"));
        return;
    }
    todo->setCustomProperty(QByteArray("KURRENT"), QByteArray("LIST"), trimmed);
}

bool completeTodo(const KCalendarCore::Todo::Ptr &todo, CompleteAction action, const QDateTime &now)
{
    if (!todo) {
        return false;
    }

    if (action == CompleteAction::Unmark) {
        todo->setCompleted(false);
        todo->setPercentComplete(0);
        return true;
    }

    if (!todo->recurs()) {
        todo->setCompleted(true);
        todo->setPercentComplete(100);
        return true;
    }

    QDateTime anchor = todo->hasDueDate() && todo->dtDue().isValid() ? todo->dtDue() : todo->dtStart();
    if (!anchor.isValid()) {
        anchor = now;
    }
    QDateTime seriesStart = (todo->hasStartDate() && todo->dtStart().isValid()) ? todo->dtStart() : anchor;
    QDateTime next = todo->recurrence()->getNextDateTime(seriesStart.addSecs(1));
    if (!next.isValid() || next.date() <= seriesStart.date()) {
        const int freq = qMax(1, todo->recurrence()->frequency());
        switch (todo->recurrence()->recurrenceType()) {
        case KCalendarCore::Recurrence::rDaily:
            next = seriesStart.addDays(freq);
            break;
        case KCalendarCore::Recurrence::rWeekly:
            next = seriesStart.addDays(7 * freq);
            break;
        case KCalendarCore::Recurrence::rMonthlyDay:
        case KCalendarCore::Recurrence::rMonthlyPos:
            next = seriesStart.addMonths(freq);
            break;
        case KCalendarCore::Recurrence::rYearlyMonth:
        case KCalendarCore::Recurrence::rYearlyDay:
        case KCalendarCore::Recurrence::rYearlyPos:
            next = seriesStart.addYears(freq);
            break;
        default:
            break;
        }
    }

    const qint64 shiftMsecs = seriesStart.msecsTo(next);
    if (shiftMsecs <= 0) {
        todo->setCompleted(true);
        todo->setPercentComplete(100);
        return true;
    }
    const QDateTime originalDue = todo->dtDue(true);
    todo->setDtStart(next);
    if (originalDue.isValid()) {
        todo->setDtDue(originalDue.addMSecs(shiftMsecs), true);
    } else {
        todo->setDtDue(next, true);
    }
    todo->setCompleted(false);
    todo->setPercentComplete(0);
    return true;
}

int reminderMinutesFromTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo) {
        return -1;
    }
    for (const KCalendarCore::Alarm::Ptr &alarm : todo->alarms()) {
        if (!alarm || !alarm->enabled()) {
            continue;
        }
        if (alarm->hasEndOffset()) {
            return qMax(0, -alarm->endOffset().asSeconds() / 60);
        }
        if (alarm->hasStartOffset()) {
            return qMax(0, -alarm->startOffset().asSeconds() / 60);
        }
        if (alarm->time().isValid()) {
            return 0;
        }
    }
    return -1;
}

void setReminderMinutes(const KCalendarCore::Todo::Ptr &todo, int minutes)
{
    if (!todo) {
        return;
    }
    todo->clearAlarms();
    if (minutes < 0) {
        return;
    }
    KCalendarCore::Alarm::Ptr alarm = todo->newAlarm();
    alarm->setDisplayAlarm(todo->summary());
    alarm->setEnabled(true);
    alarm->setEndOffset(KCalendarCore::Duration(-minutes * 60, KCalendarCore::Duration::Seconds));
}

QDateTime nextReminderTime(const KCalendarCore::Todo::Ptr &todo, const QDateTime &now)
{
    if (!todo || todo->isCompleted() || !now.isValid()) {
        return {};
    }
    QDateTime soonest;
    const QDateTime probe = now.addSecs(-1);
    for (const KCalendarCore::Alarm::Ptr &alarm : todo->alarms()) {
        if (!alarm || !alarm->enabled()) {
            continue;
        }
        const QDateTime next = alarm->nextTime(probe);
        if (!next.isValid()) {
            continue;
        }
        if (!soonest.isValid() || next < soonest) {
            soonest = next;
        }
    }
    return soonest;
}

void snoozeReminder(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDateTime &now)
{
    if (!todo || !now.isValid()) {
        return;
    }
    QDateTime when;
    if (preset == QLatin1String("15m")) {
        when = now.addSecs(15 * 60);
    } else if (preset == QLatin1String("1h")) {
        when = now.addSecs(60 * 60);
    } else if (preset == QLatin1String("tomorrow")) {
        when = QDateTime(now.date().addDays(1), QTime(9, 0));
    }
    if (!when.isValid()) {
        return;
    }
    todo->clearAlarms();
    KCalendarCore::Alarm::Ptr alarm = todo->newAlarm();
    alarm->setDisplayAlarm(todo->summary());
    alarm->setEnabled(true);
    alarm->setTime(when);
}

QDateTime dueDateFromTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo || !todo->hasDueDate()) {
        return {};
    }
    const QDateTime due = todo->dtDue();
    return due.isValid() ? due : QDateTime();
}

QDateTime startDateFromTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo || !todo->hasStartDate()) {
        return {};
    }
    const QDateTime start = todo->dtStart();
    return start.isValid() ? start : QDateTime();
}

void appendBusyIntervals(const KCalendarCore::Incidence::Ptr &incidence,
                         const QDateTime &rangeStart,
                         const QDateTime &rangeEnd,
                         QVector<BusyInterval> *out)
{
    if (!incidence || !out || !rangeStart.isValid() || !rangeEnd.isValid() || rangeStart >= rangeEnd) {
        return;
    }
    const KCalendarCore::Event::Ptr event = incidence.dynamicCast<KCalendarCore::Event>();
    if (!event) {
        return;
    }
    if (event->transparency() == KCalendarCore::Event::Transparent) {
        return;
    }
    if (incidence->status() == KCalendarCore::Incidence::StatusCanceled) {
        return;
    }

    if (!incidence->recurs()) {
        const QDateTime start = incidence->dtStart();
        const QDateTime end = event->dtEnd();
        if (start.isValid() && end.isValid() && end > rangeStart && start < rangeEnd) {
            out->append({start, end});
        }
        return;
    }

    KCalendarCore::MemoryCalendar calendar(QTimeZone::systemTimeZone());
    calendar.addIncidence(incidence);
    KCalendarCore::OccurrenceIterator it(calendar, incidence, rangeStart, rangeEnd);
    while (it.hasNext()) {
        it.next();
        const QDateTime start = it.occurrenceStartDate();
        const QDateTime end = it.occurrenceEndDate();
        if (start.isValid() && end.isValid() && end > rangeStart && start < rangeEnd) {
            out->append({start, end});
        }
    }
}

bool isBusyAt(const QDateTime &when, const QVector<BusyInterval> &intervals)
{
    if (!when.isValid()) {
        return false;
    }
    for (const BusyInterval &interval : intervals) {
        if (interval.start.isValid() && interval.end.isValid() && interval.start <= when && when < interval.end) {
            return true;
        }
    }
    return false;
}

} // namespace TaskCalendar
