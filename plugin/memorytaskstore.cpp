#include "memorytaskstore.h"

#include <QMetaObject>

MemoryTaskStore::MemoryTaskStore(QObject *parent)
    : AbstractTaskStore(parent)
{
}

void MemoryTaskStore::failNext(const QString &message)
{
    m_failNext = true;
    m_failMessage = message;
}

void MemoryTaskStore::seedItem(const Akonadi::Item &item)
{
    if (item.id() <= 0) {
        return;
    }
    m_items.insert(item.id(), item);
    if (item.id() >= m_nextId) {
        m_nextId = item.id() + 1;
    }
}

void MemoryTaskStore::deliver(const Result &result)
{
    // Match Akonadi: reply after the current call stack (optimistic UI already updated).
    QMetaObject::invokeMethod(this, [this, result]() {
        Q_EMIT finished(result);
    }, Qt::QueuedConnection);
}

void MemoryTaskStore::submit(const Request &request)
{
    Result result;
    result.kind = request.kind;
    result.clientId = request.clientId;

    if (m_failNext) {
        m_failNext = false;
        result.ok = false;
        result.errorString = m_failMessage;
        deliver(result);
        return;
    }

    switch (request.kind) {
    case Kind::Create: {
        Akonadi::Item stored = request.item;
        stored.setId(m_nextId++);
        stored.setRevision(1);
        stored.setParentCollection(request.collection);
        m_items.insert(stored.id(), stored);
        result.ok = true;
        result.item = stored;
        result.collectionId = request.collection.id();
        break;
    }
    case Kind::Modify: {
        const qint64 id = request.item.id() > 0 ? request.item.id() : request.clientId;
        if (!m_items.contains(id)) {
            result.ok = false;
            result.errorString = QStringLiteral("item not found");
            break;
        }
        Akonadi::Item stored = request.item;
        stored.setId(id);
        stored.setRevision(m_items.value(id).revision() + 1);
        if (request.moveAfterModifyId > 0) {
            stored.setParentCollection(Akonadi::Collection(request.moveAfterModifyId));
        } else {
            stored.setParentCollection(m_items.value(id).parentCollection());
        }
        m_items.insert(id, stored);
        result.ok = true;
        result.item = stored;
        break;
    }
    case Kind::Move: {
        const qint64 id = request.item.id() > 0 ? request.item.id() : request.clientId;
        if (!m_items.contains(id)) {
            result.ok = false;
            result.errorString = QStringLiteral("item not found");
            break;
        }
        Akonadi::Item stored = m_items.value(id);
        stored.setParentCollection(request.collection);
        m_items.insert(id, stored);
        result.ok = true;
        result.item = stored;
        break;
    }
    case Kind::Delete: {
        const qint64 id = request.item.id() > 0 ? request.item.id() : request.clientId;
        if (!m_items.contains(id)) {
            result.ok = false;
            result.errorString = QStringLiteral("item not found");
            break;
        }
        m_items.remove(id);
        result.ok = true;
        break;
    }
    }

    deliver(result);
}
