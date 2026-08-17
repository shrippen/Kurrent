#include "tasklogic.h"

#include <QtMath>

#include <algorithm>
#include <functional>

namespace TaskLogic
{

int priorityBand(int priority)
{
    if (priority >= 1 && priority <= 3) {
        return 1;
    }
    if (priority >= 4 && priority <= 6) {
        return 5;
    }
    if (priority >= 7 && priority <= 9) {
        return 9;
    }
    return 0;
}

bool matchesSearch(const TaskEntry &task, const QString &query)
{
    if (query.trimmed().isEmpty()) {
        return true;
    }

    const QString needle = query.trimmed().toLower();
    return task.summary.toLower().contains(needle) || task.description.toLower().contains(needle)
        || task.collectionName.toLower().contains(needle)
        || task.categories.join(QLatin1Char(' ')).toLower().contains(needle);
}

bool matchesView(const TaskEntry &task, const QString &viewId, const QDate &today)
{
    const QDate tomorrow = today.addDays(1);
    const bool hasDue = task.dueDate.isValid();
    const QDate due = hasDue ? task.dueDate.date() : QDate();

    if (viewId == QLatin1String("inbox")) {
        return true;
    }
    if (viewId == QLatin1String("today")) {
        if (!hasDue) {
            return false;
        }
        if (due == today) {
            return true;
        }
        return due < today && !task.completed;
    }
    if (viewId == QLatin1String("tomorrow")) {
        return hasDue && due == tomorrow;
    }
    if (viewId == QLatin1String("scheduled")) {
        return hasDue;
    }
    if (viewId == QLatin1String("anytime")) {
        return !hasDue;
    }
    if (viewId == QLatin1String("recurring")) {
        return task.recurring;
    }
    if (viewId == QLatin1String("unlabeled")) {
        return task.categories.isEmpty();
    }
    if (viewId == QLatin1String("completed")) {
        return task.completed;
    }
    return true;
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
        for (const QString &category : task.categories) {
            if (category.isEmpty()) {
                continue;
            }
            out.totalLabels.insert(category, out.totalLabels.value(category).toInt() + 1);
        }

        const bool passCollection = filters.selectedCollectionId < 0 || task.collectionId == filters.selectedCollectionId;
        const bool passLabel = filters.selectedLabel.isEmpty() || task.categories.contains(filters.selectedLabel);
        const bool passPriority = filters.selectedPriority < 0 || priorityBand(task.priority) == filters.selectedPriority;
        const bool passSearch = matchesSearch(task, filters.searchQuery);
        const bool passCompleted = filters.showCompleted || !task.completed;

        if (passCollection && passLabel && passPriority && passSearch) {
            for (const QString &viewId : viewIds) {
                if (viewId == QLatin1String("completed")) {
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
                                   bool defaultExists,
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
    if (mode == QLatin1String("fixed") && defaultExists && defaultCollectionId > 0) {
        target.collectionId = defaultCollectionId;
        return target;
    }

    target.ask = true;
    return target;
}

QPointF dragProxyGap(int cursorSize, bool arrowCursor)
{
    const int size = qMax(16, cursorSize);
    if (arrowCursor) {
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

QList<TaskEntry> flattenTree(const QList<TaskEntry> &input, const QString &sortMode)
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
    std::function<void(const QString &, int)> walk = [&](const QString &parent, int indent) {
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
            out.append(entry);
            walk(entry.uid, indent + 1);
            walking.remove(entry.uid);
        }
    };
    walk(QString(), 0);

    if (out.isEmpty() && !input.isEmpty()) {
        for (TaskEntry entry : input) {
            entry.indentLevel = 0;
            entry.hasChildren = false;
            out.append(entry);
        }
    }
    return out;
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

        if (!matchesView(task, filters.currentView, today)
            || !matchesFilters(task, filters.selectedCollectionId, filters.selectedLabel, filters.selectedPriority)) {
            ++out.filteredOutView;
            continue;
        }
        if (!matchesSearch(task, filters.searchQuery)) {
            ++out.filteredOutSearch;
            continue;
        }
        out.tasks.append(task);
    }
    return out;
}

QHash<qint64, int> collectionTaskCounts(const QList<TaskEntry> &tasks)
{
    QHash<qint64, int> counts;
    for (const TaskEntry &task : tasks) {
        ++counts[task.collectionId];
    }
    return counts;
}

int pendingRootCount(const QList<TaskEntry> &tasks)
{
    int pending = 0;
    for (const TaskEntry &task : tasks) {
        if (!task.completed && task.indentLevel == 0) {
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

int naturalListHeight(int rowCount, bool hasHeader, int headerHeight, int rowHeight, int gap)
{
    const int rows = qMax(0, rowCount);
    const int header = hasHeader ? headerHeight : 0;
    const int parts = rows + (hasHeader ? 1 : 0);
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
    if (viewId == QLatin1String("today")) {
        return QStringLiteral("view-calendar-day");
    }
    if (viewId == QLatin1String("tomorrow")) {
        return QStringLiteral("go-next");
    }
    if (viewId == QLatin1String("scheduled")) {
        return QStringLiteral("view-calendar");
    }
    if (viewId == QLatin1String("anytime")) {
        return QStringLiteral("view-calendar-tasks");
    }
    if (viewId == QLatin1String("recurring")) {
        return QStringLiteral("media-playlist-repeat");
    }
    if (viewId == QLatin1String("unlabeled")) {
        return QStringLiteral("tag-delete");
    }
    if (viewId == QLatin1String("completed")) {
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
        return 1;
    case 2:
        return 5;
    case 3:
        return 9;
    default:
        return 0;
    }
}

int resolveCursorSize(int envValue, bool envOk, int configValue)
{
    if (envOk && envValue > 0) {
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
