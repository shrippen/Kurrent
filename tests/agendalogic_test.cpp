#include "agendalogic.h"

#include <QtTest>

using namespace AgendaLogic;

namespace
{
const QDate kToday(2026, 10, 29);

int hm(int h, int m = 0)
{
    return h * 60 + m;
}

TaskEntry task(const QString &summary, const QDate &due, int priority = 0)
{
    TaskEntry t;
    t.itemId = qHash(summary);
    t.summary = summary;
    t.priority = priority;
    if (due.isValid()) {
        t.dueDate = QDateTime(due, QTime(0, 0));
        t.allDay = true;
    }
    return t;
}

const Suggestion *find(const QList<Suggestion> &list, const QString &summary)
{
    for (const Suggestion &s : list) {
        if (s.task.summary == summary) {
            return &s;
        }
    }
    return nullptr;
}
}

class AgendaLogicTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void blockNeedsTimedStartAndDueOnOneDay();
    void dayIsCompletionOrDue();
    void defaultMinutesByPriority();
    void planFromNowTodayEightLaterNeverBefore();
    void freeSlotsSkipBusyAndShortGaps();
    void largestSlotFirstOnTie();
    void fitFreeMovesPastBusy();
    void resizeStopsAtNeighbours();
    void resizeNeverCutsTheBlock();
    void fitFreeStepsBackBeforeTheGridEnd();
    void gridWidensForBlocksOutsideIt();
    void lanesForOverlaps();
    void suggestionsRankedWithReasons();
    void suggestionsSkipPastTargetOverdueAndOwnDay();
    void modesNormalizeAndStep();
    void dayLoadCountsEventsAndTaskLengths();
    void workMinutesDefaultAndBounds();
    void ghostSlotStaysBetweenNeighbours();
    void boardOrderTimedThenPriority();
    void monthGridSixWeeksFromMonday();
    void loadTintGrowsAndCaps();
};

void AgendaLogicTest::blockNeedsTimedStartAndDueOnOneDay()
{
    TaskEntry t = task(QStringLiteral("Angebot"), {});
    t.startDate = QDateTime(kToday, QTime(10, 45));
    t.dueDate = QDateTime(kToday, QTime(11, 45));
    QCOMPARE(taskBlock(t), (Span{hm(10, 45), hm(11, 45)}));

    TaskEntry allDay = t;
    allDay.allDay = true;
    QVERIFY(!taskBlock(allDay).isValid());

    TaskEntry noStart = t;
    noStart.startDate = {};
    QVERIFY(!taskBlock(noStart).isValid());

    TaskEntry twoDays = t;
    twoDays.startDate = QDateTime(kToday.addDays(-1), QTime(10, 45));
    QVERIFY(!taskBlock(twoDays).isValid());

    TaskEntry backwards = t;
    backwards.startDate = QDateTime(kToday, QTime(12, 0));
    QVERIFY(!taskBlock(backwards).isValid());
}

void AgendaLogicTest::dayIsCompletionOrDue()
{
    TaskEntry t = task(QStringLiteral("Rechnung"), kToday.addDays(2));
    QCOMPARE(taskDay(t), kToday.addDays(2));
    t.completed = true;
    t.completedDate = QDateTime(kToday, QTime(9, 0));
    QCOMPARE(taskDay(t), kToday);
    QVERIFY(!taskDay(task(QStringLiteral("Irgendwann"), {})).isValid());
}

void AgendaLogicTest::defaultMinutesByPriority()
{
    QCOMPARE(defaultMinutes(1), 60);
    QCOMPARE(defaultMinutes(5), 45);
    QCOMPARE(defaultMinutes(9), 30);
    QCOMPARE(defaultMinutes(0), 30);
}

