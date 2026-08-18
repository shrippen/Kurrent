#pragma once

#include <KCalendarCore/Todo>

#include <QDate>
#include <QDateTime>
#include <QString>

namespace TaskCalendar
{

QString recurrencePresetFromTodo(const KCalendarCore::Todo::Ptr &todo);
void applyRecurrencePreset(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDate &today);
QString sectionFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setSection(const KCalendarCore::Todo::Ptr &todo, const QString &section);
bool completeTodo(const KCalendarCore::Todo::Ptr &todo, bool completed, const QDateTime &now);

// -1 = no reminder, 0 = at due, N = N minutes before due.
int reminderMinutesFromTodo(const KCalendarCore::Todo::Ptr &todo);
void setReminderMinutes(const KCalendarCore::Todo::Ptr &todo, int minutes);
QDateTime nextReminderTime(const KCalendarCore::Todo::Ptr &todo, const QDateTime &now);
void snoozeReminder(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDateTime &now);

} // namespace TaskCalendar
