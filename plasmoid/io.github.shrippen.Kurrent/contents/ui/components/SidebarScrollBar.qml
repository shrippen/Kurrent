import QtQuick
import ".."

ThinScrollBar {
    required view

    parent: view
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    // Fit inside the fixed rightMargin (Design.spaceSmall); do not widen the gutter.
    extent: Design.spaceSmall
}
