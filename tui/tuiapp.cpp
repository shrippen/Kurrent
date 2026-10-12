#include "tuiapp.h"

#include "taskcontroller.h"
#include "tasklogic.h"
#include "terminal.h"

#include <KLocalizedString>
#include <QCoreApplication>
#include <QLocale>
#include <QVariantMap>

#include <algorithm>

namespace
{
constexpr int kTickMs = 1000;
const QString kKeyQuit = QStringLiteral("quit");
}

TuiApp::TuiApp(TaskController *controller, Terminal *terminal, QObject *parent)
    : QObject(parent)
    , m_controller(controller)
    , m_terminal(terminal)
{
    // All open tasks; the layouts sort them themselves.
    m_controller->setCurrentView(TaskLogic::ViewId::Inbox);
    m_controller->setShowCompleted(false);

    connect(m_terminal, &Terminal::keyPressed, this, &TuiApp::onKey);
    connect(m_terminal, &Terminal::resized, this, &TuiApp::draw);
    connect(m_controller->taskModel(), &TaskListModel::countChanged, this, &TuiApp::draw);
    connect(m_controller->taskModel(), &QAbstractItemModel::dataChanged, this, &TuiApp::draw);
    connect(m_controller->taskModel(), &QAbstractItemModel::modelReset, this, &TuiApp::draw);

    // Due labels ("today") and the clock move on without model changes.
    m_tick.setInterval(kTickMs);
    connect(&m_tick, &QTimer::timeout, this, &TuiApp::draw);
    m_tick.start();
    draw();
}

void TuiApp::onKey(const QString &key)
{
    if (m_input != Input::None) {
        onInputKey(key);
        draw();
        return;
    }
    if (key == QLatin1String("q") || key == kKeyQuit) {
        QCoreApplication::quit();
        return;
    }
    if (m_view == View::Stack) {
        onStackKey(key);
    } else {
        onFocusKey(key);
    }
    draw();
}

void TuiApp::onFocusKey(const QString &key)
{
    const QList<TaskEntry> tasks = focusOrder();
    const bool hasTask = m_selected >= 0 && m_selected < tasks.size();

    if (key == QLatin1String("down") || key == QLatin1String("j")) {
        m_selected = qMin(m_selected + 1, qMax(0, int(tasks.size()) - 1));
    } else if (key == QLatin1String("up") || key == QLatin1String("k")) {
        m_selected = qMax(0, m_selected - 1);
    } else if (key == QLatin1String("a")) {
        m_input = Input::Add;
        m_inputText.clear();
    } else if (key == QLatin1String("/")) {
        m_input = Input::Search;
        m_inputText = m_search;
    } else if (key == QLatin1String("escape")) {
        m_search.clear();
    } else if (key == QLatin1String("g")) {
        m_view = View::Stack;
    } else if (key == QLatin1String("r")) {
        m_controller->refresh();
    } else if (hasTask && (key == QLatin1String("x") || key == QLatin1String(" "))) {
        complete(tasks.at(m_selected));
    } else if (hasTask && key == QLatin1String("t")) {
        reschedule(tasks.at(m_selected), TaskLogic::ReschedulePreset::Today);
    } else if (hasTask && key == QLatin1String("m")) {
        reschedule(tasks.at(m_selected), TaskLogic::ReschedulePreset::Tomorrow);
    } else if (hasTask && key == QLatin1String("d")) {
        clearDue(tasks.at(m_selected));
    }
}

void TuiApp::onStackKey(const QString &key)
{
    if (key == QLatin1String("escape")) {
        m_view = View::Focus;
        return;
    }
    const QList<TaskEntry> queue = TaskLogic::triageQueue(openTasks(), QDate::currentDate());
    if (queue.isEmpty()) {
        return;
    }

    // ↑ done, → today, ← tomorrow, ↓ someday (no due date).
    const TaskEntry &task = queue.first();
    if (key == QLatin1String("up") || key == QLatin1String("x")) {
        complete(task);
    } else if (key == QLatin1String("right") || key == QLatin1String("t")) {
        reschedule(task, TaskLogic::ReschedulePreset::Today);
    } else if (key == QLatin1String("left") || key == QLatin1String("m")) {
        reschedule(task, TaskLogic::ReschedulePreset::Tomorrow);
    } else if (key == QLatin1String("down") || key == QLatin1String("d")) {
        clearDue(task);
    }
}

void TuiApp::onInputKey(const QString &key)
{
    if (key == QLatin1String("escape") || key == kKeyQuit) {
        m_input = Input::None;
        return;
    }
    if (key == QLatin1String("backspace")) {
        m_inputText.chop(1);
    } else if (key == QLatin1String("enter")) {
        // Quick Add as in the widget ("Dispo morgen 18:00 !hoch @harbour #orga").
        if (m_input == Input::Add && !m_inputText.trimmed().isEmpty()) {
            m_controller->createTask(m_inputText.trimmed(), 0);
        }
        if (m_input == Input::Search) {
            m_search = m_inputText.trimmed();
            m_selected = 0;
        }
        m_input = Input::None;
        return;
    } else if (key.size() == 1 || !key.at(0).isLetter()) {
        m_inputText += key;
    }

    if (m_input == Input::Search) {
        m_search = m_inputText.trimmed();
        m_selected = 0;
    }
}

