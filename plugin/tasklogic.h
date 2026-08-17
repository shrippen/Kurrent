#pragma once

#include "tasklistmodel.h"

#include <QDate>
#include <QHash>
#include <QList>
#include <QPointF>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantMap>

namespace TaskLogic
{

struct FilterState {
    QString currentView;
    QString searchQuery;
    bool showCompleted = false;
    qint64 selectedCollectionId = -1;
    QString selectedLabel;
    int selectedPriority = -1;
};

struct SidebarCounts {
    QVariantMap viewCounts;
    QVariantMap sidebarProjects;
    QVariantMap sidebarLabels;
    QVariantMap sidebarPriorities;
    QVariantMap totalLabels;
};

struct ProjectCandidate {
    qint64 id = -1;
    bool enabled = true;
    int taskCount = 0;
};

struct NewTaskTarget {
    bool ask = false;
    qint64 collectionId = -1;
};

int priorityBand(int priority);

bool matchesSearch(const TaskEntry &task, const QString &query);

bool matchesView(const TaskEntry &task, const QString &viewId, const QDate &today);

bool matchesFilters(const TaskEntry &task, qint64 selectedCollectionId, const QString &selectedLabel, int selectedPriority);

int compareTasks(const TaskEntry &left, const TaskEntry &right, const QString &sortMode);

bool wouldCreateParentCycle(const QString &draggedUid, const QString &newParentUid, const QHash<QString, QString> &parentByUid);

SidebarCounts computeCounts(const QList<TaskEntry> &tasks, const FilterState &filters, const QStringList &extraLabels, const QDate &today);

qint64 firstSidebarProjectId(const QList<ProjectCandidate> &projects, const QSet<qint64> &hiddenIds);

NewTaskTarget resolveNewTaskTarget(qint64 selectedCollectionId,
                                   const QString &mode,
                                   qint64 defaultCollectionId,
                                   bool defaultExists,
                                   qint64 firstEnabledId);

QPointF dragProxyGap(int cursorSize, bool arrowCursor);

QPointF clampDragProxyOffset(qreal cursorX,
                             qreal cursorY,
                             qreal gapX,
                             qreal gapY,
                             qreal width,
                             qreal height,
                             qreal limitRight,
                             qreal limitBottom);

struct VisibleFilterResult {
    QList<TaskEntry> tasks;
    int filteredOutCompleted = 0;
    int filteredOutView = 0;
    int filteredOutSearch = 0;
};

QList<TaskEntry> flattenTree(const QList<TaskEntry> &input, const QString &sortMode);

VisibleFilterResult filterVisibleTasks(const QList<TaskEntry> &tasks, const FilterState &filters, const QDate &today);

QHash<qint64, int> collectionTaskCounts(const QList<TaskEntry> &tasks);

int pendingRootCount(const QList<TaskEntry> &tasks);

QStringList collectAvailableLabels(const QList<TaskEntry> &tasks, const QStringList &extraLabels);

bool canCreateLabel(const QString &name, const QStringList &available, const QStringList &extraLabels);

QStringList addLabel(QStringList selected, const QString &name);

QStringList removeLabel(const QStringList &selected, const QString &name);

bool containsLabel(const QStringList &selected, const QString &name);

QStringList parseTokens(const QString &raw, const QString &separator);

QString joinTokens(const QStringList &tokens, const QString &separator);

QString toggleToken(const QString &raw, const QString &token, const QString &separator);

bool tokenSetContains(const QString &raw, const QString &token, const QString &separator);

QString toggleEnabledCsv(const QString &csv, qint64 id, const QList<qint64> &allIds);

bool isEnabledCsv(const QString &csv, qint64 id);

int visibleProjectCount(const QList<ProjectCandidate> &projects, const QSet<qint64> &hiddenIds);

int visibleLabelCount(const QStringList &labels, const QSet<QString> &hiddenLabels);

int naturalListHeight(int rowCount, bool hasHeader, int headerHeight, int rowHeight, int gap = 1);

QList<int> redistributeSections(int available, const QList<int> &mins);

QString viewIconSource(const QString &viewId);

int indexForValue(const QList<int> &values, int value);

int indexForString(const QStringList &values, const QString &value);

int normalizeStatus(int status);

int recurrenceIndexFor(const QString &preset);

QString recurrenceValueFor(int index);

QString priorityLabel(int priority);

int priorityToIndex(int priority);

int indexToPriority(int index);

int resolveCursorSize(int envValue, bool envOk, int configValue);

qreal pickLimitRight(qreal screenRight, qreal cppRight, qreal margin);

qreal pickLimitBottom(const QList<qreal> &candidates, qreal margin);

QString pad2(int n);

QString digitsOnly(const QString &str);

struct FormatToken {
    QString kind;
    QString text;
    int maxLen = 0;
};

QList<FormatToken> parseFormatTokens(const QString &fmt);

int maxDigitsFor(const QList<FormatToken> &tokens);

QString formatDigitsWithTokens(const QString &digits, const QList<FormatToken> &tokens);

struct TextSegment {
    QString kind;
    int start = 0;
    int end = 0;
    int maxLen = 0;
};

QList<TextSegment> computeSegments(const QString &text, const QList<FormatToken> &tokens);

TextSegment segmentAtPosition(const QString &text, const QList<FormatToken> &tokens, int pos);

QDate parseIsoDate(const QString &str);

bool parseHmsTime(const QString &str, int *hours, int *minutes);

} // namespace TaskLogic
