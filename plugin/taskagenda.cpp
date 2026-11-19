#include "taskagenda.h"

#include "taskentry.h"

#include <QHash>

#include <algorithm>

TaskAgenda::TaskAgenda(SharedTasks &shared, TaskUndo &undo, Writes writes, QObject *parent)
    : QObject(parent)
    , m_shared(shared)
    , m_undo(undo)
    , m_writes(std::move(writes))
{
}

TaskEntry TaskAgenda::entryOf(const SharedTasks::Entry &cached) const
{
    return TaskEntries::fromShared(m_shared, cached, 0, false);
}

QVariantMap TaskAgenda::heatmapCountsForMonth(const QList<TaskEntry> &visible, const QDate &monthStart,
                                              const QString &mode) const
{
    if (mode == QLatin1String("completed")) {
        const QDate monthEnd = monthStart.addMonths(1).addDays(-1);
        return heatmapCountsAll(monthStart, monthEnd, mode);
    }
    return TaskLogic::heatmapCounts(visible, mode, monthStart);
}

QVariantList TaskAgenda::agendaEventsForDay(const QDate &day) const
{
    QVariantList result;
    if (!day.isValid()) {
        return result;
    }
    const QDateTime dayStart(day, QTime(0, 0));
    const QDateTime dayEnd(day.addDays(1), QTime(0, 0));
    for (const TaskCalendar::BusyInterval &interval : m_shared.busyIntervals()) {
        if (interval.end <= dayStart || interval.start >= dayEnd) {
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("start"), interval.start);
        row.insert(QStringLiteral("end"), interval.end);
        row.insert(QStringLiteral("summary"), interval.summary);
        row.insert(QStringLiteral("calendarId"), interval.collectionId);
        const QString calName = m_shared.collectionNames().value(interval.collectionId);
        row.insert(QStringLiteral("calendarName"), calName);
        const bool allDay = interval.start.time() == QTime(0, 0) && interval.end.time() == QTime(0, 0);
        row.insert(QStringLiteral("allDay"), allDay);
        result.append(row);
    }
    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("start")).toDateTime()
               < b.toMap().value(QStringLiteral("start")).toDateTime();
    });
    return result;
}

QVariantMap TaskAgenda::heatmapCountsAll(const QDate &start, const QDate &end, const QString &mode) const
{
    QVariantMap counts;
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        const SharedTasks::Entry &cached = it.value();
        if (!cached.todo) continue;
        TaskEntry entry;
        entry.itemId = it.key();
        entry.completed = cached.todo->isCompleted();
        entry.completedDate = cached.todo->completed();
        entry.dueDate = TaskCalendar::dueDateFromTodo(cached.todo);
        entry.startDate = cached.todo->dtStart();
        const QString key = TaskLogic::heatmapDayKey(entry, mode, start);
        if (key.isEmpty()) continue;
        const QDate day = QDate::fromString(key, Qt::ISODate);
        if (!day.isValid() || day < start || day > end) continue;
        counts.insert(key, counts.value(key, 0).toInt() + 1);
    }
    return counts;
}

QVariantList TaskAgenda::heatmapTasksForDay(const QList<TaskEntry> &visible, const QDate &day,
                                            const QString &mode) const
{
    if (!day.isValid()) {
        return {};
    }
    const QString dayKey = day.toString(Qt::ISODate);
    QList<TaskEntry> matches;
    if (mode == QLatin1String("completed")) {
        // Completions count across all tasks (heatmapCountsAll), not only the visible ones.
        for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
            if (!it->todo || it->pendingDelete || !it->todo->isCompleted()) {
                continue;
            }
            const TaskEntry entry = entryOf(*it);
            if (TaskLogic::heatmapDayKey(entry, mode, day) == dayKey) {
                matches.append(entry);
            }
        }
    } else {
        for (const TaskEntry &entry : visible) {
            if (TaskLogic::heatmapDayKey(entry, mode, day) == dayKey) {
                matches.append(entry);
            }
        }
    }
    std::sort(matches.begin(), matches.end(), [](const TaskEntry &a, const TaskEntry &b) {
        return QString::localeAwareCompare(a.summary, b.summary) < 0;
    });
    QVariantList result;
    result.reserve(matches.size());
    for (const TaskEntry &entry : std::as_const(matches)) {
        result.append(TaskEntries::toMap(entry));
    }
    return result;
}

