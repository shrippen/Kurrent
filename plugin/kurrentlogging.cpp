#include "kurrentlogging.h"

#include "sharedsettings.h"

Q_LOGGING_CATEGORY(KURRENT_AKONADI, "com.github.shrippen.kurrent.akonadi", QtInfoMsg)

namespace
{
bool s_infoJournalLogging = true;
bool s_verboseJournalLogging = false;
}

namespace KurrentLogging
{
void reloadFromSharedSettings()
{
    const QVariantMap values = SharedSettings::instance()->values();
    s_infoJournalLogging = values.value(QStringLiteral("infoJournalLogging"), true).toBool();
    s_verboseJournalLogging = values.value(QStringLiteral("verboseJournalLogging")).toBool();
}

void info(const QString &message)
{
    if (!s_infoJournalLogging) {
        return;
    }
    qCInfo(KURRENT_AKONADI).noquote() << message;
}

void verbose(const QString &message)
{
    if (!s_verboseJournalLogging) {
        return;
    }
    qCDebug(KURRENT_AKONADI) << message;
}

bool infoEnabled()
{
    return s_infoJournalLogging;
}

bool verboseEnabled()
{
    return s_verboseJournalLogging;
}
}
