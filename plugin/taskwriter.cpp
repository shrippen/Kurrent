#include "taskwriter.h"

#include "akonadiloader.h"
#include "akonadiutil.h"
#include "akonaditaskstore.h"

#include <KLocalizedString>

#include <QHash>

namespace
{
const QString kChoiceUser = QStringLiteral("user");
const QString kChoiceEdit = QStringLiteral("edit");

QString storeKindName(AbstractTaskStore::Kind kind)
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

// A store error that means "someone else changed the item since your revision".
bool isConflictError(const QString &errorString)
{
    return errorString.contains(QLatin1String("conflict"), Qt::CaseInsensitive)
           || errorString.contains(QLatin1String("Concurrent"), Qt::CaseInsensitive);
}

QVariant dateOrNull(bool has, const QDateTime &value)
{
    return has ? QVariant(value) : QVariant();
}

// Fields both the user and the server changed away from base, e.g. priority 5 → 1 (user), 5 → 9 (server).
QVariantList computeMergeDiff(const KCalendarCore::Todo::Ptr &base,
                              const KCalendarCore::Todo::Ptr &user,
                              const KCalendarCore::Todo::Ptr &server)
{
    QVariantList conflicts;
    if (!base || !user || !server) {
        return conflicts;
    }

    auto addIfConflict = [&](const QString &key, const QString &label,
                             const QVariant &baseVal, const QVariant &userVal, const QVariant &serverVal) {
        if (userVal == baseVal || serverVal == baseVal) {
            return;
        }
        QVariantMap m;
        m[QStringLiteral("key")] = key;
        m[QStringLiteral("label")] = label;
        m[QStringLiteral("userValue")] = userVal;
        m[QStringLiteral("serverValue")] = serverVal;
        m[QStringLiteral("baseValue")] = baseVal;
        conflicts.append(m);
    };
    const QString comma = QStringLiteral(",");

    addIfConflict(QStringLiteral("summary"), i18n("Summary"), base->summary(), user->summary(), server->summary());
    addIfConflict(QStringLiteral("description"), i18n("Description"),
                  base->description(), user->description(), server->description());
    addIfConflict(QStringLiteral("priority"), i18n("Priority"), base->priority(), user->priority(), server->priority());
    addIfConflict(QStringLiteral("percentComplete"), i18n("Progress"),
                  base->percentComplete(), user->percentComplete(), server->percentComplete());
    addIfConflict(QStringLiteral("categories"), i18n("Labels"), base->categories().join(comma),
                  user->categories().join(comma), server->categories().join(comma));
    addIfConflict(QStringLiteral("location"), i18n("Location"), base->location(), user->location(), server->location());
    addIfConflict(QStringLiteral("dueDate"), i18n("Due date"), dateOrNull(base->hasDueDate(), base->dtDue()),
                  dateOrNull(user->hasDueDate(), user->dtDue()), dateOrNull(server->hasDueDate(), server->dtDue()));
    addIfConflict(QStringLiteral("startDate"), i18n("Start date"),
                  dateOrNull(base->hasStartDate(), base->dtStart()),
                  dateOrNull(user->hasStartDate(), user->dtStart()),
                  dateOrNull(server->hasStartDate(), server->dtStart()));
    return conflicts;
}

// Writes the user's value of one merge field into `merged`, by key.
void applyUserValue(const KCalendarCore::Todo::Ptr &merged, const QString &key, const QVariant &uv)
{
    using Setter = std::function<void(const KCalendarCore::Todo::Ptr &, const QVariant &)>;
    static const QHash<QString, Setter> setters = {
        {QStringLiteral("summary"), [](const auto &t, const QVariant &v) { t->setSummary(v.toString()); }},
        {QStringLiteral("description"), [](const auto &t, const QVariant &v) { t->setDescription(v.toString()); }},
        {QStringLiteral("priority"), [](const auto &t, const QVariant &v) { t->setPriority(v.toInt()); }},
        {QStringLiteral("percentComplete"), [](const auto &t, const QVariant &v) { t->setPercentComplete(v.toInt()); }},
        {QStringLiteral("categories"),
         [](const auto &t, const QVariant &v) { t->setCategories(v.toString().split(QLatin1Char(','), Qt::SkipEmptyParts)); }},
        {QStringLiteral("location"), [](const auto &t, const QVariant &v) { t->setLocation(v.toString()); }},
        {QStringLiteral("dueDate"), [](const auto &t, const QVariant &v) { t->setDtDue(v.toDateTime()); }},
        {QStringLiteral("startDate"), [](const auto &t, const QVariant &v) { t->setDtStart(v.toDateTime()); }},
    };
    const auto setter = setters.constFind(key);
    if (setter != setters.cend()) {
        (*setter)(merged, uv);
    }
}

// The merge field `key` of `fields`; empty when the dialog did not offer it.
QVariantMap fieldOf(const QVariantList &fields, const QString &key)
{
    for (const QVariant &fv : fields) {
        const QVariantMap field = fv.toMap();
        if (field.value(QStringLiteral("key")).toString() == key) {
            return field;
        }
    }
    return {};
}
}

