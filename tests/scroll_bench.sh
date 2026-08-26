#!/usr/bin/env bash
# Micro-benchmark: ListView scroll cost (reuse / cache / hover).
# Compiles a small Qt harness under /tmp and prints BENCH_RESULT lines.
set -euo pipefail

CXX="${CXX:-g++}"
OUT="${TMPDIR:-/tmp}/kurrent-scroll-bench-$$"
mkdir -p "$OUT"
trap 'rm -rf "$OUT"' EXIT

QML_PKGS=$(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Gui Qt6Core)

cat > "$OUT/bench.cpp" <<'CPP'
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QElapsedTimer>
#include <QTextStream>
#include <QFile>

int main(int argc, char **argv)
{
    if (qgetenv("QT_QPA_PLATFORM").isEmpty())
        qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);

    bool reuse = true;
    int cachePx = 1280;
    bool hoverDuring = false;
    const int steps = 240;
    const qreal stepPx = 28;
    for (int i = 1; i < argc; ++i) {
        const QByteArray a = argv[i];
        if (a == "--no-reuse") reuse = false;
        if (a == "--reuse") reuse = true;
        if (a == "--cache-small") cachePx = 108;
        if (a == "--cache-large") cachePx = 1280;
        if (a == "--hover-on") hoverDuring = true;
        if (a == "--hover-off") hoverDuring = false;
    }

    const char *qml = R"QML(
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
Window {
    width: 480; height: 640; visible: true
    ListModel { id: tasks }
    ListView {
        id: list
        objectName: "benchList"
        anchors.fill: parent
        model: tasks
        reuseItems: benchReuse
        cacheBuffer: benchCache
        property bool kineticScrolling: false
        delegate: Item {
            width: list.width; height: 52
            readonly property bool listMoving: list.moving || list.flicking || list.kineticScrolling
            Rectangle {
                anchors.fill: parent; anchors.margins: 2; radius: 4; color: "#333"
                RowLayout {
                    anchors.fill: parent; anchors.margins: 6; spacing: 8
                    Rectangle { width: 18; height: 18; radius: 3; color: "#666" }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Label { Layout.fillWidth: true; text: model.title; color: "white"; elide: Text.ElideRight }
                        Label { Layout.fillWidth: true; text: model.sub; color: "#aaa"; font.pixelSize: 11 }
                    }
                    Rectangle { width: 22; height: 22; radius: 4; color: "#555" }
                }
            }
            HoverHandler { enabled: benchHover || !parent.listMoving }
            HoverHandler { enabled: benchHover || !parent.listMoving }
            HoverHandler { enabled: benchHover || !parent.listMoving }
            HoverHandler { enabled: benchHover || !parent.listMoving }
        }
        Component.onCompleted: {
            for (var i = 0; i < 400; ++i)
                tasks.append({ title: "Task " + i, sub: "d" + (i % 7) })
        }
    }
}
)QML";

    QFile f(QString::fromUtf8(OUT) + QStringLiteral("/bench.qml"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return 2;
    f.write(qml);
    f.close();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("benchReuse"), reuse);
    engine.rootContext()->setContextProperty(QStringLiteral("benchCache"), cachePx);
    engine.rootContext()->setContextProperty(QStringLiteral("benchHover"), hoverDuring);
    engine.load(f.fileName());
    if (engine.rootObjects().isEmpty())
        return 1;
    QObject *root = engine.rootObjects().constFirst();

    QQuickItem *list = nullptr;
    for (int i = 0; i < 100; ++i) {
        app.processEvents();
        list = root->findChild<QQuickItem *>(QStringLiteral("benchList"));
        if (list && list->property("contentHeight").toReal() > 1000)
            break;
    }
    if (!list)
        return 3;

    for (int i = 0; i < 20; ++i) {
        list->setProperty("contentY", qreal(i * stepPx));
        app.processEvents();
    }
    list->setProperty("contentY", 0);
    app.processEvents();

    qreal dir = 1;
    QElapsedTimer t;
    t.start();
    for (int step = 0; step < steps; ++step) {
        list->setProperty("kineticScrolling", !hoverDuring);
        const qreal maxY = qMax<qreal>(0, list->property("contentHeight").toReal() - list->height());
        qreal y = list->property("contentY").toReal() + dir * stepPx;
        if (y >= maxY) { y = maxY; dir = -1; }
        else if (y <= 0) { y = 0; dir = 1; }
        list->setProperty("contentY", y);
        app.processEvents();
    }
    QTextStream(stdout) << "BENCH_RESULT ms=" << t.elapsed()
                        << " reuse=" << list->property("reuseItems").toBool()
                        << " cache=" << list->property("cacheBuffer").toInt()
                        << " hoverDuring=" << hoverDuring
                        << " steps=" << steps << '\n';
    return 0;
}
CPP

# Inject OUT path for QML file location
sed -i "s|QString::fromUtf8(OUT)|QStringLiteral(\"$OUT\")|" "$OUT/bench.cpp"

"$CXX" -O2 -std=c++17 "$OUT/bench.cpp" -o "$OUT/bench" $QML_PKGS

echo "Scroll bench (400 rows, 240 steps, offscreen):"
for args in "--no-reuse --cache-small --hover-on" \
            "--reuse --cache-large --hover-off"; do
  echo "=== $args ==="
  QT_QPA_PLATFORM=offscreen "$OUT/bench" $args
done