void AgendaLogicTest::planFromNowTodayEightLaterNeverBefore()
{
    QCOMPARE(planFrom(kToday, kToday, QTime(10, 40)), hm(10, 45));
    QCOMPARE(planFrom(kToday, kToday, QTime(10, 45)), hm(10, 45));
    QCOMPARE(planFrom(kToday, kToday, QTime(6, 10)), hm(8));
    QCOMPARE(planFrom(kToday.addDays(1), kToday, QTime(10, 40)), hm(8));
    QCOMPARE(planFrom(kToday.addDays(-1), kToday, QTime(10, 40)), -1);
}

void AgendaLogicTest::freeSlotsSkipBusyAndShortGaps()
{
    // 09–10 busy, 10:20–11 busy (20-minute gap is too short), 13–14 busy, unsorted input.
    const QList<Span> busy{{hm(13), hm(14)}, {hm(9), hm(10)}, {hm(10, 20), hm(11)}};
    const QList<Span> gaps = freeSlots(busy, hm(8), hm(18));
    QCOMPARE(gaps, (QList<Span>{{hm(8), hm(9)}, {hm(11), hm(13)}, {hm(14), hm(18)}}));

    // From inside a busy span; a busy span past the end.
    QCOMPARE(freeSlots(busy, hm(9, 30), hm(12)), (QList<Span>{{hm(11), hm(12)}}));
    QCOMPARE(freeSlots({{hm(17, 45), hm(19)}}, hm(17), hm(18)), (QList<Span>{{hm(17), hm(17, 45)}}));
    QVERIFY(freeSlots({}, -1, hm(18)).isEmpty());
}

void AgendaLogicTest::largestSlotFirstOnTie()
{
    QCOMPARE(largestSlot({{hm(8), hm(9)}, {hm(11), hm(13)}, {hm(14), hm(16)}}), (Span{hm(11), hm(13)}));
    QVERIFY(!largestSlot({}).isValid());
}

void AgendaLogicTest::fitFreeMovesPastBusy()
{
    const QList<Span> busy{{hm(9), hm(10)}, {hm(10, 15), hm(11)}};
    QCOMPARE(fitFree(busy, hm(8), 30), hm(8));
    QCOMPARE(fitFree(busy, hm(8, 45), 30), hm(11)); // 10:00–10:15 is too short for 30
    QCOMPARE(fitFree(busy, hm(9, 30), 15), hm(10));
    QCOMPARE(fitFree({}, hm(21, 45), 60), hm(21)); // not past the end of the grid
}

void AgendaLogicTest::resizeStopsAtNeighbours()
{
    const QList<Span> busy{{hm(9), hm(10)}, {hm(12), hm(13)}, {hm(15), hm(16)}};
    QCOMPARE(resizeLimits(busy, {hm(10, 30), hm(11)}), (Span{hm(10), hm(12)}));
    QCOMPARE(resizeLimits({}, {hm(10), hm(11)}), (Span{kGridStart, kGridEnd}));
}

void AgendaLogicTest::resizeNeverCutsTheBlock()
{
    // A block past the grid keeps its edges; the first drag of a grip must not move them.
    QCOMPARE(resizeLimits({}, {hm(21), hm(23)}), (Span{kGridStart, hm(23)}));
    QCOMPARE(resizeLimits({}, {hm(6), hm(6, 45)}), (Span{hm(6), kGridEnd}));
}

void AgendaLogicTest::fitFreeStepsBackBeforeTheGridEnd()
{
    // No room after 22:00 for the event 21:00–22:00: the free half hour before it.
    QCOMPARE(fitFree({{hm(21), hm(22)}}, hm(21), 30), hm(20, 30));
    QCOMPARE(fitFree({{hm(20), hm(20, 30)}, {hm(21), hm(22)}}, hm(21), 45), hm(19, 15));
    // A full day has no free room: the asked start stays.
    QCOMPARE(fitFree({{kGridStart, kGridEnd}}, hm(10), 30), hm(10));
}

