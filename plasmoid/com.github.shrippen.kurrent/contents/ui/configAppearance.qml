import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import "components"
import "Kante"

ConfigPageBase {
    id: root


    function selectCombo(combo, value) {
        for (var i = 0; i < combo.model.length; ++i) {
            if (combo.model[i].value === value) {
                combo.currentIndex = i
                return
            }
        }
    }

    function syncControls() {
        selectCombo(densityCombo, cfg_density || "auto")
        selectCombo(overlayDimCombo, String(cfg_overlayDimStep))
    }

    readonly property string currentStyle: cfg_uiStyle || "plasma"

    // Kante previews follow the platform brightness like KanteStyle does (Gruvbox dark or Leinen).
    readonly property QtObject kantePalette: KanteStyle.light ? KantePalette.light : KantePalette.dark

    // Miniature of each style for the picker. System and Kante Light borrow the live colour
    // scheme (that is what they use); Kante shows its own palette.
    readonly property var styleOptions: [
        {
            value: "plasma",
            title: i18n("Plasma (default)"),
            text: i18n("Follows your colour scheme, light or dark. Feels like any other KDE app."),
            ground: Kirigami.Theme.backgroundColor,
            side: Kirigami.Theme.alternateBackgroundColor,
            active: Kirigami.Theme.highlightColor,
            line: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25),
            ink: Kirigami.Theme.textColor,
            square: false,
            kanteTitle: false,
            cut: false
        },
        {
            value: "kante",
            title: i18n("Kante"),
            text: i18n("Gruvbox, or Leinen on a light colour scheme. Condensed titles, cut corners, square controls. Uses its own palette."),
            ground: kantePalette.ground,
            side: kantePalette.sunken,
            active: kantePalette.accent,
            line: kantePalette.frame,
            ink: kantePalette.strongText,
            square: true,
            kanteTitle: true,
            cut: true
        },
        {
            value: "kanteLight",
            title: i18n("Kante Light"),
            text: i18n("Kante shapes and type on your colour scheme. Controls and colours stay Plasma's."),
            ground: Kirigami.Theme.backgroundColor,
            side: Kirigami.Theme.alternateBackgroundColor,
            active: Kirigami.Theme.highlightColor,
            line: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25),
            ink: Kirigami.Theme.textColor,
            square: false,
            kanteTitle: true,
            cut: true
        }
    ]

    ConfigFormShell {

        Kirigami.FormLayout {
            Layout.fillWidth: true

            // Three equal cards in one row; below 30 grid units they stack (b1).
            GridLayout {
                id: styleFlow
                Kirigami.FormData.label: i18n("Style")
                Kirigami.FormData.labelAlignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                Layout.maximumWidth: Kirigami.Units.gridUnit * 34
                columns: width >= Kirigami.Units.gridUnit * 21 ? 3 : 1
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.largeSpacing

                QQC2.ButtonGroup { id: styleGroup }

                Repeater {
                    model: root.styleOptions

                    delegate: QQC2.AbstractButton {
                        id: styleCard
                        required property var modelData
                        readonly property bool current: root.currentStyle === modelData.value

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 7
                        checkable: true
                        checked: current
                        QQC2.ButtonGroup.group: styleGroup
                        hoverEnabled: true
                        padding: Kirigami.Units.smallSpacing
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.title
                        Accessible.description: modelData.text
                        onClicked: root.cfg_uiStyle = modelData.value

                        background: Rectangle {
                            radius: Kirigami.Units.cornerRadius
                            color: Kirigami.Theme.backgroundColor
                            border.width: styleCard.current ? 2 : 1
                            border.color: styleCard.current || styleCard.visualFocus
                                          ? Kirigami.Theme.highlightColor
                                          : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                    Kirigami.Theme.textColor.b, styleCard.hovered ? 0.35 : 0.18)
                        }

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            // Miniature: sidebar with an active row, title, three task rows on a card.
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 5

                                Rectangle {
                                    anchors.fill: parent
                                    visible: !styleCard.modelData.cut
                                    radius: Kirigami.Units.cornerRadius
                                    color: styleCard.modelData.ground
                                    border.width: 1
                                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                          Kirigami.Theme.textColor.b, 0.15)
                                }

                                KanteCard {
                                    anchors.fill: parent
                                    visible: styleCard.modelData.cut
                                    chamfer: Math.round(Kirigami.Units.gridUnit * 0.6)
                                    color: styleCard.modelData.ground
                                    borderColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                         Kirigami.Theme.textColor.b, 0.15)
                                    barColor: styleCard.modelData.active
                                    barHeight: 2
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    anchors.topMargin: styleCard.modelData.cut ? 3 : 1
                                    spacing: 0

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: parent.width * 0.3
                                        color: styleCard.modelData.side

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: Kirigami.Units.smallSpacing
                                            spacing: Kirigami.Units.smallSpacing
                                            Rectangle {
                                                width: parent.width
                                                height: Kirigami.Units.smallSpacing * 1.5
                                                radius: styleCard.modelData.square ? 0 : 2
                                                color: styleCard.modelData.active
                                            }
                                            Repeater {
                                                model: 3
                                                Rectangle {
                                                    width: parent.width * 0.8
                                                    height: 3
                                                    color: styleCard.modelData.line
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.margins: Kirigami.Units.smallSpacing
                                        spacing: Kirigami.Units.smallSpacing

                                        QQC2.Label {
                                            text: i18n("Inbox")
                                            color: styleCard.modelData.ink
                                            font: styleCard.modelData.kanteTitle
                                                  ? KanteStyle.kanteHeading(Kirigami.Theme.smallFont.pointSize * 1.2)
                                                  : Qt.font({ family: Kirigami.Theme.defaultFont.family,
                                                              pointSize: Kirigami.Theme.smallFont.pointSize, bold: true })
                                        }

                                        Repeater {
                                            model: 3
                                            RowLayout {
                                                spacing: Kirigami.Units.smallSpacing
                                                Rectangle {
                                                    Layout.preferredWidth: 8
                                                    Layout.preferredHeight: 8
                                                    radius: styleCard.modelData.square ? 0 : 2
                                                    color: "transparent"
                                                    border.width: 1
                                                    border.color: styleCard.modelData.ink
                                                }
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 3
                                                    color: styleCard.modelData.line
                                                }
                                            }
                                        }
                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                QQC2.RadioButton {
                                    checked: styleCard.current
                                    onClicked: root.cfg_uiStyle = styleCard.modelData.value
                                    focusPolicy: Qt.NoFocus
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: styleCard.modelData.title
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: styleCard.modelData.text
                                wrapMode: Text.WordWrap
                                opacity: 0.7
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                    }
                }
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Accent colours")
                text: i18n("Project and label colours")
                checked: root.cfg_accentProjectColors
                onToggled: root.cfg_accentProjectColors = checked
            }

            QQC2.CheckBox {
                text: i18n("Priority colours (red · yellow · blue)")
                checked: root.cfg_accentPriorityColors
                onToggled: root.cfg_accentPriorityColors = checked
            }

            ConfigHint {
                text: root.currentStyle === "kante"
                      ? i18n("Kante uses its own palette for the whole widget; priorities use its red, yellow and blue.")
                      : i18n("Everything else — surfaces, text, selection, buttons — comes from your Plasma colour scheme.")
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
            }

            QQC2.CheckBox {
                id: blurBackgroundCheck
                Kirigami.FormData.label: i18n("Background")
                text: i18n("Translucent with blurred wallpaper")
                checked: root.cfg_blurBackground
                onToggled: root.cfg_blurBackground = checked
            }

            ConfigHint {
                text: i18n("Applies to every style and the panel flyout: Kurrent never paints its own background, Kante surfaces are tints on top. On the desktop the widget stays translucent either way; the flyout turns opaque when this is off.")
            }

            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Wide layout")
                text: i18n("Tiles with the key views above the tasks")
                checked: root.cfg_showViewTiles
                onToggled: root.cfg_showViewTiles = checked
            }

            QQC2.CheckBox {
                text: i18n("Inspector beside the list")
                checked: root.cfg_showInspector
                onToggled: root.cfg_showInspector = checked
            }

            // Where overdue tasks show depends on the layout (b2).
            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Overdue")
                text: i18n("Show overdue tasks (tile, chip or notice)")
                checked: root.cfg_showOverdueBanner
                onToggled: root.cfg_showOverdueBanner = checked
            }
            ConfigHint {
                text: i18n("With tiles the overdue tile offers “Move all to today”; the narrow layout shows a chip in the header; otherwise a notice above the tasks.")
            }

            QQC2.ComboBox {
                id: densityCombo
                Kirigami.FormData.label: i18n("Density")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                textRole: "text"
                model: [
                    { text: i18n("Auto (compact, larger with touch)"), value: "auto" },
                    { text: i18n("Compact"), value: "compact" },
                    { text: i18n("Comfortable"), value: "comfortable" }
                ]
                onActivated: cfg_density = model[currentIndex].value
                Component.onCompleted: selectCombo(densityCombo, plasmoid.configuration.density || "auto")
            }

            QQC2.ComboBox {
                id: overlayDimCombo
                Kirigami.FormData.label: i18n("Editor dim")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                textRole: "text"
                model: [
                    { text: i18n("Light"), value: "0" },
                    { text: i18n("Medium"), value: "1" },
                    { text: i18n("Strong"), value: "2" }
                ]
                onActivated: root.cfg_overlayDimStep = Number(model[currentIndex].value)
                Component.onCompleted: selectCombo(overlayDimCombo, String(plasmoid.configuration.overlayDimStep !== undefined ? plasmoid.configuration.overlayDimStep : 1))
            }

            QQC2.CheckBox {
                id: reducedMotionCheck
                Kirigami.FormData.label: i18n("Motion")
                text: i18n("Reduced motion (no spinner, quieter hover)")
                checked: root.cfg_reducedMotion
                onToggled: root.cfg_reducedMotion = checked
            }

        }

        ConfigResetButton {
            page: root
            defaults: ({
                uiStyle: "plasma",
                accentProjectColors: true,
                accentPriorityColors: true,
                showOverdueBanner: true,
                showViewTiles: true,
                showInspector: true,
                blurBackground: true,
                density: "auto",
                overlayDimStep: 1,
                reducedMotion: false
            })
        }
    }
}
