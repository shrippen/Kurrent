#include "kurrentdbus.h"
#include "taskcontroller.h"

KurrentDBusAdaptor::KurrentDBusAdaptor(TaskController *parent)
    : QDBusAbstractAdaptor(parent)
{
    setAutoRelaySignals(false);
}

void KurrentDBusAdaptor::show()
{
    TaskController::broadcastDbusShow();
}

void KurrentDBusAdaptor::addTask(const QString &summary)
{
    TaskController::broadcastDbusAddTask(summary);
}

void KurrentDBusAdaptor::openView(const QString &view)
{
    TaskController::broadcastDbusOpenView(view);
}

void KurrentDBusAdaptor::searchAndShow(const QString &query)
{
    TaskController::broadcastDbusSearchAndShow(query);
}
