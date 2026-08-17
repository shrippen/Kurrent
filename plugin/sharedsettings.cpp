#include "sharedsettings.h"

#include <KConfig>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QQmlEngine>
#include <QQmlPropertyMap>
#include <QStandardPaths>

namespace
{
constexpr const char *kGroupName = "General";
constexpr const char *kDefaultFileName = "com.github.shrippen.kurrent/kurrentrc";
constexpr const char *kLegacyFileName = "plasma_com.github.shrippen.kurrentrc";
}

const SharedSettings::KeySpec *SharedSettings::specs()
{
    static const KeySpec keys[] = {
        {"defaultView", ValueType::String, QStringLiteral("inbox")},
        {"showCompleted", ValueType::Bool, false},
        {"blurBackground", ValueType::Bool, true},
        {"enabledCollections", ValueType::String, QString()},
        {"hiddenProjects", ValueType::String, QString()},
        {"hiddenLabels", ValueType::String, QString()},
        {"sidebarRowSize", ValueType::String, QStringLiteral("auto")},
        {"newTaskProjectMode", ValueType::String, QStringLiteral("ask")},
        {"newTaskDefaultCollectionId", ValueType::String, QString()},
        {"sortMode", ValueType::String, QStringLiteral("default")},
        {"catchUpEnabled", ValueType::Bool, true},
        {"catchUpDays", ValueType::Int, 14},
        {"morningHour", ValueType::Int, 6},
        {"afternoonHour", ValueType::Int, 12},
        {"eveningHour", ValueType::Int, 18},
        {"showJoinButton", ValueType::Bool, true},
    };
    return keys;
}

int SharedSettings::specCount()
{
    return 16;
}

SharedSettings *SharedSettings::instance()
{
    static SharedSettings *s_instance = nullptr;
    if (!s_instance) {
        s_instance = new SharedSettings();
        QQmlEngine::setObjectOwnership(s_instance, QQmlEngine::CppOwnership);
    }
    return s_instance;
}

SharedSettings::SharedSettings(QObject *parent)
    : SharedSettings(QString::fromLatin1(kDefaultFileName), parent)
{
}

SharedSettings::SharedSettings(const QString &fileName, QObject *parent)
    : QObject(parent)
{
    init(fileName);
}

SharedSettings::~SharedSettings() = default;

void SharedSettings::init(const QString &fileName)
{
    migrateLegacyConfig(fileName);
    m_config = KSharedConfig::openConfig(fileName);
    m_group = KConfigGroup(m_config, QLatin1String(kGroupName));
    reloadFromDisk();

    m_watcher = KConfigWatcher::create(m_config);
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group, const QByteArrayList &) {
        if (m_syncing) {
            return;
        }
        if (group.name() != QLatin1String(kGroupName)) {
            return;
        }
        reloadFromDisk();
        Q_EMIT changed();
    });
}

void SharedSettings::migrateLegacyConfig(const QString &fileName)
{
    if (fileName != QLatin1String(kDefaultFileName)) {
        return;
    }

    const QString configHome = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const QString newPath = configHome + QLatin1Char('/') + QLatin1String(kDefaultFileName);
    if (QFile::exists(newPath)) {
        return;
    }

    const QString oldPath = configHome + QLatin1Char('/') + QLatin1String(kLegacyFileName);
    if (!QFile::exists(oldPath)) {
        return;
    }

    QDir().mkpath(QFileInfo(newPath).absolutePath());
    if (QFile::copy(oldPath, newPath)) {
        QFile::remove(oldPath);
    }
}

void SharedSettings::reloadFromDisk()
{
    m_cache.clear();
    const KeySpec *keys = specs();
    for (int i = 0; i < specCount(); ++i) {
        m_cache.insert(QLatin1String(keys[i].name), readStored(keys[i]));
    }
}

