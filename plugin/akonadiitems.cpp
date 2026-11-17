#include "akonadiitems.h"

#include <KCalendarCore/Todo>

namespace AkonadiItems
{
bool isTodo(const Akonadi::Item &item)
{
    // Only an item without a type is asked for its payload (parsing the iCalendar text).
    if (!item.mimeType().isEmpty()) {
        return item.mimeType() == QLatin1String(KCalendarCore::Todo::todoMimeType());
    }
    return item.hasPayload<KCalendarCore::Todo::Ptr>();
}

Akonadi::Item::List todos(const Akonadi::Item::List &headers)
{
    Akonadi::Item::List result;
    for (const Akonadi::Item &header : headers) {
        if (!isTodo(header)) {
            continue;
        }
        result.append(Akonadi::Item(header.id()));
    }
    return result;
}
}