TaskWriter::TaskWriter(SharedTasks &shared, Online online, QObject *parent)
    : QObject(parent)
    , m_shared(shared)
    , m_online(std::move(online))
{
    // Akonadi jobs go through the store; MemoryTaskStore swaps in for unit tests.
    m_store = new AkonadiTaskStore(this);
    connect(m_store, &AbstractTaskStore::finished, this, &TaskWriter::onStoreFinished);
}

void TaskWriter::setStore(AbstractTaskStore *store)
{
    if (!store || store == m_store) {
        return;
    }

    disconnect(m_store, &AbstractTaskStore::finished, this, &TaskWriter::onStoreFinished);
    if (m_store && m_store->parent() == this) {
        m_store->deleteLater();
    }
    m_store = store;
    if (m_store->parent() == nullptr) {
        m_store->setParent(this);
    }
    connect(m_store, &AbstractTaskStore::finished, this, &TaskWriter::onStoreFinished);
}

void TaskWriter::submit(const AbstractTaskStore::Request &request)
{
    m_store->submit(request);
}

void TaskWriter::onStoreFinished(const AbstractTaskStore::Result &result)
{
    logAkonadi(QStringLiteral("storeFinished kind=%1 clientId=%2 ok=%3 collection=%4 rev=%5 error=%6")
                   .arg(storeKindName(result.kind))
                   .arg(result.clientId)
                   .arg(result.ok)
                   .arg(result.collectionId)
                   .arg(result.item.isValid() ? result.item.revision() : -1)
                   .arg(result.errorString));

    if (result.kind == AbstractTaskStore::Kind::Modify || result.kind == AbstractTaskStore::Kind::Move) {
        finishSync(result.clientId, result.ok ? SyncResult::Ok : SyncResult::Error, result.errorString, result.item);
        return;
    }
    Q_EMIT finished(result);
}

void TaskWriter::finishSync(qint64 itemId, SyncResult ok, const QString &errorString, const Akonadi::Item &ackedItem)
{
    auto it = m_shared.tasks().find(itemId);
    if (it == m_shared.tasks().end()) {
        if (ok == SyncResult::Error && !errorString.isEmpty()) {
            logAkonadi(QStringLiteral("finishSync: missing cache itemId=%1 error=%2").arg(itemId).arg(errorString));
            Q_EMIT error(errorString);
        }
        return;
    }

    it->inflight = qMax(0, it->inflight - 1);
    if (it->inflight > 0) {
        logAkonadi(QStringLiteral("finishSync: still inflight itemId=%1 remaining=%2 ok=%3 error=%4")
                       .arg(itemId)
                       .arg(it->inflight)
                       .arg(ok == SyncResult::Ok)
                       .arg(errorString));
        if (ok == SyncResult::Error && !errorString.isEmpty()) {
            Q_EMIT error(errorString);
        }
        Q_EMIT inflightChanged();
        return;
    }

    if (ok == SyncResult::Error) {
        logAkonadi(QStringLiteral("finishSync: ROLLBACK itemId=%1 rev=%2 collection=%3 queued=%4 error=%5")
                       .arg(itemId)
                       .arg(it->item.revision())
                       .arg(it->item.parentCollection().id())
                       .arg(it->persistQueued)
                       .arg(errorString));

        // A conflict is merged, not rolled back: before the rollback clears submittedTodo.
        const bool isConflict = isConflictError(errorString);
        if (isConflict && it->submittedTodo) {
            logAkonadi(QStringLiteral("finishSync: conflict detected on itemId=%1, auto-resolving").arg(itemId));
            autoResolveConflict(itemId);
            return;
        }
        rollBack(*it, itemId, errorString, isConflict ? Failure::Conflict : Failure::Error);
        return;
    }

    if (ackedItem.revision() > 0) {
        it->item.setRevision(ackedItem.revision());
    }
    if (ackedItem.parentCollection().id() > 0) {
        it->item.setParentCollection(ackedItem.parentCollection());
    }
    if (it->submittedTodo) {
        it->revertTodo = it->submittedTodo;
        it->revertCollectionId = it->item.parentCollection().id();
    }
    it->submittedTodo.clear();

    if (it->persistQueued) {
        const qint64 moveId = it->persistQueuedMoveId;
        logAkonadi(QStringLiteral("finishSync: flush queued persist itemId=%1 moveTo=%2").arg(itemId).arg(moveId));
        it->persistQueued = false;
        it->persistQueuedMoveId = -1;
        persist(it->item, it->todo, moveId);
        return;
    }

    it->revertTodo.clear();
    it->revertCollectionId = -1;
    it->syncing = false;
    it->inflight = 0;
    m_shared.notifyTasksChanged();
}

