// Demo data for Kurrent: the tasks of Studio Weber, the demo world shared by all
// shrippen projects (demo/world.json, copied from shrippen.github.io/demo; do not edit).
// KURRENT_DEMO=de|en (or 1: language from the locale) starts Kurrent with these tasks in
// memory instead of Akonadi. The data is read at runtime from KURRENT_DEMO_WORLD (a path;
// demo/start.sh and demo/shots.sh set it), so releases carry no demo data. Dates are day
// offsets from Monday of the current week; DEMO_TODAY=YYYY-MM-DD fixes "today".
#pragma once

#include "taskcalendar.h"

#include <Akonadi/Collection>
#include <KCalendarCore/Todo>
#include <QList>
#include <QString>

namespace DemoData
{
struct Task {
    qint64 id = 0;
    qint64 collectionId = 0;
    KCalendarCore::Todo::Ptr todo;
};

struct Data {
    QList<Akonadi::Collection> collections;
    QList<Task> tasks;
    // Calendar events for the agenda ("Calendar + tasks" view).
    QVector<TaskCalendar::BusyInterval> events;
    // Monday of the demo week: the agenda opens there, where the demo events are.
    QDate monday;
};

// Language from KURRENT_DEMO, or an empty string when demo mode is off.
QString language();
bool enabled();
// Collection id -> color, for the projectColors setting.
QString projectColorsJson();
Data load();
}