void TuiApp::draw()
{
    const Screens::Size size{m_terminal->columns(), m_terminal->rows()};
    const QDate today = QDate::currentDate();

    if (m_view == View::Stack) {
        const QList<TaskEntry> all = openTasks();
        const QList<TaskEntry> queue = TaskLogic::triageQueue(all, today);
        Screens::StackModel model;
        model.count = int(queue.size());
        model.status = status();
        if (!queue.isEmpty()) {
            model.task = rowOf(queue.first());
            const int late = TaskLogic::overdueDays(queue.first(), today);
            model.overdue = i18np("1 day overdue", "%1 days overdue", late);
        }
        m_terminal->render(Screens::stackScreen(model, size, words()));
        return;
    }

    Screens::FocusModel model;
    for (const TaskEntry &task : focusOrder()) {
        switch (TaskLogic::horizonOf(task, today)) {
        case TaskLogic::Horizon::Now:
            model.now.append(rowOf(task));
            break;
        case TaskLogic::Horizon::Soon:
            model.soon.append(rowOf(task));
            break;
        default:
            model.someday.append(rowOf(task));
            break;
        }
    }
    model.selected = qMin(m_selected, int(model.now.size() + model.soon.size() + model.someday.size()) - 1);
    model.title = QLocale().toString(today, QLocale::LongFormat);
    model.status = status();
    model.message = m_controller->errorMessage();
    if (m_input == Input::Add) {
        model.prompt = i18n("New task:");
    } else if (m_input == Input::Search) {
        model.prompt = i18n("Search:");
    } else if (!m_search.isEmpty()) {
        model.message = i18n("Search: %1 (Esc clears)", m_search);
    }
    model.input = m_inputText;
    m_terminal->render(Screens::focusScreen(model, size, words()));
}

QList<TaskEntry> TuiApp::openTasks() const
{
    QList<TaskEntry> out;
    const TaskListModel *list = m_controller->taskModel();
    for (int row = 0; row < list->count(); ++row) {
        const TaskEntry task = list->taskAt(row);
        if (task.completed || task.pendingDelete) {
            continue;
        }
        if (!m_search.isEmpty()
            && !TaskLogic::matchesSearch(task, m_search, TaskLogic::SearchScope::All, TaskLogic::SearchCase::Insensitive)) {
            continue;
        }
        out.append(task);
    }
    return out;
}

// Now and Soon by due date, overdue first; Someday by priority, then title.
QList<TaskEntry> TuiApp::focusOrder() const
{
    const QDate today = QDate::currentDate();
    QList<TaskEntry> tasks = openTasks();
    std::stable_sort(tasks.begin(), tasks.end(), [&today](const TaskEntry &a, const TaskEntry &b) {
        const auto ha = TaskLogic::horizonOf(a, today);
        const auto hb = TaskLogic::horizonOf(b, today);
        if (ha != hb) {
            return int(ha) < int(hb);
        }
        if (a.dueDate.isValid() && b.dueDate.isValid() && a.dueDate != b.dueDate) {
            return a.dueDate < b.dueDate;
        }
        if (TaskLogic::priorityBand(a.priority) != TaskLogic::priorityBand(b.priority)) {
            return a.priority != 0 && (b.priority == 0 || a.priority < b.priority);
        }
        return a.summary.localeAwareCompare(b.summary) < 0;
    });
    return tasks;
}

Screens::Row TuiApp::rowOf(const TaskEntry &task) const
{
    const QDate today = QDate::currentDate();
    Screens::Row row;
    row.title = task.summary;
    row.project = task.collectionName;

    const int late = TaskLogic::overdueDays(task, today);
    if (!task.dueDate.isValid()) {
        row.due = Screens::Row::Due::None;
    } else if (late > 0) {
        row.due = Screens::Row::Due::Overdue;
        row.dueLabel = i18np("1 day late", "%1 days late", late);
    } else if (task.dueDate.date() == today) {
        row.due = Screens::Row::Due::Today;
        row.dueLabel = task.allDay ? i18n("today") : QLocale().toString(task.dueDate.time(), QLocale::ShortFormat);
    } else {
        row.due = Screens::Row::Due::Later;
        row.dueLabel = QLocale().toString(task.dueDate.date(), QStringLiteral("ddd d.M."));
    }
    return row;
}

Screens::Words TuiApp::words() const
{
    Screens::Words w;
    w.now = i18n("Now");
    w.soon = i18n("Soon");
    w.someday = i18n("Someday");
    w.empty = i18n("No open tasks. Press a to add one.");
    w.focusKeys = i18n("↑↓ move · x done · t today · m tomorrow · d someday · a add · / search · g go through overdue · q quit");
    w.stackTitle = i18n("Go through overdue");
    w.stackDone = i18n("Nothing overdue.");
    w.stackKeys = i18n("↑ done|← tomorrow          → today|↓ someday");
    return w;
}

QString TuiApp::status() const
{
    if (!m_controller->akonadiAvailable()) {
        return i18n("Akonadi not running");
    }
    return m_controller->loading() ? i18n("Loading…") : QString();
}

void TuiApp::complete(const TaskEntry &task)
{
    m_controller->setTaskCompleted(task.itemId, true);
}

void TuiApp::reschedule(const TaskEntry &task, const QString &preset)
{
    m_controller->rescheduleTask(task.itemId, preset);
}

void TuiApp::clearDue(const TaskEntry &task)
{
    m_controller->updateTaskFull(task.itemId, QVariantMap{{QStringLiteral("clearDue"), true}});
}
