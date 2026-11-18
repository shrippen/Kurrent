// The busy-event part of AkonadiLoader: events of the chosen calendars, for the Agenda
// and for reminder suppression. Own file to keep akonadiloader.cpp within the file limit.
#include "akonadiloader.h"

#include "akonadiutil.h"
#include "sharedtasks.h"
#include "tasklogic.h"

#include <Akonadi/ItemFetchJob>
#include <Akonadi/Monitor>

#include <KCalendarCore/Event>

#include <KJob>

void AkonadiLoader::setBusyCalendarIds(const QString &csv)
{
    if (m_busyCalendarIds == csv) {
        return;
    }
    m_busyCalendarIds = csv;
    scheduleRefreshBusyEvents();
}

QList<Akonadi::Collection> AkonadiLoader::busyEventCollections() const
{
    QList<Akonadi::Collection> result;
    result.reserve(m_shared.eventCollections().size());
    for (const Akonadi::Collection &collection : m_shared.eventCollections()) {
        if (TaskLogic::isEnabledCsv(m_busyCalendarIds, collection.id())) {
            result.append(collection);
        }
    }
    return result;
}

void AkonadiLoader::scheduleRefreshBusyEvents()
{
    if (!m_available) {
        return;
    }
    QTimer::singleShot(0, this, &AkonadiLoader::refreshBusyEvents);
}

// Timer tick, event change, tasks loaded: fetch only when an event changed or the day did.
// Before, every tick fetched all events of the busy calendars (7500 events: ~1 s each 5 min).
void AkonadiLoader::refreshBusyIfDue()
{
    if (!m_shared.busyRefreshDue(QDate::currentDate())) {
        return;
    }
    refreshBusyEvents();
}

// Headers only (no payload): a change just marks the busy events for the next fetch.
void AkonadiLoader::watchBusyEvents()
{
    m_eventMonitor = new Akonadi::Monitor(this);
    m_eventMonitor->setMimeTypeMonitored(QString::fromLatin1(KCalendarCore::Event::eventMimeType()));
    m_eventMonitor->fetchCollection(false);
    m_eventMonitor->fetchCollectionStatistics(false);

    auto changed = [this] {
        m_shared.markBusyChanged();
        m_busyChangeTimer.start();
    };
    connect(m_eventMonitor, &Akonadi::Monitor::itemAdded, this, changed);
    connect(m_eventMonitor, &Akonadi::Monitor::itemChanged, this, changed);
    connect(m_eventMonitor, &Akonadi::Monitor::itemRemoved, this, changed);
    connect(m_eventMonitor, &Akonadi::Monitor::itemMoved, this, changed);
}

void AkonadiLoader::refreshBusyEvents()
{
    // Busy events feed both reminder suppression and the Agenda view,
    // so they are fetched whenever Akonadi is available.
    if (!m_available) {
        m_shared.setBusyIntervals({});
        return;
    }

    const QList<Akonadi::Collection> collections = busyEventCollections();
    if (collections.isEmpty()) {
        m_shared.setBusyIntervals({});
        return;
    }

    if (m_pendingBusyFetchJobs > 0) {
        return;
    }

    const QDateTime now = QDateTime::currentDateTime();
    // Wide enough for agenda week navigation and heatmap click-through.
    const QDateTime rangeStart = now.addDays(-35);
    const QDateTime rangeEnd = now.addDays(70);

    // Changes from now on make the next tick fetch again.
    m_shared.markBusyFetched(now.date());
    m_busyFetchIntervals.clear();
    m_pendingBusyFetchJobs = collections.size();

    for (const Akonadi::Collection &collection : collections) {
        auto *job = new Akonadi::ItemFetchJob(collection, this);
        configureItemFetchJob(job);
        connect(job, &Akonadi::ItemFetchJob::result, this, [this, rangeStart, rangeEnd](KJob *kjob) {
            onBusyEventsFetched(kjob, rangeStart, rangeEnd);
        });
    }
}

void AkonadiLoader::onBusyEventsFetched(KJob *job, const QDateTime &rangeStart, const QDateTime &rangeEnd)
{
    --m_pendingBusyFetchJobs;

    if (job->error()) {
        m_shared.markBusyChanged();
    }
    if (auto *fetchJob = qobject_cast<Akonadi::ItemFetchJob *>(job)) {
        if (!job->error()) {
            for (const Akonadi::Item &item : fetchJob->items()) {
                if (item.mimeType() != QLatin1String(KCalendarCore::Event::eventMimeType())
                    && !item.hasPayload<KCalendarCore::Event::Ptr>()) {
                    continue;
                }
                if (!item.hasPayload<KCalendarCore::Event::Ptr>()) {
                    continue;
                }
                const KCalendarCore::Event::Ptr event = item.payload<KCalendarCore::Event::Ptr>();
                const int before = m_busyFetchIntervals.size();
                TaskCalendar::appendBusyIntervals(event, rangeStart, rangeEnd, &m_busyFetchIntervals);
                for (int i = before; i < m_busyFetchIntervals.size(); ++i) {
                    m_busyFetchIntervals[i].collectionId = item.parentCollection().id();
                }
            }
        }
    }

    if (m_pendingBusyFetchJobs > 0) {
        return;
    }

    m_pendingBusyFetchJobs = 0;
    m_shared.setBusyIntervals(m_busyFetchIntervals);
    m_busyFetchIntervals.clear();
}
