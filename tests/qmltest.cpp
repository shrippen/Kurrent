#include <KLocalizedContext>
#include <KLocalizedString>

#include <QQmlContext>
#include <QQmlEngine>
#include <QtQuickTest>

// i18n() in the components under test, as in the widget.
class Setup : public QObject
{
    Q_OBJECT

public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        KLocalizedString::setApplicationDomain(TRANSLATION_DOMAIN);
        engine->rootContext()->setContextObject(new KLocalizedContext(engine));
        // CI sets it: a test that needs kirigami-addons fails instead of skipping without it.
        engine->rootContext()->setContextProperty(QStringLiteral("kurrentRequireAddons"),
                                                  qgetenv("KURRENT_REQUIRE_KIRIGAMI_ADDONS") == "1");
    }
};

QUICK_TEST_MAIN_WITH_SETUP(kurrentqml, Setup)

#include "qmltest.moc"
