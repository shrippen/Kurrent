#pragma once

#include <KConfig>
#include <KConfigGroup>
#include <KConfigWatcher>
#include <KSharedConfig>

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantMap>

class SharedSettings : public QObject
{
    Q_OBJECT

public:
    explicit SharedSettings(QObject *parent = nullptr);
    explicit SharedSettings(const QString &fileName, QObject *parent = nullptr);
    ~SharedSettings() override;

    static SharedSettings *instance();

    Q_INVOKABLE void seedFromIfEmpty(QObject *configuration);
    Q_INVOKABLE void copyFrom(QObject *configuration);
    Q_INVOKABLE void applyTo(QObject *configuration);
    Q_INVOKABLE void resetToDefaults();
    Q_INVOKABLE void resetKeys(const QStringList &names);
    Q_INVOKABLE bool isEmpty() const;
    Q_INVOKABLE QStringList keys() const;
    Q_INVOKABLE QVariantMap values() const;
    Q_INVOKABLE QVariantMap defaults() const;
    Q_INVOKABLE void storeString(const QString &key, const QString &value);

Q_SIGNALS:
    void changed();

private:
    enum class ValueType {
        Bool,
        String,
        Int,
    };

    struct KeySpec {
        const char *name;
        ValueType type;
        QVariant defaultValue;
    };

    void init(const QString &fileName);
    void migrateLegacyConfig(const QString &fileName);
    void reloadFromDisk();
    QVariant readStored(const KeySpec &spec) const;
    void writeStored(const KeySpec &spec, const QVariant &value);
    static QVariant readConfigProperty(QObject *configuration, const QString &key);
    static void writeConfigProperty(QObject *configuration, const QString &key, const QVariant &value);
    static bool sameValue(const QVariant &left, const QVariant &right, ValueType type);
    static QVariant typedValue(const QVariant &value, ValueType type);
    static const KeySpec *specs();
    static int specCount();

    KSharedConfig::Ptr m_config;
    KConfigGroup m_group;
    KConfigWatcher::Ptr m_watcher;
    QVariantMap m_cache;
    bool m_syncing = false;
};
