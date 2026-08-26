#include "tasklogic.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QTime>
#include <QUrl>
#include <QtGlobal>
#include <QtMath>

#include <algorithm>
#include <functional>

namespace TaskLogic
{

int priorityBand(int priority)
{
    if (priority >= 1 && priority <= 3) {
        return PriorityBand::High;
    }
    if (priority >= 4 && priority <= 6) {
        return PriorityBand::Medium;
    }
    if (priority >= 7 && priority <= 9) {
        return PriorityBand::Low;
    }
    return PriorityBand::None;
}

bool matchesSearch(const TaskEntry &task, const QString &query, SearchScope scope, SearchCase cs)
{
    if (query.trimmed().isEmpty()) {
        return true;
    }

    const Qt::CaseSensitivity csFlag = cs == SearchCase::Sensitive ? Qt::CaseSensitive : Qt::CaseInsensitive;
    const QString needle = query.trimmed();
    if (task.summary.contains(needle, csFlag)) {
        return true;
    }
    if (scope == SearchScope::TitleOnly) {
        return false;
    }
    return task.description.contains(needle, csFlag)
        || task.collectionName.contains(needle, csFlag)
        || task.categories.join(QLatin1Char(' ')).contains(needle, csFlag);
}

bool matchesView(const TaskEntry &task, const QString &viewId, const QDate &today)
{
    const QDate tomorrow = today.addDays(1);
    const bool hasDue = task.dueDate.isValid();
    const QDate due = hasDue ? task.dueDate.date() : QDate();

    if (viewId == ViewId::Inbox) {
        return true;
    }
    if (viewId == ViewId::Today) {
        return hasDue && due == today;
    }
    if (viewId == ViewId::Overdue) {
        return hasDue && due < today && !task.completed;
    }
    if (viewId == ViewId::Tomorrow) {
        return hasDue && due == tomorrow;
    }
    if (viewId == ViewId::Scheduled) {
        return hasDue;
    }
    if (viewId == ViewId::Anytime) {
        return !hasDue;
    }
    if (viewId == ViewId::Recurring) {
        return task.recurring;
    }
    if (viewId == ViewId::Unlabeled) {
        return task.categories.isEmpty();
    }
    if (viewId == ViewId::Completed) {
        return task.completed;
    }
    return true;
}

bool isCatchUp(const TaskEntry &task, const QDate &today, int lookbackDays)
{
    if (task.completed || !task.dueDate.isValid()) {
        return false;
    }
    const QDate due = task.dueDate.date();
    if (due >= today) {
        return false;
    }
    if (lookbackDays < 0) {
        return true;
    }
    return due >= today.addDays(-lookbackDays);
}

bool matchesTodayList(const TaskEntry &task, const FilterState &filters, const QDate &today)
{
    if (matchesView(task, QStringLiteral("today"), today)) {
        return true;
    }
    return filters.catchUpEnabled && isCatchUp(task, today, filters.catchUpDays);
}

QString dayPart(const QDateTime &when, const FilterState &filters)
{
    if (!when.isValid()) {
        return QStringLiteral("unspecified");
    }
    const int hour = when.time().hour();
    const int morning = qBound(0, filters.morningHour, 23);
    const int afternoon = qBound(morning, filters.afternoonHour, 23);
    const int evening = qBound(afternoon, filters.eveningHour, 23);
    if (hour < morning) {
        return QStringLiteral("evening");
    }
    if (hour < afternoon) {
        return QStringLiteral("morning");
    }
    if (hour < evening) {
        return QStringLiteral("afternoon");
    }
    return QStringLiteral("evening");
}

QString listBucket(const TaskEntry &task, const FilterState &filters, const QDate &today)
{
    if (filters.currentView == QLatin1String("today")) {
        if (isCatchUp(task, today, filters.catchUpDays)) {
            return QStringLiteral("catchup");
        }
        if (task.allDay || !task.dueDate.isValid()) {
            return QStringLiteral("unspecified");
        }
        return dayPart(task.dueDate, filters);
    }
    if (!task.section.isEmpty()) {
        return task.section;
    }
    if (filters.currentView == QLatin1String("scheduled") && task.dueDate.isValid() && !task.allDay) {
        return dayPart(task.dueDate, filters);
    }
    return {};
}

QDateTime rescheduleDue(const QDateTime &currentDue, DaySpan daySpan, const QDateTime &now, const QString &preset)
{
    const bool allDay = daySpan == DaySpan::AllDay;
    const QDateTime base = now.isValid() ? now : QDateTime::currentDateTime();

    if (preset == ReschedulePreset::Min15) {
        return base.addSecs(ReschedulePreset::Sec15m);
    }
    if (preset == ReschedulePreset::Hour1) {
        return base.addSecs(ReschedulePreset::Sec1h);
    }
    if (preset == ReschedulePreset::Hour4) {
        return base.addSecs(ReschedulePreset::Sec4h);
    }

    QDateTime seed = currentDue.isValid() ? currentDue : base;
    if (preset == ReschedulePreset::Tomorrow) {
        if (allDay || !seed.time().isValid() || (seed.time() == QTime(0, 0) && allDay)) {
            return QDateTime(base.date().addDays(1), QTime(0, 0));
        }
        return QDateTime(base.date().addDays(1), seed.time());
    }
    if (preset == ReschedulePreset::NextWeek) {
        if (allDay) {
            return QDateTime(seed.date().addDays(7), QTime(0, 0));
        }
        const QDate origin = seed.isValid() ? seed.date() : base.date();
        return QDateTime(origin.addDays(7), seed.isValid() ? seed.time() : base.time());
    }
    return seed;
}

QString joinUrl(const QString &description, const QString &location)
{
    static const QRegularExpression re(QStringLiteral(R"((https?://[^\s<>"'\)\]]+))"),
                                       QRegularExpression::CaseInsensitiveOption);
    const QString haystack = location + QLatin1Char('\n') + description;
    const QRegularExpressionMatch match = re.match(haystack);
    if (!match.hasMatch()) {
        return {};
    }
    QString url = match.captured(1);
    while (url.endsWith(QLatin1Char('.')) || url.endsWith(QLatin1Char(',')) || url.endsWith(QLatin1Char(';'))) {
        url.chop(1);
    }
    const QUrl parsed = QUrl(url);
    if (!parsed.isValid() || parsed.scheme().isEmpty()) {
        return {};
    }
    return parsed.toString();
}

bool matchesFilters(const TaskEntry &task, qint64 selectedCollectionId, const QString &selectedLabel, int selectedPriority)
{
    if (selectedCollectionId >= 0 && task.collectionId != selectedCollectionId) {
        return false;
    }
    if (!selectedLabel.isEmpty() && !task.categories.contains(selectedLabel)) {
        return false;
    }
    if (selectedPriority >= 0 && priorityBand(task.priority) != selectedPriority) {
        return false;
    }
    return true;
}

int compareTasks(const TaskEntry &left, const TaskEntry &right, const QString &sortMode)
{
    const QStringList keys = sortMode.split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (QString raw : keys) {
        raw = raw.trimmed();
        if (raw.isEmpty() || raw == QLatin1String("default")) {
            continue;
        }

        bool descending = false;
        QString field = raw;
        if (raw.endsWith(QLatin1String("Desc"))) {
            descending = true;
            field = raw.left(raw.size() - 4);
        }

        int cmp = 0;
        if (field == QLatin1String("due")) {
            const bool leftHasDue = left.dueDate.isValid();
            const bool rightHasDue = right.dueDate.isValid();
            if (leftHasDue != rightHasDue) {
                cmp = leftHasDue ? -1 : 1;
            } else if (leftHasDue && rightHasDue) {
                if (left.dueDate < right.dueDate) {
                    cmp = -1;
                } else if (left.dueDate > right.dueDate) {
                    cmp = 1;
                }
            }
        } else if (field == QLatin1String("priority")) {
            const int leftRank = left.priority <= 0 ? 100 : left.priority;
            const int rightRank = right.priority <= 0 ? 100 : right.priority;
            if (leftRank < rightRank) {
                cmp = -1;
            } else if (leftRank > rightRank) {
                cmp = 1;
            }
        } else if (field == QLatin1String("title")) {
            cmp = QString::compare(left.summary, right.summary, Qt::CaseInsensitive);
            if (cmp > 0) {
                cmp = 1;
            } else if (cmp < 0) {
                cmp = -1;
            }
        } else if (field == QLatin1String("completed")) {
            if (left.completed != right.completed) {
                cmp = left.completed ? 1 : -1;
            }
        }

        if (cmp != 0) {
            return descending ? -cmp : cmp;
        }
    }

    const int titleCmp = QString::compare(left.summary, right.summary, Qt::CaseInsensitive);
    if (titleCmp != 0) {
        return titleCmp < 0 ? -1 : 1;
    }
    return 0;
}

bool wouldCreateParentCycle(const QString &draggedUid, const QString &newParentUid, const QHash<QString, QString> &parentByUid)
{
    if (draggedUid.isEmpty()) {
        return true;
    }

    QString walkUid = newParentUid;
    QSet<QString> seen;
    while (!walkUid.isEmpty()) {
        if (walkUid == draggedUid) {
            return true;
        }
        if (seen.contains(walkUid)) {
            return true;
        }
        seen.insert(walkUid);

        const auto it = parentByUid.constFind(walkUid);
        if (it == parentByUid.cend()) {
            break;
        }
        walkUid = it.value();
    }
    return false;
}

SidebarCounts computeCounts(const QList<TaskEntry> &tasks, const FilterState &filters, const QStringList &extraLabels, const QDate &today)
{
    static const QStringList viewIds = {
        QStringLiteral("inbox"),
        QStringLiteral("today"),
        QStringLiteral("overdue"),
        QStringLiteral("tomorrow"),
        QStringLiteral("scheduled"),
        QStringLiteral("anytime"),
        QStringLiteral("recurring"),
        QStringLiteral("unlabeled"),
        QStringLiteral("completed"),
    };

    SidebarCounts out;
    for (const QString &viewId : viewIds) {
        out.viewCounts.insert(viewId, 0);
    }
    out.sidebarPriorities.insert(QStringLiteral("0"), 0);
    out.sidebarPriorities.insert(QStringLiteral("1"), 0);
    out.sidebarPriorities.insert(QStringLiteral("5"), 0);
    out.sidebarPriorities.insert(QStringLiteral("9"), 0);

    for (const TaskEntry &task : tasks) {
        if (task.treeHidden) {
            continue;
        }
        for (const QString &category : task.categories) {
            if (category.isEmpty()) {
                continue;
            }
            out.totalLabels.insert(category, out.totalLabels.value(category).toInt() + 1);
        }

        const bool passCollection = filters.selectedCollectionId < 0 || task.collectionId == filters.selectedCollectionId;
        const bool passLabel = filters.selectedLabel.isEmpty() || task.categories.contains(filters.selectedLabel);
        const bool passPriority = filters.selectedPriority < 0 || priorityBand(task.priority) == filters.selectedPriority;
        const bool passSearch = matchesSearch(task, filters.searchQuery, filters.searchScope, filters.searchCase);
        const bool passCompleted = filters.showCompleted || !task.completed;

        if (passCollection && passLabel && passPriority && passSearch) {
            for (const QString &viewId : viewIds) {
                if (viewId == ViewId::Completed) {
                    if (task.completed && matchesView(task, viewId, today)) {
                        out.viewCounts.insert(viewId, out.viewCounts.value(viewId).toInt() + 1);
                    }
                } else if (passCompleted && matchesView(task, viewId, today)) {
                    out.viewCounts.insert(viewId, out.viewCounts.value(viewId).toInt() + 1);
                }
            }
        }

        const bool inCurrentView = (filters.currentView == QLatin1String("completed"))
            ? task.completed && matchesView(task, filters.currentView, today)
            : passCompleted && matchesView(task, filters.currentView, today);

        if (inCurrentView && passLabel && passPriority && passSearch) {
            const QString projectKey = QString::number(task.collectionId);
            out.sidebarProjects.insert(projectKey, out.sidebarProjects.value(projectKey).toInt() + 1);
        }
        if (inCurrentView && passCollection && passPriority && passSearch) {
            for (const QString &category : task.categories) {
                if (category.isEmpty()) {
                    continue;
                }
                out.sidebarLabels.insert(category, out.sidebarLabels.value(category).toInt() + 1);
            }
        }
        if (inCurrentView && passCollection && passLabel && passSearch) {
            const QString priorityKey = QString::number(priorityBand(task.priority));
            out.sidebarPriorities.insert(priorityKey, out.sidebarPriorities.value(priorityKey).toInt() + 1);
        }
    }

    for (const QString &extra : extraLabels) {
        if (!extra.isEmpty() && !out.totalLabels.contains(extra)) {
            out.totalLabels.insert(extra, 0);
        }
        if (!extra.isEmpty() && !out.sidebarLabels.contains(extra)) {
            out.sidebarLabels.insert(extra, 0);
        }
    }

    return out;
}

qint64 firstSidebarProjectId(const QList<ProjectCandidate> &projects, const QSet<qint64> &hiddenIds)
{
    qint64 firstNonHidden = -1;
    for (const ProjectCandidate &project : projects) {
        if (!project.enabled || hiddenIds.contains(project.id)) {
            continue;
        }
        if (firstNonHidden < 0) {
            firstNonHidden = project.id;
        }
        if (project.taskCount > 0) {
            return project.id;
        }
    }
    return firstNonHidden;
}

NewTaskTarget resolveNewTaskTarget(qint64 selectedCollectionId,
                                   const QString &mode,
                                   qint64 defaultCollectionId,
                                   DefaultCollection defaultState,
                                   qint64 firstEnabledId)
{
    NewTaskTarget target;
    if (selectedCollectionId > 0) {
        target.collectionId = selectedCollectionId;
        return target;
    }

    if (mode == QLatin1String("first") && firstEnabledId > 0) {
        target.collectionId = firstEnabledId;
        return target;
    }
    if (mode == QLatin1String("fixed")
        && defaultState == DefaultCollection::Exists
        && defaultCollectionId > 0) {
        target.collectionId = defaultCollectionId;
        return target;
    }

    target.ask = true;
    return target;
}

QPointF dragProxyGap(int cursorSize, CursorKind cursorKind)
{
    const int size = qMax(16, cursorSize);
    if (cursorKind == CursorKind::Arrow) {
        return QPointF(qCeil(size * 0.85), qCeil(size * 0.2));
    }
    return QPointF(qCeil(size * 0.55), qCeil(size * 0.55));
}

QPointF clampDragProxyOffset(qreal cursorX,
                             qreal cursorY,
                             qreal gapX,
                             qreal gapY,
                             qreal width,
                             qreal height,
                             qreal limitRight,
                             qreal limitBottom)
{
    qreal ox = gapX;
    qreal oy = gapY;
    if (cursorX + ox + width > limitRight) {
        ox = limitRight - width - cursorX;
    }
    if (cursorY + oy + height > limitBottom) {
        oy = limitBottom - height - cursorY;
    }
    return QPointF(ox, oy);
}

// Depth-first flatten for the list view.
// Parents before children. Collapsed parents omit descendants from the list so
// contentHeight / scrollbar always match visible rows.
//
//   root
//    ├─ childA
//    └─ childB
//         └─ grand
QList<TaskEntry> flattenTree(const QList<TaskEntry> &input, const QString &sortMode, const QSet<QString> &collapsedUids)
{
    QHash<QString, QList<int>> children;
    for (int i = 0; i < input.size(); ++i) {
        children[input.at(i).parentUid].append(i);
    }

    const auto sortKids = [&](QList<int> &kids) {
        if (kids.size() < 2 || sortMode == QLatin1String("default") || sortMode.isEmpty()) {
            return;
        }
        std::sort(kids.begin(), kids.end(), [&](int left, int right) {
            const int cmp = compareTasks(input.at(left), input.at(right), sortMode);
            if (cmp != 0) {
                return cmp < 0;
            }
            return input.at(left).itemId < input.at(right).itemId;
        });
    };

    QList<TaskEntry> out;
    QSet<QString> walking;
    std::function<void(const QString &, int)> walk =
        [&](const QString &parent, int indent) {
        QList<int> kids = children.value(parent);
        sortKids(kids);
        for (int idx : kids) {
            TaskEntry entry = input.at(idx);
            if (walking.contains(entry.uid)) {
                continue;
            }
            walking.insert(entry.uid);
            entry.indentLevel = indent;
            entry.hasChildren = children.contains(entry.uid) && !children.value(entry.uid).isEmpty();
            entry.treeCollapsed = entry.hasChildren && collapsedUids.contains(entry.uid);
            entry.treeHidden = false;
            out.append(entry);
            if (!entry.treeCollapsed) {
                walk(entry.uid, indent + 1);
            }
            walking.remove(entry.uid);
        }
    };
    walk(QString(), 0);

    if (out.isEmpty() && !input.isEmpty()) {
        for (TaskEntry entry : input) {
            entry.indentLevel = 0;
            entry.hasChildren = false;
            entry.treeCollapsed = false;
            entry.treeHidden = false;
            out.append(entry);
        }
    }
    return out;
}

QString emptyKind(LoadState loading,
                  BackendState backend,
                  int collectionCount,
                  int visibleCount,
                  ErrorPresence error)
{
    if (visibleCount > 0) {
        return {};
    }
    if (loading == LoadState::Loading) {
        return QStringLiteral("loading");
    }
    if (backend == BackendState::Offline) {
        return QStringLiteral("offline");
    }
    if (collectionCount <= 0) {
        return QStringLiteral("no-collections");
    }
    if (error == ErrorPresence::Present) {
        return QStringLiteral("error");
    }
    return QStringLiteral("empty");
}

int panelBadgeCount(const QString &mode, int openRoots, int todayCount, int overdueCount)
{
    if (mode == QLatin1String("off")) {
        return 0;
    }
    if (mode == QLatin1String("today")) {
        return qMax(0, todayCount);
    }
    if (mode == QLatin1String("overdue")) {
        return qMax(0, overdueCount);
    }
    return qMax(0, openRoots);
}

QDateTime defaultDueForMode(const QString &mode, const QDate &today)
{
    if (!today.isValid()) {
        return {};
    }
    if (mode == QLatin1String("today")) {
        return QDateTime(today, QTime(0, 0));
    }
    if (mode == QLatin1String("tomorrow")) {
        return QDateTime(today.addDays(1), QTime(0, 0));
    }
    return {};
}

int clampSidebarWidthUnits(int units)
{
    return qBound(6, units, 20);
}

qreal overlayDimForStep(int step)
{
    if (step <= 0) {
        return 0.25;
    }
    if (step >= 2) {
        return 0.55;
    }
    return 0.40;
}

QString undoKindName(UndoRecord::Kind kind)
{
    switch (kind) {
    case UndoRecord::Kind::Complete:
        return QStringLiteral("complete");
    case UndoRecord::Kind::Reschedule:
        return QStringLiteral("reschedule");
    case UndoRecord::Kind::Move:
        return QStringLiteral("move");
    case UndoRecord::Kind::Delete:
        return QStringLiteral("delete");
    case UndoRecord::Kind::None:
        break;
    }
    return {};
}

void UndoStack::push(UndoRecord record)
{
    m_record = record;
}

UndoRecord UndoStack::take()
{
    const UndoRecord out = m_record;
    m_record = {};
    return out;
}

UndoRecord UndoStack::peek() const
{
    return m_record;
}

bool UndoStack::canUndo() const
{
    return m_record.kind != UndoRecord::Kind::None;
}

void UndoStack::clear()
{
    m_record = {};
}

VisibleFilterResult filterVisibleTasks(const QList<TaskEntry> &tasks, const FilterState &filters, const QDate &today)
{
    VisibleFilterResult out;
    for (const TaskEntry &task : tasks) {
        if (filters.currentView == QLatin1String("completed")) {
            if (!task.completed) {
                ++out.filteredOutView;
                continue;
            }
        } else if (!filters.showCompleted && task.completed) {
            ++out.filteredOutCompleted;
            continue;
        }

        if (filters.currentView == QLatin1String("today")) {
            if (!matchesTodayList(task, filters, today)
                || !matchesFilters(task, filters.selectedCollectionId, filters.selectedLabel, filters.selectedPriority)) {
                ++out.filteredOutView;
                continue;
            }
        } else if (!matchesView(task, filters.currentView, today)
                   || !matchesFilters(task, filters.selectedCollectionId, filters.selectedLabel, filters.selectedPriority)) {
            ++out.filteredOutView;
            continue;
        }
        if (!matchesSearch(task, filters.searchQuery, filters.searchScope, filters.searchCase)) {
            ++out.filteredOutSearch;
            continue;
        }
        TaskEntry visible = task;
        visible.bucket = listBucket(task, filters, today);
        out.tasks.append(visible);
    }

    // Drop hidden rows whose parent is not in this filtered list (e.g. parent in
    // another view). Keep hidden children when the parent row is present so the
    // ListView can animate height without insert/remove.
    {
        QSet<QString> present;
        present.reserve(out.tasks.size());
        for (const TaskEntry &task : out.tasks) {
            present.insert(task.uid);
        }
        QList<TaskEntry> pruned;
        pruned.reserve(out.tasks.size());
        for (const TaskEntry &task : out.tasks) {
            if (task.treeHidden && !present.contains(task.parentUid)) {
                continue;
            }
            pruned.append(task);
        }
        out.tasks = pruned;
    }

    // Hidden rows inherit the nearest visible ancestor's bucket so Today sections
    // do not grow empty headers from collapsed subtasks alone.
    QString lastVisibleBucket;
    for (TaskEntry &task : out.tasks) {
        if (task.treeHidden) {
            task.bucket = lastVisibleBucket;
        } else {
            lastVisibleBucket = task.bucket;
        }
    }
    return out;
}

QHash<qint64, int> collectionTaskCounts(const QList<TaskEntry> &tasks)
{
    QHash<qint64, int> counts;
    for (const TaskEntry &task : tasks) {
        if (task.treeHidden) {
            continue;
        }
        ++counts[task.collectionId];
    }
    return counts;
}

int pendingRootCount(const QList<TaskEntry> &tasks)
{
    int pending = 0;
    for (const TaskEntry &task : tasks) {
        if (!task.completed && task.indentLevel == 0 && !task.treeHidden) {
            ++pending;
        }
    }
    return pending;
}

QStringList collectAvailableLabels(const QList<TaskEntry> &tasks, const QStringList &extraLabels)
{
    QSet<QString> labels;
    for (const TaskEntry &task : tasks) {
        for (const QString &category : task.categories) {
            if (!category.isEmpty()) {
                labels.insert(category);
            }
        }
    }
    for (const QString &extra : extraLabels) {
        if (!extra.isEmpty()) {
            labels.insert(extra);
        }
    }
    QStringList sorted = labels.values();
    sorted.sort(Qt::CaseInsensitive);
    return sorted;
}

bool canCreateLabel(const QString &name, const QStringList &available, const QStringList &extraLabels)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }
    return !available.contains(trimmed) && !extraLabels.contains(trimmed);
}

