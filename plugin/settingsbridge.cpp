#include "settingsbridge.h"

#include "sharedsettings.h"

#include <QMetaMethod>
#include <QMetaObject>
#include <QMetaProperty>

SettingsBridge::SettingsBridge(QObject *parent)
    : QObject(parent)
{
}

void SettingsBridge::bind(QObject *configuration)
{
    if (!configuration) {
        return;
    }
    m_configuration = configuration;
    SharedSettings *store = SharedSettings::instance();
    store->seedFromIfEmpty(configuration);
    store->seedMissingFrom(configuration);
    store->applyTo(configuration);

    // One generic bridge: any known key's change signal pushes the whole configuration.
    // QML writes (KCM Apply) and C++ inserts both emit these, unlike valueChanged().
    const QStringList keys = store->keys();
    const QMetaMethod slot = staticMetaObject.method(staticMetaObject.indexOfSlot("onConfigEdited()"));
    const QMetaObject *meta = configuration->metaObject();
    for (int i = 0; i < meta->propertyCount(); ++i) {
        const QMetaProperty property = meta->property(i);
        if (!property.hasNotifySignal() || !keys.contains(QLatin1String(property.name()))) {
            continue;
        }
        connect(configuration, property.notifySignal(), this, slot);
    }
}

void SettingsBridge::applyStored()
{
    if (!m_configuration) {
        return;
    }
    SharedSettings::instance()->applyTo(m_configuration);
}

void SettingsBridge::onConfigEdited()
{
    if (!m_configuration) {
        return;
    }
    SharedSettings::instance()->copyFrom(m_configuration);
}
