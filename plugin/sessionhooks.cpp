#include "sessionhooks.h"

#include <QByteArray>
#include <QDebug>
#include <QFile>
#include <QIODevice>

namespace
{
const char kSmokeEnv[] = "KURRENT_SMOKE";
const char kSmokeLogEnv[] = "KURRENT_SMOKE_LOG";
const char kScreenshotDirEnv[] = "KURRENT_SCREENSHOT_DIR";
const char kScreenshotPlanEnv[] = "KURRENT_SCREENSHOT_PLAN";
const QLatin1String kSmokeDoneMarker("KURRENT_SMOKE_DONE");
}

QList<SessionHooks *> SessionHooks::s_instances;
int SessionHooks::s_smokeStep = 0;
bool SessionHooks::s_smokeFinished = false;
SessionHooks *SessionHooks::s_smokeLeader = nullptr;

SessionHooks::SessionHooks(QObject *parent)
    : QObject(parent)
{
    s_instances.append(this);
}

// A leader that goes away hands over: the siblings ask again who leads.
SessionHooks::~SessionHooks()
{
    s_instances.removeAll(this);
    if (s_smokeLeader != this) {
        return;
    }

    s_smokeLeader = nullptr;
    for (SessionHooks *instance : s_instances) {
        Q_EMIT instance->smokeLeaderChanged();
    }
}

bool SessionHooks::smokeTest() const
{
    const QByteArray value = qgetenv(kSmokeEnv);
    return value == "1" || value.compare("true", Qt::CaseInsensitive) == 0;
}

QString SessionHooks::screenshotDir() const
{
    return QString::fromLocal8Bit(qgetenv(kScreenshotDirEnv));
}

QString SessionHooks::screenshotPlan() const
{
    return QString::fromLocal8Bit(qgetenv(kScreenshotPlanEnv));
}

int SessionHooks::smokeStep() const
{
    return s_smokeStep;
}

void SessionHooks::setSmokeStep(int step)
{
    if (s_smokeStep == step) {
        return;
    }

    s_smokeStep = step;
    for (SessionHooks *instance : s_instances) {
        Q_EMIT instance->smokeStepChanged();
    }
}

bool SessionHooks::smokeFinished() const
{
    return s_smokeFinished;
}

bool SessionHooks::smokeLeader()
{
    if (!smokeTest() || s_smokeFinished) {
        return false;
    }
    if (s_smokeLeader) {
        return s_smokeLeader == this;
    }

    s_smokeLeader = this;
    // Notify siblings so only one SmokeTest timer runs.
    for (SessionHooks *instance : s_instances) {
        if (instance != this) {
            Q_EMIT instance->smokeLeaderChanged();
        }
    }
    return true;
}

void SessionHooks::smokeTrace(const QString &message) const
{
    qWarning().noquote() << message;
    if (message.contains(kSmokeDoneMarker) && !s_smokeFinished) {
        s_smokeFinished = true;
        for (SessionHooks *instance : s_instances) {
            Q_EMIT instance->smokeFinishedChanged();
        }
    }

    const QString path = QString::fromLocal8Bit(qgetenv(kSmokeLogEnv));
    if (path.isEmpty()) {
        return;
    }

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        file.write(message.toUtf8());
        file.write("\n");
    }
}