QVariantList TaskAgenda::agendaTasksForRange(const QDate &from, const QDate &to) const
{
    QVariantList result;
    if (!from.isValid() || !to.isValid() || from > to) {
        return result;
    }
    // Iterate ALL Akonadi tasks (m_shared.tasks()) so completed tasks are always included,
    // regardless of the current sidebar filter state.
    const QDateTime rangeStart(from, QTime(0, 0));
    const QDateTime rangeEnd(to.addDays(1), QTime(0, 0));
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        const SharedTasks::Entry &cached = it.value();
        if (!cached.todo) continue;
        const bool isCompleted = cached.todo->isCompleted();
        const QDateTime dueDt = TaskCalendar::dueDateFromTodo(cached.todo);
        const QDateTime compDt = cached.todo->completed();
        // Uncompleted tasks: match by dueDate
        bool matchUncompleted = !isCompleted && dueDt.isValid()
                && dueDt >= rangeStart && dueDt < rangeEnd;
        // Completed tasks: match by completedDate; fallback to dueDate if completedDate is invalid
        bool matchCompleted = isCompleted
                && ((compDt.isValid() && compDt >= rangeStart && compDt < rangeEnd)
                    || (!compDt.isValid() && dueDt.isValid() && dueDt >= rangeStart && dueDt < rangeEnd));
        if (!matchUncompleted && !matchCompleted) {
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("itemId"), it.key());
        row.insert(QStringLiteral("uid"), cached.todo->uid());
        row.insert(QStringLiteral("summary"), cached.todo->summary());
        row.insert(QStringLiteral("completed"), isCompleted);
        row.insert(QStringLiteral("completedDate"), compDt);
        row.insert(QStringLiteral("due"), dueDt);
        row.insert(QStringLiteral("priority"), cached.todo->priority());
        row.insert(QStringLiteral("categories"), cached.todo->categories());
        result.append(row);
    }
    return result;
}

QVariantMap TaskAgenda::agendaTasksByDay(const QDate &from, const QDate &to) const
{
    // Day lists in task order, open tasks first: {"2026-10-12": [open…, done…]}.
    QHash<QString, QVariantList> open;
    QHash<QString, QVariantList> done;
    QStringList days;
    const QVariantList tasks = agendaTasksForRange(from, to);
    for (const QVariant &value : tasks) {
        const QVariantMap task = value.toMap();
        const bool completed = task.value(QStringLiteral("completed")).toBool();
        const QDateTime completedAt = task.value(QStringLiteral("completedDate")).toDateTime();
        const QDateTime when = completed && completedAt.isValid()
                ? completedAt : task.value(QStringLiteral("due")).toDateTime();
        const QString day = when.isValid() ? when.toLocalTime().date().toString(Qt::ISODate) : QString();
        if (!days.contains(day)) {
            days.append(day);
        }
        (completed ? done : open)[day].append(task);
    }

    QVariantMap out;
    for (const QString &day : std::as_const(days)) {
        out.insert(day, open.value(day) + done.value(day));
    }
    return out;
}

QList<TaskEntry> TaskAgenda::agendaEntries() const
{
    QList<TaskEntry> tasks;
    tasks.reserve(m_shared.tasks().size());
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (!it->todo || it->pendingDelete) {
            continue;
        }
        tasks.append(entryOf(*it));
    }
    return tasks;
}

namespace
{
// Day of a task in the Agenda: a block's start day (a block until midnight may end at the next
// day's 00:00), else AgendaLogic::taskDay.
QDate agendaDayOf(const TaskEntry &task, const AgendaLogic::Span &block)
{
    return block.isValid() ? task.startDate.toLocalTime().date() : AgendaLogic::taskDay(task);
}

int minutesInto(const QDate &day, const QDateTime &when)
{
    const QDateTime local = when.toLocalTime();
    if (local.date() < day) {
        return 0;
    }
    if (local.date() > day) {
        return 24 * 60;
    }
    return local.time().hour() * 60 + local.time().minute();
}
}