bool containsLabel(const QStringList &selected, const QString &name)
{
    return selected.contains(name);
}

QStringList addLabel(QStringList selected, const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || selected.contains(trimmed)) {
        return selected;
    }
    selected.append(trimmed);
    return selected;
}

QStringList removeLabel(const QStringList &selected, const QString &name)
{
    QStringList out;
    out.reserve(selected.size());
    for (const QString &label : selected) {
        if (label != name) {
            out.append(label);
        }
    }
    return out;
}

QStringList renameLabel(QStringList selected, const QString &from, const QString &to)
{
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (source.isEmpty() || dest.isEmpty() || source == dest) {
        return selected;
    }
    bool found = false;
    QStringList out;
    for (const QString &label : selected) {
        if (label == source) {
            found = true;
            continue;
        }
        if (!out.contains(label)) {
            out.append(label);
        }
    }
    if (!found) {
        return selected;
    }
    if (!out.contains(dest)) {
        out.append(dest);
    }
    return out;
}

bool canRenameLabel(const QString &from, const QString &to, const QStringList &available, const QStringList &extraLabels)
{
    const QString source = from.trimmed();
    const QString dest = to.trimmed();
    if (source.isEmpty() || dest.isEmpty() || source == dest) {
        return false;
    }
    return available.contains(source) || extraLabels.contains(source);
}

