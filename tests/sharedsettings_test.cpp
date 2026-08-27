#include "sharedsettings.h"

#include <KConfig>
#include <KConfigGroup>

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
    void persistsNewPlannerKeys();
    void persistsKcmCatalogAndReset();
    void persistsReminderSearchAndColors();
    void dropsLegacySortModeKey();

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

void SharedSettingsTest::persistsNewPlannerKeys()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-d"));
    SharedSettings store(fileName);

    QQmlPropertyMap source;
    source.insert(QStringLiteral("catchUpEnabled"), false);
    source.insert(QStringLiteral("catchUpDays"), 7);
    source.insert(QStringLiteral("morningHour"), 8);
    source.insert(QStringLiteral("afternoonHour"), 13);
    source.insert(QStringLiteral("eveningHour"), 19);
    source.insert(QStringLiteral("showJoinButton"), false);
    store.copyFrom(&source);

    SharedSettings other(fileName);
    QQmlPropertyMap target;
    other.applyTo(&target);

    QCOMPARE(target.value(QStringLiteral("catchUpEnabled")).toBool(), false);
    QCOMPARE(target.value(QStringLiteral("catchUpDays")).toInt(), 7);
    QCOMPARE(target.value(QStringLiteral("morningHour")).toInt(), 8);
    QCOMPARE(target.value(QStringLiteral("afternoonHour")).toInt(), 13);
    QCOMPARE(target.value(QStringLiteral("eveningHour")).toInt(), 19);
    QCOMPARE(target.value(QStringLiteral("showJoinButton")).toBool(), false);
    QVERIFY(!store.keys().contains(QStringLiteral("sortMode")));
    QVERIFY(store.keys().contains(QStringLiteral("catchUpDays")));
}

void SharedSettingsTest::dropsLegacySortModeKey()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-sort-legacy"));
    {
        KConfig config(fileName);
        KConfigGroup group(&config, QStringLiteral("General"));
        group.writeEntry(QStringLiteral("sortMode"), QStringLiteral("due"));
        group.writeEntry(QStringLiteral("catchUpDays"), 7);
        config.sync();
    }

    SharedSettings store(fileName);
    QVERIFY(!store.keys().contains(QStringLiteral("sortMode")));
    QCOMPARE(store.values().value(QStringLiteral("catchUpDays")).toInt(), 7);

    KConfig config(fileName);
    KConfigGroup group(&config, QStringLiteral("General"));
    QVERIFY(!group.hasKey(QStringLiteral("sortMode")));
}