QList<AgendaLogic::Span> TaskAgenda::agendaBusy(const QDate &day, const QList<TaskEntry> &tasks,
                                                    qint64 skipItemId) const
{
    QList<AgendaLogic::Span> busy;
    const QVariantList events = agendaEventsForDay(day);
    for (const QVariant &value : events) {
        const QVariantMap event = value.toMap();
        if (event.value(QStringLiteral("allDay")).toBool()) {
            continue;
        }
        busy.append({minutesInto(day, event.value(QStringLiteral("start")).toDateTime()),
                     minutesInto(day, event.value(QStringLiteral("end")).toDateTime())});
    }
    for (const TaskEntry &task : tasks) {
        if (task.completed || task.itemId == skipItemId) {
            continue;
        }
        const AgendaLogic::Span block = AgendaLogic::taskBlock(task);
        if (block.isValid() && agendaDayOf(task, block) == day) {
            busy.append(block);
        }
    }
    return busy;
}

QVariantList TaskAgenda::agendaDays(const QDate &from, int count) const
{
    QVariantList out;
    if (!from.isValid() || count <= 0) {
        return out;
    }
    const QDate today = QDate::currentDate();
    const QTime now = QTime::currentTime();
    const QList<TaskEntry> tasks = agendaEntries();
    for (int i = 0; i < count; ++i) {
        const QDate day = from.addDays(i);
        QVariantList allDayEvents;
        QVariantList items;
        QList<AgendaLogic::Span> spans;
        for (const QVariant &value : agendaEventsForDay(day)) {
            QVariantMap event = value.toMap();
            if (event.value(QStringLiteral("allDay")).toBool()) {
                allDayEvents.append(event);
                continue;
            }
            const AgendaLogic::Span span{minutesInto(day, event.value(QStringLiteral("start")).toDateTime()),
                                         minutesInto(day, event.value(QStringLiteral("end")).toDateTime())};
            event.insert(QStringLiteral("kind"), QStringLiteral("event"));
            items.append(event);
            spans.append(span);
        }
        const QList<AgendaLogic::Span> busy = agendaBusy(day, tasks, -1);
        QVariantList openLoose;
        QVariantList doneLoose;
        QList<TaskEntry> openTasks;
        QVariantList doneTasks;
        for (const TaskEntry &task : tasks) {
            const AgendaLogic::Span block = AgendaLogic::taskBlock(task);
            if (agendaDayOf(task, block) != day) {
                continue;
            }
            if (task.completed) {
                doneTasks.append(TaskEntries::toMap(task));
            } else {
                openTasks.append(task);
            }
            QVariantMap row = TaskEntries::toMap(task);
            if (!block.isValid()) {
                (task.completed ? doneLoose : openLoose).append(row);
                continue;
            }
            QList<AgendaLogic::Span> others = agendaBusy(day, tasks, task.itemId);
            const AgendaLogic::Span limits = AgendaLogic::resizeLimits(others, block);
            row.insert(QStringLiteral("kind"), QStringLiteral("task"));
            row.insert(QStringLiteral("lo"), limits.start);
            row.insert(QStringLiteral("hi"), limits.end);
            items.append(row);
            spans.append(block);
        }
        // Lanes for the drawn length: a short entry is drawn kMinShown long, moved up at the
        // day's end so it stays in the grid.
        QList<AgendaLogic::Span> drawn = spans;
        for (AgendaLogic::Span &span : drawn) {
            if (span.end - span.start < AgendaLogic::kMinShown) {
                span.start = qMin(span.start, 24 * 60 - AgendaLogic::kMinShown);
                span.end = span.start + AgendaLogic::kMinShown;
            }
        }
        const QList<AgendaLogic::Lane> lanes = AgendaLogic::lanes(drawn);
        for (int k = 0; k < items.size(); ++k) {
            QVariantMap item = items.at(k).toMap();
            item.insert(QStringLiteral("start"), spans.at(k).start);
            item.insert(QStringLiteral("end"), spans.at(k).end);
            // The drawn start, as QML derives it live (agenda.js drawnStart).
            item.insert(QStringLiteral("drawStart"), drawn.at(k).start);
            item.insert(QStringLiteral("lane"), lanes.at(k).lane);
            item.insert(QStringLiteral("lanes"), lanes.at(k).lanes);
            items[k] = item;
        }
        // The grid holds what is drawn, so a short entry at its end stays inside.
        const AgendaLogic::Span grid = AgendaLogic::gridRange(drawn);
        const int planFrom = AgendaLogic::planFrom(day, today, now);
        QVariantList free;
        for (const AgendaLogic::Span &gap : AgendaLogic::freeSlots(busy, planFrom, AgendaLogic::kWorkEnd)) {
            free.append(QVariantMap{{QStringLiteral("start"), gap.start}, {QStringLiteral("end"), gap.end}});
        }
        // Week and month boards: every appointment of the day, open tasks in board order.
        QVariantList events;
        QList<AgendaLogic::Span> eventSpans;
        for (const QVariant &value : allDayEvents) {
            QVariantMap event = value.toMap();
            event.insert(QStringLiteral("kind"), QStringLiteral("event"));
            events.append(event);
        }
        for (int k = 0; k < items.size(); ++k) {
            if (items.at(k).toMap().value(QStringLiteral("kind")) == QStringLiteral("event")) {
                events.append(items.at(k));
                eventSpans.append(spans.at(k));
            }
        }
        QVariantList open;
        for (const TaskEntry &task : AgendaLogic::boardOrder(openTasks)) {
            QVariantMap row = TaskEntries::toMap(task);
            const AgendaLogic::Span block = AgendaLogic::taskBlock(task);
            if (block.isValid()) {
                row.insert(QStringLiteral("start"), block.start);
                row.insert(QStringLiteral("end"), block.end);
            }
            open.append(row);
        }
        out.append(QVariantMap{
            {QStringLiteral("date"), day},
            {QStringLiteral("events"), events},
            {QStringLiteral("open"), open},
            {QStringLiteral("done"), doneTasks},
            {QStringLiteral("load"), AgendaLogic::dayLoad(eventSpans, openTasks)},
            {QStringLiteral("planFrom"), planFrom},
            {QStringLiteral("gridStart"), grid.start},
            {QStringLiteral("gridEnd"), grid.end},
            {QStringLiteral("workStart"), AgendaLogic::kWorkStart},
            {QStringLiteral("workEnd"), AgendaLogic::kWorkEnd},
            {QStringLiteral("step"), AgendaLogic::kStep},
            {QStringLiteral("minGap"), AgendaLogic::kMinGap},
            {QStringLiteral("minShown"), AgendaLogic::kMinShown},
            {QStringLiteral("allDayEvents"), allDayEvents},
            {QStringLiteral("items"), items},
            {QStringLiteral("loose"), openLoose + doneLoose},
            {QStringLiteral("free"), free},
        });
    }
    return out;
}

