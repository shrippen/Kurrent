#pragma once

#include "taskstore.h"

#include <QHash>

/**
 * In-memory backend for unit tests — no Akonadi server required.
 * Results are delivered asynchronously (queued) like real jobs.
 */
class MemoryTaskStore : public AbstractTaskStore
{
    Q_OBJECT

public:
    explicit MemoryTaskStore(QObject *parent = nullptr);

    void submit(const Request &request) override;
    void fetch(const Akonadi::Item &item, QObject *context, FetchDone done) override;

    int itemCount() const { return m_items.size(); }
    bool contains(qint64 id) const { return m_items.contains(id); }
    Akonadi::Item item(qint64 id) const { return m_items.value(id); }

    // Sync in-memory map without emitting finished (controller cache seed).
    void seedItem(const Akonadi::Item &item);

    // Force the next submit to fail (tests rollback paths).
    void failNext(const QString &message = QStringLiteral("forced failure"));

    // Force the next fetch to fail (tests the refetch paths).
    void failNextFetch(const QString &message = QStringLiteral("forced fetch failure"));

private:
    void deliver(const Result &result);

    QHash<qint64, Akonadi::Item> m_items;
    qint64 m_nextId = 1;
    bool m_failNext = false;
    QString m_failMessage;
    bool m_failNextFetch = false;
    QString m_failFetchMessage;
};
