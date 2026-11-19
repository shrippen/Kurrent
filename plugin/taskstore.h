#pragma once

#include <Akonadi/Collection>
#include <Akonadi/Item>

#include <QMetaType>
#include <QObject>
#include <QString>

#include <functional>

/**
 * Persistence boundary for task CRUD.
 *
 * Optimistic UI + rollback live in TaskController (cache, inflight, revertTodo).
 * This layer only talks to a backend (Akonadi or in-memory for tests).
 *
 *   UI / TaskController                  AbstractTaskStore
 *   -------------------                  ------------------
 *   update cache, syncing=true    --->   submit(Request)
 *   finishSync / upsert / remove  <---   finished(Result)
 *   conflict, revision 0          --->   fetch(item, context, done)
 *   re-apply or surface           <---   done(item, error)
 *
 * The controller coalesces further edits while a job for that clientId is in
 * flight, then submits the latest payload after the job finishes.
 */
class AbstractTaskStore : public QObject
{
    Q_OBJECT

public:
    enum class Kind { Modify, Move, Create, Delete };

    struct Request {
        Kind kind = Kind::Modify;
        qint64 clientId = -1;
        Akonadi::Item item;
        Akonadi::Collection collection;
        qint64 moveAfterModifyId = -1;
    };

    struct Result {
        Kind kind = Kind::Modify;
        qint64 clientId = -1;
        bool ok = false;
        QString errorString;
        Akonadi::Item item;
        qint64 collectionId = -1;
    };

    explicit AbstractTaskStore(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    virtual void submit(const Request &request) = 0;

    /// Called with the current version of an item, or an error. Not called once
    /// `context` is destroyed.
    using FetchDone = std::function<void(const Akonadi::Item &item, const QString &error)>;

    /// Reads the current version of an item from the backend: after a conflict, or
    /// when the cached revision is unknown (0). Payload and attributes included.
    virtual void fetch(const Akonadi::Item &item, QObject *context, FetchDone done) = 0;

Q_SIGNALS:
    void finished(const AbstractTaskStore::Result &result);
};

Q_DECLARE_METATYPE(AbstractTaskStore::Result)