void AgendaLogicTest::gridWidensForBlocksOutsideIt()
{
    QCOMPARE(gridRange({}), (Span{kGridStart, kGridEnd}));
    QCOMPARE(gridRange({{hm(10), hm(11)}}), (Span{kGridStart, kGridEnd}));
    // To whole hours around early and late blocks, never past the day.
    QCOMPARE(gridRange({{hm(6, 20), hm(6, 45)}}), (Span{hm(6), kGridEnd}));
    QCOMPARE(gridRange({{hm(22, 30), hm(23, 15)}}), (Span{kGridStart, hm(24)}));
    QCOMPARE(gridRange({{hm(20), hm(24)}, {hm(0), hm(1)}}), (Span{hm(0), hm(24)}));
}

void AgendaLogicTest::lanesForOverlaps()
{
    // A 9–11 and B 10–12 overlap, C 10:30–11 overlaps both; D 13–14 stands alone.
    const QList<Span> spans{{hm(13), hm(14)}, {hm(9), hm(11)}, {hm(10), hm(12)}, {hm(10, 30), hm(11)}};
    const QList<Lane> out = lanes(spans);
    QCOMPARE(out.size(), 4);
    QCOMPARE(out[0].lane, 0);
    QCOMPARE(out[0].lanes, 1);
    QCOMPARE(out[1].lane, 0);
    QCOMPARE(out[2].lane, 1);
    QCOMPARE(out[3].lane, 2);
    QCOMPARE(out[1].lanes, 3);
    QCOMPARE(out[3].lanes, 3);
}

void AgendaLogicTest::suggestionsRankedWithReasons()
{
    const QDate target = kToday;
    QList<TaskEntry> tasks{
        task(QStringLiteral("Lange überfällig"), kToday.addDays(-12)), // 30 + 24 + 5 (fits) = 59
        task(QStringLiteral("Überfällig, wichtig"), kToday.addDays(-1), 1), // 32 + 30 = 62 (60 minutes do not fit)
        task(QStringLiteral("Morgen fällig, wichtig"), kToday.addDays(1), 2), // 36 + 30 = 66
        task(QStringLiteral("In fünf Tagen"), kToday.addDays(5)), // 20 + 5 = 25
        task(QStringLiteral("In acht Tagen"), kToday.addDays(8)), // too far
        task(QStringLiteral("Ohne Datum"), {}, 5), // 10 + 10 + 5 = 25
    };
    TaskEntry sub = task(QStringLiteral("Unteraufgabe ohne Datum"), {});
    sub.parentUid = QStringLiteral("parent");
    tasks.append(sub);
    TaskEntry done = task(QStringLiteral("Erledigt"), kToday.addDays(-3));
    done.completed = true;
    tasks.append(done);

    // Largest gap 10:45–11:30: 45 minutes, enough for 30 and 45, not for 60.
    const Span gap{hm(10, 45), hm(11, 30)};
    const QList<Suggestion> out = rankSuggestions(tasks, target, kToday, gap);
    QStringList order;
    for (const Suggestion &s : out) {
        order << s.task.summary;
    }
    QCOMPARE(order, (QStringList{QStringLiteral("Morgen fällig, wichtig"), QStringLiteral("Überfällig, wichtig"),
                                 QStringLiteral("Lange überfällig"), QStringLiteral("In fünf Tagen"),
                                 QStringLiteral("Ohne Datum")}));

    const Suggestion *late = find(out, QStringLiteral("Lange überfällig"));
    QCOMPARE(late->score, 59);
    QCOMPARE(late->tier, Tier::Then);
    QCOMPARE(late->reasons.size(), 2);
    QCOMPARE(late->reasons[0].kind, ReasonKind::Overdue);
    QCOMPARE(late->reasons[0].days, 12);
    QCOMPARE(late->reasons[1].kind, ReasonKind::Fits);
    QCOMPARE(late->reasons[1].gap, gap);

    const Suggestion *soon = find(out, QStringLiteral("Morgen fällig, wichtig"));
    QCOMPARE(soon->score, 66); // 60 minutes do not fit the gap
    QCOMPARE(soon->tier, Tier::First);
    QCOMPARE(soon->reasons.size(), 2);
    QCOMPARE(soon->reasons[0].kind, ReasonKind::DueSoon);
    QCOMPARE(soon->reasons[0].days, 1);
    QCOMPARE(soon->reasons[1].kind, ReasonKind::HighPriority);

    const Suggestion *undated = find(out, QStringLiteral("Ohne Datum"));
    QCOMPARE(undated->score, 25);
    QCOMPARE(undated->tier, Tier::Later);
    QCOMPARE(undated->reasons[0].kind, ReasonKind::Undated);

    QCOMPARE(tierKey(Tier::First), QStringLiteral("first"));
    QCOMPARE(reasonKey(ReasonKind::DueSoon), QStringLiteral("dueSoon"));
}

