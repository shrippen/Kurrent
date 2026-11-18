#pragma once

#include "kurrentlogging.h"

#include <Akonadi/Item>
#include <Akonadi/ItemFetchJob>
#include <Akonadi/ItemFetchScope>

#include <KCalendarCore/Todo>

// Small helpers for code that reads Akonadi items: the controller and the loader.

inline void logAkonadi(const QString &message)
{
    KurrentLogging::info(message);
}

inline KCalendarCore::Todo::Ptr todoFromPayload(const Akonadi::Item &item)
{
    if (!item.hasPayload<KCalendarCore::Todo::Ptr>()) {
        return {};
    }
    return item.payload<KCalendarCore::Todo::Ptr>();
}

inline KCalendarCore::Todo::Ptr cloneTodo(const KCalendarCore::Todo::Ptr &todo)
{
    if (!todo) {
        return {};
    }
    return KCalendarCore::Todo::Ptr(static_cast<KCalendarCore::Todo *>(todo->clone()));
}

inline void configureItemFetchJob(Akonadi::ItemFetchJob *job)
{
    auto scope = job->fetchScope();
    scope.fetchFullPayload();
    scope.fetchAllAttributes();
    scope.setFetchTags(true);
    // Never fetch ancestors: that issues FetchCollections per item.
    scope.setAncestorRetrieval(Akonadi::ItemFetchScope::None);
    job->setFetchScope(scope);
}
