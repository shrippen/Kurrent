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
    }
};

QUICK_TEST_MAIN_WITH_SETUP(kurrentqml, Setup)

#include "qmltest.moc"
