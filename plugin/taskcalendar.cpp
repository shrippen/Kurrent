#include "taskcalendar.h"

#include <KCalendarCore/Recurrence>

#include <QDateTime>
#include <QTime>

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

} // namespace TaskCalendar