void AgendaLogicTest::suggestionsSkipPastTargetOverdueAndOwnDay()
{
    const QList<TaskEntry> tasks{
        task(QStringLiteral("Überfällig"), kToday.addDays(-4)),
        task(QStringLiteral("Am Ziel fällig"), kToday.addDays(2)),
        task(QStringLiteral("Danach fällig"), kToday.addDays(3)),
    };
    // Overdue is not suggested for a past day; the target's own tasks never are.
    const QList<Suggestion> past = rankSuggestions(tasks, kToday.addDays(-2), kToday, {});
    QVERIFY(!find(past, QStringLiteral("Überfällig")));
    const QList<Suggestion> later = rankSuggestions(tasks, kToday.addDays(2), kToday, {});
    QVERIFY(find(later, QStringLiteral("Überfällig")));
    QVERIFY(!find(later, QStringLiteral("Am Ziel fällig")));
    QCOMPARE(find(later, QStringLiteral("Danach fällig"))->score, 36);
}

void AgendaLogicTest::modesNormalizeAndStep()
{
    QCOMPARE(normalizeMode(QStringLiteral("week")), Mode::Week);
    QCOMPARE(normalizeMode(QStringLiteral("year")), Mode::Day);
    QCOMPARE(normalizeMode(QString()), Mode::Day);

    QCOMPARE(stepDate(kToday, Mode::Day, -1), kToday.addDays(-1));
    QCOMPARE(stepDate(kToday, Mode::Week, 2), kToday.addDays(14));
    QCOMPARE(stepDate(QDate(2026, 1, 31), Mode::Month, 1), QDate(2026, 2, 28));
    QCOMPARE(stepDate(QDate(2026, 3, 31), Mode::Month, -1), QDate(2026, 2, 28));
    QCOMPARE(stepDate(QDate(2026, 12, 15), Mode::Month, 1), QDate(2027, 1, 15));
}

void AgendaLogicTest::dayLoadCountsEventsAndTaskLengths()
{
    TaskEntry timed = task(QStringLiteral("Block"), {});
    timed.startDate = QDateTime(kToday, QTime(10, 0));
    timed.dueDate = QDateTime(kToday, QTime(11, 30));
    const QList<TaskEntry> open{timed, task(QStringLiteral("Hoch"), kToday, 1), task(QStringLiteral("Ohne"), kToday)};
    // 45 + 90 + 60 + 30
    QCOMPARE(dayLoad({{hm(9), hm(9, 45)}}, open), 225);
    QCOMPARE(dayLoad({}, {}), 0);
}

void AgendaLogicTest::workMinutesDefaultAndBounds()
{
    QCOMPARE(workMinutes(0), kDefaultWorkMinutes);
    QCOMPARE(workMinutes(-30), kDefaultWorkMinutes);
    QCOMPARE(workMinutes(450), 450);
    // Half-hour steps, one to sixteen hours.
    QCOMPARE(workMinutes(460), 450);
    QCOMPARE(workMinutes(10), kWorkStep);
    QCOMPARE(workMinutes(24 * 60), kMaxWorkMinutes);
}

