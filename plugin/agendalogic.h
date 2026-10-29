#pragma once

#include "tasklistmodel.h"

#include <QDate>
#include <QList>
#include <QString>
#include <QTime>

// The Agenda's day view: time blocks, free gaps and suggestions for a target day. Times are
// minutes since midnight on the day ("10:45" = 645).
namespace AgendaLogic
{
constexpr int kGridStart = 7 * 60;
constexpr int kGridEnd = 22 * 60;
constexpr int kWorkStart = 8 * 60;
constexpr int kWorkEnd = 18 * 60;
constexpr int kStep = 15;
constexpr int kMinGap = 30;

struct Span {
    int start = 0;
    int end = 0;
    bool isValid() const { return end > start; }
    int length() const { return end - start; }
    bool operator==(const Span &other) const { return start == other.start && end == other.end; }
};

/** Time block of a task: start and due both timed, on the same local day, start before due.
 *  Anything else (all-day, no start, several days) has no block; it shows as "no time". */
Span taskBlock(const TaskEntry &task);

/** Day a task belongs to in the agenda: the completion day when done, else the due day. */
QDate taskDay(const TaskEntry &task);

/** Minutes a task takes when it gets a time without one: high priority 60, medium 45, else 30. */
int defaultMinutes(int priority);

/** Where free time starts on `day`: today from now (rounded up to 15 minutes, not before
 *  08:00), later days from 08:00, past days never (-1). */
int planFrom(const QDate &day, const QDate &today, const QTime &now);

/** Gaps of at least 30 minutes between `from` and `to` not covered by `busy`. */
QList<Span> freeSlots(const QList<Span> &busy, int from, int to);

/** The longest gap; the first one on a tie, invalid when there is none. */
Span largestSlot(const QList<Span> &gaps);

/** First start at or after `start` where `minutes` overlap nothing busy and end by 22:00; else
 *  the latest such start before it; `start` itself when the day has no room. */
int fitFree(const QList<Span> &busy, int start, int minutes);

/** Hours the day's grid shows: 07–22, widened to whole hours around anything outside. */
Span gridRange(const QList<Span> &spans);

/** How far a block's edges may be dragged: up to the neighbouring busy spans, inside the grid,
 *  never tighter than the block itself. */
Span resizeLimits(const QList<Span> &busy, const Span &block);

/** Side-by-side columns for overlapping spans: lane of each span (input order) and the
 *  number of lanes in its overlap cluster. */
struct Lane {
    int lane = 0;
    int lanes = 1;
};
QList<Lane> lanes(const QList<Span> &spans);

enum class Tier { First, Then, Later };
enum class ReasonKind { Overdue, DueSoon, Undated, HighPriority, Fits };
struct Reason {
    ReasonKind kind = ReasonKind::Undated;
    int days = 0; // Overdue: days late; DueSoon: days after the target
    Span gap; // Fits: the gap it fits in
};
struct Suggestion {
    TaskEntry task;
    int score = 0;
    Tier tier = Tier::Later;
    QList<Reason> reasons;
};

/** Open tasks worth doing on `target`, most relevant first. Overdue (the longer, the higher;
 *  not for past targets), due within a week after the target (the sooner, the higher) and
 *  undated top-level tasks; plus high priority and whether it fits the largest gap.
 *  Tasks already on the target day are left out. Tiers: First ≥ 65, Then ≥ 35, else Later. */
QList<Suggestion> rankSuggestions(const QList<TaskEntry> &tasks, const QDate &target,
                                  const QDate &today, const Span &largestGap);

QString tierKey(Tier tier);
QString reasonKey(ReasonKind kind);

} // namespace AgendaLogic
