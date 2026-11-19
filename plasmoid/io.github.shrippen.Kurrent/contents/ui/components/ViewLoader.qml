import QtQuick 2.15

// A Loader that builds its view asynchronously, so a frame is never blocked. The smoke
// test is the one exception: it needs the whole tree at once to measure it.
Loader {
    property var controller

    asynchronous: !controller || !controller.smokeTest
}