// Roll back the optimistic edit to the last acknowledged snapshot.
void TaskWriter::rollBack(SharedTasks::Entry &cached, qint64 itemId, const QString &errorString, Failure failure)
{
    if (cached.revertTodo) {
        cached.todo = cached.revertTodo;
        cached.item.setPayload<KCalendarCore::Todo::Ptr>(cached.todo);
        if (cached.revertCollectionId > 0) {
            cached.item.setParentCollection(Akonadi::Collection(cached.revertCollectionId));
        }
    }
    cached.pendingDelete = false;
    cached.persistQueued = false;
    cached.persistQueuedMoveId = -1;
    cached.submittedTodo.clear();
    if (!errorString.isEmpty()) {
        Q_EMIT error(errorString);
    }
    if (failure == Failure::Conflict) {
        setConflict(itemId);
    }
    cached.revertTodo.clear();
    cached.revertCollectionId = -1;
    cached.syncing = false;
    cached.inflight = 0;
    m_shared.notifyTasksChanged();
}

void TaskWriter::persist(const Akonadi::Item &item, const KCalendarCore::Todo::Ptr &todo, qint64 moveToCollectionId)
{
    const qint64 itemId = item.id();
    if (itemId < 0 || !todo) {
        logAkonadi(QStringLiteral("persistTodo: skip invalid itemId=%1 hasTodo=%2").arg(itemId).arg(bool(todo)));
        return;
    }

    auto it = m_shared.tasks().find(itemId);
    if (it == m_shared.tasks().end()) {
        logAkonadi(QStringLiteral("persistTodo: skip, not in cache itemId=%1 summary=%2").arg(itemId).arg(todo->summary()));
        return;
    }

    it->todo = todo;
    it->item.setPayload<KCalendarCore::Todo::Ptr>(todo);
    it->syncing = true;
    m_shared.notifyTasksChanged();

    const bool online = m_online();
    if (it->inflight > 0) {
        it->persistQueued = true;
        it->persistQueuedMoveId = moveToCollectionId;
        logAkonadi(QStringLiteral("persistTodo: QUEUE while inflight itemId=%1 inflight=%2 rev=%3 collection=%4 akonadi=%5 moveTo=%6 summary=%7")
                       .arg(itemId)
                       .arg(it->inflight)
                       .arg(it->item.revision())
                       .arg(it->item.parentCollection().id())
                       .arg(online)
                       .arg(moveToCollectionId)
                       .arg(todo->summary()));
        return;
    }

    if (!online) {
        logAkonadi(QStringLiteral("persistTodo: SUBMIT while Akonadi offline itemId=%1 rev=%2 collection=%3 summary=%4")
                       .arg(itemId).arg(it->item.revision())
                       .arg(it->item.parentCollection().id()).arg(todo->summary()));
    }

    // Revision 0 makes the DAV resource send a modify without If-Match ETag, which the
    // server rejects (412). Fetch the item first for its real revision.
    if (online && it->item.revision() == 0) {
        logAkonadi(QStringLiteral("persistTodo: revision=0 for itemId=%1, refetching before submit").arg(itemId));
        m_store->fetch(it->item, this,
                       [this, itemId, todo, moveToCollectionId](const Akonadi::Item &freshItem, const QString &error) {
            auto fresh = m_shared.tasks().find(itemId);
            if (fresh == m_shared.tasks().end()) {
                return;
            }
            // A failed fetch submits anyway; a conflict is settled by autoResolveConflict.
            if (error.isEmpty()) {
                fresh->item = freshItem;
                fresh->item.setPayload<KCalendarCore::Todo::Ptr>(todo);
                logAkonadi(QStringLiteral("persistTodo: refetched itemId=%1, now rev=%2").arg(itemId).arg(freshItem.revision()));
            }
            submitModify(*fresh, moveToCollectionId);
        });
        return;
    }

    submitModify(*it, moveToCollectionId);
}

