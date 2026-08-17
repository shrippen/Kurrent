#pragma once

#include <KCalendarCore/Todo>

#include <QDate>
#include <QString>

namespace TaskCalendar
{

QString recurrencePresetFromTodo(const KCalendarCore::Todo::Ptr &todo);
void applyRecurrencePreset(const KCalendarCore::Todo::Ptr &todo, const QString &preset, const QDate &today);
QString sectionFromTodo(const KCalendarCore::Todo::Ptr &todo);

} // namespace TaskCalendar
