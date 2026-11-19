#pragma once

#include "sharedtasks.h"

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QTimer>

#include <functional>

/**
 * The reminder topic of one controller: the notification settings, the timer that scans
 * the tasks for due reminders, and the notification with its snooze actions.
 *
 *   QML ── controller ──> TaskReminders ── reads ──> SharedTasks, TaskCalendar, TaskLogic
 *                              │
 *                              ├── Host.available ──> controller (is Akonadi reachable)
 *                              └── Host.snooze ─────> controller (a write, with undo)
 *
 * Without KNotifications at build time it sends nothing.
 */
class TaskReminders : public QObject
{
    Q_OBJECT

public:
    /// What the reminders ask of the controller.
    struct Host {
        std::function<bool()> available;
        std::function<void(qint64, const QString &)> snooze;
    };

    TaskReminders(SharedTasks &shared, Host host, QObject *parent);

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    int defaultMinutes() const { return m_defaultMinutes; }
    void setDefaultMinutes(int minutes);
    bool quietEnabled() const { return m_quietEnabled; }
    void setQuietEnabled(bool enabled);
    int quietStart() const { return m_quietStart; }
    void setQuietStart(int hour);
    int quietEnd() const { return m_quietEnd; }
    void setQuietEnd(int hour);
    bool suppressDuringEvents() const { return m_suppressDuringEvents; }
    void setSuppressDuringEvents(bool enabled);

    /// Settings "Send test notification"; false without KNotifications support.
    bool sendTest(const QString &title, const QString &text);

Q_SIGNALS:
    void enabledChanged();
    void defaultMinutesChanged();
    void quietHoursChanged();
    void suppressDuringEventsChanged();

private:
    void check();
    void notify(qint64 itemId, const QString &summary, const QDateTime &when);
    bool inBusyEvent(const QDateTime &when) const;

    SharedTasks &m_shared;
    Host m_host;
    QTimer m_timer;
    QDateTime m_lastScan;
    QHash<qint64, QDateTime> m_lastNotified;
    bool m_enabled = true;
    int m_defaultMinutes = -1;
    bool m_quietEnabled = false;
    int m_quietStart = 22;
    int m_quietEnd = 7;
    bool m_suppressDuringEvents = false;
};