QVariant SharedSettings::readStored(const KeySpec &spec) const
{
    const QString name = QLatin1String(spec.name);
    if (!m_group.hasKey(name)) {
        return spec.defaultValue;
    }
    if (spec.type == ValueType::Bool) {
        return m_group.readEntry(name, spec.defaultValue.toBool());
    }
    if (spec.type == ValueType::Int) {
        return m_group.readEntry(name, spec.defaultValue.toInt());
    }
    return m_group.readEntry(name, spec.defaultValue.toString());
}

void SharedSettings::writeStored(const KeySpec &spec, const QVariant &value)
{
    const QString name = QLatin1String(spec.name);
    if (spec.type == ValueType::Bool) {
        m_group.writeEntry(name, value.toBool(), KConfig::Notify);
    } else if (spec.type == ValueType::Int) {
        m_group.writeEntry(name, value.toInt(), KConfig::Notify);
    } else {
        m_group.writeEntry(name, value.toString(), KConfig::Notify);
    }
}

QVariant SharedSettings::readConfigProperty(QObject *configuration, const QString &key)
{
    if (!configuration) {
        return {};
    }
    if (auto *map = qobject_cast<QQmlPropertyMap *>(configuration)) {
        return map->value(key);
    }
    return configuration->property(key.toUtf8().constData());
}

void SharedSettings::writeConfigProperty(QObject *configuration, const QString &key, const QVariant &value)
{
    if (!configuration) {
        return;
    }
    if (auto *map = qobject_cast<QQmlPropertyMap *>(configuration)) {
        map->insert(key, value);
        return;
    }
    configuration->setProperty(key.toUtf8().constData(), value);
}

bool SharedSettings::sameValue(const QVariant &left, const QVariant &right, ValueType type)
{
    if (type == ValueType::Bool) {
        return left.toBool() == right.toBool();
    }
    if (type == ValueType::Int) {
        return left.toInt() == right.toInt();
    }
    return left.toString() == right.toString();
}

QVariant SharedSettings::typedValue(const QVariant &value, ValueType type)
{
    if (type == ValueType::Bool) {
        return value.toBool();
    }
    if (type == ValueType::Int) {
        return value.toInt();
    }
    return value.toString();
}

bool SharedSettings::isEmpty() const
{
    const KeySpec *keys = specs();
    for (int i = 0; i < specCount(); ++i) {
        if (m_group.hasKey(QLatin1String(keys[i].name))) {
            return false;
        }
    }
    return true;
}

QStringList SharedSettings::keys() const
{
    QStringList list;
    const KeySpec *keySpecs = specs();
    for (int i = 0; i < specCount(); ++i) {
        list.append(QLatin1String(keySpecs[i].name));
    }
    return list;
}

QVariantMap SharedSettings::values() const
{
    return m_cache;
}

void SharedSettings::seedFromIfEmpty(QObject *configuration)
{
    if (!isEmpty() || !configuration) {
        return;
    }
    copyFrom(configuration);
}

void SharedSettings::copyFrom(QObject *configuration)
{
    if (m_syncing || !configuration) {
        return;
    }

    bool dirty = false;
    const KeySpec *keySpecs = specs();
    for (int i = 0; i < specCount(); ++i) {
        const QString name = QLatin1String(keySpecs[i].name);
        const QVariant incoming = typedValue(readConfigProperty(configuration, name), keySpecs[i].type);
        if (sameValue(m_cache.value(name), incoming, keySpecs[i].type)) {
            continue;
        }
        m_cache.insert(name, incoming);
        writeStored(keySpecs[i], incoming);
        dirty = true;
    }
    if (!dirty) {
        return;
    }
    m_config->sync();
    Q_EMIT changed();
}

void SharedSettings::applyTo(QObject *configuration)
{
    if (!configuration) {
        return;
    }
    m_syncing = true;
    const KeySpec *keySpecs = specs();
    for (int i = 0; i < specCount(); ++i) {
        const QString name = QLatin1String(keySpecs[i].name);
        const QVariant stored = m_cache.value(name, keySpecs[i].defaultValue);
        if (sameValue(readConfigProperty(configuration, name), stored, keySpecs[i].type)) {
            continue;
        }
        writeConfigProperty(configuration, name, stored);
    }
    m_syncing = false;
}
