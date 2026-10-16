#pragma once

#include "screens.h"
#include "tasklistmodel.h"

#include <QObject>
#include <QTimer>

class TaskController;
class Terminal;

// kurrent-tui: the Focus and Stack layouts on the shared TaskController.
//
//   Terminal.keyPressed ──▶ TuiApp::onKey ──▶ TaskController (complete, reschedule, create)
//   TaskController.taskModel / 1 s tick ──▶ TuiApp::draw ──▶ Screens ──▶ Terminal.render
class TuiApp : public QObject
{
    Q_OBJECT

public:
    TuiApp(TaskController *controller, Terminal *terminal, QObject *parent = nullptr);

private:
    enum class View { Focus, Stack };
    enum class Input { None, Add, Search };

    void onKey(const QString &key);
    void onFocusKey(const QString &key);
    void onStackKey(const QString &key);
    void onInputKey(const QString &key);
    void draw();

    /** Open tasks of the controller's list, filtered by the search text. */
    QList<TaskEntry> openTasks() const;
    QList<TaskEntry> focusOrder() const;
    Screens::Row rowOf(const TaskEntry &task) const;
    Screens::Words words() const;
    QString status() const;

    void complete(const TaskEntry &task);
    void reschedule(const TaskEntry &task, const QString &preset);
    void clearDue(const TaskEntry &task);

    TaskController *m_controller;
    Terminal *m_terminal;
    QTimer m_tick;
    View m_view = View::Focus;
    Input m_input = Input::None;
    QString m_inputText;
    QString m_search;
    int m_selected = 0;
};
