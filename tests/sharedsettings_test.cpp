#include "sharedsettings.h"

#include <QDir>
#include <QFile>
#include <QQmlPropertyMap>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

class SharedSettingsTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void copiesBetweenMapsAndPersists();
    void seedOnlyWhenEmpty();
    void copyFromIgnoredWhileApplying();
    void migratesLegacyConfigFile();

private:
    QTemporaryDir m_dir;
};

void SharedSettingsTest::initTestCase()
{
    QVERIFY(m_dir.isValid());
    QStandardPaths::setTestModeEnabled(true);
}

void SharedSettingsTest::copiesBetweenMapsAndPersists()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-a"));
    SharedSettings store(fileName);
    QVERIFY(store.isEmpty());

    QQmlPropertyMap source;
    source.insert(QStringLiteral("defaultView"), QStringLiteral("today"));
    source.insert(QStringLiteral("showCompleted"), true);
    source.insert(QStringLiteral("blurBackground"), false);
    source.insert(QStringLiteral("enabledCollections"), QStringLiteral("1,2"));
    source.insert(QStringLiteral("hiddenProjects"), QStringLiteral("3"));
    source.insert(QStringLiteral("hiddenLabels"), QStringLiteral("work"));
    source.insert(QStringLiteral("sidebarRowSize"), QStringLiteral("compact"));
    source.insert(QStringLiteral("newTaskProjectMode"), QStringLiteral("first"));
    source.insert(QStringLiteral("newTaskDefaultCollectionId"), QStringLiteral("9"));

    store.copyFrom(&source);

    SharedSettings other(fileName);
    QQmlPropertyMap target;
    other.applyTo(&target);

    QCOMPARE(target.value(QStringLiteral("defaultView")).toString(), QStringLiteral("today"));
    QCOMPARE(target.value(QStringLiteral("showCompleted")).toBool(), true);
    QCOMPARE(target.value(QStringLiteral("blurBackground")).toBool(), false);
    QCOMPARE(target.value(QStringLiteral("enabledCollections")).toString(), QStringLiteral("1,2"));
    QCOMPARE(target.value(QStringLiteral("sidebarRowSize")).toString(), QStringLiteral("compact"));
    QCOMPARE(target.value(QStringLiteral("newTaskProjectMode")).toString(), QStringLiteral("first"));
}

void SharedSettingsTest::seedOnlyWhenEmpty()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-b"));
    SharedSettings store(fileName);

    QQmlPropertyMap first;
    first.insert(QStringLiteral("defaultView"), QStringLiteral("scheduled"));
    first.insert(QStringLiteral("blurBackground"), false);
    store.seedFromIfEmpty(&first);
    QCOMPARE(store.values().value(QStringLiteral("defaultView")).toString(), QStringLiteral("scheduled"));

    QQmlPropertyMap second;
    second.insert(QStringLiteral("defaultView"), QStringLiteral("inbox"));
    store.seedFromIfEmpty(&second);
    QCOMPARE(store.values().value(QStringLiteral("defaultView")).toString(), QStringLiteral("scheduled"));
}

void SharedSettingsTest::copyFromIgnoredWhileApplying()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-c"));
    SharedSettings store(fileName);

    QQmlPropertyMap source;
    source.insert(QStringLiteral("defaultView"), QStringLiteral("anytime"));
    store.copyFrom(&source);

    QQmlPropertyMap target;
    target.insert(QStringLiteral("defaultView"), QStringLiteral("inbox"));
    int changes = 0;
    connect(&store, &SharedSettings::changed, this, [&]() {
        ++changes;
        store.copyFrom(&target);
    });
    store.applyTo(&target);
    QCOMPARE(changes, 0);
    QCOMPARE(store.values().value(QStringLiteral("defaultView")).toString(), QStringLiteral("anytime"));
}

void SharedSettingsTest::migratesLegacyConfigFile()
{
    const QString configHome = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    QVERIFY(QDir().mkpath(configHome));
    const QString legacyPath = configHome + QStringLiteral("/plasma_com.github.shrippen.kurrentrc");
    const QString newPath = configHome + QStringLiteral("/com.github.shrippen.kurrent/kurrentrc");
    QFile::remove(legacyPath);
    QFile::remove(newPath);

    QFile legacy(legacyPath);
    QVERIFY(legacy.open(QIODevice::WriteOnly | QIODevice::Truncate));
    legacy.write("[General]\ndefaultView=today\nnewTaskProjectMode=first\n");
    legacy.close();

    SharedSettings store;
    QCOMPARE(store.values().value(QStringLiteral("defaultView")).toString(), QStringLiteral("today"));
    QCOMPARE(store.values().value(QStringLiteral("newTaskProjectMode")).toString(), QStringLiteral("first"));
    QVERIFY(QFile::exists(newPath));
    QVERIFY(!QFile::exists(legacyPath));
}

QTEST_MAIN(SharedSettingsTest)
#include "sharedsettings_test.moc"
