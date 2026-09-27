import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "colors.js" as Colors
import "."
import "components"

// Projects, labels and locations on one page with tabs and one shared row (l1).
ConfigPageBase {
    id: root

    ConfigControllerLoader {
        id: configControllerLoader
        Component.onCompleted: refresh()
    }
    readonly property var configController: configControllerLoader.controller

    // Locations count completed tasks too, like the sidebar filter.
    Loader {
        id: locationControllerLoader
        source: Qt.resolvedUrl("PluginController.qml")
        onLoaded: item.showCompleted = true
    }
    readonly property var locationController: locationControllerLoader.item

    readonly property int switchColumn: Kirigami.Units.gridUnit * 5

    // ── Separated lists ("a||b", "1,2") ──
    function tokenSet(raw, sep) {
        var s = {}
        String(raw || "").split(sep).forEach(function(v) {
            v = v.trim()
            if (v !== "") s[v] = true
        })
        return s
    }
    function toggleToken(raw, sep, key) {
        var s = tokenSet(raw, sep)
        if (s[key]) delete s[key]; else s[key] = true
        return Object.keys(s).join(sep)
    }
    function colorOf(json, key) {
        try {
            return JSON.parse(json || "{}")[key] || ""
        } catch (e) {
            return ""
        }
    }
    function matches(name) {
        var q = searchField.text.trim().toLowerCase()
        return q.length === 0 || String(name).toLowerCase().indexOf(q) >= 0
    }

    // ── Projects ──
    function writableIds() {
        var m = configController ? configController.collectionModel : null
        var ids = []
        if (m) for (var i = 0; i < m.count; ++i) if (m.writableAt(i)) ids.push(String(m.collectionIdAt(i)))
        return ids
    }
    function isEnabled(id) {
        var s = tokenSet(cfg_enabledCollections, ",")
        return Object.keys(s).length === 0 || !!s[String(id)]
    }
    function toggleEnabled(id) {
        var s = tokenSet(cfg_enabledCollections, ",")
        var key = String(id)
        var all = writableIds()
        if (Object.keys(s).length === 0) {
            cfg_enabledCollections = all.filter(function(k) { return k !== key }).join(",")
            return
        }
        if (s[key]) delete s[key]; else s[key] = true
        var arr = Object.keys(s)
        cfg_enabledCollections = arr.length >= all.length ? "" : arr.join(",")
    }
    function isDefaultProject(id) {
        return cfg_newTaskProjectMode === "fixed" && Number(cfg_newTaskDefaultCollectionId) === Number(id)
    }

    ConfigFormShell {
        id: shell

        PluginMissingView {
            visible: configControllerLoader.status === Loader.Error
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
        }

        QQC2.TabBar {
            id: tabs
            Layout.fillWidth: true
            QQC2.TabButton { text: i18n("Projects") }
            QQC2.TabButton { text: i18n("Labels") }
            QQC2.TabButton { text: i18n("Locations") }
        }

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
        }

        // As tall as the current tab, not the tallest one.
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.preferredHeight: children[currentIndex] ? children[currentIndex].implicitHeight : 0
            currentIndex: tabs.currentIndex

            // ── Projects ──
            ColumnLayout {
                spacing: 0

                ConfigHint {
                    text: i18n("Off under “Load”: the calendar is not read at all. Off under “Sidebar”: its tasks load but the project is not listed.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [i18n("Load"), i18n("Sidebar")]
                        QQC2.Label {
                            required property string modelData
                            Layout.preferredWidth: root.switchColumn
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                    Item { Layout.preferredWidth: Kirigami.Units.iconSizes.medium * 2 }
                }

                Repeater {
                    model: configController ? configController.collectionModel : 0
                    delegate: OrganizeRow {
                        required property var model
                        visible: model.writable && root.matches(model.name)
                        name: model.name
                        count: model.taskCount
                        iconName: "folder"
                        autoColor: Colors.colorForKey(String(model.collectionId))
                        colorValue: root.colorOf(root.cfg_projectColors, String(model.collectionId))
                        renamable: false
                        deletable: false
                        onColorPicked: function(hex) {
                            if (configController) {
                                root.cfg_projectColors = configController.setColorOverride(root.cfg_projectColors || "", String(model.collectionId), hex)
                            }
                        }

                        Item {
                            Layout.preferredWidth: root.switchColumn
                            implicitHeight: loadSwitch.implicitHeight
                            QQC2.Switch {
                                id: loadSwitch
                                anchors.centerIn: parent
                                checked: root.isEnabled(model.collectionId)
                                onToggled: root.toggleEnabled(model.collectionId)
                                QQC2.ToolTip.text: i18n("Read this calendar when loading tasks")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                        Item {
                            Layout.preferredWidth: root.switchColumn
                            implicitHeight: loadSwitch.implicitHeight
                            QQC2.Switch {
                                anchors.centerIn: parent
                                enabled: loadSwitch.checked
                                checked: !root.tokenSet(root.cfg_hiddenProjects, ",")[String(model.collectionId)]
                                onToggled: root.cfg_hiddenProjects = root.toggleToken(root.cfg_hiddenProjects, ",", String(model.collectionId))
                                QQC2.ToolTip.text: i18n("Show this project in the sidebar")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                        // Default project for new tasks (i4).
                        QQC2.ToolButton {
                            icon.name: root.isDefaultProject(model.collectionId) ? "starred-symbolic" : "non-starred-symbolic"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18n("Default project for new tasks")
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            onClicked: {
                                root.cfg_newTaskProjectMode = "fixed"
                                root.cfg_newTaskDefaultCollectionId = String(model.collectionId)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    QQC2.Button { text: i18n("Enable All"); icon.name: "checkbox"; onClicked: root.cfg_enabledCollections = "" }
                    QQC2.Button { text: i18n("Show All"); icon.name: "view-visible"; onClicked: root.cfg_hiddenProjects = "" }
                }
            }

            // ── Labels ──
            ColumnLayout {
                spacing: 0

                ConfigHint {
                    text: i18n("Labels are task categories in Akonadi. Hidden labels stay on the tasks but are not listed in the sidebar.")
                }

                Repeater {
                    model: configController ? configController.availableLabels : []
                    delegate: OrganizeRow {
                        required property string modelData
                        visible: root.matches(modelData)
                        name: modelData
                        count: {
                            var n = configController ? configController.labelTaskCounts[modelData] : 0
                            return n ? Number(n) : 0
                        }
                        iconName: "tag"
                        autoColor: Colors.colorForKey(modelData, "label")
                        colorValue: root.colorOf(root.cfg_labelColors, modelData)
                        onColorPicked: function(hex) {
                            root.cfg_labelColors = configController.setColorOverride(root.cfg_labelColors || "", modelData, hex)
                        }
                        onRenameRequested: function(dest) {
                            configController.renameLabel(modelData, dest)
                            root.cfg_hiddenLabels = configController.renameSeparatedList(root.cfg_hiddenLabels || "", modelData, dest, "||")
                            root.cfg_labelColors = configController.moveColorKey(root.cfg_labelColors || "", modelData, dest)
                        }
                        onDeleteRequested: configController.deleteLabel(modelData)

                        QQC2.Switch {
                            checked: !root.tokenSet(root.cfg_hiddenLabels, "||")[modelData]
                            onToggled: root.cfg_hiddenLabels = root.toggleToken(root.cfg_hiddenLabels, "||", modelData)
                            QQC2.ToolTip.text: i18n("Show this label in the sidebar filter")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    QQC2.TextField {
                        id: newLabelField
                        Layout.fillWidth: true
                        placeholderText: i18n("New label")
                        onAccepted: addLabelButton.clicked()
                    }
                    QQC2.Button {
                        id: addLabelButton
                        text: i18n("Add label")
                        icon.name: "list-add"
                        enabled: newLabelField.text.trim().length > 0
                        onClicked: {
                            configController.createLabel(newLabelField.text.trim())
                            newLabelField.text = ""
                        }
                    }
                    QQC2.Button { text: i18n("Show All"); icon.name: "view-visible"; onClicked: root.cfg_hiddenLabels = "" }
                }
            }

            // ── Locations ──
            ColumnLayout {
                spacing: 0

                ConfigHint {
                    text: i18n("Locations come from the task’s location field. Hidden locations stay on the tasks but are not listed in the sidebar.")
                }

                Repeater {
                    model: locationController ? locationController.availableLocations : []
                    delegate: OrganizeRow {
                        required property string modelData
                        visible: root.matches(modelData)
                        name: modelData
                        count: {
                            var n = locationController ? locationController.sidebarLocationCounts[modelData] : 0
                            return n ? Number(n) : 0
                        }
                        iconName: "mark-location"
                        autoColor: Colors.colorForKey(modelData, "location")
                        colorValue: root.colorOf(root.cfg_locationColors, modelData)
                        onColorPicked: function(hex) {
                            root.cfg_locationColors = locationController.setColorOverride(root.cfg_locationColors || "", modelData, hex)
                        }
                        onRenameRequested: function(dest) {
                            locationController.renameLocation(modelData, dest)
                            root.cfg_hiddenLocations = locationController.renameSeparatedList(root.cfg_hiddenLocations || "", modelData, dest, "||")
                            root.cfg_locationColors = locationController.moveColorKey(root.cfg_locationColors || "", modelData, dest)
                        }
                        onDeleteRequested: locationController.deleteLocation(modelData)

                        QQC2.Switch {
                            checked: !root.tokenSet(root.cfg_hiddenLocations, "||")[modelData]
                            onToggled: root.cfg_hiddenLocations = root.toggleToken(root.cfg_hiddenLocations, "||", modelData)
                            QQC2.ToolTip.text: i18n("Show this location in the sidebar filter")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    QQC2.TextField {
                        id: newLocationField
                        Layout.fillWidth: true
                        placeholderText: i18n("New location")
                        onAccepted: addLocationButton.clicked()
                    }
                    QQC2.Button {
                        id: addLocationButton
                        text: i18n("Add location")
                        icon.name: "list-add"
                        enabled: newLocationField.text.trim().length > 0
                        onClicked: {
                            locationController.createLocation(newLocationField.text.trim())
                            newLocationField.text = ""
                        }
                    }
                    QQC2.Button { text: i18n("Show All"); icon.name: "view-visible"; onClicked: root.cfg_hiddenLocations = "" }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            ConfigResetButton {
                page: root
                defaults: ({
                    enabledCollections: "",
                    hiddenProjects: "",
                    hiddenLabels: "",
                    hiddenLocations: "",
                    projectColors: "",
                    labelColors: "",
                    locationColors: ""
                })
            }
            Item { Layout.fillWidth: true }
            QQC2.Button {
                Layout.topMargin: Kirigami.Units.largeSpacing
                text: i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: {
                    if (configController) configController.refresh()
                    if (locationController && locationController.refresh) locationController.refresh()
                }
            }
        }
    }
}
