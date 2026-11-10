#include "taskcontroller.h"

#include <KLocalizedString>

#include <QFile>
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
    void initTestCase();
    void cleanupTestCase();
    void undoLabelUsesWidgetCatalog();
    void listGroupHeadsAreTranslated_data();
    void listGroupHeadsAreTranslated();

private:
    QByteArray m_messagesLocale;
};

// German catalog and a real LC_MESSAGES for every test; restored afterwards.
void CoreI18nTest::initTestCase()
{
    const QString catalog = QStringLiteral(KURRENT_TEST_LOCALE_DIR "/de/LC_MESSAGES/" KURRENT_TEST_DOMAIN ".mo");
    if (!QFile::exists(catalog)) {
        SKIP_OR_FAIL("German catalog not built (msgfmt missing)");
    }

    // glibc's gettext ignores LANGUAGE (which KI18n sets) while LC_MESSAGES is C or POSIX.
    // Take any real locale; without one nothing can be translated.
    m_messagesLocale = setlocale(LC_MESSAGES, nullptr);
    if (m_messagesLocale == "C" || m_messagesLocale == "POSIX" || m_messagesLocale.startsWith("C.")) {
        if (!setlocale(LC_MESSAGES, "de_DE.UTF-8") && !setlocale(LC_MESSAGES, "en_US.UTF-8")) {
            SKIP_OR_FAIL("Only the C locale is installed; gettext cannot translate here");
        }
    }

    // Before the first i18n(): KLocalizedString reads the catalog paths once per domain.
    KLocalizedString::addDomainLocaleDir(KURRENT_TEST_DOMAIN, QStringLiteral(KURRENT_TEST_LOCALE_DIR));
    KLocalizedString::setLanguages({QStringLiteral("de")});
}

void CoreI18nTest::cleanupTestCase()
{
    KLocalizedString::clearLanguages();
    setlocale(LC_MESSAGES, m_messagesLocale.constData());
}

void CoreI18nTest::undoLabelUsesWidgetCatalog()
{
    TaskController controller;
    QCOMPARE(controller.undoLabel(), QStringLiteral("Rückgängig"));
}

// The list shows listGroupLabelForKey() as is; Kanban translates in QML, the list does not.
void CoreI18nTest::listGroupHeadsAreTranslated_data()
{
    QTest::addColumn<QString>("mode");
    QTest::addColumn<QString>("key");
    QTest::addColumn<QString>("expected");
    QTest::newRow("priority high") << QStringLiteral("priority") << QStringLiteral("high") << QStringLiteral("Hoch");
    QTest::newRow("priority none") << QStringLiteral("priority") << QStringLiteral("none") << QStringLiteral("Keine");
    QTest::newRow("secrecy confidential") << QStringLiteral("secrecy") << QStringLiteral("confidential") << QStringLiteral("Vertraulich");
    QTest::newRow("location none") << QStringLiteral("location") << QStringLiteral("none") << QStringLiteral("Ohne Ort");
}

void CoreI18nTest::listGroupHeadsAreTranslated()
{
    QFETCH(QString, mode);
    QFETCH(QString, key);
    QFETCH(QString, expected);
    TaskController controller;
    controller.setListGroupMode(mode);
    QCOMPARE(controller.listGroupLabelForKey(key), expected);
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
