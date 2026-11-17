#pragma once

#include <Akonadi/Item>

/**
 * What an Akonadi item is, read from what was fetched (no jobs here).
 *
 * Task lists are often whole calendars: of 7506 items in two lists, 529 were tasks.
 * Loading fetches headers first (id and MIME type, no payload), then the tasks only:
 *
 *   collection ──headers──> todos(headers) ──full payload──> tasks
 */
namespace AkonadiItems
{
/// A task (VTODO). The MIME type decides when it is set, so an event is never parsed.
bool isTodo(const Akonadi::Item &item);

/// The tasks among fetched headers, as bare ids for the payload fetch.
Akonadi::Item::List todos(const Akonadi::Item::List &headers);
}
