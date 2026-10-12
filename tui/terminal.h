#pragma once

#include <QObject>
#include <QString>

class QSocketNotifier;
class QTimer;

// -- Terminal: raw keyboard input and screen output for kurrent-tui ----------
// POSIX termios raw mode and ANSI escapes (Kurrent runs where Plasma runs).
//
//   stdin ──QSocketNotifier──▶ parse bytes ──▶ keyPressed("up" | "enter" | "a" …)
//   QML render(text) ──▶ alternate screen, cursor home, write
class Terminal : public QObject {
    Q_OBJECT
    Q_PROPERTY(int columns READ columns NOTIFY resized)
    Q_PROPERTY(int rows READ rows NOTIFY resized)

public:
    explicit Terminal(QObject *parent = nullptr);
    ~Terminal() override;

    /** Raw mode and the alternate screen; false when stdin is no terminal. */
    bool open();
    /** Back to the shell's screen and line mode. Safe to call twice. */
    void close();

    int columns() const { return m_columns; }
    int rows() const { return m_rows; }

    /** Replaces the screen with `text` (lines separated by \n, ANSI colours allowed). */
    Q_INVOKABLE void render(const QString &text);

signals:
    /** Named keys: up, down, left, right, enter, escape, backspace, tab; else the character. */
    void keyPressed(const QString &key);
    void resized();

private:
    void readInput();
    void checkSize();

    QSocketNotifier *m_input = nullptr;
    QTimer *m_sizeTimer = nullptr;
    int m_columns = 80;
    int m_rows = 24;
    bool m_open = false;
};
