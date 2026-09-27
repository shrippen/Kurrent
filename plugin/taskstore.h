#pragma once

#include <Akonadi/Collection>
#include <Akonadi/Item>

#include <QMetaType>
#include <QObject>
#include <QString>

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

Q_SIGNALS:
    void finished(const AbstractTaskStore::Result &result);
};

Q_DECLARE_METATYPE(AbstractTaskStore::Result)
