#pragma once

#include <QLoggingCategory>
#include <QString>

Q_DECLARE_LOGGING_CATEGORY(KURRENT_AKONADI)

namespace KurrentLogging
{
void reloadFromSharedSettings();
void info(const QString &message);
void verbose(const QString &message);
bool infoEnabled();
bool verboseEnabled();
}