QString renameToken(const QString &raw, const QString &from, const QString &to, const QString &separator)
{
    return joinTokens(renameLabel(parseTokens(raw, separator), from, to), separator);
}

QStringList descendantUids(const QString &parentUid, const QHash<QString, QString> &parentByUid)
{
    QStringList out;
    if (parentUid.isEmpty()) {
        return out;
    }
    QList<QString> stack{parentUid};
    QSet<QString> seen;
    seen.insert(parentUid);
    while (!stack.isEmpty()) {
        const QString current = stack.takeLast();
        for (auto it = parentByUid.constBegin(); it != parentByUid.constEnd(); ++it) {
            if (it.value() != current || seen.contains(it.key())) {
                continue;
            }
            seen.insert(it.key());
            out.append(it.key());
            stack.append(it.key());
        }
    }
    return out;
}

bool isHexColor(const QString &color)
{
    const QString s = color.trimmed();
    if (s.size() != 7 || !s.startsWith(QLatin1Char('#'))) {
        return false;
    }
    for (int i = 1; i < 7; ++i) {
        const char ch = s.at(i).toLower().toLatin1();
        if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))) {
            return false;
        }
    }
    return true;
}

QVariantMap parseColorMap(const QString &raw)
{
    QVariantMap out;
    const QString trimmed = raw.trimmed();
    if (trimmed.isEmpty()) {
        return out;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(trimmed.toUtf8());
    if (!doc.isObject()) {
        return out;
    }
    const QJsonObject obj = doc.object();
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        const QString color = it.value().toString();
        if (isHexColor(color)) {
            out.insert(it.key(), color.toLower());
        }
    }
    return out;
}

