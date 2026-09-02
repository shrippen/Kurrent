#include "tasklogic.h"

#include <QHash>
#include <QJsonArray>
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

QString kanbanColumnKey(const TaskEntry &task,
                        const QString &source,
                        const FilterState &filters,
                        const QDate &today);
QString kanbanColumnLabel(const QString &key, const QString &source);

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
    if (viewId == ViewId::Reminder) {
        return task.reminderMinutes >= 0;
    }
    if (viewId == ViewId::NoLocation) {
        return task.location.trimmed().isEmpty();
    }
    if (viewId == ViewId::NoPriority) {
        return priorityBand(task.priority) == PriorityBand::None;
    }
    if (viewId == ViewId::NoStatus) {
        return normalizeStatus(task.status) == 0;
    }
    return true;
}

bool matchesViewFilter(const TaskEntry &task, const FilterState &filters, const QDate &today)
{
    if (filters.hasSmartRules) {
        return matchesSmartView(task, filters.smartRules, today);
    }
    return matchesView(task, filters.currentView, today);
}

bool matchesTodayList(const TaskEntry &task, const FilterState &filters, const QDate &today)
{
    Q_UNUSED(filters);
    return matchesView(task, QStringLiteral("today"), today);
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

QString listGroupKey(const TaskEntry &task, const QString &mode, const FilterState &filters, const QDate &today)
{
    const QString normalized = mode.trimmed();
    if (normalized.isEmpty() || normalized == ListGroupSource::None) {
        return {};
    }
    if (normalized == ListGroupSource::Progress) {
        return progressBandKey(task.percentComplete);
    }
    if (normalized == ListGroupSource::Location) {
        const QString loc = task.location.trimmed();
        return loc.isEmpty() ? QStringLiteral("none") : loc;
    }
    if (normalized == ListGroupSource::Status) {
        return QString::number(normalizeStatus(task.status));
    }
    return kanbanColumnKey(task, normalized, filters, today);
}

QString listViewSectionKey(const TaskEntry &task, const FilterState &filters, const QDate &today)
{
    const QString grouped = listGroupKey(task, filters.listGroupMode, filters, today);
    if (!grouped.isEmpty()) {
        return grouped;
    }
    return listBucket(task, filters, today);
}

QString listGroupLabel(const QString &key, const QString &mode)
{
    const QString normalized = mode.trimmed();
    if (normalized == ListGroupSource::Progress) {
        if (key == QLatin1String("0-25")) {
            return QStringLiteral("0–25%");
        }
        if (key == QLatin1String("26-50")) {
            return QStringLiteral("26–50%");
        }
        if (key == QLatin1String("51-75")) {
            return QStringLiteral("51–75%");
        }
        if (key == QLatin1String("76-100")) {
            return QStringLiteral("76–100%");
        }
    }
    if (normalized == ListGroupSource::Location && key == QLatin1String("none")) {
        return QStringLiteral("No location");
    }
    if (normalized == ListGroupSource::Status) {
        if (key == QLatin1String("0")) {
            return QStringLiteral("None");
        }
        if (key == QLatin1String("4")) {
            return QStringLiteral("Needs action");
        }
        if (key == QLatin1String("6")) {
            return QStringLiteral("In process");
        }
        if (key == QLatin1String("3")) {
            return QStringLiteral("Completed");
        }
        if (key == QLatin1String("5")) {
            return QStringLiteral("Canceled");
        }
    }
    return kanbanColumnLabel(key, normalized);
}

QString listGroupAlphaLabel(const TaskEntry &task, const QString &mode)
{
    const QString normalized = mode.trimmed();
    if (normalized.isEmpty() || normalized == ListGroupSource::None) {
        return {};
    }
    if (normalized == ListGroupSource::Project) {
        const QString name = task.collectionName.trimmed();
        if (task.collectionId < 0 || name.isEmpty()) {
            return kanbanColumnLabel(QStringLiteral("inbox"), normalized);
        }
        return name;
    }
    QString key = task.bucket.trimmed();
    if (key.isEmpty()) {
        // Bucket is normally set by filterVisibleTasks; fall back for unit tests.
        key = listGroupKey(task, normalized, FilterState{}, QDate::currentDate());
    }
    return listGroupLabel(key, normalized);
}

namespace
{
QStringList sidebarFixedListGroupKeys(const QString &mode)
{
    const QString normalized = mode.trimmed();
    if (normalized == ListGroupSource::Priority) {
        // Sidebar: High → Medium → Low → None
        return {QStringLiteral("high"), QStringLiteral("medium"), QStringLiteral("low"),
                QStringLiteral("none")};
    }
    if (normalized == ListGroupSource::Progress) {
        return {QStringLiteral("0-25"), QStringLiteral("26-50"), QStringLiteral("51-75"),
                QStringLiteral("76-100")};
    }
    if (normalized == ListGroupSource::Status) {
        // Sidebar status rows (None/0 is not a sidebar row — ends up after these).
        return {QStringLiteral("4"), QStringLiteral("6"), QStringLiteral("3"), QStringLiteral("5")};
    }
    if (normalized == ListGroupSource::Secrecy) {
        return {QStringLiteral("public"), QStringLiteral("private"), QStringLiteral("confidential")};
    }
    return {};
}

QStringList listGroupSidebarOrderKeys(const QString &mode, const ListGroupOrderContext &ctx)
{
    const QString normalized = mode.trimmed();
    if (normalized == ListGroupSource::Project) {
        return ctx.projectKeys;
    }
    if (normalized == ListGroupSource::Label) {
        return ctx.labelKeys;
    }
    if (normalized == ListGroupSource::Location) {
        return ctx.locationKeys;
    }
    return sidebarFixedListGroupKeys(normalized);
}
} // namespace

int compareListGroupKeys(const QString &leftKey,
                         const QString &rightKey,
                         const QString &mode,
                         const ListGroupOrderContext &ctx)
{
    const QStringList ordered = listGroupSidebarOrderKeys(mode, ctx);
    const int leftRank = ordered.indexOf(leftKey);
    const int rightRank = ordered.indexOf(rightKey);
    const bool leftKnown = leftRank >= 0;
    const bool rightKnown = rightRank >= 0;
    if (leftKnown && rightKnown) {
        if (leftRank == rightRank) {
            return 0;
        }
        return leftRank < rightRank ? -1 : 1;
    }
    if (leftKnown != rightKnown) {
        return leftKnown ? -1 : 1;
    }
    const int labelCmp = QString::localeAwareCompare(listGroupLabel(leftKey, mode),
                                                     listGroupLabel(rightKey, mode));
    if (labelCmp != 0) {
        return labelCmp < 0 ? -1 : 1;
    }
    return leftKey < rightKey ? -1 : (leftKey > rightKey ? 1 : 0);
}

void applyListGroupTreeBuckets(QList<TaskEntry> &tasks,
                               const QString &groupMode,
                               const FilterState &filters,
                               const QDate &today)
{
    const QString normalized = groupMode.trimmed();
    if (normalized.isEmpty() || normalized == ListGroupSource::None || tasks.isEmpty()) {
        return;
    }

    int i = 0;
    while (i < tasks.size()) {
        const int start = i;
        const QString key = listGroupKey(tasks.at(i), normalized, filters, today);
        ++i;
        while (i < tasks.size() && tasks.at(i).indentLevel > 0) {
            ++i;
        }
        for (int k = start; k < i; ++k) {
            tasks[k].bucket = key;
        }
    }
}

QList<TaskEntry> sortFlatForListGroup(const QList<TaskEntry> &tasks,
                                      const QString &groupMode,
                                      const QString &sortMode,
                                      const ListGroupOrderContext &ctx)
{
    const QString normalized = groupMode.trimmed();
    if (normalized.isEmpty() || normalized == ListGroupSource::None || tasks.size() < 2) {
        return tasks;
    }

    QString mode = sortMode;
    if (mode.isEmpty() || mode == QLatin1String("default")) {
        mode = QStringLiteral("priority,due,title");
    }

    QList<QList<TaskEntry>> segments;
    segments.reserve(tasks.size());
    int i = 0;
    while (i < tasks.size()) {
        QList<TaskEntry> segment;
        do {
            segment.append(tasks.at(i++));
        } while (i < tasks.size() && tasks.at(i).indentLevel > 0);
        segments.append(segment);
    }

    const QDate today = QDate::currentDate();
    std::stable_sort(segments.begin(), segments.end(), [&](const QList<TaskEntry> &left, const QList<TaskEntry> &right) {
        const TaskEntry &leftRoot = left.first();
        const TaskEntry &rightRoot = right.first();
        const QString leftKey = leftRoot.bucket.isEmpty()
                ? listGroupKey(leftRoot, normalized, FilterState{}, today)
                : leftRoot.bucket;
        const QString rightKey = rightRoot.bucket.isEmpty()
                ? listGroupKey(rightRoot, normalized, FilterState{}, today)
                : rightRoot.bucket;
        if (leftKey != rightKey) {
            const int groupCmp = compareListGroupKeys(leftKey, rightKey, normalized, ctx);
            if (groupCmp != 0) {
                return groupCmp < 0;
            }
        }
        const int cmp = compareTasks(leftRoot, rightRoot, mode);
        if (cmp != 0) {
            return cmp < 0;
        }
        return leftRoot.itemId < rightRoot.itemId;
    });

    QList<TaskEntry> out;
    out.reserve(tasks.size());
    for (const QList<TaskEntry> &segment : segments) {
        out.append(segment);
    }
    return out;
}

TaskRebuildOutput computeTaskRebuild(const TaskRebuildInput &input, const QDate &today)
{
    TaskRebuildOutput out;
    out.allTasks = input.allTasks;
    out.filtered = filterVisibleTasks(input.allTasks, input.filters, today);
    // Always honour collapsedUids — flattenTree marks hidden children with
    // treeHidden=true so the ListView can animate height without row removal.
    out.tasks = flattenTree(out.filtered.tasks, input.sortMode, input.collapsedUids);
    if (!input.listGroupMode.isEmpty()) {
        applyListGroupTreeBuckets(out.tasks, input.listGroupMode, input.filters, today);
        out.tasks = sortFlatForListGroup(out.tasks, input.listGroupMode, input.sortMode, input.listGroupOrder);
    }
    if (!input.planPreviewWeek.isEmpty()) {
        QList<TaskEntry> preview;
        preview.reserve(out.tasks.size());
        for (const TaskEntry &task : out.tasks) {
            const QString week = planWeekKey(task, today);
            const QString project = task.collectionId >= 0 ? QString::number(task.collectionId)
                                                           : QStringLiteral("inbox");
            if (week == input.planPreviewWeek && project == input.planPreviewProject) {
                preview.append(task);
            }
        }
        out.tasks = preview;
    }
    out.flatForCounts = flattenTree(input.allTasks, input.sortMode, input.collapsedUids);
    return out;
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
    if (preset == ReschedulePreset::Plus1Day) {
        if (allDay || !seed.time().isValid()) {
            return QDateTime(seed.date().addDays(1), QTime(0, 0));
        }
        return seed.addDays(1);
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

bool matchesFilters(const TaskEntry &task, const FilterState &filters)
{
    if (filters.selectedCollectionId >= 0 && task.collectionId != filters.selectedCollectionId) {
        return false;
    }
    if (!filters.selectedLabel.isEmpty() && !task.categories.contains(filters.selectedLabel)) {
        return false;
    }
    if (filters.selectedPriority >= 0 && priorityBand(task.priority) != filters.selectedPriority) {
        return false;
    }
    if (!filters.selectedProgressBand.isEmpty()
        && progressBandKey(task.percentComplete) != filters.selectedProgressBand) {
        return false;
    }
    if (filters.selectedStatus >= 0 && normalizeStatus(task.status) != filters.selectedStatus) {
        return false;
    }
    if (filters.selectedSecrecy >= 0 && task.secrecy != filters.selectedSecrecy) {
        return false;
    }
    if (!filters.selectedLocation.isEmpty()
        && task.location.trimmed() != filters.selectedLocation) {
        return false;
    }
    return true;
}

bool hasSidebarFilters(const FilterState &filters)
{
    return filters.selectedCollectionId >= 0
            || !filters.selectedLabel.isEmpty()
            || filters.selectedPriority >= 0
            || !filters.selectedProgressBand.isEmpty()
            || filters.selectedStatus >= 0
            || filters.selectedSecrecy >= 0
            || !filters.selectedLocation.isEmpty();
}

QStringList progressBandKeys()
{
    return {
        QStringLiteral("0-25"),
        QStringLiteral("26-50"),
        QStringLiteral("51-75"),
        QStringLiteral("76-100"),
    };
}

QString progressBandKey(int percentComplete)
{
    const int percent = qBound(0, percentComplete, 100);
    if (percent <= 25) {
        return QStringLiteral("0-25");
    }
    if (percent <= 50) {
        return QStringLiteral("26-50");
    }
    if (percent <= 75) {
        return QStringLiteral("51-75");
    }
    return QStringLiteral("76-100");
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
        // When true, "has value" vs empty stays dated/started-before-empty even if Desc.
        bool flipHasEmpty = true;
        if (field == QLatin1String("due")) {
            const bool leftHasDue = left.dueDate.isValid();
            const bool rightHasDue = right.dueDate.isValid();
            if (leftHasDue != rightHasDue) {
                cmp = leftHasDue ? -1 : 1;
                flipHasEmpty = false;
            } else if (leftHasDue && rightHasDue) {
                if (left.dueDate < right.dueDate) {
                    cmp = -1;
                } else if (left.dueDate > right.dueDate) {
                    cmp = 1;
                }
            }
        } else if (field == QLatin1String("start")) {
            const bool leftHas = left.startDate.isValid();
            const bool rightHas = right.startDate.isValid();
            if (leftHas != rightHas) {
                cmp = leftHas ? -1 : 1;
                flipHasEmpty = false;
            } else if (leftHas && rightHas) {
                if (left.startDate < right.startDate) {
                    cmp = -1;
                } else if (left.startDate > right.startDate) {
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
        } else if (field == QLatin1String("reminder")) {
            const bool leftHas = left.reminderMinutes >= 0;
            const bool rightHas = right.reminderMinutes >= 0;
            if (leftHas != rightHas) {
                cmp = leftHas ? -1 : 1;
            } else if (leftHas && rightHas) {
                if (left.reminderMinutes < right.reminderMinutes) {
                    cmp = -1;
                } else if (left.reminderMinutes > right.reminderMinutes) {
                    cmp = 1;
                }
            }
        } else if (field == QLatin1String("recurring")) {
            if (left.recurring != right.recurring) {
                cmp = left.recurring ? -1 : 1;
            }
        } else if (field == QLatin1String("progress")) {
            if (left.percentComplete < right.percentComplete) {
                cmp = -1;
            } else if (left.percentComplete > right.percentComplete) {
                cmp = 1;
            }
        } else if (field == QLatin1String("project")) {
            const QString leftName = left.collectionName.trimmed();
            const QString rightName = right.collectionName.trimmed();
            if (leftName.isEmpty() != rightName.isEmpty()) {
                cmp = leftName.isEmpty() ? 1 : -1;
                flipHasEmpty = false;
            } else {
                cmp = QString::compare(leftName, rightName, Qt::CaseInsensitive);
                if (cmp > 0) {
                    cmp = 1;
                } else if (cmp < 0) {
                    cmp = -1;
                }
            }
        } else if (field == QLatin1String("label")) {
            const QString leftLabel = left.categories.isEmpty() ? QString() : left.categories.first().trimmed();
            const QString rightLabel = right.categories.isEmpty() ? QString() : right.categories.first().trimmed();
            if (leftLabel.isEmpty() != rightLabel.isEmpty()) {
                cmp = leftLabel.isEmpty() ? 1 : -1;
                flipHasEmpty = false;
            } else {
                cmp = QString::compare(leftLabel, rightLabel, Qt::CaseInsensitive);
                if (cmp > 0) {
                    cmp = 1;
                } else if (cmp < 0) {
                    cmp = -1;
                }
            }
        } else if (field == QLatin1String("status")) {
            const auto statusRank = [](int status, bool completed) -> int {
                if (completed || status == 3) {
                    return 3;
                }
                if (status == 5) {
                    return 4;
                }
                if (status == 6) {
                    return 2;
                }
                if (status == 4) {
                    return 1;
                }
                return 5;
            };
            const int leftRank = statusRank(left.status, left.completed);
            const int rightRank = statusRank(right.status, right.completed);
            if (leftRank < rightRank) {
                cmp = -1;
            } else if (leftRank > rightRank) {
                cmp = 1;
            }
        } else if (field == QLatin1String("secrecy")) {
            if (left.secrecy < right.secrecy) {
                cmp = -1;
            } else if (left.secrecy > right.secrecy) {
                cmp = 1;
            }
        } else if (field == QLatin1String("location")) {
            const QString leftLoc = left.location.trimmed();
            const QString rightLoc = right.location.trimmed();
            if (leftLoc.isEmpty() != rightLoc.isEmpty()) {
                cmp = leftLoc.isEmpty() ? 1 : -1;
                flipHasEmpty = false;
            } else {
                cmp = QString::compare(leftLoc, rightLoc, Qt::CaseInsensitive);
                if (cmp > 0) {
                    cmp = 1;
                } else if (cmp < 0) {
                    cmp = -1;
                }
            }
        }

        if (cmp != 0) {
            return (descending && flipHasEmpty) ? -cmp : cmp;
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
        QStringLiteral("reminder"),
        QStringLiteral("nolocation"),
        QStringLiteral("nopriority"),
        QStringLiteral("nostatus"),
    };

    SidebarCounts out;
    for (const QString &viewId : viewIds) {
        out.viewCounts.insert(viewId, 0);
    }
    out.viewCounts.insert(QStringLiteral("high"), 0);
    out.sidebarPriorities.insert(QStringLiteral("0"), 0);
    out.sidebarPriorities.insert(QStringLiteral("1"), 0);
    out.sidebarPriorities.insert(QStringLiteral("5"), 0);
    out.sidebarPriorities.insert(QStringLiteral("9"), 0);
    for (const QString &band : progressBandKeys()) {
        out.sidebarProgress.insert(band, 0);
    }
    for (const int status : {0, 4, 6, 3, 5}) {
        out.sidebarStatus.insert(QString::number(status), 0);
    }
    for (const int secrecy : {0, 1, 2}) {
        out.sidebarSecrecy.insert(QString::number(secrecy), 0);
    }

    const auto passExcept = [&](const TaskEntry &task, bool skipCollection, bool skipLabel, bool skipPriority,
                                bool skipProgress, bool skipStatus, bool skipSecrecy, bool skipLocation) -> bool {
        if (!skipCollection && filters.selectedCollectionId >= 0 && task.collectionId != filters.selectedCollectionId) {
            return false;
        }
        if (!skipLabel && !filters.selectedLabel.isEmpty() && !task.categories.contains(filters.selectedLabel)) {
            return false;
        }
        if (!skipPriority && filters.selectedPriority >= 0 && priorityBand(task.priority) != filters.selectedPriority) {
            return false;
        }
        if (!skipProgress && !filters.selectedProgressBand.isEmpty()
            && progressBandKey(task.percentComplete) != filters.selectedProgressBand) {
            return false;
        }
        if (!skipStatus && filters.selectedStatus >= 0 && normalizeStatus(task.status) != filters.selectedStatus) {
            return false;
        }
        if (!skipSecrecy && filters.selectedSecrecy >= 0 && task.secrecy != filters.selectedSecrecy) {
            return false;
        }
        if (!skipLocation && !filters.selectedLocation.isEmpty()
            && task.location.trimmed() != filters.selectedLocation) {
            return false;
        }
        return true;
    };

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
        const QString location = task.location.trimmed();
        if (!location.isEmpty()) {
            out.totalLocations.insert(location, out.totalLocations.value(location).toInt() + 1);
        }

        const bool passSearch = matchesSearch(task, filters.searchQuery, filters.searchScope, filters.searchCase);
        const bool passCompleted = filters.showCompleted || !task.completed;
        const bool passSidebarForViews = passExcept(task, false, false, false, false, false, false, false);

        if (passSidebarForViews && passSearch) {
            for (const QString &viewId : viewIds) {
                if (viewId == ViewId::Completed) {
                    if (task.completed && matchesView(task, viewId, today)) {
                        out.viewCounts.insert(viewId, out.viewCounts.value(viewId).toInt() + 1);
                    }
                } else if (passCompleted && matchesView(task, viewId, today)) {
                    out.viewCounts.insert(viewId, out.viewCounts.value(viewId).toInt() + 1);
                }
            }
            if (passCompleted && !task.completed && priorityBand(task.priority) == PriorityBand::High) {
                out.viewCounts.insert(QStringLiteral("high"),
                                      out.viewCounts.value(QStringLiteral("high")).toInt() + 1);
            }
        }

        const bool inCurrentView = (filters.currentView == QLatin1String("completed"))
            ? task.completed && matchesView(task, filters.currentView, today)
            : passCompleted && matchesView(task, filters.currentView, today);

        if (inCurrentView && passSearch
            && passExcept(task, true, false, false, false, false, false, false)) {
            const QString projectKey = QString::number(task.collectionId);
            out.sidebarProjects.insert(projectKey, out.sidebarProjects.value(projectKey).toInt() + 1);
        }
        if (inCurrentView && passSearch
            && passExcept(task, false, true, false, false, false, false, false)) {
            for (const QString &category : task.categories) {
                if (category.isEmpty()) {
                    continue;
                }
                out.sidebarLabels.insert(category, out.sidebarLabels.value(category).toInt() + 1);
            }
        }
        if (inCurrentView && passSearch
            && passExcept(task, false, false, true, false, false, false, false)) {
            const QString priorityKey = QString::number(priorityBand(task.priority));
            out.sidebarPriorities.insert(priorityKey, out.sidebarPriorities.value(priorityKey).toInt() + 1);
        }
        if (inCurrentView && passSearch
            && passExcept(task, false, false, false, true, false, false, false)) {
            const QString band = progressBandKey(task.percentComplete);
            out.sidebarProgress.insert(band, out.sidebarProgress.value(band).toInt() + 1);
        }
        if (inCurrentView && passSearch
            && passExcept(task, false, false, false, false, true, false, false)) {
            const QString statusKey = QString::number(normalizeStatus(task.status));
            out.sidebarStatus.insert(statusKey, out.sidebarStatus.value(statusKey).toInt() + 1);
        }
        if (inCurrentView && passSearch
            && passExcept(task, false, false, false, false, false, true, false)) {
            const QString secrecyKey = QString::number(qBound(0, task.secrecy, 2));
            out.sidebarSecrecy.insert(secrecyKey, out.sidebarSecrecy.value(secrecyKey).toInt() + 1);
        }
        if (inCurrentView && passSearch
            && passExcept(task, false, false, false, false, false, false, true)
            && !location.isEmpty()) {
            out.sidebarLocations.insert(location, out.sidebarLocations.value(location).toInt() + 1);
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
        QString mode = sortMode;
        if (mode.isEmpty() || mode == QLatin1String("default")) {
            mode = QStringLiteral("priority,due,title");
        }
        if (kids.size() < 2) {
            return;
        }
        std::sort(kids.begin(), kids.end(), [&](int left, int right) {
            const int cmp = compareTasks(input.at(left), input.at(right), mode);
            if (cmp != 0) {
                return cmp < 0;
            }
            return input.at(left).itemId < input.at(right).itemId;
        });
    };

    QList<TaskEntry> out;
    QSet<QString> walking;

    // Walk the tree depth-first.  Collapsed children stay in the list with
    // treeHidden = true so the ListView can animate their height to 0
    // (TaskDelegate "reveal" binding) without insert/remove row operations.
    std::function<void(const QString &, int, bool)> walk =
        [&](const QString &parent, int indent, bool parentHidden) {
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
            entry.treeHidden = parentHidden;
            out.append(entry);
            // Always walk children so hidden rows stay in the model.
            walk(entry.uid, indent + 1, parentHidden || entry.treeCollapsed);
            walking.remove(entry.uid);
        }
    };
    walk(QString(), 0, false);

    if (out.isEmpty() && !input.isEmpty()) {
        for (TaskEntry entry : input) {
            entry.indentLevel = 0;
            entry.hasChildren = false;
            entry.treeCollapsed = false;
            entry.treeHidden = false;
            out.append(entry);
        }
    }

    // Prune hidden rows whose parent is not in this list (e.g. parent was
    // filtered out by search).  Keep hidden children when the parent is
    // present so the ListView can animate height without insert/remove.
    {
        QSet<QString> present;
        present.reserve(out.size());
        for (const TaskEntry &task : out) {
            present.insert(task.uid);
        }
        QList<TaskEntry> pruned;
        pruned.reserve(out.size());
        for (const TaskEntry &task : out) {
            if (task.treeHidden && !present.contains(task.parentUid)) {
                continue;
            }
            pruned.append(task);
        }
        out = pruned;
    }

    // Hidden rows inherit the nearest visible ancestor's bucket so Today
    // section headers do not grow empty from collapsed subtasks alone.
    QString lastVisibleBucket;
    for (TaskEntry &task : out) {
        if (task.treeHidden) {
            task.bucket = lastVisibleBucket;
        } else {
            lastVisibleBucket = task.bucket;
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

int panelBadgeCount(const QString &mode, int openRoots, const QVariantMap &viewCounts)
{
    if (mode == QLatin1String("off")) {
        return 0;
    }
    if (mode == QLatin1String("today")) {
        return qMax(0, viewCounts.value(QStringLiteral("today")).toInt());
    }
    if (mode == QLatin1String("overdue")) {
        return qMax(0, viewCounts.value(QStringLiteral("overdue")).toInt());
    }
    if (mode == QLatin1String("tomorrow")) {
        return qMax(0, viewCounts.value(QStringLiteral("tomorrow")).toInt());
    }
    if (mode == QLatin1String("high")) {
        return qMax(0, viewCounts.value(QStringLiteral("high")).toInt());
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
    case UndoRecord::Kind::Edit:
        return QStringLiteral("edit");
    case UndoRecord::Kind::KanbanLayout:
        return QStringLiteral("kanban");
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

    const bool completedView = filters.currentView == QLatin1String("completed");
    // Completed view always rescues ancestors of done tasks. Other views rescue the
    // open tree around search/sidebar hits (completed descendants stay hidden).
    const bool hierarchyAware = completedView
            || !filters.searchQuery.trimmed().isEmpty()
            || hasSidebarFilters(filters);

    QHash<QString, QString> parentByUid;
    QHash<QString, int> indexByUid;
    parentByUid.reserve(tasks.size());
    indexByUid.reserve(tasks.size());
    for (int i = 0; i < tasks.size(); ++i) {
        const TaskEntry &task = tasks.at(i);
        parentByUid.insert(task.uid, task.parentUid);
        indexByUid.insert(task.uid, i);
    }

    // Completed tasks appear only in the Completed view. Elsewhere they never seed
    // or ride along via hierarchy.
    const auto passesCompleted = [&](const TaskEntry &task) -> bool {
        return completedView ? task.completed : !task.completed;
    };

    const auto passesViewAndSidebar = [&](const TaskEntry &task) -> bool {
        if (filters.currentView == QLatin1String("today")) {
            return matchesTodayList(task, filters, today)
                    && matchesFilters(task, filters);
        }
        return matchesViewFilter(task, filters, today)
                && matchesFilters(task, filters);
    };

    const auto isDirectMatch = [&](const TaskEntry &task) -> bool {
        if (!passesCompleted(task)) {
            return false;
        }
        if (!passesViewAndSidebar(task)) {
            return false;
        }
        if (!matchesSearch(task, filters.searchQuery, filters.searchScope, filters.searchCase)) {
            return false;
        }
        return true;
    };

    QSet<QString> keep;
    if (hierarchyAware) {
        for (const TaskEntry &task : tasks) {
            if (task.uid.isEmpty() || !isDirectMatch(task)) {
                continue;
            }
            if (completedView) {
                // Done task + ancestors only (open siblings stay out).
                keep.insert(task.uid);
                QString walk = task.parentUid;
                QSet<QString> seen;
                while (!walk.isEmpty() && indexByUid.contains(walk) && !seen.contains(walk)) {
                    seen.insert(walk);
                    keep.insert(walk);
                    walk = parentByUid.value(walk);
                }
            } else {
                // Whole open tree from the topmost available ancestor.
                QString rootUid = task.uid;
                while (true) {
                    const QString parent = parentByUid.value(rootUid);
                    if (parent.isEmpty() || !indexByUid.contains(parent)) {
                        break;
                    }
                    rootUid = parent;
                }
                keep.insert(rootUid);
                const QStringList descendants = descendantUids(rootUid, parentByUid);
                for (const QString &uid : descendants) {
                    if (!uid.isEmpty()) {
                        keep.insert(uid);
                    }
                }
            }
        }
    }

    QHash<QString, QString> matchBucket;
    if (hierarchyAware) {
        for (const TaskEntry &task : tasks) {
            if (isDirectMatch(task)) {
                matchBucket.insert(task.uid, listViewSectionKey(task, filters, today));
            }
        }
    }

    const auto bucketForKept = [&](const TaskEntry &task) -> QString {
        if (!hierarchyAware) {
            return listViewSectionKey(task, filters, today);
        }
        // Prefer a direct match's bucket so rescued parents/children stay in the
        // same Today section as the hit that pulled the tree in.
        if (matchBucket.contains(task.uid)) {
            return matchBucket.value(task.uid);
        }
        QString walk = task.uid;
        while (!walk.isEmpty()) {
            if (matchBucket.contains(walk)) {
                return matchBucket.value(walk);
            }
            walk = parentByUid.value(walk);
        }
        const QStringList descendants = descendantUids(task.uid, parentByUid);
        for (const QString &uid : descendants) {
            if (matchBucket.contains(uid)) {
                return matchBucket.value(uid);
            }
        }
        return listViewSectionKey(task, filters, today);
    };

    for (const TaskEntry &task : tasks) {
        const bool direct = isDirectMatch(task);
        const bool inKeep = hierarchyAware && !task.uid.isEmpty() && keep.contains(task.uid);
        // Outside Completed: hierarchy never resurrects done tasks.
        // In Completed: incomplete ancestors of done hits are allowed.
        const bool viaTree = inKeep && (completedView ? !direct : !task.completed);
        if (!direct && !viaTree) {
            if (completedView) {
                if (!task.completed) {
                    ++out.filteredOutView;
                }
            } else if (task.completed) {
                ++out.filteredOutCompleted;
            } else if (filters.currentView == QLatin1String("today")) {
                if (!matchesTodayList(task, filters, today)
                        || !matchesFilters(task, filters)) {
                    ++out.filteredOutView;
                } else if (!matchesSearch(task, filters.searchQuery, filters.searchScope, filters.searchCase)) {
                    ++out.filteredOutSearch;
                }
            } else if (!matchesViewFilter(task, filters, today)
                       || !matchesFilters(task, filters)) {
                ++out.filteredOutView;
            } else if (!matchesSearch(task, filters.searchQuery, filters.searchScope, filters.searchCase)) {
                ++out.filteredOutSearch;
            }
            continue;
        }

        TaskEntry visible = task;
        visible.bucket = bucketForKept(task);
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

QStringList collectAvailableLocations(const QList<TaskEntry> &tasks, const QStringList &extraLocations)
{
    QSet<QString> locations;
    for (const TaskEntry &task : tasks) {
        const QString location = task.location.trimmed();
        if (!location.isEmpty()) {
            locations.insert(location);
        }
    }
    for (const QString &extra : extraLocations) {
        if (!extra.trimmed().isEmpty()) {
            locations.insert(extra.trimmed());
        }
    }
    QStringList sorted = locations.values();
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
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }
    for (const QString &label : selected) {
        if (label.trimmed() == trimmed) {
            return true;
        }
    }
    return false;
}

QStringList addLabel(QStringList selected, const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || containsLabel(selected, trimmed)) {
        return selected;
    }
    selected.append(trimmed);
    return selected;
}

QStringList removeLabel(const QStringList &selected, const QString &name)
{
    const QString trimmed = name.trimmed();
    QStringList out;
    out.reserve(selected.size());
    for (const QString &label : selected) {
        if (label.trimmed() != trimmed) {
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
    return {
        QStringLiteral("views"),
        QStringLiteral("projects"),
        QStringLiteral("labels"),
        QStringLiteral("priorities"),
        QStringLiteral("progress"),
        QStringLiteral("status"),
        QStringLiteral("secrecy"),
        QStringLiteral("location"),
    };
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
        QStringLiteral("reminder"),
        QStringLiteral("nolocation"),
        QStringLiteral("nopriority"),
        QStringLiteral("nostatus"),
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
        return QStringLiteral("chronometer");
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
    if (viewId == ViewId::Reminder) {
        return QStringLiteral("appointment-reminder");
    }
    if (viewId == ViewId::NoLocation) {
        return QStringLiteral("location-disabled");
    }
    if (viewId == ViewId::NoPriority) {
        return QStringLiteral("flag");
    }
    if (viewId == ViewId::NoStatus) {
        return QStringLiteral("task-new");
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

QString normalizeStatusColumnKey(const QString &key)
{
    bool ok = false;
    const int n = key.toInt(&ok);
    if (ok) {
        return QString::number(normalizeStatus(n));
    }
    if (key == QLatin1String("needs-action")) {
        return QStringLiteral("4");
    }
    if (key == QLatin1String("in-process")) {
        return QStringLiteral("6");
    }
    if (key == QLatin1String("completed")) {
        return QStringLiteral("3");
    }
    if (key == QLatin1String("cancelled")) {
        return QStringLiteral("5");
    }
    return key;
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

QList<SmartViewDef> parseSmartViews(const QString &json)
{
    QList<SmartViewDef> result;
    if (json.trimmed().isEmpty()) {
        return result;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) {
        return result;
    }
    const QJsonArray arr = doc.array();
    for (const QJsonValue &val : arr) {
        if (!val.isObject()) {
            continue;
        }
        result.append(parseSmartViewObject(val.toObject()));
    }
    return result;
}

SmartViewDef parseSmartViewObject(const QJsonObject &obj)
{
    SmartViewDef def;
    def.id = obj.value(QStringLiteral("id")).toString().trimmed();
    def.name = obj.value(QStringLiteral("name")).toString().trimmed();
    def.icon = obj.value(QStringLiteral("icon")).toString().trimmed();
    if (def.icon.isEmpty()) {
        def.icon = QStringLiteral("view-filter");
    }
    def.defaultMode = obj.value(QStringLiteral("mode")).toString(MainPaneMode::List);
    def.sortOverride = obj.value(QStringLiteral("sort")).toString();

    const QJsonObject rules = obj.value(QStringLiteral("rules")).toObject();
    def.rules.text = rules.value(QStringLiteral("text")).toString();
    def.rules.projectId = rules.value(QStringLiteral("projectId")).toVariant().toLongLong();
    def.rules.label = rules.value(QStringLiteral("label")).toString();
    def.rules.priority = rules.value(QStringLiteral("priority")).toInt(-1);
    def.rules.dueWindow = rules.value(QStringLiteral("dueWindow")).toString();
    def.rules.statusFilter = rules.value(QStringLiteral("status")).toString();
    def.rules.recurringOnly = rules.value(QStringLiteral("recurring")).toBool(false);
    def.rules.kurrentList = rules.value(QStringLiteral("list")).toString();
    def.rules.kurrentColumn = rules.value(QStringLiteral("column")).toString();
    return def;
}

bool matchesSmartView(const TaskEntry &task, const SmartViewRules &rules, const QDate &today)
{
    if (!rules.text.trimmed().isEmpty()) {
        if (!matchesSearch(task, rules.text, SearchScope::All, SearchCase::Insensitive)) {
            return false;
        }
    }
    if (rules.projectId >= 0 && task.collectionId != rules.projectId) {
        return false;
    }
    if (!rules.label.isEmpty() && !containsLabel(task.categories, rules.label)) {
        return false;
    }
    if (rules.priority >= 0 && priorityBand(task.priority) != rules.priority) {
        return false;
    }
    if (rules.recurringOnly && !task.recurring) {
        return false;
    }
    if (!rules.kurrentList.isEmpty() && task.section != rules.kurrentList) {
        return false;
    }
    if (!rules.kurrentColumn.isEmpty() && task.column != rules.kurrentColumn) {
        return false;
    }
    if (!rules.statusFilter.isEmpty()) {
        if (rules.statusFilter == QLatin1String("completed") && !task.completed) {
            return false;
        }
        if (rules.statusFilter == QLatin1String("open") && task.completed) {
            return false;
        }
        if (rules.statusFilter == QLatin1String("in-process")
            && (task.completed || (task.status != 2 && task.status != 4 && task.status != 6))) {
            return false;
        }
        if (rules.statusFilter == QLatin1String("cancelled") && task.status != 3) {
            return false;
        }
    }
    if (!rules.dueWindow.isEmpty()) {
        const bool hasDue = task.dueDate.isValid();
        const QDate due = hasDue ? task.dueDate.date() : QDate();
        if (rules.dueWindow == QLatin1String("overdue")) {
            if (!hasDue || due >= today || task.completed) {
                return false;
            }
        } else if (rules.dueWindow == QLatin1String("today")) {
            if (!hasDue || due != today) {
                return false;
            }
        } else if (rules.dueWindow == QLatin1String("tomorrow")) {
            if (!hasDue || due != today.addDays(1)) {
                return false;
            }
        } else if (rules.dueWindow == QLatin1String("week")) {
            if (!hasDue || due < today || due > today.addDays(7)) {
                return false;
            }
        } else if (rules.dueWindow == QLatin1String("none")) {
            if (hasDue) {
                return false;
            }
        }
    }
    return true;
}

QString kanbanColumnKey(const TaskEntry &task, const QString &source, const FilterState &filters, const QDate &today)
{
    const QString src = source.isEmpty() ? KanbanSource::Status : source;
    if (src == KanbanSource::Completion) {
        return task.completed ? QStringLiteral("done") : QStringLiteral("open");
    }
    if (src == KanbanSource::Status) {
        // Same VTODO STATUS enum as Sidebar counts and list grouping (0/4/6/3/5).
        return QString::number(normalizeStatus(task.status));
    }
    if (src == KanbanSource::Secrecy) {
        // KCalendarCore::Incidence::Secrecy: Public=0, Private=1, Confidential=2
        if (task.secrecy == 1) {
            return QStringLiteral("private");
        }
        if (task.secrecy == 2) {
            return QStringLiteral("confidential");
        }
        return QStringLiteral("public");
    }
    if (src == KanbanSource::Project) {
        return task.collectionId >= 0 ? QString::number(task.collectionId) : QStringLiteral("inbox");
    }
    if (src == KanbanSource::Due) {
        if (!task.dueDate.isValid()) {
            return QStringLiteral("no-date");
        }
        const QDate due = task.dueDate.date();
        if (due < today) {
            return QStringLiteral("overdue");
        }
        if (due == today) {
            return QStringLiteral("today");
        }
        if (due == today.addDays(1)) {
            return QStringLiteral("tomorrow");
        }
        if (due <= today.addDays(7)) {
            return QStringLiteral("this-week");
        }
        return QStringLiteral("later");
    }
    if (src == KanbanSource::Priority) {
        const int band = priorityBand(task.priority);
        if (band == PriorityBand::High) {
            return QStringLiteral("high");
        }
        if (band == PriorityBand::Medium) {
            return QStringLiteral("medium");
        }
        if (band == PriorityBand::Low) {
            return QStringLiteral("low");
        }
        return QStringLiteral("none");
    }
    if (src == KanbanSource::Label) {
        return task.categories.isEmpty() ? QStringLiteral("none") : task.categories.first();
    }
    if (src == KanbanSource::DaySection) {
        const QString bucket = listBucket(task, filters, today);
        return bucket.isEmpty() ? QStringLiteral("unscheduled") : bucket;
    }
    if (src == KanbanSource::Column) {
        if (!task.column.isEmpty()) {
            return task.column;
        }
        return kanbanColumnKey(task, KanbanSource::Status, filters, today);
    }
    return QStringLiteral("default");
}

QStringList fixedKanbanColumnKeys(const QString &source)
{
    const QString src = source.isEmpty() ? KanbanSource::Status : source;
    if (src == KanbanSource::Status) {
        return {QStringLiteral("4"), QStringLiteral("6"), QStringLiteral("3"), QStringLiteral("5"),
                QStringLiteral("0")};
    }
    if (src == KanbanSource::Completion) {
        return {QStringLiteral("open"), QStringLiteral("done")};
    }
    if (src == KanbanSource::Priority) {
        return {QStringLiteral("none"), QStringLiteral("low"), QStringLiteral("medium"),
                QStringLiteral("high")};
    }
    if (src == KanbanSource::Due) {
        return {QStringLiteral("overdue"), QStringLiteral("today"), QStringLiteral("tomorrow"),
                QStringLiteral("this-week"), QStringLiteral("later"), QStringLiteral("no-date")};
    }
    if (src == KanbanSource::DaySection) {
        return {QStringLiteral("morning"), QStringLiteral("afternoon"), QStringLiteral("evening"),
                QStringLiteral("unspecified"), QStringLiteral("unscheduled")};
    }
    if (src == KanbanSource::Secrecy) {
        return {QStringLiteral("public"), QStringLiteral("private"), QStringLiteral("confidential")};
    }
    return {};
}

QStringList orderKanbanColumnKeys(const QStringList &keys, const QString &source,
                                   const QHash<QString, QString> &displayNames)
{
    const QString src = source.isEmpty() ? KanbanSource::Status : source;
    const QStringList ranked = fixedKanbanColumnKeys(src);

    QSet<QString> seen;
    QStringList out;
    if (src == KanbanSource::Label || src == KanbanSource::Project) {
        QStringList named;
        bool hasInbox = false;
        bool hasNone = false;
        for (const QString &key : keys) {
            if (key == QLatin1String("inbox")) {
                hasInbox = true;
            } else if (key == QLatin1String("none")) {
                hasNone = true;
            } else {
                named.append(key);
            }
        }
        std::sort(named.begin(), named.end(), [&](const QString &a, const QString &b) {
            const QString la = displayNames.value(a, a);
            const QString lb = displayNames.value(b, b);
            const int cmp = la.localeAwareCompare(lb);
            return cmp != 0 ? cmp < 0 : a < b;
        });
        if (hasInbox) {
            out.append(QStringLiteral("inbox"));
        }
        out += named;
        if (hasNone) {
            out.append(QStringLiteral("none"));
        }
        return out;
    }

    // Fixed vocabularies: always show every column so empty targets stay droppable.
    for (const QString &key : ranked) {
        if (!seen.contains(key)) {
            out.append(key);
            seen.insert(key);
        }
    }
    QStringList rest;
    for (const QString &key : keys) {
        if (!seen.contains(key)) {
            rest.append(key);
        }
    }
    std::sort(rest.begin(), rest.end(), [&](const QString &a, const QString &b) {
        const QString la = displayNames.value(a, a);
        const QString lb = displayNames.value(b, b);
        return la.localeAwareCompare(lb) < 0;
    });
    return out + rest;
}

QList<qint64> applyManualKanbanOrder(const QList<qint64> &ids, const QList<qint64> &manualOrder)
{
    QList<qint64> out;
    QSet<qint64> remaining = QSet<qint64>(ids.begin(), ids.end());
    for (qint64 id : manualOrder) {
        if (remaining.contains(id)) {
            out.append(id);
            remaining.remove(id);
        }
    }
    for (qint64 id : ids) {
        if (remaining.contains(id)) {
            out.append(id);
        }
    }
    return out;
}

QString kanbanColumnLabel(const QString &key, const QString &source)
{
    Q_UNUSED(source)
    static const QHash<QString, QString> labels = {
        {QStringLiteral("0"), QStringLiteral("None")},
        {QStringLiteral("4"), QStringLiteral("Needs action")},
        {QStringLiteral("6"), QStringLiteral("In process")},
        {QStringLiteral("3"), QStringLiteral("Completed")},
        {QStringLiteral("5"), QStringLiteral("Canceled")},
        {QStringLiteral("needs-action"), QStringLiteral("Needs action")},
        {QStringLiteral("in-process"), QStringLiteral("In process")},
        {QStringLiteral("completed"), QStringLiteral("Completed")},
        {QStringLiteral("cancelled"), QStringLiteral("Cancelled")},
        {QStringLiteral("open"), QStringLiteral("Open")},
        {QStringLiteral("done"), QStringLiteral("Done")},
        {QStringLiteral("inbox"), QStringLiteral("Inbox")},
        {QStringLiteral("overdue"), QStringLiteral("Overdue")},
        {QStringLiteral("today"), QStringLiteral("Today")},
        {QStringLiteral("tomorrow"), QStringLiteral("Tomorrow")},
        {QStringLiteral("this-week"), QStringLiteral("This week")},
        {QStringLiteral("later"), QStringLiteral("Later")},
        {QStringLiteral("no-date"), QStringLiteral("No date")},
        {QStringLiteral("high"), QStringLiteral("High")},
        {QStringLiteral("medium"), QStringLiteral("Medium")},
        {QStringLiteral("low"), QStringLiteral("Low")},
        {QStringLiteral("none"), QStringLiteral("None")},
        {QStringLiteral("unscheduled"), QStringLiteral("Unscheduled")},
        {QStringLiteral("morning"), QStringLiteral("Morning")},
        {QStringLiteral("afternoon"), QStringLiteral("Afternoon")},
        {QStringLiteral("evening"), QStringLiteral("Evening")},
        {QStringLiteral("public"), QStringLiteral("Public")},
        {QStringLiteral("private"), QStringLiteral("Private")},
        {QStringLiteral("confidential"), QStringLiteral("Confidential")},
    };
    return labels.value(key, key);
}

QString swimlaneTimeBucket(const TaskEntry &task, const QString &bucketMode, const QDate &today)
{
    QDate anchor;
    if (task.dueDate.isValid()) {
        anchor = task.dueDate.date();
    } else if (task.startDate.isValid()) {
        anchor = task.startDate.date();
    } else {
        return QStringLiteral("unscheduled");
    }
    if (bucketMode == QLatin1String("week")) {
        return QStringLiteral("%1-W%2").arg(anchor.year()).arg(anchor.weekNumber(), 2, 10, QChar('0'));
    }
    if (bucketMode == QLatin1String("month")) {
        return QStringLiteral("%1-%2").arg(anchor.year()).arg(anchor.month(), 2, 10, QChar('0'));
    }
    return anchor.toString(Qt::ISODate);
}

QString swimlaneLaneKey(const TaskEntry &task, const QString &laneAxis)
{
    if (laneAxis == QLatin1String("label")) {
        return task.categories.isEmpty() ? QStringLiteral("none") : task.categories.first();
    }
    if (laneAxis == QLatin1String("priority")) {
        return QString::number(priorityBand(task.priority));
    }
    if (laneAxis == QLatin1String("parent")) {
        return task.parentUid.isEmpty() ? task.uid : task.parentUid;
    }
    return task.collectionId >= 0 ? QString::number(task.collectionId) : QStringLiteral("inbox");
}

QString planWeekKey(const TaskEntry &task, const QDate &today)
{
    Q_UNUSED(today)
    QDate anchor;
    if (task.dueDate.isValid()) {
        anchor = task.dueDate.date();
    } else if (task.startDate.isValid()) {
        anchor = task.startDate.date();
    } else {
        return {};
    }
    return QStringLiteral("%1-W%2").arg(anchor.year()).arg(anchor.weekNumber(), 2, 10, QChar('0'));
}

QString heatmapDayKey(const TaskEntry &task, const QString &mode, const QDate &today)
{
    Q_UNUSED(today)
    if (mode == QLatin1String("completed")) {
        if (!task.completed || !task.completedDate.isValid()) {
            return {};
        }
        return task.completedDate.date().toString(Qt::ISODate);
    }
    if (task.completed || !task.dueDate.isValid()) {
        return QString();
    }
    return task.dueDate.date().toString(Qt::ISODate);
}

QVariantMap heatmapCounts(const QList<TaskEntry> &tasks, const QString &mode, const QDate &monthStart)
{
    const QDate monthEnd = monthStart.addMonths(1).addDays(-1);
    QVariantMap counts;
    for (const TaskEntry &task : tasks) {
        const QString key = heatmapDayKey(task, mode, monthStart);
        if (key.isEmpty()) {
            continue;
        }
        const QDate day = QDate::fromString(key, Qt::ISODate);
        if (!day.isValid() || day < monthStart || day > monthEnd) {
            continue;
        }
        counts.insert(key, counts.value(key, 0).toInt() + 1);
    }
    return counts;
}

QVariantMap heatmapCountsForYear(const QList<TaskEntry> &tasks, const QString &mode, const QDate &anyDayInYear)
{
    if (!anyDayInYear.isValid()) {
        return {};
    }
    const QDate yearStart(anyDayInYear.year(), 1, 1);
    const QDate yearEnd(anyDayInYear.year(), 12, 31);
    QVariantMap counts;
    for (const TaskEntry &task : tasks) {
        const QString key = heatmapDayKey(task, mode, anyDayInYear);
        if (key.isEmpty()) {
            continue;
        }
        const QDate day = QDate::fromString(key, Qt::ISODate);
        if (!day.isValid() || day < yearStart || day > yearEnd) {
            continue;
        }
        counts.insert(key, counts.value(key, 0).toInt() + 1);
    }
    return counts;
}

QVariantMap planMatrixCounts(const QList<TaskEntry> &tasks, const QDate &today)
{
    QVariantMap matrix;
    for (const TaskEntry &task : tasks) {
        if (task.completed) {
            continue;
        }
        const QString week = planWeekKey(task, today);
        if (week.isEmpty()) {
            continue;
        }
        const QString row = task.collectionId >= 0 ? QString::number(task.collectionId) : QStringLiteral("inbox");
        const QString cell = row + QLatin1Char('|') + week;
        matrix.insert(cell, matrix.value(cell, 0).toInt() + 1);
    }
    return matrix;
}

QVariantMap buildSwimlaneMatrix(const QList<TaskEntry> &tasks,
                                const QString &laneAxis,
                                const QString &timeBucket,
                                const QDate &today)
{
    QStringList lanes;
    QStringList times;
    QSet<QString> laneSeen;
    QSet<QString> timeSeen;
    QVariantMap cells;

    for (const TaskEntry &task : tasks) {
        const QString lane = swimlaneLaneKey(task, laneAxis);
        const QString time = swimlaneTimeBucket(task, timeBucket, today);
        if (!laneSeen.contains(lane)) {
            laneSeen.insert(lane);
            lanes.append(lane);
        }
        if (!timeSeen.contains(time)) {
            timeSeen.insert(time);
            times.append(time);
        }
        const QString key = lane + QLatin1Char('|') + time;
        QVariantList ids = cells.value(key).toList();
        ids.append(task.itemId);
        cells.insert(key, ids);
    }

    std::sort(lanes.begin(), lanes.end());
    std::sort(times.begin(), times.end(), [timeBucket](const QString &left, const QString &right) {
        if (left == QLatin1String("unscheduled")) {
            return false;
        }
        if (right == QLatin1String("unscheduled")) {
            return true;
        }
        return left < right;
    });

    QVariantMap result;
    result.insert(QStringLiteral("lanes"), lanes);
    result.insert(QStringLiteral("times"), times);
    result.insert(QStringLiteral("cells"), cells);
    return result;
}

QVariantMap buildPlanMatrixGrid(const QList<TaskEntry> &tasks, const QDate &today)
{
    QStringList projects;
    QStringList weeks;
    QSet<QString> projectSeen;
    QSet<QString> weekSeen;
    QVariantMap counts;
    QVariantMap taskIds;

    for (const TaskEntry &task : tasks) {
        if (task.completed) {
            continue;
        }
        const QString week = planWeekKey(task, today);
        if (week.isEmpty()) {
            continue;
        }
        const QString project = task.collectionId >= 0 ? QString::number(task.collectionId) : QStringLiteral("inbox");
        if (!projectSeen.contains(project)) {
            projectSeen.insert(project);
            projects.append(project);
        }
        if (!weekSeen.contains(week)) {
            weekSeen.insert(week);
            weeks.append(week);
        }
        const QString key = project + QLatin1Char('|') + week;
        counts.insert(key, counts.value(key, 0).toInt() + 1);
        QVariantList ids = taskIds.value(key).toList();
        ids.append(task.itemId);
        taskIds.insert(key, ids);
    }

    std::sort(projects.begin(), projects.end(), [](const QString &left, const QString &right) {
        if (left == QLatin1String("inbox")) {
            return true;
        }
        if (right == QLatin1String("inbox")) {
            return false;
        }
        return left.toLongLong() < right.toLongLong();
    });
    std::sort(weeks.begin(), weeks.end());

    QVariantMap result;
    result.insert(QStringLiteral("projects"), projects);
    result.insert(QStringLiteral("weeks"), weeks);
    result.insert(QStringLiteral("counts"), counts);
    result.insert(QStringLiteral("taskIds"), taskIds);
    return result;
}

QString swimlaneLaneLabel(const QString &key, const QString &laneAxis)
{
    if (laneAxis == QLatin1String("label")) {
        return key == QLatin1String("none") ? QStringLiteral("No label") : key;
    }
    if (laneAxis == QLatin1String("priority")) {
        if (key == QString::number(PriorityBand::High)) {
            return QStringLiteral("High");
        }
        if (key == QString::number(PriorityBand::Medium)) {
            return QStringLiteral("Medium");
        }
        if (key == QString::number(PriorityBand::Low)) {
            return QStringLiteral("Low");
        }
        return QStringLiteral("None");
    }
    if (laneAxis == QLatin1String("parent")) {
        return key;
    }
    if (key == QLatin1String("inbox")) {
        return QStringLiteral("Inbox");
    }
    return key;
}

QString swimlaneTimeLabel(const QString &key, const QString &timeBucket)
{
    if (key == QLatin1String("unscheduled")) {
        return QStringLiteral("Unscheduled");
    }
    if (timeBucket == QLatin1String("day")) {
        return key;
    }
    return key;
}

QStringList busyDayKeys(const QList<TaskEntry> &tasks, const QDate &today)
{
    QSet<QString> days;
    for (const TaskEntry &task : tasks) {
        if (task.completed) {
            continue;
        }
        QDate anchor;
        if (task.dueDate.isValid()) {
            anchor = task.dueDate.date();
        } else if (task.startDate.isValid()) {
            anchor = task.startDate.date();
        } else {
            continue;
        }
        if (anchor >= today.addDays(-7) && anchor <= today.addDays(14)) {
            days.insert(anchor.toString(Qt::ISODate));
        }
    }
    QStringList result = QStringList(days.begin(), days.end());
    std::sort(result.begin(), result.end());
    return result;
}

} // namespace TaskLogic
