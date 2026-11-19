#pragma once

#include "sharedtasks.h"
#include "taskstore.h"

#include <KCalendarCore/Todo>

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

/**
 * The write path of one controller: hands each write of a task to the store,
 * keeps the optimistic state of the shared entry (syncing, inflight, queue,
 * rollback) and settles conflicts.
 *
 *   controller ── persist / submit ──> TaskWriter ── submit / fetch ──> store
 *        ▲                                │  ▲                            │
 *        └── finished (create, delete) ───┘  └──────── finished ──────────┘
 *
 * A conflict refetches the task and merges the user's edit into the server's
 * version (three-way: last acknowledged, user, server). Fields both sides
 * changed go to the user (mergeConflictAvailable); otherwise the edit is
 * submitted again on the fresh revision.
 */
class TaskWriter : public QObject
{
    Q_OBJECT

public:
    enum class SyncResult { Error, Ok };
    using Online = std::function<bool()>;

    TaskWriter(SharedTasks &shared, Online online, QObject *parent);

    AbstractTaskStore *store() const { return m_store; }
    /// Swaps the store (tests, demo); takes ownership of one without parent.
    void setStore(AbstractTaskStore *store);

    /// Writes `todo` as the new state of `item`; queued while a write is in flight.
    void persist(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId = -1);
    /// A create, move or delete; its entry is prepared by the caller.
    void submit(const AbstractTaskStore::Request &request);
    /// Settles the entry after a store result (or a failed delete).
    void finishSync(qint64 itemId, SyncResult ok, const QString &errorString = {}, const Akonadi::Item &ackedItem = {});

    /// Fetches the task again, applies it and clears its conflict.
    void reload(qint64 itemId);
    void dismissConflict();
    void resolveMergeConflict(const QVariantMap &resolution);
    /// Debug: shows the merge dialog for the first task with made-up changes.
    void simulateMergeConflict();

    qint64 conflictItemId() const { return m_conflictItemId; }
    QVariantList mergeFields() const { return m_pendingMergeFields; }

Q_SIGNALS:
    void error(const QString &message);
    void conflictItemIdChanged();
    void mergeConflictAvailable(QVariantList fields, qint64 itemId);
    /// A write finished while others of the same task are still in flight.
    void inflightChanged();
    /// Results of creates and deletes; the controller settles those (undo).
    void finished(const AbstractTaskStore::Result &result);

private:
    void onStoreFinished(const AbstractTaskStore::Result &result);
    void submitModify(SharedTasks::Entry &cached, qint64 moveToCollectionId);
    void autoResolveConflict(qint64 itemId);
    void applyFresh(qint64 itemId, const Akonadi::Item &freshItem, const KCalendarCore::Todo::Ptr &desiredTodo);
    void rollBack(SharedTasks::Entry &cached, qint64 itemId, const QString &errorString, bool isConflict);
    void setConflict(qint64 itemId);
    void clearPendingMerge();

    SharedTasks &m_shared;
    Online m_online;
    AbstractTaskStore *m_store = nullptr;
    qint64 m_conflictItemId = -1;
    qint64 m_pendingMergeItemId = -1;
    QVariantList m_pendingMergeFields;
    KCalendarCore::Todo::Ptr m_pendingMergeFreshTodo;
};