QString serializeColorMap(const QVariantMap &map)
{
    QJsonObject obj;
    for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
        const QString color = it.value().toString();
        if (it.key().isEmpty() || !isHexColor(color)) {
            continue;
        }
        obj.insert(it.key(), color.toLower());
    }
    if (obj.isEmpty()) {
        return {};
    }
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

QString setColorOverride(const QString &raw, const QString &key, const QString &color)
{
    QVariantMap map = parseColorMap(raw);
    const QString trimmedKey = key.trimmed();
    if (trimmedKey.isEmpty()) {
        return serializeColorMap(map);
    }
    if (color.trimmed().isEmpty()) {
        map.remove(trimmedKey);
    } else if (isHexColor(color)) {
        map.insert(trimmedKey, color.trimmed().toLower());
    }
    return serializeColorMap(map);
}

QStringList parseTokens(const QString &raw, const QString &separator)
{
    QStringList out;
    if (raw.trimmed().isEmpty()) {
        return out;
    }
    const QStringList parts = raw.split(separator);
    for (const QString &part : parts) {
        const QString trimmed = part.trimmed();
        if (!trimmed.isEmpty()) {
            out.append(trimmed);
        }
    }
    return out;
}

QString joinTokens(const QStringList &tokens, const QString &separator)
{
    return tokens.join(separator);
}

