import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import ".."

// View-mode picker: compact menu button, or expanded icon strip in chrome.
// The list-group button lives in FullView headerTools (between toolbar and sort).
RowLayout {
    id: root

    required property var fullRoot
    required property var plasmoidRoot
    property var mainPaneHost: null
    property bool expanded: false

    readonly property alias compactViewModeButton: compactViewModeButton
    // QML cannot track deep property changes through two layers of
    // `var`-typed references (fullRoot.backend.mainPaneMode).  We use
    // optimistic updates + a polling fallback to stay in sync.
    property string currentMode: Design.viewModeList
    readonly property bool listMode: currentMode === Design.viewModeList

    // 1) Optimistic update: set immediately when the user clicks a button.
    //    This gives instant visual feedback regardless of signal propagation.
    // 2) Connections on the full root for mode changes from other sources
    //    (keyboard shortcuts, programmatic).
    Connections {
        target: fullRoot
        function onBackendChanged() {
            root._syncModeFromBackend()
        }
    }

    // Polling fallback: catches any missed signal and startup state.
    // Runs at 500ms intervals but only reads the property – negligible cost.
    Timer {
        id: syncTimer
        interval: 500
        repeat: true
        running: !!fullRoot.backend
        onTriggered: root._syncModeFromBackend()
        Component.onCompleted: root._syncModeFromBackend()
    }

    function _syncModeFromBackend() {
        if (!fullRoot.backend) {
            return
        }
        var raw = fullRoot.backend.mainPaneMode
        if (raw && raw !== root.currentMode) {
            root.currentMode = raw
        }
    }

    readonly property int toolSize: Design.mainPaneHeaderToolSize
    readonly property int viewModeCount: fullRoot ? fullRoot.viewModeOptions.length : 0
    readonly property int expandedChromeWidth:
            viewModeCount * toolSize + Design.viewModeToolbarChromePadH * 2

    readonly property var viewModeMap: {
        if (!fullRoot || !fullRoot.backend) {
            return {}
        }
        var map = {}
        var options = fullRoot.viewModeOptions
        for (var i = 0; i < options.length; ++i) {
            map[options[i].id] = options[i]
        }
        return map
    }

    function isActiveMode(modeId) {
        return currentMode === modeId
    }

    Component.onCompleted: {
        if (fullRoot.backend) {
            root.currentMode = fullRoot.backend.mainPaneMode || Design.viewModeList
        }
    }

    spacing: 0
    implicitWidth: expanded ? expandedChromeWidth : toolSize
    implicitHeight: toolSize + (expanded ? Design.viewModeToolbarChromePadV * 2 : 0)
    Layout.alignment: Qt.AlignVCenter
    Layout.fillWidth: false
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    visible: !!fullRoot.backend
    clip: false

    function activeViewModeIcon() {
        if (!fullRoot || !fullRoot.backend) {
            return "view-list-details"
        }
        var options = fullRoot.viewModeOptions
        for (var i = 0; i < options.length; ++i) {
            if (options[i].id === fullRoot.backend.mainPaneMode) {
                return options[i].icon
            }
        }
        return "view-list-details"
    }

    function selectViewMode(modeId) {
        // Optimistic update: immediate visual feedback.
        root.currentMode = modeId
        mainPaneHost.beginViewTransition(modeId)
        if (plasmoidRoot) {
            plasmoidRoot.setMainPaneMode(modeId)
        } else if (fullRoot && fullRoot.backend) {
            // Fallback: plasmoidRoot is unavailable (QML scoping issue
            // with required property in externally loaded component).
            // Set backend directly – persist config so the value survives.
            if (typeof Plasmoid !== "undefined" && Plasmoid.configuration) {
                Plasmoid.configuration.mainPaneMode = modeId || "list"
            }
            fullRoot.backend.mainPaneMode = modeId
        }
    }

    QQC2.ToolButton {
        id: compactViewModeButton
        visible: !root.expanded
        Layout.preferredWidth: root.toolSize
        Layout.preferredHeight: root.toolSize
        Layout.minimumWidth: root.toolSize
        icon.name: root.activeViewModeIcon()
        display: QQC2.AbstractButton.IconOnly
        onClicked: fullRoot.openViewModeMenu()
        QQC2.ToolTip.text: fullRoot.backend ? i18n("View mode: %1", fullRoot.viewModeLabel(fullRoot.backend.mainPaneMode)) : ""
        QQC2.ToolTip.visible: hovered
    }

    Rectangle {
        id: expandedStrip
        visible: root.expanded && !!fullRoot.backend
        Layout.preferredWidth: root.expandedChromeWidth
        Layout.preferredHeight: root.toolSize + Design.viewModeToolbarChromePadV * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight
        Layout.alignment: Qt.AlignVCenter
        radius: Design.inputRadius
        color: Qt.rgba(Kirigami.Theme.textColor.r,
                       Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b,
                       Design.viewModeToolbarFillOpacity)
        border.color: Design.windowBorderColor()
        border.width: 1

        Row {
            id: stripLayout
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: fullRoot.viewModeOptions
                delegate: QQC2.ToolButton {
                    required property var modelData
                    width: root.toolSize
                    height: root.toolSize
                    display: QQC2.AbstractButton.IconOnly
                    hoverEnabled: true
                    onClicked: root.selectViewMode(modelData.id)

                    readonly property bool isActive: root.currentMode === modelData.id

                    contentItem: Kirigami.Icon {
                        source: modelData.icon
                        isMask: true
                        color: isActive
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.textColor
                        implicitWidth: root.toolSize - Design.spaceSmall * 2
                        implicitHeight: root.toolSize - Design.spaceSmall * 2
                    }

                    background: Rectangle {
                        radius: Design.inputRadius
                        color: {
                            if (parent && parent.down) {
                                return Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b,
                                               Design.viewModeToolbarFillOpacity * 1.5)
                            }
                            if (isActive) {
                                return Qt.rgba(Kirigami.Theme.highlightColor.r,
                                               Kirigami.Theme.highlightColor.g,
                                               Kirigami.Theme.highlightColor.b, 0.15)
                            }
                            if (parent && parent.hovered) {
                                return Qt.rgba(Kirigami.Theme.textColor.r,
                                               Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b,
                                               Design.viewModeToolbarFillOpacity)
                            }
                            return "transparent"
                        }
                    }
                    QQC2.ToolTip.text: modelData.label
                    QQC2.ToolTip.visible: hovered
                }
            }
        }
    }
}