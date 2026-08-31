#include "akonaditaskstore.h"
#include "kurrentlogging.h"

#include <Akonadi/ItemCreateJob>
#include <Akonadi/ItemDeleteJob>
#include <Akonadi/ItemModifyJob>
#include <Akonadi/ItemMoveJob>

#include <KJob>

namespace
{
QString jobKindName(AbstractTaskStore::Kind kind)
{
    switch (kind) {
    case AbstractTaskStore::Kind::Create:
        return QStringLiteral("Create");
    case AbstractTaskStore::Kind::Modify:
        return QStringLiteral("Modify");
    case AbstractTaskStore::Kind::Move:
        return QStringLiteral("Move");
    case AbstractTaskStore::Kind::Delete:
        return QStringLiteral("Delete");
    }
    return QStringLiteral("Unknown");
}
}

AkonadiTaskStore::AkonadiTaskStore(QObject *parent)
    : AbstractTaskStore(parent)
{
}

void AkonadiTaskStore::submit(const Request &request)
{
    KurrentLogging::info(QStringLiteral("AkonadiJob start kind=%1 clientId=%2 itemId=%3 rev=%4 collection=%5 moveAfter=%6")
                                 .arg(jobKindName(request.kind))
                                 .arg(request.clientId)
                                 .arg(request.item.id())
                                 .arg(request.item.revision())
                                 .arg(request.collection.isValid() ? request.collection.id()
                                                                   : request.item.parentCollection().id())
                                 .arg(request.moveAfterModifyId));
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
    connect(job, &Akonadi::ItemModifyJob::result, this, [this, clientId, moveAfter, job](KJob *kjob) {
        if (kjob->error()) {
            KurrentLogging::info(QStringLiteral("ItemModifyJob FAIL clientId=%1 error=%2 text=%3")
                                         .arg(clientId)
                                         .arg(kjob->error())
                                         .arg(kjob->errorString()));
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
            moveReq.item = job->item().isValid() ? job->item() : Akonadi::Item(clientId);
            moveReq.collection = Akonadi::Collection(moveAfter);
            runMove(moveReq);
            return;
        }

        Result r;
        r.kind = Kind::Modify;
        r.clientId = clientId;
        r.ok = true;
        r.item = job->item();
        emitResult(r);
    });
}

void AkonadiTaskStore::runMove(const Request &request)
{
    const qint64 clientId = request.clientId;
    auto *job = new Akonadi::ItemMoveJob(request.item, request.collection, this);
    connect(job, &Akonadi::ItemMoveJob::result, this, [this, clientId](KJob *kjob) {
        if (kjob->error()) {
            KurrentLogging::info(QStringLiteral("ItemMoveJob FAIL clientId=%1 error=%2 text=%3")
                                         .arg(clientId)
                                         .arg(kjob->error())
                                         .arg(kjob->errorString()));
        }
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
            KurrentLogging::info(QStringLiteral("ItemCreateJob FAIL clientId=%1 error=%2 text=%3")
                                         .arg(clientId)
                                         .arg(kjob->error())
                                         .arg(kjob->errorString()));
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
        if (kjob->error()) {
            KurrentLogging::info(QStringLiteral("ItemDeleteJob FAIL clientId=%1 error=%2 text=%3")
                                         .arg(clientId)
                                         .arg(kjob->error())
                                         .arg(kjob->errorString()));
        }
        Result r;
        r.kind = Kind::Delete;
        r.clientId = clientId;
        r.ok = !kjob->error();
        r.errorString = kjob->errorString();
        emitResult(r);
    });
}