QStringList defaultSidebarSections()
{
    return {QStringLiteral("views"), QStringLiteral("projects"), QStringLiteral("labels"), QStringLiteral("priorities")};
}

QStringList defaultViewIds()
{
    return {
        QStringLiteral("inbox"),
        QStringLiteral("today"),
        QStringLiteral("overdue"),
        QStringLiteral("tomorrow"),
        QStringLiteral("scheduled"),
        QStringLiteral("anytime"),
        QStringLiteral("recurring"),
        QStringLiteral("unlabeled"),
        QStringLiteral("completed"),
    };
}

QStringList mergeOrderedKeys(const QStringList &raw, const QStringList &defaults)
{
    QStringList out;
    QSet<QString> seen;
    for (const QString &key : raw) {
        if (defaults.contains(key) && !seen.contains(key)) {
            out.append(key);
            seen.insert(key);
        }
    }
    for (const QString &key : defaults) {
        if (!seen.contains(key)) {
            out.append(key);
        }
    }
    return out;
}

QStringList visibleOrderedKeys(const QStringList &ordered, const QStringList &hidden)
{
    QSet<QString> hide(hidden.begin(), hidden.end());
    QStringList out;
    for (const QString &key : ordered) {
        if (!hide.contains(key)) {
            out.append(key);
        }
    }
    return out;
}

