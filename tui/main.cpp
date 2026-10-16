#include "taskcontroller.h"
#include "terminal.h"
#include "tuiapp.h"

#include <KLocalizedString>
#include <QCoreApplication>
#include <cstdio>

// kurrent-tui: Kurrent in a terminal. The same TaskController as the widget
// (kurrentcore), without the session services the widget owns.
int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("kurrent-tui"));
    // The widget's catalog: the TUI's texts are translated with it.
    KLocalizedString::setApplicationDomain("plasma_applet_com.github.shrippen.kurrent");

    Terminal terminal;
    if (!terminal.open()) {
        fprintf(stderr, "kurrent-tui needs a terminal\n");
        return 1;
    }

    // The widget keeps the D-Bus name and the global shortcuts.
    TaskController::setSessionServices(TaskController::SessionServices::Off);
    TaskController controller;
    TuiApp tui(&controller, &terminal);

    const int code = app.exec();
    terminal.close();
    return code;
}
