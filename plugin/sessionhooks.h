#pragma once

#include <QList>
#include <QObject>
#include <QString>

/**
 * The hooks of the smoke test and the screenshot mode for one controller.
 *
 *   QML ── controller ──> SessionHooks ── reads ──> KURRENT_SMOKE*, KURRENT_SCREENSHOT_*
 *
 * Smoke progress, "finished" and the leader are process-wide: with several widgets only
 * one SmokeTest timer runs, and a recreated view continues instead of restarting. A change
 * is signalled on every hook object of the process.
 */
class SessionHooks : public QObject
{
    Q_OBJECT

public:
    explicit SessionHooks(QObject *parent = nullptr);
    ~SessionHooks() override;

    /// KURRENT_SMOKE=1|true.
    bool smokeTest() const;
    /// KURRENT_SCREENSHOT_DIR: output folder, empty outside screenshot mode.
    QString screenshotDir() const;
    /// KURRENT_SCREENSHOT_PLAN: what to shoot, empty = everything.
    QString screenshotPlan() const;

    int smokeStep() const;
    void setSmokeStep(int step);
    bool smokeFinished() const;
    /// True for the one hook object that runs the smoke steps; the first asker becomes it.
    bool smokeLeader();
    /// Warns the message, marks the run finished on KURRENT_SMOKE_DONE, appends to KURRENT_SMOKE_LOG.
    void smokeTrace(const QString &message) const;

Q_SIGNALS:
    void smokeStepChanged();
    void smokeFinishedChanged();
    void smokeLeaderChanged();

private:
    static QList<SessionHooks *> s_instances;
    static int s_smokeStep;
    static bool s_smokeFinished;
    static SessionHooks *s_smokeLeader;
};