QVariantList TaskAgenda::agendaSuggestions(const QDate &target) const
{
    QVariantList out;
    if (!target.isValid()) {
        return out;
    }
    const QDate today = QDate::currentDate();
    const QList<TaskEntry> tasks = agendaEntries();
    const QList<AgendaLogic::Span> gaps = AgendaLogic::freeSlots(
        agendaBusy(target, tasks, -1), AgendaLogic::planFrom(target, today, QTime::currentTime()), AgendaLogic::kWorkEnd);
    const QList<AgendaLogic::Suggestion> ranked =
        AgendaLogic::rankSuggestions(tasks, target, today, AgendaLogic::largestSlot(gaps));
    for (const AgendaLogic::Suggestion &suggestion : ranked) {
        QVariantList reasons;
        for (const AgendaLogic::Reason &reason : suggestion.reasons) {
            reasons.append(QVariantMap{
                {QStringLiteral("kind"), AgendaLogic::reasonKey(reason.kind)},
                {QStringLiteral("days"), reason.days},
                {QStringLiteral("start"), reason.gap.start},
                {QStringLiteral("end"), reason.gap.end},
            });
        }
        out.append(QVariantMap{
            {QStringLiteral("task"), TaskEntries::toMap(suggestion.task)},
            {QStringLiteral("score"), suggestion.score},
            {QStringLiteral("tier"), AgendaLogic::tierKey(suggestion.tier)},
            {QStringLiteral("reasons"), reasons},
        });
    }
    return out;
}

