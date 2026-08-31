#include <KLocalizedString>
#include <KPluginFactory>
#include <KPluginMetaData>
#include <KRunner/AbstractRunner>
#include <KRunner/RunnerSyntax>
#include <KRunner/RunnerContext>
#include <KRunner/QueryMatch>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QIcon>

class KurrentRunner : public KRunner::AbstractRunner
{
    Q_OBJECT

public:
    KurrentRunner(QObject *parent, const KPluginMetaData &metaData)
        : AbstractRunner(parent, metaData)
    {
        addSyntax(KRunner::RunnerSyntax(QStringLiteral("kurrent"), i18n("Open Kurrent")));
        addSyntax(KRunner::RunnerSyntax(QStringLiteral("task :q:"), i18n("Add or search tasks in Kurrent")));
        addSyntax(KRunner::RunnerSyntax(QStringLiteral("todo :q:"), i18n("Add or search todos in Kurrent")));
    }

    void match(KRunner::RunnerContext &context) override
    {
        const QString query = context.query().trimmed();
        if (query.isEmpty()) {
            return;
        }

        const QString lower = query.toLower();
        if (!lower.startsWith(QLatin1String("task"))
            && !lower.startsWith(QLatin1String("kurrent"))
            && !lower.startsWith(QLatin1String("todo"))) {
            return;
        }

        QList<KRunner::QueryMatch> matches;
        const QIcon icon = QIcon::fromTheme(QStringLiteral("kurrent"));

        auto addMatch = [&](const QString &id, const QString &text, const QString &details, const QString &dbusMethod, const QString &arg = {}) {
            KRunner::QueryMatch match(this);
            match.setId(id);
            match.setText(text);
            match.setSubtext(details);
            match.setIcon(icon);
            match.setData(QVariantList{dbusMethod, arg});
            match.setCategoryRelevance(KRunner::QueryMatch::CategoryRelevance::Highest);
            matches.append(match);
        };

        if (lower == QLatin1String("kurrent") || lower == QLatin1String("task") || lower == QLatin1String("todo")) {
            addMatch(QStringLiteral("show"), i18n("Open Kurrent"), i18n("Show the task widget"), QStringLiteral("show"));
        }

        const QStringList viewIds = {
            QStringLiteral("today"),
            QStringLiteral("inbox"),
            QStringLiteral("overdue"),
            QStringLiteral("tomorrow"),
            QStringLiteral("scheduled"),
        };
        for (const QString &viewId : viewIds) {
            if (lower == QStringLiteral("task ") + viewId || lower == QStringLiteral("kurrent ") + viewId) {
                addMatch(QStringLiteral("view-") + viewId,
                         i18n("Open %1", viewId),
                         i18n("Switch Kurrent to the %1 view", viewId),
                         QStringLiteral("openView"),
                         viewId);
            }
        }

        QString payload = query;
        if (lower.startsWith(QLatin1String("task "))) {
            payload = query.mid(5).trimmed();
        } else if (lower.startsWith(QLatin1String("todo "))) {
            payload = query.mid(5).trimmed();
        } else if (lower.startsWith(QLatin1String("kurrent "))) {
            payload = query.mid(8).trimmed();
        }

        if (!payload.isEmpty() && lower != QLatin1String("kurrent") && lower != QLatin1String("task") && lower != QLatin1String("todo")) {
            addMatch(QStringLiteral("search"),
                     i18n("Search tasks for “%1”", payload),
                     i18n("Open Kurrent with this search"),
                     QStringLiteral("searchAndShow"),
                     payload);
            addMatch(QStringLiteral("add"),
                     i18n("Add task “%1”", payload),
                     i18n("Create a new task in Kurrent"),
                     QStringLiteral("addTask"),
                     payload);
        }

        if (!matches.isEmpty()) {
            context.addMatches(matches);
        }
    }

    void run(const KRunner::RunnerContext &context, const KRunner::QueryMatch &match) override
    {
        Q_UNUSED(context)
        const QVariantList data = match.data().toList();
        if (data.isEmpty()) {
            return;
        }
        const QString method = data.at(0).toString();
        const QString arg = data.size() > 1 ? data.at(1).toString() : QString();

        QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.github.shrippen.Kurrent"),
                                                              QStringLiteral("/Kurrent"),
                                                              QStringLiteral("org.github.shrippen.Kurrent"),
                                                              method);
        if (!arg.isEmpty()) {
            message << arg;
        }
        QDBusConnection::sessionBus().call(message, QDBus::NoBlock);
    }
};

K_PLUGIN_CLASS_WITH_JSON(KurrentRunner, "kurrentrunner.json")

#include "kurrentrunner.moc"