QStringList moveOrderedKey(QStringList ordered, const QString &key, int delta)
{
    const int idx = ordered.indexOf(key);
    if (idx < 0 || delta == 0) {
        return ordered;
    }
    const int dest = qBound(0, idx + delta, ordered.size() - 1);
    if (dest == idx) {
        return ordered;
    }
    ordered.move(idx, dest);
    return ordered;
}

QString relativeDueKind(const QDate &due, const QDate &today)
{
    if (!due.isValid() || !today.isValid()) {
        return {};
    }
    const int delta = today.daysTo(due);
    if (delta == 0) {
        return QStringLiteral("today");
    }
    if (delta == 1) {
        return QStringLiteral("tomorrow");
    }
    if (delta == -1) {
        return QStringLiteral("yesterday");
    }
    return QStringLiteral("date");
}

bool inQuietHours(const QTime &now, int startHour, int endHour, QuietHoursMode mode)
{
    if (mode == QuietHoursMode::Disabled || !now.isValid()) {
        return false;
    }
    const int start = qBound(0, startHour, 23);
    const int end = qBound(0, endHour, 23);
    if (start == end) {
        return false;
    }
    const int hour = now.hour();
    if (start < end) {
        return hour >= start && hour < end;
    }
    return hour >= start || hour < end;
}

QString toggleToken(const QString &raw, const QString &token, const QString &separator)
{
    QStringList tokens = parseTokens(raw, separator);
    const int idx = tokens.indexOf(token);
    if (idx >= 0) {
        tokens.removeAt(idx);
    } else if (!token.isEmpty()) {
        tokens.append(token);
    }
    return joinTokens(tokens, separator);
}

bool tokenSetContains(const QString &raw, const QString &token, const QString &separator)
{
    return parseTokens(raw, separator).contains(token);
}

QString toggleEnabledCsv(const QString &csv, qint64 id, const QList<qint64> &allIds)
{
    const QString key = QString::number(id);
    QStringList current = parseTokens(csv, QStringLiteral(","));
    QStringList all;
    all.reserve(allIds.size());
    for (qint64 collectionId : allIds) {
        all.append(QString::number(collectionId));
    }

    if (current.isEmpty()) {
        QStringList result;
        for (const QString &candidate : all) {
            if (candidate != key) {
                result.append(candidate);
            }
        }
        return joinTokens(result, QStringLiteral(","));
    }

    const int idx = current.indexOf(key);
    if (idx >= 0) {
        current.removeAt(idx);
        return joinTokens(current, QStringLiteral(","));
    }

    current.append(key);
    if (current.size() >= all.size()) {
        return {};
    }
    return joinTokens(current, QStringLiteral(","));
}

bool isEnabledCsv(const QString &csv, qint64 id)
{
    const QStringList current = parseTokens(csv, QStringLiteral(","));
    if (current.isEmpty()) {
        return true;
    }
    return current.contains(QString::number(id));
}

int visibleProjectCount(const QList<ProjectCandidate> &projects, const QSet<qint64> &hiddenIds)
{
    int count = 0;
    for (const ProjectCandidate &project : projects) {
        if (project.taskCount > 0 && !hiddenIds.contains(project.id)) {
            ++count;
        }
    }
    return count;
}

int visibleLabelCount(const QStringList &labels, const QSet<QString> &hiddenLabels)
{
    int count = 0;
    for (const QString &label : labels) {
        if (!hiddenLabels.contains(label)) {
            ++count;
        }
    }
    return count;
}

int naturalListHeight(int rowCount, ListHeader hasHeader, int headerHeight, int rowHeight, int gap)
{
    const int rows = qMax(0, rowCount);
    const int header = hasHeader == ListHeader::Yes ? headerHeight : 0;
    const int parts = rows + (hasHeader == ListHeader::Yes ? 1 : 0);
    const int gaps = qMax(0, parts - 1);
    return header + rows * rowHeight + gaps * gap;
}

QList<int> redistributeSections(int available, const QList<int> &mins)
{
    const int count = mins.size();
    if (available < 4 || count == 0) {
        return QList<int>(count, 0);
    }

    QList<bool> locked(count, false);
    QList<int> alloc(count, 0);
    int remaining = available;
    int open = count;
    bool progress = true;
    int guard = 0;
    while (progress && open > 0 && guard < 8) {
        ++guard;
        progress = false;
        const qreal share = qreal(remaining) / qreal(open);
        for (int j = 0; j < count; ++j) {
            if (!locked.at(j) && mins.at(j) <= share) {
                locked[j] = true;
                alloc[j] = mins.at(j);
                remaining -= mins.at(j);
                --open;
                progress = true;
            }
        }
    }
    if (open > 0) {
        const int even = remaining / open;
        int extra = remaining - even * open;
        for (int k = 0; k < count; ++k) {
            if (!locked.at(k)) {
                alloc[k] = even + (extra > 0 ? 1 : 0);
                if (extra > 0) {
                    --extra;
                }
            }
        }
    }
    return alloc;
}

