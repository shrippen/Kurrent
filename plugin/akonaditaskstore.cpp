#include "akonaditaskstore.h"

#include <Akonadi/ItemCreateJob>
#include <Akonadi/ItemDeleteJob>
#include <Akonadi/ItemModifyJob>
#include <Akonadi/ItemMoveJob>

#include <KJob>

AkonadiTaskStore::AkonadiTaskStore(QObject *parent)
    : AbstractTaskStore(parent)
{
}

void AkonadiTaskStore::submit(const Request &request)
{
    switch (request.kind) {
    case Kind::Modify:
        runModify(request);
        break;
    case Kind::Move:
        runMove(request);
        break;
    case Kind::Create:
        runCreate(request);
        break;
    case Kind::Delete:
        runDelete(request);
        break;
    }
}

void AkonadiTaskStore::emitResult(Result result)
{
    Q_EMIT finished(result);
}

void AkonadiTaskStore::runModify(const Request &request)
{
    const qint64 clientId = request.clientId;
    const qint64 moveAfter = request.moveAfterModifyId;
    auto *job = new Akonadi::ItemModifyJob(request.item, this);
    connect(job, &Akonadi::ItemModifyJob::result, this, [this, clientId, moveAfter](KJob *kjob) {
        if (kjob->error()) {
            Result r;
            r.kind = Kind::Modify;
            r.clientId = clientId;
            r.ok = false;
            r.errorString = kjob->errorString();
            emitResult(r);
            return;
        }

        if (moveAfter > 0) {
            Request moveReq;
            moveReq.kind = Kind::Move;
            moveReq.clientId = clientId;
            moveReq.item = Akonadi::Item(clientId);
            moveReq.collection = Akonadi::Collection(moveAfter);
            runMove(moveReq);
            return;
        }

        Result r;
        r.kind = Kind::Modify;
        r.clientId = clientId;
        r.ok = true;
        emitResult(r);
    });
}

void AkonadiTaskStore::runMove(const Request &request)
{
    const qint64 clientId = request.clientId;
    auto *job = new Akonadi::ItemMoveJob(request.item, request.collection, this);
    connect(job, &Akonadi::ItemMoveJob::result, this, [this, clientId](KJob *kjob) {
        Result r;
        r.kind = Kind::Move;
        r.clientId = clientId;
        r.ok = !kjob->error();
        r.errorString = kjob->errorString();
        emitResult(r);
    });
}

void AkonadiTaskStore::runCreate(const Request &request)
{
    const qint64 clientId = request.clientId;
    const qint64 collectionId = request.collection.id();
    auto *job = new Akonadi::ItemCreateJob(request.item, request.collection, this);
    connect(job, &Akonadi::ItemCreateJob::result, this, [this, clientId, collectionId](KJob *kjob) {
        Result r;
        r.kind = Kind::Create;
        r.clientId = clientId;
        r.collectionId = collectionId;
        auto *createJob = qobject_cast<Akonadi::ItemCreateJob *>(kjob);
        if (kjob->error() || !createJob) {
            r.ok = false;
            r.errorString = kjob->errorString();
            emitResult(r);
            return;
        }
        r.ok = true;
        r.item = createJob->item();
        emitResult(r);
    });
}

void AkonadiTaskStore::runDelete(const Request &request)
{
    const qint64 clientId = request.clientId;
    auto *job = new Akonadi::ItemDeleteJob(request.item, this);
    connect(job, &Akonadi::ItemDeleteJob::result, this, [this, clientId](KJob *kjob) {
        Result r;
        r.kind = Kind::Delete;
        r.clientId = clientId;
        r.ok = !kjob->error();
        r.errorString = kjob->errorString();
        emitResult(r);
    });
}