void SharedSettingsTest::persistsKcmCatalogAndReset()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-e"));
    SharedSettings store(fileName);

    QCOMPARE(store.defaults().value(QStringLiteral("sidebarWidthUnits")).toInt(), 10);
    QCOMPARE(store.defaults().value(QStringLiteral("overlayDimStep")).toInt(), 1);
    QCOMPARE(store.defaults().value(QStringLiteral("clickAction")).toString(), QStringLiteral("inline"));
    QVERIFY(store.keys().contains(QStringLiteral("rememberLastView")));
    QVERIFY(store.keys().contains(QStringLiteral("panelBadge")));
    QVERIFY(store.keys().contains(QStringLiteral("flyoutHeightUnits")));
    QVERIFY(!store.keys().contains(QString()));

    QQmlPropertyMap source;
    source.insert(QStringLiteral("rememberLastView"), true);
    source.insert(QStringLiteral("lastView"), QStringLiteral("today"));
    source.insert(QStringLiteral("density"), QStringLiteral("compact"));
    source.insert(QStringLiteral("sidebarWidthUnits"), 14);
    source.insert(QStringLiteral("overlayDimStep"), 2);
    source.insert(QStringLiteral("reducedMotion"), true);
    source.insert(QStringLiteral("showEmptyProjects"), true);
    source.insert(QStringLiteral("showSidebarCounts"), false);
    source.insert(QStringLiteral("showDateChip"), false);
    source.insert(QStringLiteral("showLabelChips"), false);
    source.insert(QStringLiteral("showPriorityChip"), false);
    source.insert(QStringLiteral("showRecurringIcon"), false);
    source.insert(QStringLiteral("defaultDueMode"), QStringLiteral("tomorrow"));
    source.insert(QStringLiteral("confirmDelete"), true);
    source.insert(QStringLiteral("clickAction"), QStringLiteral("full"));
    source.insert(QStringLiteral("panelBadge"), QStringLiteral("overdue"));
    source.insert(QStringLiteral("flyoutWidthUnits"), 40);
    source.insert(QStringLiteral("flyoutHeightUnits"), 28);
    store.copyFrom(&source);

    SharedSettings other(fileName);
    QQmlPropertyMap target;
    other.applyTo(&target);
    QCOMPARE(target.value(QStringLiteral("density")).toString(), QStringLiteral("compact"));
    QCOMPARE(target.value(QStringLiteral("sidebarWidthUnits")).toInt(), 14);
    QCOMPARE(target.value(QStringLiteral("panelBadge")).toString(), QStringLiteral("overdue"));
    QCOMPARE(target.value(QStringLiteral("confirmDelete")).toBool(), true);

    store.resetKeys({QStringLiteral("density"), QStringLiteral("confirmDelete")});
    QCOMPARE(store.values().value(QStringLiteral("density")).toString(), QStringLiteral("auto"));
    QCOMPARE(store.values().value(QStringLiteral("confirmDelete")).toBool(), false);
    QCOMPARE(store.values().value(QStringLiteral("sidebarWidthUnits")).toInt(), 14);

    store.resetToDefaults();
    QCOMPARE(store.values().value(QStringLiteral("sidebarWidthUnits")).toInt(), 10);
    QCOMPARE(store.values().value(QStringLiteral("lastView")).toString(), QStringLiteral("inbox"));
    QCOMPARE(store.values().value(QStringLiteral("flyoutWidthUnits")).toInt(), 32);
}

void SharedSettingsTest::persistsReminderSearchAndColors()
{
    const QString fileName = m_dir.filePath(QStringLiteral("kurrent-shared-f"));
    SharedSettings store(fileName);
    QQmlPropertyMap source;
    source.insert(QStringLiteral("searchTitleOnly"), true);
    source.insert(QStringLiteral("completeChildren"), true);
    source.insert(QStringLiteral("notificationsEnabled"), false);
    source.insert(QStringLiteral("defaultReminderMinutes"), 15);
    source.insert(QStringLiteral("projectColors"), QStringLiteral("{\"11\":\"#cc3333\"}"));
    source.insert(QStringLiteral("labelColors"), QStringLiteral("{\"home\":\"#3366cc\"}"));
    source.insert(QStringLiteral("descriptionPreviewLines"), 2);
    source.insert(QStringLiteral("hiddenViews"), QStringLiteral("anytime||unlabeled"));
    source.insert(QStringLiteral("quietHoursEnabled"), true);
    store.copyFrom(&source);

    SharedSettings other(fileName);
    QQmlPropertyMap target;
    other.applyTo(&target);
    QCOMPARE(target.value(QStringLiteral("searchTitleOnly")).toBool(), true);
    QCOMPARE(target.value(QStringLiteral("completeChildren")).toBool(), true);
    QCOMPARE(target.value(QStringLiteral("defaultReminderMinutes")).toInt(), 15);
    QCOMPARE(target.value(QStringLiteral("descriptionPreviewLines")).toInt(), 2);
    QCOMPARE(target.value(QStringLiteral("hiddenViews")).toString(), QStringLiteral("anytime||unlabeled"));
    QCOMPARE(target.value(QStringLiteral("quietHoursEnabled")).toBool(), true);
    QVERIFY(store.keys().contains(QStringLiteral("projectColors")));
    QVERIFY(store.keys().contains(QStringLiteral("notificationsEnabled")));
}

QTEST_MAIN(SharedSettingsTest)
#include "sharedsettings_test.moc"
