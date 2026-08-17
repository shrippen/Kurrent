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

bool completeTodo(const KCalendarCore::Todo::Ptr &todo, bool completed, const QDateTime &now)
{
    if (!todo) {
        return false;
    }

    if (!completed) {
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

} // namespace TaskCalendar
