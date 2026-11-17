// What AkonadiItems reads from fetched items: which are tasks, without parsing the rest.

#include "akonadiitems.h"

#include <KCalendarCore/Event>
#include <KCalendarCore/Todo>

#include <QTest>

class AkonadiItemsTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void todoByMimeType();
    void eventIsNotParsedAsTodo();
    void todoWithoutMimeTypeByPayload();
    void todoIdsFromHeaders();
};

static const QString todoMime = QString::fromLatin1(KCalendarCore::Todo::todoMimeType());
static const QString eventMime = QString::fromLatin1(KCalendarCore::Event::eventMimeType());

// A fetched item: MIME type plus the raw iCalendar text, parsed only on request.
static Akonadi::Item fetched(const QString &mime, const QByteArray &ical)
{
    Akonadi::Item item(1);
    item.setMimeType(mime);
    item.setPayloadFromData(ical);
    return item;
}

static const QByteArray todoIcal = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VTODO\r\nUID:t1\r\nSUMMARY:Task\r\nEND:VTODO\r\nEND:VCALENDAR\r\n";

void AkonadiItemsTest::todoByMimeType()
{
    QVERIFY(AkonadiItems::isTodo(fetched(todoMime, todoIcal)));
}

// The MIME type decides, so an event is rejected without parsing its payload. Before,
// hasPayload<Todo>() came first: it parsed every item of a mixed calendar and took this
// event (whose text is a VTODO) for a task.
void AkonadiItemsTest::eventIsNotParsedAsTodo()
{
    QVERIFY(!AkonadiItems::isTodo(fetched(eventMime, todoIcal)));
}

void AkonadiItemsTest::todoWithoutMimeTypeByPayload()
{
    Akonadi::Item item(2);
    item.setPayload(KCalendarCore::Todo::Ptr(new KCalendarCore::Todo));
    QVERIFY(AkonadiItems::isTodo(item));
}

// Headers carry id and MIME type only: the second fetch asks for the tasks among them.
void AkonadiItemsTest::todoIdsFromHeaders()
{
    Akonadi::Item::List headers;
    for (int id = 1; id <= 6; ++id) {
        Akonadi::Item item(id);
        item.setMimeType(id % 3 == 0 ? todoMime : eventMime);
        headers.append(item);
    }
    const Akonadi::Item::List todos = AkonadiItems::todos(headers);
    QCOMPARE(todos.size(), 2);
    QCOMPARE(todos.at(0).id(), 3);
    QCOMPARE(todos.at(1).id(), 6);
}

QTEST_GUILESS_MAIN(AkonadiItemsTest)
#include "akonadiitems_test.moc"