void AgendaLogicTest::ghostSlotStaysBetweenNeighbours()
{
    const QList<Span> taken{{hm(10), hm(11)}, {hm(15), hm(16, 30)}};
    // An hour from the clicked quarter hour.
    QCOMPARE(ghostSlot(taken, hm(12, 7), 60), (Span{hm(12), hm(13)}));
    QCOMPARE(ghostSlot(taken, hm(11), 60), (Span{hm(11), hm(12)}));
    // Up against the next entry: it moves back into the free time instead of covering it.
    QCOMPARE(ghostSlot(taken, hm(14, 30), 60), (Span{hm(14), hm(15)}));
    // A gap shorter than the length: the whole gap.
    const QList<Span> tight{{hm(9), hm(10)}, {hm(10, 30), hm(11)}};
    QCOMPARE(ghostSlot(tight, hm(10, 15), 60), (Span{hm(10), hm(10, 30)}));
    // Grid end, and busy time gives nothing.
    QCOMPARE(ghostSlot({}, hm(21, 40), 60), (Span{hm(21), hm(22)}));
    QCOMPARE(ghostSlot(taken, hm(10, 30), 60), (Span{-1, -1}));
}

void AgendaLogicTest::boardOrderTimedThenPriority()
{
    TaskEntry late = task(QStringLiteral("Spät"), {});
    late.startDate = QDateTime(kToday, QTime(15, 0));
    late.dueDate = QDateTime(kToday, QTime(16, 0));
    TaskEntry early = late;
    early.summary = QStringLiteral("Früh");
    early.startDate = QDateTime(kToday, QTime(9, 0));
    early.dueDate = QDateTime(kToday, QTime(9, 30));
    const QList<TaskEntry> tasks{
        task(QStringLiteral("Ohne Priorität"), kToday),
        late,
        task(QStringLiteral("Niedrig"), kToday, 9),
        task(QStringLiteral("B hoch"), kToday, 1),
        early,
        task(QStringLiteral("A hoch"), kToday, 2),
        task(QStringLiteral("Mittel"), kToday, 5),
    };
    QStringList order;
    for (const TaskEntry &t : boardOrder(tasks)) {
        order << t.summary;
    }
    QCOMPARE(order, (QStringList{QStringLiteral("Früh"), QStringLiteral("Spät"), QStringLiteral("A hoch"),
                                 QStringLiteral("B hoch"), QStringLiteral("Mittel"), QStringLiteral("Niedrig"),
                                 QStringLiteral("Ohne Priorität")}));
}

void AgendaLogicTest::monthGridSixWeeksFromMonday()
{
    // October 2026 starts on a Thursday: the grid starts on Monday 28 September.
    const QList<QDate> all = monthGrid(kToday, Weekend::Show);
    QCOMPARE(all.size(), 42);
    QCOMPARE(all.first(), QDate(2026, 9, 28));
    QCOMPARE(all.last(), QDate(2026, 11, 8));
    const QList<QDate> workdays = monthGrid(kToday, Weekend::Hide);
    QCOMPARE(workdays.size(), 30);
    QCOMPARE(workdays.at(5), QDate(2026, 10, 5));
    for (const QDate &d : workdays) {
        QVERIFY(d.dayOfWeek() <= 5);
    }
    // A month starting on a Monday starts the grid on its 1st.
    QCOMPARE(monthGrid(QDate(2026, 6, 20), Weekend::Show).first(), QDate(2026, 6, 1));
}

void AgendaLogicTest::loadTintGrowsAndCaps()
{
    QCOMPARE(loadTint(0), 0.0);
    QCOMPARE(loadTint(1), 0.11);
    QCOMPARE(loadTint(3), 0.21);
    QCOMPARE(loadTint(10), 0.30);
}

QTEST_GUILESS_MAIN(AgendaLogicTest)
#include "agendalogic_test.moc"
