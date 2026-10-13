#include "screens.h"

#include <QStringList>

namespace Screens
{

namespace
{

// SGR colours close to Kante's roles on a dark terminal.
const QString kReset = QStringLiteral("\x1b[0m");
const QString kBold = QStringLiteral("\x1b[1m");
const QString kDim = QStringLiteral("\x1b[2m");
const QString kPrimary = QStringLiteral("\x1b[33m");
const QString kFocus = QStringLiteral("\x1b[36m");
const QString kDanger = QStringLiteral("\x1b[31m");
const QString kInverse = QStringLiteral("\x1b[7m");

constexpr int kDueWidth = 12;
constexpr int kProjectWidth = 16;
constexpr int kChrome = 4; // header, rule, input or message, keys

QString paint(const QString &style, const QString &text)
{
    return style + text + kReset;
}

QString header(const QString &title, const QString &status, int width)
{
    const QString left = QStringLiteral("KURRENT · ") + title;
    const int gap = qMax(1, width - int(left.size()) - int(status.size()));
    return paint(kBold + kPrimary, left) + QString(gap, QLatin1Char(' ')) + paint(kDim, status);
}

QString rule(int width)
{
    return paint(kDim, QString(qMax(0, width), QChar(0x2500)));
}

QString dueStyle(Row::Due due)
{
    switch (due) {
    case Row::Due::Overdue:
        return kDanger;
    case Row::Due::Today:
        return kPrimary;
    default:
        return kDim;
    }
}

// "[ ] Rohschnitt Folge 4          Harbour Lights    seit 23 T"
QString rowLine(const Row &row, int width)
{
    const QString indent(row.indent * 2, QLatin1Char(' '));
    // "[ ] " + title + "  " + project + " " + due
    const int titleWidth = qMax(8, width - kDueWidth - kProjectWidth - 7 - int(indent.size()));
    return QStringLiteral("[ ] ") + indent + fit(row.title, titleWidth) + QStringLiteral("  ")
        + fit(row.project, kProjectWidth) + QStringLiteral(" ") + fit(row.dueLabel, kDueWidth);
}

// Words of `text` in lines of at most `width` characters.
QStringList wrap(const QString &text, int width)
{
    QStringList lines;
    QString line;
    const QStringList words = text.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (const QString &word : words) {
        if (!line.isEmpty() && line.size() + 1 + word.size() > width) {
            lines.append(line);
            line.clear();
        }
        line += (line.isEmpty() ? QString() : QStringLiteral(" ")) + word;
    }
    if (!line.isEmpty()) {
        lines.append(line);
    }
    return lines;
}

QString centered(const QString &text, int width)
{
    const int left = qMax(0, (width - int(text.size())) / 2);
    return QString(left, QLatin1Char(' ')) + text;
}

} // namespace

QString fit(const QString &text, int width)
{
    if (width <= 0) {
        return QString();
    }
    if (text.size() > width) {
        return width > 1 ? text.left(width - 1) + QChar(0x2026) : text.left(width);
    }
    return text + QString(width - text.size(), QLatin1Char(' '));
}

QString focusScreen(const FocusModel &model, const Size &size, const Words &words)
{
    const int w = size.columns;

    // All body lines first, each remembering whether it is the selected row.
    struct Line {
        QString text;
        bool selected = false;
    };
    QList<Line> body;
    int index = 0;
    const auto section = [&](const QString &name, const QList<Row> &rows) {
        body.append({QString(), false});
        body.append({paint(kBold + kPrimary, name.toUpper()) + QStringLiteral(" ")
                         + paint(kDim, QString::number(rows.size())), false});
        for (const Row &row : rows) {
            const bool selected = index == model.selected;
            const QString plain = rowLine(row, w);
            body.append({selected ? paint(kInverse, plain)
                                  : plain.left(plain.size() - kDueWidth) + paint(dueStyle(row.due), plain.right(kDueWidth)),
                         selected});
            ++index;
        }
    };
    section(words.now, model.now);
    section(words.soon, model.soon);
    section(words.someday, model.someday);
    if (index == 0) {
        body.append({paint(kDim, words.empty), false});
    }

    // Scroll so the selected row stays on screen.
    const int room = qMax(1, size.rows - kChrome);
    int first = 0;
    for (int i = 0; i < body.size(); ++i) {
        if (body.at(i).selected && i >= room) {
            first = i - room + 1;
        }
    }

    QStringList lines{header(model.title, model.status, w), rule(w)};
    for (int i = first; i < body.size() && lines.size() < room + 2; ++i) {
        lines.append(body.at(i).text);
    }
    while (lines.size() < size.rows - 2) {
        lines.append(QString());
    }

    if (!model.prompt.isEmpty()) {
        lines.append(paint(kFocus, model.prompt + QStringLiteral(" ")) + model.input + paint(kFocus, QStringLiteral("▌")));
    } else {
        lines.append(model.message.isEmpty() ? QString() : paint(kDanger, fit(model.message, w)));
    }
    lines.append(paint(kDim, fit(words.focusKeys, w)));
    return lines.join(QLatin1Char('\n'));
}

QString stackScreen(const StackModel &model, const Size &size, const Words &words)
{
    const int w = size.columns;
    QStringList lines{header(words.stackTitle, model.status, w), rule(w), QString()};

    if (model.count == 0) {
        lines.append(paint(kPrimary, centered(words.stackDone, w)));
    } else {
        // Progress, then the task large in the middle.
        QString bar;
        for (int i = 0; i < model.count; ++i) {
            bar += i <= model.position ? paint(kPrimary, QStringLiteral("■")) : paint(kDim, QStringLiteral("□"));
        }
        lines.append(bar + QStringLiteral("  ") + paint(kDim, QStringLiteral("%1 / %2").arg(model.position + 1).arg(model.count)));
        lines.append(QString());
        lines.append(QString());
        for (const QString &line : wrap(model.task.title, qMax(10, w - 8))) {
            lines.append(paint(kBold, centered(line, w)));
        }
        lines.append(paint(kDim, centered(model.task.project, w)));
        lines.append(paint(kDanger, centered(model.overdue, w)));
        lines.append(QString());
        lines.append(QString());
        const QStringList keys = words.stackKeys.split(QLatin1Char('|'));
        for (const QString &key : keys) {
            lines.append(paint(kFocus, centered(key, w)));
        }
    }

    while (lines.size() < size.rows - 1) {
        lines.append(QString());
    }
    lines.append(paint(kDim, fit(QStringLiteral("Esc"), w)));
    return lines.join(QLatin1Char('\n'));
}

} // namespace Screens
