#include "taskcontroller.h"
#include "tasklistmodel.h"
#include "collectionlistmodel.h"
#include "sharedsettings.h"

#include <QQmlEngine>
#include <QQmlExtensionPlugin>

class KurrentPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("com.github.shrippen.kurrent"));

        qmlRegisterSingletonType<SharedSettings>(uri, 1, 0, "SharedSettings",
            [](QQmlEngine *, QJSEngine *) -> QObject * {
                SharedSettings *settings = SharedSettings::instance();
                QQmlEngine::setObjectOwnership(settings, QQmlEngine::CppOwnership);
                return settings;
            });
        qmlRegisterType<TaskController>(uri, 1, 0, "TaskController");
        qmlRegisterUncreatableType<TaskListModel>(uri, 1, 0, "TaskListModel",
            QStringLiteral("TaskListModel is provided by TaskController"));
        qmlRegisterUncreatableType<CollectionListModel>(uri, 1, 0, "CollectionListModel",
            QStringLiteral("CollectionListModel is provided by TaskController"));
    }
};

#include "kurrentplugin.moc"
