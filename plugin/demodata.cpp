#include "demodata.h"

#include <QDate>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QTimeZone>

namespace
{
constexpr qint64 kCollectionBase = 9001;

QJsonObject world()
{
    QFile file(QString::fromLocal8Bit(qgetenv("KURRENT_DEMO_WORLD")));
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QJsonDocument::fromJson(file.readAll()).object();
}

QString text(const QJsonValue &value, const QString &lang)
{
    if (value.isObject()) {
        const QJsonObject o = value.toObject();
        return o.value(lang).toString(o.value(QStringLiteral("en")).toString());
    }
    return value.toString();
}

QDate anchor()
{
    QDate today = QDate::fromString(QString::fromLocal8Bit(qgetenv("DEMO_TODAY")), Qt::ISODate);
    if (!today.isValid()) {
        today = QDate::currentDate();
    }
    return today.addDays(1 - today.dayOfWeek());
}
}

namespace DemoData
{
QString language()
{
    const QString value = QString::fromLocal8Bit(qgetenv("KURRENT_DEMO")).trimmed().toLower();
    if (value.isEmpty() || value == QLatin1String("0") || value == QLatin1String("false")) {
        return {};
    }
    if (value == QLatin1String("de") || value == QLatin1String("en")) {
        return value;
    }
    return QLocale().language() == QLocale::German ? QStringLiteral("de") : QStringLiteral("en");
}

bool enabled()
{
    return !language().isEmpty();
}

QString projectColorsJson()
{
    QJsonObject colors;
    const QJsonArray collections = world().value(QStringLiteral("tasks")).toObject().value(QStringLiteral("collections")).toArray();
    for (int i = 0; i < collections.size(); ++i) {
        colors.insert(QString::number(kCollectionBase + i), collections.at(i).toObject().value(QStringLiteral("color")).toString());
    }
    return QString::fromUtf8(QJsonDocument(colors).toJson(QJsonDocument::Compact));
}

Data load()
{
    const QString lang = language();
    const QJsonObject tasks = world().value(QStringLiteral("tasks")).toObject();
    const QDate monday = anchor();
    Data data;
    data.monday = monday;

    QHash<QString, qint64> collectionIds;
    const QJsonArray collections = tasks.value(QStringLiteral("collections")).toArray();
    for (int i = 0; i < collections.size(); ++i) {
        const QJsonObject c = collections.at(i).toObject();
        Akonadi::Collection collection(kCollectionBase + i);
        collection.setName(text(c.value(QStringLiteral("name")), lang));
        collection.setContentMimeTypes({KCalendarCore::Todo::todoMimeType()});
        collection.setRights(Akonadi::Collection::AllRights);
        data.collections.append(collection);
        collectionIds.insert(c.value(QStringLiteral("id")).toString(), collection.id());
    }

    QHash<QString, QString> labels;
    for (const QJsonValue &l : tasks.value(QStringLiteral("labels")).toArray()) {
        labels.insert(l.toObject().value(QStringLiteral("id")).toString(), text(l.toObject().value(QStringLiteral("name")), lang));
    }

    const QTimeZone zone = QTimeZone::systemTimeZone();
    const QJsonArray items = tasks.value(QStringLiteral("items")).toArray();
    for (int i = 0; i < items.size(); ++i) {
        const QJsonObject t = items.at(i).toObject();
        KCalendarCore::Todo::Ptr todo(new KCalendarCore::Todo);
        todo->setUid(QStringLiteral("demo-%1").arg(t.value(QStringLiteral("uid")).toString()));
        todo->setSummary(text(t.value(QStringLiteral("summary")), lang));
        todo->setDescription(text(t.value(QStringLiteral("description")), lang));
        todo->setPriority(t.value(QStringLiteral("priority")).toInt());
        QStringList categories;
        for (const QJsonValue &l : t.value(QStringLiteral("labels")).toArray()) {
            categories.append(labels.value(l.toString()));
        }
        todo->setCategories(categories);
        if (t.contains(QStringLiteral("parent"))) {
            todo->setRelatedTo(QStringLiteral("demo-%1").arg(t.value(QStringLiteral("parent")).toString()));
        }
        if (t.contains(QStringLiteral("start"))) {
            todo->setDtStart(QDateTime(monday.addDays(t.value(QStringLiteral("start")).toInt()), QTime(0, 0), zone));
        }
        if (t.contains(QStringLiteral("due"))) {
            todo->setDtDue(QDateTime(monday.addDays(t.value(QStringLiteral("due")).toInt()), QTime(0, 0), zone), true);
            todo->setAllDay(true);
        }
        if (t.contains(QStringLiteral("percent"))) {
            todo->setPercentComplete(t.value(QStringLiteral("percent")).toInt());
        }
        if (t.contains(QStringLiteral("completed"))) {
            todo->setCompleted(QDateTime(monday.addDays(t.value(QStringLiteral("completed")).toInt()), QTime(17, 0), zone));
        }
        data.tasks.append({i + 1, collectionIds.value(t.value(QStringLiteral("collection")).toString()), todo});
    }

    for (const QJsonValue &value : tasks.value(QStringLiteral("events")).toArray()) {
        const QJsonObject e = value.toObject();
        const QDate day = monday.addDays(e.value(QStringLiteral("day")).toInt());
        TaskCalendar::BusyInterval interval;
        interval.start = QDateTime(day, QTime::fromString(e.value(QStringLiteral("start")).toString(), QStringLiteral("HH:mm")), zone);
        interval.end = QDateTime(day, QTime::fromString(e.value(QStringLiteral("end")).toString(), QStringLiteral("HH:mm")), zone);
        interval.summary = text(e.value(QStringLiteral("summary")), lang);
        interval.collectionId = collectionIds.value(e.value(QStringLiteral("collection")).toString());
        data.events.append(interval);
    }
    return data;
}
}
