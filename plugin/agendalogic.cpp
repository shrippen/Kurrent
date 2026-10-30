#include "agendalogic.h"

#include "tasklogic.h"

#include <algorithm>
#include <numeric>

namespace AgendaLogic
{

namespace
{
int minuteOfDay(const QTime &time)
{
    return time.hour() * 60 + time.minute();
}

QDate localDate(const QDateTime &when, bool allDay)
{
    // An all-day date has no time zone to convert from.
    return allDay ? when.date() : when.toLocalTime().date();
}
}

Span taskBlock(const TaskEntry &task)
{
    if (task.allDay || !task.startDate.isValid() || !task.dueDate.isValid()) {
        return {};
    }
    const QDateTime start = task.startDate.toLocalTime();
    const QDateTime due = task.dueDate.toLocalTime();
    // Until midnight: the next day's 00:00 (other apps) or 23:59 (Kurrent writes it so, 24:00
    // is no QTime) both end the block at 24:00 of its day.
    if (due.date() == start.date().addDays(1) && due.time() == QTime(0, 0)) {
        return {minuteOfDay(start.time()), 24 * 60};
    }
    if (start.date() != due.date() || start >= due) {
        return {};
    }
    const int end = due.time() == QTime(23, 59) ? 24 * 60 : minuteOfDay(due.time());
    return {minuteOfDay(start.time()), end};
}

QDate taskDay(const TaskEntry &task)
{
    if (task.completed && task.completedDate.isValid()) {
        return task.completedDate.toLocalTime().date();
    }
    if (taskBlock(task).isValid()) {
        return task.startDate.toLocalTime().date();
    }
    return task.dueDate.isValid() ? localDate(task.dueDate, task.allDay) : QDate();
}

int defaultMinutes(int priority)
{
    switch (TaskLogic::priorityBand(priority)) {
    case TaskLogic::PriorityBand::High:
        return 60;
    case TaskLogic::PriorityBand::Medium:
        return 45;
    default:
        return 30;
    }
}

int planFrom(const QDate &day, const QDate &today, const QTime &now)
{
    if (day < today) {
        return -1;
    }
    if (day > today) {
        return kWorkStart;
    }
    const int from = qMax(minuteOfDay(now), kWorkStart);
    return (from + kStep - 1) / kStep * kStep;
}

QList<Span> freeSlots(const QList<Span> &busy, int from, int to)
{
    QList<Span> out;
    if (from < 0) {
        return out;
    }
    QList<Span> sorted = busy;
    std::sort(sorted.begin(), sorted.end(), [](const Span &a, const Span &b) {
        return a.start < b.start;
    });
    int cur = from;
    const auto add = [&out](int start, int end) {
        if (end - start >= kMinGap) {
            out.append({start, end});
        }
    };
    for (const Span &span : std::as_const(sorted)) {
        if (cur >= to) {
            break;
        }
        if (span.start > cur) {
            add(cur, qMin(span.start, to));
        }
        cur = qMax(cur, span.end);
    }
    if (cur < to) {
        add(cur, to);
    }
    return out;
}

Span largestSlot(const QList<Span> &gaps)
{
    Span best;
    for (const Span &gap : gaps) {
        if (gap.length() > best.length()) {
            best = gap;
        }
    }
    return best;
}

int fitFree(const QList<Span> &busy, int start, int minutes)
{
    const auto overlap = [&busy, minutes](int at) -> const Span * {
        for (const Span &span : busy) {
            if (at < span.end && at + minutes > span.start) {
                return &span;
            }
        }
        return nullptr;
    };
    // Later first, up to the end of the grid.
    int at = start;
    while (const Span *span = overlap(at)) {
        at = span->end;
    }
    if (at + minutes <= kGridEnd) {
        return at;
    }
    // Then the free room before it.
    at = qMin(start, kGridEnd - minutes);
    while (const Span *span = overlap(at)) {
        at = span->start - minutes;
    }
    return at >= kGridStart ? at : start;
}

Span gridRange(const QList<Span> &spans)
{
    Span range{kGridStart, kGridEnd};
    for (const Span &span : spans) {
        if (!span.isValid()) {
            continue;
        }
        range.start = qMin(range.start, span.start / 60 * 60);
        range.end = qMax(range.end, (span.end + 59) / 60 * 60);
    }
    return {qMax(0, range.start), qMin(24 * 60, range.end)};
}

Span resizeLimits(const QList<Span> &busy, const Span &block)
{
    // Never tighter than the block itself, which may reach past the grid.
    Span limits{qMin(kGridStart, block.start), qMax(kGridEnd, block.end)};
    for (const Span &span : busy) {
        if (span.end <= block.start) {
            limits.start = qMax(limits.start, span.end);
        }
        if (span.start >= block.end) {
            limits.end = qMin(limits.end, span.start);
        }
    }
    return limits;
}

QList<Lane> lanes(const QList<Span> &spans)
{
    QList<Lane> out(spans.size());
    QList<int> order(spans.size());
    std::iota(order.begin(), order.end(), 0);
    std::sort(order.begin(), order.end(), [&spans](int a, int b) {
        return spans[a].start < spans[b].start
            || (spans[a].start == spans[b].start && spans[a].end > spans[b].end);
    });
    QList<int> cluster;
    QList<int> laneEnds;
    int clusterEnd = -1;
    const auto flush = [&]() {
        for (int index : std::as_const(cluster)) {
            out[index].lanes = laneEnds.size();
        }
        cluster.clear();
        laneEnds.clear();
    };
    for (int index : std::as_const(order)) {
        const Span &span = spans[index];
        if (!cluster.isEmpty() && span.start >= clusterEnd) {
            flush();
            clusterEnd = -1;
        }
        int lane = 0;
        while (lane < laneEnds.size() && laneEnds[lane] > span.start) {
            ++lane;
        }
        if (lane == laneEnds.size()) {
            laneEnds.append(0);
        }
        laneEnds[lane] = span.end;
        out[index].lane = lane;
        cluster.append(index);
        clusterEnd = qMax(clusterEnd, span.end);
    }
    flush();
    return out;
}

QList<Suggestion> rankSuggestions(const QList<TaskEntry> &tasks, const QDate &target,
                                  const QDate &today, const Span &largestGap)
{
    QList<Suggestion> out;
    for (const TaskEntry &task : tasks) {
        if (task.completed) {
            continue;
        }
        const QDate due = task.dueDate.isValid() ? localDate(task.dueDate, task.allDay) : QDate();
        // Already on the target: due there, or a block there (one until midnight is due the next day).
        const QDate onDay = taskBlock(task).isValid() ? task.startDate.toLocalTime().date() : due;
        if (onDay == target && onDay.isValid()) {
            continue;
        }
        Suggestion s;
        s.task = task;
        if (due.isValid() && due < today) {
            if (target < today) {
                continue;
            }
            const int days = int(due.daysTo(today));
            s.score = 30 + qMin(days, 14) * 2;
            s.reasons.append({ReasonKind::Overdue, days, {}});
        } else if (due.isValid() && due > target && due <= target.addDays(7)) {
            const int days = int(target.daysTo(due));
            s.score = 40 - days * 4;
            s.reasons.append({ReasonKind::DueSoon, days, {}});
        } else if (!due.isValid() && task.parentUid.isEmpty()) {
            s.score = 10;
            s.reasons.append({ReasonKind::Undated, 0, {}});
        } else {
            continue;
        }
        const int band = TaskLogic::priorityBand(task.priority);
        if (band == TaskLogic::PriorityBand::High) {
            s.score += 30;
            s.reasons.append({ReasonKind::HighPriority, 0, {}});
        } else if (band == TaskLogic::PriorityBand::Medium) {
            s.score += 10;
        }
        if (largestGap.isValid() && largestGap.length() >= defaultMinutes(task.priority)) {
            s.score += 5;
            s.reasons.append({ReasonKind::Fits, 0, largestGap});
        }
        s.tier = s.score >= 65 ? Tier::First : s.score >= 35 ? Tier::Then : Tier::Later;
        out.append(s);
    }
    std::sort(out.begin(), out.end(), [](const Suggestion &a, const Suggestion &b) {
        if (a.score != b.score) {
            return a.score > b.score;
        }
        return QString::localeAwareCompare(a.task.summary, b.task.summary) < 0;
    });
    return out;
}

QString tierKey(Tier tier)
{
    switch (tier) {
    case Tier::First:
        return QStringLiteral("first");
    case Tier::Then:
        return QStringLiteral("then");
    case Tier::Later:
        return QStringLiteral("later");
    }
    return {};
}

QString reasonKey(ReasonKind kind)
{
    switch (kind) {
    case ReasonKind::Overdue:
        return QStringLiteral("overdue");
    case ReasonKind::DueSoon:
        return QStringLiteral("dueSoon");
    case ReasonKind::Undated:
        return QStringLiteral("undated");
    case ReasonKind::HighPriority:
        return QStringLiteral("highPriority");
    case ReasonKind::Fits:
        return QStringLiteral("fits");
    }
    return {};
}

} // namespace AgendaLogic
