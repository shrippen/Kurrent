#pragma once

#include <QDate>
#include <QList>
#include <QString>

// Screens of kurrent-tui as text: pure functions from a model to lines with
// ANSI colours. TuiApp builds the models from the TaskController; nothing
// here knows Akonadi.
//
//   TaskController ─TuiApp─▶ FocusModel / StackModel ─focusScreen() / stackScreen()─▶ Terminal

namespace Screens
{

struct Size {
    int columns = 80;
    int rows = 24;
};

/** One task row: title, project, due label, how urgent it is. */
struct Row {
    enum class Due { None, Overdue, Today, Later };

    QString title;
    QString project;
    QString dueLabel;
    Due due = Due::None;
    int indent = 0;
};

/** The Focus layout: Now, Soon, Someday. */
struct FocusModel {
    QList<Row> now;
    QList<Row> soon;
    QList<Row> someday;
    /** Index over now + soon + someday. */
    int selected = 0;
    QString title;
    QString status;
    /** Quick Add or search text being typed; empty prompt = no input line. */
    QString prompt;
    QString input;
    QString message;
};

/** The Stack layout: one overdue task at a time. */
struct StackModel {
    Row task;
    int position = 0;
    int count = 0;
    /** "23 days overdue", already in the user's language. */
    QString overdue;
    QString status;
};

/** Words in the user's language, from TuiApp (i18n). */
struct Words {
    QString now;
    QString soon;
    QString someday;
    QString empty;
    QString focusKeys;
    QString stackTitle;
    QString stackDone;
    QString stackKeys;
};

QString fit(const QString &text, int width);
QString focusScreen(const FocusModel &model, const Size &size, const Words &words);
QString stackScreen(const StackModel &model, const Size &size, const Words &words);

} // namespace Screens
