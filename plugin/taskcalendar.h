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
QString columnFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setColumn(const KCalendarCore::Todo::Ptr &todo, const QString &column);
int columnOrderFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setColumnOrder(const KCalendarCore::Todo::Ptr &todo, int order);
int appleSortOrderFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setAppleSortOrder(const KCalendarCore::Todo::Ptr &todo, int order);
int kanbanSortOrderFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setKanbanSortOrder(const KCalendarCore::Todo::Ptr &todo, int order);
QStringList attendeesFromTodo(const KCalendarCore::Todo::Ptr &todo);
QString geoMapUrlFromTodo(const KCalendarCore::Todo::Ptr &todo);
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
    QString summary;
    qint64 collectionId = 0;
};

/** Expand opaque (busy) occurrences of an incidence into [start, end) intervals. */
void appendBusyIntervals(const KCalendarCore::Incidence::Ptr &incidence,
                         const QDateTime &rangeStart,
                         const QDateTime &rangeEnd,
                         QVector<BusyInterval> *out);

bool isBusyAt(const QDateTime &when, const QVector<BusyInterval> &intervals);

} // namespace TaskCalendar
