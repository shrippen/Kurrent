#include "taskreminders.h"

#include "taskcalendar.h"
#include "tasklogic.h"

#include <KLocalizedString>

#ifdef KURRENT_HAS_NOTIFICATIONS
#include <KNotification>
#endif

#include <QLocale>

namespace {
constexpr int kScanIntervalMs = 30000;
// First scan: look this far back, so a reminder due just before start still fires.
constexpr int kFirstScanBackSecs = 45;
constexpr int kLastHour = 23;
}

TaskReminders::TaskReminders(SharedTasks &shared, Host host, QObject *parent)
    : QObject(parent)
    , m_shared(shared)
    , m_host(std::move(host))
{
    m_timer.setInterval(kScanIntervalMs);
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &TaskReminders::check);
    m_timer.start();
}

void TaskReminders::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
}

void TaskReminders::setDefaultMinutes(int minutes)
{
    const int bounded = (minutes < 0) ? -1 : minutes;
    if (m_defaultMinutes == bounded) {
        return;
    }
    m_defaultMinutes = bounded;
    Q_EMIT defaultMinutesChanged();
}

void TaskReminders::setQuietEnabled(bool enabled)
{
    if (m_quietEnabled == enabled) {
        return;
    }
    m_quietEnabled = enabled;
    Q_EMIT quietHoursChanged();
}

void TaskReminders::setQuietStart(int hour)
{
    const int bounded = qBound(0, hour, kLastHour);
    if (m_quietStart == bounded) {
        return;
    }
    m_quietStart = bounded;
    Q_EMIT quietHoursChanged();
}

void TaskReminders::setQuietEnd(int hour)
{
    const int bounded = qBound(0, hour, kLastHour);
    if (m_quietEnd == bounded) {
        return;
    }
    m_quietEnd = bounded;
    Q_EMIT quietHoursChanged();
}

void TaskReminders::setSuppressDuringEvents(bool enabled)
{
    if (m_suppressDuringEvents == enabled) {
        return;
    }
    m_suppressDuringEvents = enabled;
    Q_EMIT suppressDuringEventsChanged();
}

bool TaskReminders::inBusyEvent(const QDateTime &when) const
{
    if (!m_suppressDuringEvents || m_shared.busyIntervals().isEmpty()) {
        return false;
    }
    return TaskCalendar::isBusyAt(when, m_shared.busyIntervals());
}

void TaskReminders::check()
{
    if (!m_enabled || !m_host.available()) {
        return;
    }
    const QDateTime now = QDateTime::currentDateTime();
    if (TaskLogic::inQuietHours(now.time(), m_quietStart, m_quietEnd,
        m_quietEnabled ? TaskLogic::QuietHoursMode::Enabled : TaskLogic::QuietHoursMode::Disabled)) {
        return;
    }
    if (inBusyEvent(now)) {
        return;
    }
    const QDateTime from = m_lastScan.isValid() ? m_lastScan : now.addSecs(-kFirstScanBackSecs);
    for (auto it = m_shared.tasks().cbegin(); it != m_shared.tasks().cend(); ++it) {
        if (!it->todo || it->todo->isCompleted()) {
            continue;
        }
        const QDateTime when = TaskCalendar::nextReminderTime(it->todo, from);
        if (!TaskCalendar::isReminderDue(when, from, now, m_lastNotified.value(it.key()))) {
            continue;
        }
        m_lastNotified.insert(it.key(), when);
        notify(it.key(), it->todo->summary(), when);
    }
    m_lastScan = now;
}

bool TaskReminders::sendTest(const QString &title, const QString &text)
{
#ifdef KURRENT_HAS_NOTIFICATIONS
    auto *notification = new KNotification(QStringLiteral("taskReminder"), KNotification::CloseOnTimeout, this);
    notification->setTitle(title);
    notification->setText(text);
    notification->sendEvent();
    return true;
#else
    Q_UNUSED(title);
    Q_UNUSED(text);
    return false;
#endif
}

void TaskReminders::notify(qint64 itemId, const QString &summary, const QDateTime &when)
{
#ifdef KURRENT_HAS_NOTIFICATIONS
    auto *notification = new KNotification(QStringLiteral("taskReminder"), KNotification::CloseOnTimeout, this);
    notification->setTitle(summary.isEmpty() ? i18n("Task reminder") : summary);
    notification->setText(when.isValid() ? i18n("Due %1", QLocale().toString(when, QLocale::ShortFormat)) : i18n("A task is due."));
    KNotificationAction *snooze15 = notification->addAction(i18n("15 minutes"));
    KNotificationAction *snoozeHour = notification->addAction(i18n("1 hour"));
    KNotificationAction *snoozeTomorrow = notification->addAction(i18n("Tomorrow"));
    connect(snooze15, &KNotificationAction::activated, this, [this, itemId]() {
        m_host.snooze(itemId, QStringLiteral("15m"));
    });
    connect(snoozeHour, &KNotificationAction::activated, this, [this, itemId]() {
        m_host.snooze(itemId, QStringLiteral("1h"));
    });
    connect(snoozeTomorrow, &KNotificationAction::activated, this, [this, itemId]() {
        m_host.snooze(itemId, QStringLiteral("tomorrow"));
    });
    notification->sendEvent();
#else
    Q_UNUSED(itemId);
    Q_UNUSED(summary);
    Q_UNUSED(when);
#endif
}