QString viewIconSource(const QString &viewId)
{
    if (viewId == ViewId::Today) {
        return QStringLiteral("view-calendar-day");
    }
    if (viewId == ViewId::Overdue) {
        return QStringLiteral("appointment-missed");
    }
    if (viewId == ViewId::Tomorrow) {
        return QStringLiteral("go-next");
    }
    if (viewId == ViewId::Scheduled) {
        return QStringLiteral("view-calendar");
    }
    if (viewId == ViewId::Anytime) {
        return QStringLiteral("view-calendar-tasks");
    }
    if (viewId == ViewId::Recurring) {
        return QStringLiteral("media-playlist-repeat");
    }
    if (viewId == ViewId::Unlabeled) {
        return QStringLiteral("tag-delete");
    }
    if (viewId == ViewId::Completed) {
        return QStringLiteral("checkmark");
    }
    return QStringLiteral("mail-folder-inbox");
}

int indexForValue(const QList<int> &values, int value)
{
    return values.indexOf(value);
}

int indexForString(const QStringList &values, const QString &value)
{
    if (value.isEmpty()) {
        return -1;
    }
    return values.indexOf(value);
}

int normalizeStatus(int status)
{
    static const QList<int> values = {0, 4, 6, 3, 5};
    return values.contains(status) ? status : 0;
}

int recurrenceIndexFor(const QString &preset)
{
    if (preset == QLatin1String("daily")) {
        return 1;
    }
    if (preset == QLatin1String("weekly")) {
        return 2;
    }
    if (preset == QLatin1String("monthly")) {
        return 3;
    }
    if (preset == QLatin1String("yearly")) {
        return 4;
    }
    return 0;
}

QString recurrenceValueFor(int index)
{
    switch (index) {
    case 1:
        return QStringLiteral("daily");
    case 2:
        return QStringLiteral("weekly");
    case 3:
        return QStringLiteral("monthly");
    case 4:
        return QStringLiteral("yearly");
    default:
        return QStringLiteral("none");
    }
}

QString priorityLabel(int priority)
{
    const int band = priorityBand(priority);
    if (band == 1) {
        return QStringLiteral("high");
    }
    if (band == 5) {
        return QStringLiteral("medium");
    }
    if (band == 9) {
        return QStringLiteral("low");
    }
    return {};
}

int priorityToIndex(int priority)
{
    switch (priorityBand(priority)) {
    case 1:
        return 1;
    case 5:
        return 2;
    case 9:
        return 3;
    default:
        return 0;
    }
}

int indexToPriority(int index)
{
    switch (index) {
    case 1:
        return PriorityBand::High;
    case 2:
        return PriorityBand::Medium;
    case 3:
        return PriorityBand::Low;
    default:
        return PriorityBand::None;
    }
}

int resolveCursorSize(int envValue, EnvCursor envCursor, int configValue)
{
    if (envCursor == EnvCursor::Valid && envValue > 0) {
        return envValue;
    }
    return configValue > 0 ? configValue : 24;
}

qreal pickLimitRight(qreal screenRight, qreal cppRight, qreal margin)
{
    qreal right = screenRight;
    if (cppRight > 0) {
        right = qMin(right, cppRight);
    }
    return right - margin;
}

qreal pickLimitBottom(const QList<qreal> &candidates, qreal margin)
{
    if (candidates.isEmpty()) {
        return -margin;
    }
    qreal bottom = candidates.first();
    for (int i = 1; i < candidates.size(); ++i) {
        if (candidates.at(i) < bottom) {
            bottom = candidates.at(i);
        }
    }
    return bottom - margin;
}

QString pad2(int n)
{
    if (n < 10) {
        return QStringLiteral("0") + QString::number(n);
    }
    return QString::number(n);
}

QString digitsOnly(const QString &str)
{
    QString out;
    for (const QChar ch : str) {
        if (ch.isDigit()) {
            out.append(ch);
        }
    }
    return out;
}

QList<FormatToken> parseFormatTokens(const QString &fmt)
{
    QList<FormatToken> tokens;
    const QString s = fmt;
    int i = 0;
    while (i < s.size()) {
        const QChar c = s.at(i);
        if (c == QLatin1Char('\'')) {
            const int end = s.indexOf(QLatin1Char('\''), i + 1);
            if (end < 0) {
                tokens.append({QStringLiteral("sep"), s.mid(i), 0});
                break;
            }
            tokens.append({QStringLiteral("sep"), s.mid(i + 1, end - i - 1), 0});
            i = end + 1;
            continue;
        }
        if (c == QLatin1Char('y') || c == QLatin1Char('M') || c == QLatin1Char('d')
            || c == QLatin1Char('H') || c == QLatin1Char('h') || c == QLatin1Char('m')) {
            int j = i;
            while (j < s.size() && s.at(j) == c) {
                ++j;
            }
            FormatToken token;
            token.text = s.mid(i, j - i);
            token.maxLen = 2;
            if (c == QLatin1Char('y')) {
                token.kind = QStringLiteral("year");
                token.maxLen = 4;
            } else if (c == QLatin1Char('M')) {
                token.kind = QStringLiteral("month");
            } else if (c == QLatin1Char('d')) {
                token.kind = QStringLiteral("day");
            } else {
                token.kind = QStringLiteral("hour");
                if (c == QLatin1Char('m')) {
                    token.kind = QStringLiteral("minute");
                }
            }
            tokens.append(token);
            i = j;
            continue;
        }
        if (QStringLiteral("aAtpP").contains(c)) {
            int j2 = i;
            while (j2 < s.size() && QStringLiteral("aAtpP").contains(s.at(j2))) {
                ++j2;
            }
            tokens.append({QStringLiteral("ampm"), s.mid(i, j2 - i), 0});
            i = j2;
            continue;
        }
        int k = i;
        while (k < s.size()) {
            const QChar ch = s.at(k);
            if (QStringLiteral("yMdHhmatA'pP").contains(ch)) {
                break;
            }
            ++k;
        }
        tokens.append({QStringLiteral("sep"), s.mid(i, k - i), 0});
        i = k;
    }
    return tokens;
}

