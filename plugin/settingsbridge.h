#pragma once

#include <QObject>
#include <QPointer>

/**
 * Keeps the widget's Plasmoid.configuration and kurrentrc (SharedSettings) equal.
 *
 *   settings pages ─cfg_*─▶ configuration ─ any known key edited ─▶ kurrentrc
 *                                ▲                                     │
 *                                └───────────── applyStored ◀──────────┘ changed
 *
 * The controller reads kurrentrc; the views never write the configuration.
 */
class SettingsBridge : public QObject
{
    Q_OBJECT

public:
    explicit SettingsBridge(QObject *parent);

    /// Seeds kurrentrc from `configuration` where it has no value, writes kurrentrc back
    /// into it, and from then on copies every edit of a known key into kurrentrc.
    void bind(QObject *configuration);
    /// kurrentrc changed: the configuration follows.
    void applyStored();

private Q_SLOTS:
    void onConfigEdited();

private:
    QPointer<QObject> m_configuration;
};
