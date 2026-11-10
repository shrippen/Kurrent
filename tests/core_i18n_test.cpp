#include "taskcontroller.h"

#include <KLocalizedString>

#include <QFile>
#include <QScopeGuard>
#include <QStandardPaths>
#include <QTest>

#include <clocale>

/*
 * kurrentcore translates with the widget's catalog (TRANSLATION_DOMAIN in plugin/CMakeLists.txt).
 * This test links the library as built, so it fails when kurrentcore loses that definition;
 * the store test compiles the sources itself and would not notice.
 */
// Skip, or fail where the CI promises a catalog and a real locale (KURRENT_REQUIRE_TRANSLATION).
#define SKIP_OR_FAIL(why) \
    if (qEnvironmentVariableIsSet("KURRENT_REQUIRE_TRANSLATION")) { \
        QFAIL(why); \
    } \
    QSKIP(why)

class CoreI18nTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void undoLabelUsesWidgetCatalog();
};

void CoreI18nTest::undoLabelUsesWidgetCatalog()
{
    const QString catalog = QStringLiteral(KURRENT_TEST_LOCALE_DIR "/de/LC_MESSAGES/" KURRENT_TEST_DOMAIN ".mo");
    if (!QFile::exists(catalog)) {
        SKIP_OR_FAIL("German catalog not built (msgfmt missing)");
    }

    // glibc's gettext ignores LANGUAGE (which KI18n sets) while LC_MESSAGES is C or POSIX.
    // Take any real locale; without one nothing can be translated.
    const QByteArray messagesLocale = setlocale(LC_MESSAGES, nullptr);
    const auto restoreLocale = qScopeGuard([messagesLocale] { setlocale(LC_MESSAGES, messagesLocale.constData()); });
    if (messagesLocale == "C" || messagesLocale == "POSIX" || messagesLocale.startsWith("C.")) {
        if (!setlocale(LC_MESSAGES, "de_DE.UTF-8") && !setlocale(LC_MESSAGES, "en_US.UTF-8")) {
            SKIP_OR_FAIL("Only the C locale is installed; gettext cannot translate here");
        }
    }

    // Before the first i18n(): KLocalizedString reads the catalog paths once per domain.
    KLocalizedString::addDomainLocaleDir(KURRENT_TEST_DOMAIN, QStringLiteral(KURRENT_TEST_LOCALE_DIR));
    KLocalizedString::setLanguages({QStringLiteral("de")});

    TaskController controller;
    QCOMPARE(controller.undoLabel(), QStringLiteral("Rückgängig"));
}

int main(int argc, char **argv)
{
    // SharedSettings then lives in ~/.qttest, never the user's kurrentrc.
    QStandardPaths::setTestModeEnabled(true);
    QCoreApplication app(argc, argv);
    CoreI18nTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "core_i18n_test.moc"