void TaskAgenda::agendaPlaceTask(qint64 itemId, const QDate &day, int minute)
{
    const QVariantMap place = agendaPlacement(itemId, day, minute);
    if (place.isEmpty()) {
        return;
    }
    agendaSetBlock(itemId, day, place.value(QStringLiteral("start")).toInt(), place.value(QStringLiteral("end")).toInt());
}

QVariantMap TaskAgenda::agendaPlacement(qint64 itemId, const QDate &day, int minute) const
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (it == m_shared.tasks().cend() || !it->todo || !day.isValid()) {
        return {};
    }
    const TaskEntry task = entryOf(*it);
    const AgendaLogic::Span block = AgendaLogic::taskBlock(task);
    // A block longer than the grid (00:00 to 24:00 from another app) is placed as long as the grid.
    const int minutes = qMin(block.isValid() ? block.length() : AgendaLogic::defaultMinutes(task.priority),
                             AgendaLogic::kGridEnd - AgendaLogic::kGridStart);
    const int from = qBound(AgendaLogic::kGridStart, minute / AgendaLogic::kStep * AgendaLogic::kStep,
                            AgendaLogic::kGridEnd - minutes);
    const int start = AgendaLogic::fitFree(agendaBusy(day, agendaEntries(), itemId), from, minutes);
    return {
        {QStringLiteral("start"), start},
        {QStringLiteral("end"), start + minutes},
        {QStringLiteral("detach"), agendaWouldDetach(itemId, start, start + minutes)},
    };
}

bool TaskAgenda::agendaWouldDetach(qint64 itemId, int start, int end) const
{
    if (!isSeries(itemId)) {
        return false;
    }
    const TaskEntry task = entryOf(*m_shared.tasks().constFind(itemId));
    return !(AgendaLogic::taskBlock(task) == AgendaLogic::Span{start, end});
}

void TaskAgenda::agendaSetBlock(qint64 itemId, const QDate &day, int start, int end)
{
    if (!day.isValid() || start < 0 || end > 24 * 60 || end <= start) {
        return;
    }
    // A series keeps one time of day for all occurrences (KCalendarCore). The same times on
    // another day move only this occurrence (#29); another time detaches it into a task of its
    // own, and the series goes on with its next occurrence (owner, 10.11.2026).
    if (isSeries(itemId)) {
        if (!agendaWouldDetach(itemId, start, end)) {
            const QDate from = seriesOccurrenceDay(itemId);
            m_writes.moveOccurrence(itemId, from.isValid() ? from.daysTo(day) : 0);
            return;
        }
        m_writes.detach(itemId, AgendaLogic::atMinute(day, start), AgendaLogic::atMinute(day, end));
        return;
    }
    m_writes.update(itemId, {
        {QStringLiteral("allDay"), false},
        {QStringLiteral("startDate"), AgendaLogic::atMinute(day, start)},
        {QStringLiteral("dueDate"), AgendaLogic::atMinute(day, end)},
    });
}

void TaskAgenda::agendaMoveToDay(qint64 itemId, const QDate &day)
{
    if (!day.isValid()) {
        return;
    }
    // A series moves only this occurrence and keeps its times (#29).
    if (isSeries(itemId)) {
        const QDate from = seriesOccurrenceDay(itemId);
        m_writes.moveOccurrence(itemId, from.isValid() ? from.daysTo(day) : 0);
        return;
    }
    QVariantMap fields{
        {QStringLiteral("allDay"), true},
        {QStringLiteral("dueDate"), QDateTime(day, QTime(0, 0))},
    };
    // Only a time block loses its start; an earlier start day (a long run, a recurrence) stays.
    const auto it = m_shared.tasks().constFind(itemId);
    const TaskEntry task = it != m_shared.tasks().cend() && it->todo ? entryOf(*it) : TaskEntry{};
    const QDate startDay = task.startDate.isValid()
                               ? (task.allDay ? task.startDate.date() : task.startDate.toLocalTime().date())
                               : QDate();
    if (AgendaLogic::taskBlock(task).isValid() || !startDay.isValid() || startDay > day) {
        fields.insert(QStringLiteral("clearStart"), true);
    } else {
        fields.insert(QStringLiteral("startDate"), QDateTime(startDay, QTime(0, 0)));
    }
    m_writes.update(itemId, fields);
}

