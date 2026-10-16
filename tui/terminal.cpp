#include "terminal.h"

#include <QCoreApplication>
#include <QSocketNotifier>
#include <QTimer>

#include <csignal>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

namespace {

// ANSI / xterm sequences.
constexpr char kAltScreenOn[] = "\x1b[?1049h\x1b[?25l";
constexpr char kAltScreenOff[] = "\x1b[?25h\x1b[?1049l";
constexpr char kHome[] = "\x1b[H";
constexpr char kClearLineEnd[] = "\x1b[K";
constexpr char kClearScreenEnd[] = "\x1b[J";

constexpr char kEsc = '\x1b';
constexpr char kDelete = '\x7f';
constexpr char kBackspace = '\x08';
constexpr char kCtrlC = '\x03';
constexpr char kCtrlD = '\x04';
constexpr int kSizePollMs = 500;
constexpr int kReadChunk = 256;

// The shell's terminal settings, for the signal handler too.
termios g_saved {};
volatile sig_atomic_t g_raw = 0;

void writeAll(const char *data, size_t length)
{
    while (length > 0) {
        const ssize_t n = ::write(STDOUT_FILENO, data, length);
        if (n <= 0) {
            return;
        }
        data += n;
        length -= size_t(n);
    }
}

void restoreTerminal()
{
    if (!g_raw) {
        return;
    }
    writeAll(kAltScreenOff, sizeof(kAltScreenOff) - 1);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &g_saved);
    g_raw = 0;
}

// Killed while raw: give the shell its terminal back (async-signal-safe calls only).
void onFatalSignal(int sig)
{
    restoreTerminal();
    std::signal(sig, SIG_DFL);
    std::raise(sig);
}

// "\x1b[A" → "up"; the final byte of a CSI sequence names the key.
QString csiKey(char final)
{
    switch (final) {
    case 'A':
        return QStringLiteral("up");
    case 'B':
        return QStringLiteral("down");
    case 'C':
        return QStringLiteral("right");
    case 'D':
        return QStringLiteral("left");
    case 'H':
        return QStringLiteral("home");
    case 'F':
        return QStringLiteral("end");
    default:
        return QString();
    }
}

} // namespace

Terminal::Terminal(QObject *parent)
    : QObject(parent)
{
}

Terminal::~Terminal()
{
    close();
}

bool Terminal::open()
{
    if (m_open) {
        return true;
    }
    if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO) || tcgetattr(STDIN_FILENO, &g_saved) != 0) {
        return false;
    }

    // Raw input, but keep output processing (\n moves to the next line start).
    termios raw = g_saved;
    raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG | IEXTEN);
    raw.c_iflag &= ~tcflag_t(IXON | ICRNL);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != 0) {
        return false;
    }
    g_raw = 1;
    std::signal(SIGTERM, onFatalSignal);
    std::signal(SIGHUP, onFatalSignal);
    writeAll(kAltScreenOn, sizeof(kAltScreenOn) - 1);

    m_input = new QSocketNotifier(STDIN_FILENO, QSocketNotifier::Read, this);
    connect(m_input, &QSocketNotifier::activated, this, &Terminal::readInput);

    // SIGWINCH needs a self-pipe; polling the size is enough for a timer display.
    m_sizeTimer = new QTimer(this);
    m_sizeTimer->setInterval(kSizePollMs);
    connect(m_sizeTimer, &QTimer::timeout, this, &Terminal::checkSize);
    m_sizeTimer->start();
    connect(qApp, &QCoreApplication::aboutToQuit, this, &Terminal::close);

    m_open = true;
    checkSize();
    return true;
}

void Terminal::close()
{
    if (!m_open) {
        return;
    }
    m_open = false;
    delete m_input;
    m_input = nullptr;
    delete m_sizeTimer;
    m_sizeTimer = nullptr;
    restoreTerminal();
}

void Terminal::render(const QString &text)
{
    if (!m_open) {
        return;
    }

    // Overwrite in place (no full clear: no flicker), then clear what is left.
    QByteArray out(kHome);
    const QStringList lines = text.split(QLatin1Char('\n'));
    for (int i = 0; i < lines.size() && i < m_rows; ++i) {
        if (i > 0) {
            out += "\r\n";
        }
        out += lines.at(i).toUtf8();
        out += kClearLineEnd;
    }
    out += kClearScreenEnd;
    writeAll(out.constData(), size_t(out.size()));
}

void Terminal::readInput()
{
    char buffer[kReadChunk];
    QByteArray bytes;
    ssize_t n = 0;
    while ((n = ::read(STDIN_FILENO, buffer, sizeof(buffer))) > 0) {
        bytes.append(buffer, int(n));
    }

    int i = 0;
    while (i < bytes.size()) {
        const char c = bytes.at(i);

        // Escape sequences: "\x1b[A" arrows; a lone ESC is the Escape key.
        if (c == kEsc) {
            const bool csi = i + 2 < bytes.size() && (bytes.at(i + 1) == '[' || bytes.at(i + 1) == 'O');
            if (!csi) {
                emit keyPressed(QStringLiteral("escape"));
                ++i;
                continue;
            }
            int end = i + 2;
            while (end < bytes.size() && !(bytes.at(end) >= '@' && bytes.at(end) <= '~')) {
                ++end;
            }
            const QString key = end < bytes.size() ? csiKey(bytes.at(end)) : QString();
            if (!key.isEmpty()) {
                emit keyPressed(key);
            }
            i = end + 1;
            continue;
        }

        if (c == '\r' || c == '\n') {
            emit keyPressed(QStringLiteral("enter"));
        } else if (c == kDelete || c == kBackspace) {
            emit keyPressed(QStringLiteral("backspace"));
        } else if (c == '\t') {
            emit keyPressed(QStringLiteral("tab"));
        } else if (c == kCtrlC || c == kCtrlD) {
            emit keyPressed(QStringLiteral("quit"));
        } else if (static_cast<unsigned char>(c) >= 0x20) {
            // A whole UTF-8 character ("ä" is two bytes).
            int len = 1;
            const auto lead = static_cast<unsigned char>(c);
            if (lead >= 0xf0) {
                len = 4;
            } else if (lead >= 0xe0) {
                len = 3;
            } else if (lead >= 0xc0) {
                len = 2;
            }
            emit keyPressed(QString::fromUtf8(bytes.mid(i, len)));
            i += len;
            continue;
        }
        ++i;
    }
}

void Terminal::checkSize()
{
    winsize size {};
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) != 0 || size.ws_col == 0) {
        return;
    }
    if (size.ws_col == m_columns && size.ws_row == m_rows) {
        return;
    }
    m_columns = size.ws_col;
    m_rows = size.ws_row;
    emit resized();
}
