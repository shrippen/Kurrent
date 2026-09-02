#pragma once

#include <QDBusAbstractAdaptor>
#include <QString>

class TaskController;

class KurrentDBusAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.github.shrippen.Kurrent")

public:
    explicit KurrentDBusAdaptor(TaskController *parent);

public Q_SLOTS:
    Q_NOREPLY void show();
    Q_NOREPLY void addTask(const QString &summary);
    Q_NOREPLY void openView(const QString &view);
    Q_NOREPLY void searchAndShow(const QString &query);
    Q_NOREPLY void testMergeConflict();
};