void TaskWriter::submitModify(SharedTasks::Entry &cached, qint64 moveToCollectionId)
{
    KCalendarCore::Todo::Ptr snapshot = cloneTodo(cached.todo);
    cached.submittedTodo = snapshot;
    cached.syncing = true;
    cached.inflight = 1;
    cached.persistQueued = false;

    Akonadi::Item modifiedItem = cached.item;
    modifiedItem.setPayload<KCalendarCore::Todo::Ptr>(snapshot);

    logAkonadi(QStringLiteral("submitModify itemId=%1 rev=%2 collection=%3 moveTo=%4 akonadi=%5 summary=%6")
                   .arg(cached.item.id())
                   .arg(modifiedItem.revision())
                   .arg(modifiedItem.parentCollection().id())
                   .arg(moveToCollectionId)
                   .arg(m_online())
                   .arg(snapshot ? snapshot->summary() : QString()));

    AbstractTaskStore::Request req;
    req.kind = AbstractTaskStore::Kind::Modify;
    req.clientId = cached.item.id();
    req.item = modifiedItem;
    req.moveAfterModifyId = moveToCollectionId;
    m_store->submit(req);
}

void TaskWriter::autoResolveConflict(qint64 itemId)
{
    auto it = m_shared.tasks().find(itemId);
    if (it == m_shared.tasks().end()) {
        return;
    }

    if (!it->submittedTodo) {
        logAkonadi(QStringLiteral("autoResolveConflict: no submittedTodo for itemId=%1, surfacing error").arg(itemId));
        it->syncing = false;
        it->inflight = 0;
        setConflict(itemId);
        m_shared.notifyTasksChanged();
        return;
    }

    // The user's desired state, reapplied on the fresh item.
    const KCalendarCore::Todo::Ptr desiredTodo = cloneTodo(it->submittedTodo);
    logAkonadi(QStringLiteral("autoResolveConflict: refetching itemId=%1 to reapply changes").arg(itemId));

    m_store->fetch(Akonadi::Item(itemId), this,
                   [this, itemId, desiredTodo](const Akonadi::Item &freshItem, const QString &error) {
        if (error.isEmpty()) {
            applyFresh(itemId, freshItem, desiredTodo);
            return;
        }

        logAkonadi(QStringLiteral("autoResolveConflict: refetch failed for itemId=%1, surfacing error").arg(itemId));
        auto failed = m_shared.tasks().find(itemId);
        if (failed != m_shared.tasks().end()) {
            failed->submittedTodo.clear();
            failed->syncing = false;
            failed->inflight = 0;
            failed->revertTodo.clear();
            failed->revertCollectionId = -1;
        }
        setConflict(itemId);
        m_shared.notifyTasksChanged();
    });
}

// Three-way merge of a conflict: base (last acknowledged), user (desired), server (fresh).
void TaskWriter::applyFresh(qint64 itemId, const Akonadi::Item &freshItem, const KCalendarCore::Todo::Ptr &desiredTodo)
{
    auto it = m_shared.tasks().find(itemId);
    if (it == m_shared.tasks().end()) {
        return;
    }

    const KCalendarCore::Todo::Ptr freshTodo = todoFromPayload(freshItem);
    it->item = freshItem;
    if (freshTodo) {
        it->todo = freshTodo;
    }
    it->revertCollectionId = freshItem.parentCollection().id();

    const KCalendarCore::Todo::Ptr baseTodo = it->revertTodo ? it->revertTodo : freshTodo;
    const QVariantList conflicts = computeMergeDiff(baseTodo, desiredTodo, freshTodo);
    if (!conflicts.isEmpty()) {
        logAkonadi(QStringLiteral("autoResolveConflict: %1 conflicts for itemId=%2, showing dialog")
                       .arg(conflicts.size()).arg(itemId));
        m_pendingMergeItemId = itemId;
        m_pendingMergeFields = conflicts;
        m_pendingMergeFreshTodo = freshTodo;
        setConflict(itemId);
        Q_EMIT mergeConflictAvailable(conflicts, itemId);
        return;
    }

    logAkonadi(QStringLiteral("autoResolveConflict: no field conflicts, auto-applying itemId=%1 with fresh rev=%2")
                   .arg(itemId).arg(freshItem.revision()));
    it->todo = desiredTodo;
    it->item.setPayload<KCalendarCore::Todo::Ptr>(desiredTodo);
    it->revertTodo = freshTodo ? cloneTodo(freshTodo) : KCalendarCore::Todo::Ptr();

    const qint64 moveId = it->persistQueuedMoveId;
    it->persistQueuedMoveId = -1;
    submitModify(*it, moveId);
}

