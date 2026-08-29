#pragma once

#include <KCalendarCore/Incidence>
#include <KCalendarCore/Todo>

#include <QDate>
#include <QDateTime>
#include <QString>
#include <QVector>

namespace TaskCalendar
{

enum class CompleteAction { Unmark, Mark };

QString recurrencePresetFromTodo(const KCalendarCore::Todo::Ptr &todo);
void applyRecurrencePreset(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDate &today);
QString sectionFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setSection(const KCalendarCore::Todo::Ptr &todo, const QString &section);
bool completeTodo(const KCalendarCore::Todo::Ptr &todo, CompleteAction action, const QDateTime &now);

// -1 = no reminder, 0 = at due, N = N minutes before due.
int reminderMinutesFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setReminderMinutes(const KCalendarCore::Todo::Ptr &todo, int minutes);
QDateTime nextReminderTime(const KCalendarCore::Todo::Ptr &todo, const QDateTime &now);
void snoozeReminder(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDateTime &now);

/** Due/start for list/editor: empty when unset; local midnight for date-only values. */
QDateTime dueDateFromTodo(const KCalendarCore::Todo::Ptr &todo);
QDateTime startDateFromTodo(const KCalendarCore::Todo::Ptr &todo);

struct BusyInterval {
    QDateTime start;
    QDateTime end;
};

/** Expand opaque (busy) occurrences of an incidence into [start, end) intervals. */
void appendBusyIntervals(const KCalendarCore::Incidence::Ptr &incidence,
                         const QDateTime &rangeStart,
                         const QDateTime &rangeEnd,
                         QVector<BusyInterval> *out);

bool isBusyAt(const QDateTime &when, const QVector<BusyInterval> &intervals);

} // namespace TaskCalendar
