#include "screens.h"

#include <QRegularExpression>
#include <QtTest>

// kurrent-tui screens: lines fit the terminal, sections and the triage card.
class TuiScreensTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void fitPadsAndCuts();
    void focusScreenSectionsAndSelection();
    void stackScreenShowsTaskOrDone();

private:
    static QStringList plainLines(const QString &text)
    {
        QString plain = text;
        plain.remove(QRegularExpression(QStringLiteral("\x1b\\[[0-9;?]*[A-Za-z]")));
        return plain.split(QLatin1Char('\n'));
    }

    static Screens::Words words()
    {
        Screens::Words w;
        w.now = QStringLiteral("Now");
        w.soon = QStringLiteral("Soon");
        w.someday = QStringLiteral("Someday");
        w.empty = QStringLiteral("No open tasks");
        w.focusKeys = QStringLiteral("keys");
        w.stackTitle = QStringLiteral("Go through overdue");
        w.stackDone = QStringLiteral("Nothing overdue.");
        w.stackKeys = QStringLiteral("up|left right|down");
        return w;
    }
};

void TuiScreensTest::fitPadsAndCuts()
{
    QCOMPARE(Screens::fit(QStringLiteral("abc"), 5), QStringLiteral("abc  "));
    QCOMPARE(Screens::fit(QStringLiteral("abcdef"), 4), QStringLiteral("abc") + QChar(0x2026));
    QCOMPARE(Screens::fit(QStringLiteral("abc"), 0), QString());
}

void TuiScreensTest::focusScreenSectionsAndSelection()
{
    Screens::FocusModel model;
    Screens::Row late;
    late.title = QStringLiteral("Rohschnitt Folge 4 an Northlight schicken");
    late.project = QStringLiteral("Harbour Lights");
    late.dueLabel = QStringLiteral("23 days late");
    late.due = Screens::Row::Due::Overdue;
    Screens::Row later = late;
    later.title = QStringLiteral("Drehplan Folge 6");
    later.due = Screens::Row::Due::Later;
    model.now = {late};
    model.soon = {later};
    model.selected = 1;
    model.title = QStringLiteral("Wednesday");

    const Screens::Size size{70, 16};
    const QString text = Screens::focusScreen(model, size, words());
    const QStringList lines = plainLines(text);

    QCOMPARE(lines.size(), size.rows);
    QVERIFY(lines.contains(QStringLiteral("NOW 1")));
    QVERIFY(lines.contains(QStringLiteral("SOON 1")));
    QVERIFY(lines.contains(QStringLiteral("SOMEDAY 0")));
    for (const QString &line : lines) {
        QVERIFY2(line.size() <= size.columns, qPrintable(line));
    }
    // The selected row (index 1: "Drehplan") is drawn inverted.
    QVERIFY(text.contains(QStringLiteral("\x1b[7m[ ] Drehplan")));
}

void TuiScreensTest::stackScreenShowsTaskOrDone()
{
    Screens::StackModel model;
    model.count = 3;
    model.task.title = QStringLiteral("Drehgenehmigung Landungsbrücken beantragen");
    model.task.project = QStringLiteral("Harbour Lights");
    model.overdue = QStringLiteral("25 days overdue");

    const Screens::Size size{60, 20};
    QStringList lines = plainLines(Screens::stackScreen(model, size, words()));
    QCOMPARE(lines.size(), size.rows);
    QVERIFY(lines.at(3).endsWith(QStringLiteral("1 / 3")));
    QVERIFY(std::any_of(lines.cbegin(), lines.cend(), [](const QString &l) { return l.trimmed() == QStringLiteral("25 days overdue"); }));

    model.count = 0;
    lines = plainLines(Screens::stackScreen(model, size, words()));
    QVERIFY(std::any_of(lines.cbegin(), lines.cend(), [](const QString &l) { return l.trimmed() == QStringLiteral("Nothing overdue."); }));
}

QTEST_GUILESS_MAIN(TuiScreensTest)
#include "tui_screens_test.moc"