void TaskAgenda::agendaShiftAllToDay(const QVariantList &itemIds, const QDate &day)
{
    // One undo step for the whole tray (#29): the single-record stack would keep only
    // the last task otherwise.
    m_undo.beginCollect();
    for (const QVariant &id : itemIds) {
        agendaShiftToDay(id.toLongLong(), day);
    }
    m_undo.endCollect();
}

bool TaskAgenda::isSeries(qint64 itemId) const
{
    const auto it = m_shared.tasks().constFind(itemId);
    return it != m_shared.tasks().cend() && it->todo && it->todo->recurs();
}

QDate TaskAgenda::seriesOccurrenceDay(qint64 itemId) const
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (it == m_shared.tasks().cend() || !it->todo) {
        return {};
    }
    const TaskEntry task = entryOf(*it);
    return agendaDayOf(task, AgendaLogic::taskBlock(task));
}

void TaskAgenda::agendaShiftToDay(qint64 itemId, const QDate &day)
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (it == m_shared.tasks().cend() || !it->todo || !day.isValid()) {
        return;
    }
    const TaskEntry task = entryOf(*it);
    const QDate from = agendaDayOf(task, AgendaLogic::taskBlock(task));
    // A series moves only its current occurrence (#29, owner decision): the rule, DTSTART
    // and DUE stay, completing continues from the original day.
    if (task.recurring) {
        m_writes.moveOccurrence(itemId, from.isValid() ? from.daysTo(day) : 0);
        return;
    }
    if (!task.dueDate.isValid() || !from.isValid()) {
        agendaMoveToDay(itemId, day);
        return;
    }
    const qint64 days = from.daysTo(day);
    if (days == 0) {
        return;
    }
    QVariantMap fields{{QStringLiteral("dueDate"), task.dueDate.addDays(days)}};
    if (task.startDate.isValid()) {
        fields.insert(QStringLiteral("startDate"), task.startDate.addDays(days));
    }
    m_writes.update(itemId, fields);
}

QVariantMap TaskAgenda::agendaGhostSlot(const QVariantList &items, int minute, int length) const
{
    QList<AgendaLogic::Span> taken;
    for (const QVariant &value : items) {
        const QVariantMap item = value.toMap();
        taken.append({item.value(QStringLiteral("start")).toInt(), item.value(QStringLiteral("end")).toInt()});
    }
    const AgendaLogic::Span slot = AgendaLogic::ghostSlot(taken, minute, length);
    return {{QStringLiteral("start"), slot.start}, {QStringLiteral("end"), slot.end}};
}

QVariantList TaskAgenda::agendaMonth(const QDate &anyDay, bool weekend) const
{
    QVariantList out;
    const QList<QDate> grid = AgendaLogic::monthGrid(anyDay, AgendaLogic::Weekend::Show);
    if (grid.isEmpty()) {
        return out;
    }
    const QVariantList days = agendaDays(grid.first(), grid.size());
    for (const QVariant &value : days) {
        QVariantMap day = value.toMap();
        const QDate date = day.value(QStringLiteral("date")).toDate();
        if (!weekend && date.dayOfWeek() > 5) {
            continue;
        }
        const int count = day.value(QStringLiteral("events")).toList().size() + day.value(QStringLiteral("open")).toList().size();
        day.insert(QStringLiteral("inMonth"), date.month() == anyDay.month());
        day.insert(QStringLiteral("count"), count);
        day.insert(QStringLiteral("level"), AgendaLogic::loadLevel(count));
        out.append(day);
    }
    return out;
}