void TaskWriter::resolveMergeConflict(const QVariantMap &resolution)
{
    const qint64 itemId = m_pendingMergeItemId;
    if (itemId < 0 || !m_pendingMergeFreshTodo) {
        return;
    }

    auto it = m_shared.tasks().find(itemId);
    if (it == m_shared.tasks().end()) {
        clearPendingMerge();
        return;
    }

    logAkonadi(QStringLiteral("resolveMergeConflict: applying resolution for itemId=%1 fields=%2")
                   .arg(itemId).arg(resolution.size()));

    // Start from the server's version; "server" keeps its value, "user" takes the user's.
    KCalendarCore::Todo::Ptr merged(new KCalendarCore::Todo(*m_pendingMergeFreshTodo));
    bool needsEditor = false;
    for (auto choice = resolution.constBegin(); choice != resolution.constEnd(); ++choice) {
        const QString value = choice.value().toString();
        if (value == kChoiceEdit) {
            needsEditor = true;
            continue;
        }
        const QVariantMap field = fieldOf(m_pendingMergeFields, choice.key());
        if (value == kChoiceUser && !field.isEmpty()) {
            applyUserValue(merged, choice.key(), field.value(QStringLiteral("userValue")));
        }
    }

    it->todo = merged;
    it->item.setPayload<KCalendarCore::Todo::Ptr>(merged);
    it->revertTodo = cloneTodo(m_pendingMergeFreshTodo);
    it->revertCollectionId = it->item.parentCollection().id();
    clearPendingMerge();
    m_conflictItemId = -1;
    Q_EMIT conflictItemIdChanged();

    // "edit" leaves the merged state to the editor, unsubmitted.
    if (needsEditor) {
        m_shared.notifyTasksChanged();
        return;
    }

    it->submittedTodo = cloneTodo(merged);
    it->syncing = true;
    submitModify(*it, -1);
}

void TaskWriter::simulateMergeConflict()
{
    if (m_shared.tasks().isEmpty()) {
        logAkonadi(QStringLiteral("testMergeConflict: no tasks in cache"));
        return;
    }
    auto it = m_shared.tasks().constBegin();
    const qint64 itemId = it.key();
    if (!it->todo) {
        return;
    }

    auto baseTodo = cloneTodo(it->todo);
    auto userTodo = cloneTodo(it->todo);
    auto serverTodo = cloneTodo(it->todo);
    userTodo->setSummary(baseTodo->summary() + QStringLiteral(" (edited)"));
    serverTodo->setSummary(baseTodo->summary() + QStringLiteral(" (changed)"));
    userTodo->setPriority(1);
    serverTodo->setPriority(9);

    m_pendingMergeItemId = itemId;
    m_pendingMergeFreshTodo = serverTodo;
    m_pendingMergeFields = computeMergeDiff(baseTodo, userTodo, serverTodo);
    logAkonadi(QStringLiteral("testMergeConflict: showing %1 conflicting fields for itemId=%2")
                   .arg(m_pendingMergeFields.size()).arg(itemId));
    Q_EMIT mergeConflictAvailable(m_pendingMergeFields, itemId);
}

void TaskWriter::reload(qint64 itemId)
{
    const auto it = m_shared.tasks().constFind(itemId);
    if (it == m_shared.tasks().cend()) {
        return;
    }
    m_store->fetch(it->item, this, [this, itemId](const Akonadi::Item &fresh, const QString &error) {
        if (!error.isEmpty()) {
            return;
        }
        AkonadiLoader::instance().applyItem(fresh);
        m_shared.notifyTasksChanged();
        if (m_conflictItemId == itemId) {
            m_conflictItemId = -1;
            Q_EMIT conflictItemIdChanged();
        }
    });
}

void TaskWriter::dismissConflict()
{
    if (m_conflictItemId < 0) {
        return;
    }
    m_conflictItemId = -1;
    Q_EMIT conflictItemIdChanged();
}

void TaskWriter::setConflict(qint64 itemId)
{
    m_conflictItemId = itemId;
    Q_EMIT conflictItemIdChanged();
}

void TaskWriter::clearPendingMerge()
{
    m_pendingMergeItemId = -1;
    m_pendingMergeFields.clear();
    m_pendingMergeFreshTodo.clear();
}