int maxDigitsFor(const QList<FormatToken> &tokens)
{
    int n = 0;
    for (const FormatToken &token : tokens) {
        if (token.kind != QLatin1String("sep") && token.kind != QLatin1String("ampm")) {
            n += token.maxLen;
        }
    }
    return n;
}

QString formatDigitsWithTokens(const QString &digits, const QList<FormatToken> &tokens)
{
    struct Chunk {
        QString kind;
        QString text;
        int maxLen = 0;
        bool complete = false;
    };

    const QString d = digits;
    int pos = 0;
    QList<Chunk> chunks;
    for (const FormatToken &token : tokens) {
        if (token.kind == QLatin1String("sep") || token.kind == QLatin1String("ampm")) {
            chunks.append({token.kind, token.text, token.maxLen, false});
            continue;
        }
        if (pos >= d.size()) {
            break;
        }
        const int take = qMin(token.maxLen, d.size() - pos);
        chunks.append({token.kind, d.mid(pos, take), token.maxLen, take >= token.maxLen});
        pos += take;
    }

    QString out;
    for (int j = 0; j < chunks.size(); ++j) {
        const Chunk &chunk = chunks.at(j);
        if (chunk.kind == QLatin1String("sep")) {
            const Chunk *prev = nullptr;
            const Chunk *next = nullptr;
            for (int k = j - 1; k >= 0; --k) {
                if (chunks.at(k).kind != QLatin1String("sep") && chunks.at(k).kind != QLatin1String("ampm")) {
                    prev = &chunks.at(k);
                    break;
                }
            }
            for (int n = j + 1; n < chunks.size(); ++n) {
                if (chunks.at(n).kind != QLatin1String("sep") && chunks.at(n).kind != QLatin1String("ampm")) {
                    next = &chunks.at(n);
                    break;
                }
            }
            if (prev && next && (prev->complete || !next->text.isEmpty())) {
                out += chunk.text;
            }
        } else if (chunk.kind != QLatin1String("ampm")) {
            out += chunk.text;
        }
    }
    return out;
}

QList<TextSegment> computeSegments(const QString &text, const QList<FormatToken> &tokens)
{
    const QString s = text;
    QList<TextSegment> segments;
    int cursor = 0;
    for (const FormatToken &token : tokens) {
        if (token.kind == QLatin1String("sep")) {
            if (cursor < s.size() && s.mid(cursor, token.text.size()) == token.text) {
                cursor += token.text.size();
            }
            continue;
        }
        if (token.kind == QLatin1String("ampm")) {
            continue;
        }
        const int start = cursor;
        int n = 0;
        while (cursor < s.size() && n < token.maxLen && s.at(cursor).isDigit()) {
            ++cursor;
            ++n;
        }
        segments.append({token.kind, start, qMax(start, cursor), token.maxLen});
    }
    return segments;
}

TextSegment segmentAtPosition(const QString &text, const QList<FormatToken> &tokens, int pos)
{
    const QList<TextSegment> segments = computeSegments(text, tokens);
    if (segments.isEmpty()) {
        return {};
    }
    for (int i = 0; i < segments.size(); ++i) {
        const TextSegment &seg = segments.at(i);
        if (pos >= seg.start && pos < seg.end) {
            return seg;
        }
        if (pos == seg.end && seg.end > seg.start) {
            if (i + 1 < segments.size() && segments.at(i + 1).start == pos && segments.at(i + 1).end == pos) {
                return segments.at(i + 1);
            }
            return seg;
        }
    }
    for (const TextSegment &seg : segments) {
        if (pos <= seg.start) {
            return seg;
        }
    }
    return segments.last();
}

QDate parseIsoDate(const QString &str)
{
    const QString s = str.trimmed();
    if (s.size() != 10 || s.at(4) != QLatin1Char('-') || s.at(7) != QLatin1Char('-')) {
        return {};
    }
    bool okYear = false;
    bool okMonth = false;
    bool okDay = false;
    const int year = s.left(4).toInt(&okYear);
    const int month = s.mid(5, 2).toInt(&okMonth);
    const int day = s.mid(8, 2).toInt(&okDay);
    if (!okYear || !okMonth || !okDay) {
        return {};
    }
    const QDate date(year, month, day);
    return date.isValid() ? date : QDate();
}

bool parseHmsTime(const QString &str, int *hours, int *minutes)
{
    const QString s = str.trimmed();
    if (s.isEmpty()) {
        if (hours) {
            *hours = 0;
        }
        if (minutes) {
            *minutes = 0;
        }
        return true;
    }
    const int colon = s.indexOf(QLatin1Char(':'));
    if (colon <= 0) {
        return false;
    }
    bool okH = false;
    bool okM = false;
    const int h = s.left(colon).toInt(&okH);
    const int m = s.mid(colon + 1).toInt(&okM);
    if (!okH || !okM || h < 0 || h > 23 || m < 0 || m > 59) {
        return false;
    }
    if (hours) {
        *hours = h;
    }
    if (minutes) {
        *minutes = m;
    }
    return true;
}

} // namespace TaskLogic