QVariantList TaskAgenda::agendaOverdue() const
{
    const QDate today = QDate::currentDate();
    // Exactly the open tasks on a past column (local day, agendaDayOf): also a block from
    // yesterday until midnight (DUE today 00:00), and a DUE stored in UTC by its local day.
    QList<TaskEntry> past;
    QHash<qint64, QDate> dayOf;
    for (const TaskEntry &task : agendaEntries()) {
        const QDate day = agendaDayOf(task, AgendaLogic::taskBlock(task));
        if (!task.completed && day.isValid() && day < today) {
            past.append(task);
            dayOf.insert(task.itemId, day);
        }
    }
    // Triage order (oldest by DUE, then priority, then title), then the oldest day first.
    QList<TaskEntry> ordered = TaskLogic::triageQueue(past, today);
    for (const TaskEntry &task : std::as_const(past)) {
        if (TaskLogic::overdueDays(task, today) <= 0) {
            ordered.append(task);
        }
    }
    std::stable_sort(ordered.begin(), ordered.end(), [&dayOf](const TaskEntry &a, const TaskEntry &b) {
        return dayOf.value(a.itemId) < dayOf.value(b.itemId);
    });
    QVariantList out;
    for (const TaskEntry &task : std::as_const(ordered)) {
        out.append(TaskEntries::toMap(task));
    }
    return out;
}

QVariantMap TaskAgenda::heatmapPeriod(const QList<TaskEntry> &visible, const QDate &monthStart,
                                      const QVariantList &years, const QString &mode) const
{
    QList<QVariantMap> countsInOrder;
    QDate start(monthStart.year(), monthStart.month(), 1);
    QDate end = start.addMonths(1);
    if (years.isEmpty()) {
        countsInOrder.append(heatmapCountsForMonth(visible, monthStart, mode));
    } else {
        start = QDate(monthStart.year(), 1, 1);
        end = start.addYears(1);
        for (const QVariant &year : years) {
            countsInOrder.append(heatmapCountsForYear(visible, year.toInt(), mode));
        }
    }

    QVariantMap merged;
    for (const QVariantMap &counts : std::as_const(countsInOrder)) {
        merged.insert(counts);
    }
    const TaskLogic::HeatmapSummary summary = TaskLogic::summarizeHeatmap(
            countsInOrder, start.startOfDay(), end.startOfDay(), QDateTime::currentDateTime());
    return {
        {QStringLiteral("counts"), merged},
        {QStringLiteral("total"), summary.total},
        {QStringLiteral("perDay"), summary.perDay},
        {QStringLiteral("bestCount"), summary.bestCount},
        {QStringLiteral("bestKey"), summary.bestKey},
    };
}

QVariantMap TaskAgenda::heatmapCountsForYear(const QList<TaskEntry> &visible, int year, const QString &mode) const
{
    // For completions, iterate all Akonadi tasks (not just filtered model)
    // because completed tasks are excluded from the filtered model by default.
    if (mode == QLatin1String("completed")) {
        return heatmapCountsAll(QDate(year, 1, 1), QDate(year, 12, 31), mode);
    }
    return TaskLogic::heatmapCountsForYear(visible, mode, QDate(year, 1, 1));
}

void TaskAgenda::setSelectedDate(const QDate &date)
{
    if (date == m_selectedDate) {
        return;
    }
    m_selectedDate = date;
    Q_EMIT selectedDateChanged();
}

void TaskAgenda::setMode(const QString &mode)
{
    const QString normalized = AgendaLogic::normalizeMode(mode);
    if (normalized == m_mode) {
        return;
    }
    m_mode = normalized;
    Q_EMIT settingsChanged();
}

void TaskAgenda::setWeekend(bool show)
{
    if (show == m_weekend) {
        return;
    }
    m_weekend = show;
    Q_EMIT settingsChanged();
}

void TaskAgenda::setWorkMinutes(int minutes)
{
    const int valid = AgendaLogic::workMinutes(minutes);
    if (valid == m_workMinutes) {
        return;
    }
    m_workMinutes = valid;
    Q_EMIT settingsChanged();
}
