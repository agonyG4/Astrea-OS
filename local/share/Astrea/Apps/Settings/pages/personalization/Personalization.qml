import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../components"

Item {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    property color accent: Theme.accent
    property color textPrimary: Theme.textPrimary
    property color textSecondary: Theme.textSecondary
    property color cardBg: Theme.cardBg
    property color cardBorder: Theme.cardBorder
    property color popupBg: Theme.popupBg

    // ── State ─────────────────────────────────────────────────────────────
    readonly property var themeOptions: ["Dark", "Light"]
    readonly property var styleOptions: ["Transparent", "Default", "Frosted"]
    readonly property var accentColors: [
        { label: "Blue",   value: "#0a84ff" },
        { label: "Green",  value: "#30d158" },
        { label: "Orange", value: "#ff9f0a" },
        { label: "Red",    value: "#ff375f" },
        { label: "Purple", value: "#bf5af2" },
        { label: "Teal",   value: "#64d2ff" },
        { label: "Yellow", value: "#ffd60a" }
    ]

    // Icon style options: 0=clear, 1=colored
    readonly property var iconStyleOptions: [
        { label: "Colored", value: 1 },
        { label: "Clear",   value: 0 }
    ]

    // ── Layout ────────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        anchors.margins: 28
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 0

            SectionHeader { 
                text: "APPEARANCE"
                Layout.bottomMargin: 12 
                textSecondary: root.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: appearanceCol.implicitHeight

                ColumnLayout {
                    id: appearanceCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: "Theme"
                        sublabel: "Light or dark mode"
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        SelectButton {
                            implicitWidth: 140
                            label: root.themeOptions[Theme.themeMode]
                            options: root.themeOptions
                            selectedIndex: Theme.themeMode
                            onSelected: i => {
                                Theme.themeMode = i
                                Theme.save()
                            }
                            accent: root.accent; textPrimary: root.textPrimary; textSecondary: root.textSecondary; popupBg: root.popupBg
                        }
                    }

                    SettingRow {
                        label: "Style"
                        sublabel: "Window chrome and card treatment"
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        SelectButton {
                            implicitWidth: 140
                            label: root.styleOptions[Theme.shellStyle]
                            options: root.styleOptions
                            selectedIndex: Theme.shellStyle
                            onSelected: i => {
                                Theme.shellStyle = i
                                Theme.save()
                            }
                            accent: root.accent; textPrimary: root.textPrimary; textSecondary: root.textSecondary; popupBg: root.popupBg
                        }
                    }

                    SettingRow {
                        label: "Accent Color"
                        sublabel: "Used across the whole shell"
                        isLast: true
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        RowLayout {
                            spacing: 8; Layout.rightMargin: 16
                            Repeater {
                                model: root.accentColors
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: Theme.accentHex === modelData.value
                                    width: 22; height: 22; radius: 11
                                    color: modelData.value
                                    border.width: active ? 2 : 0; border.color: "#ffffff"
                                    Behavior on border.width { NumberAnimation { duration: 130 } }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8; height: 8; radius: 4; color: "#ffffff"
                                        opacity: parent.active ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
                                    }
                                     MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Theme.accentHex = modelData.value
                                            Theme.save()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Icons Section ──────────────────────────────────────────────────
            SectionHeader {
                text: "ICONS"
                Layout.bottomMargin: 12
                textSecondary: root.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: iconsCol.implicitHeight

                ColumnLayout {
                    id: iconsCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    SettingRow {
                        label: "Icon Style"
                        sublabel: "Color mode for custom icons"
                        isLast: true
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder

                        // Pill-style toggle
                        Rectangle {
                            implicitWidth: iconStyleRow.implicitWidth + 6
                            implicitHeight: 32
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            Layout.rightMargin: 16

                            Row {
                                id: iconStyleRow
                                anchors.centerIn: parent
                                spacing: 4
                                padding: 3

                                Repeater {
                                    model: root.iconStyleOptions
                                    delegate: Item {
                                        required property var modelData
                                        required property int index
                                        readonly property bool active: Theme.iconStyle === modelData.value

                                        width: pillLabel.implicitWidth + 20
                                        height: 26

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 7
                                            color: parent.active
                                                ? Qt.rgba(0.04, 0.52, 1, 0.25)
                                                : "transparent"
                                            border.width: parent.active ? 1 : 0
                                            border.color: Qt.rgba(0.04, 0.52, 1, 0.5)

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                id: pillLabel
                                                anchors.centerIn: parent
                                                text: parent.parent.modelData.label
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: parent.parent.active ? Theme.fontWeightDemiBold : Theme.fontWeightNormal
                                                color: parent.parent.active ? "#ffffff" : Qt.rgba(1, 1, 1, 0.5)
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Theme.iconStyle = parent.modelData.value
                                                Theme.save()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // ── Icon Theme Section ─────────────────────────────────────────────
            SectionHeader {
                text: "ICON THEME"
                Layout.bottomMargin: 12
                textSecondary: root.textSecondary
            }

            // Theme cards row
            Flow {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                spacing: 12

                // ── Default card ──────────────────────────────────────────────
                Rectangle {
                    id: defaultThemeCard
                    width: 150
                    height: 110
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: Theme.iconTheme === "" ? 2 : 1
                    border.color: Theme.iconTheme === ""
                        ? root.accent
                        : root.cardBorder
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 150 } }

                    // Preview background — subtle glass
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 72
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.06)
                        clip: true

                        // Preview icons using the base (non-themed) sources
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: [
                                    "file:///home/agony/.local/share/Astrea/Assets/icons/settings/display.svg",
                                    "file:///home/agony/.local/share/Astrea/Assets/icons/settings/network.svg",
                                    "file:///home/agony/.local/share/Astrea/Assets/icons/settings/bluetooth.svg",
                                    "file:///home/agony/.local/share/Astrea/Assets/icons/settings/audio.svg"
                                ]
                                delegate: Image {
                                    required property string modelData
                                    width: 22; height: 22
                                    source: modelData
                                    sourceSize: Qt.size(44, 44)
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    smooth: true
                                    opacity: 0.7
                                }
                            }
                        }
                    }

                    // Label row
                    Row {
                        anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                        spacing: 6
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: Theme.iconTheme === "" ? root.accent : Qt.rgba(1, 1, 1, 0.25)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: "Default"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.iconTheme === "" ? Theme.fontWeightDemiBold : Theme.fontWeightNormal
                            color: Theme.iconTheme === "" ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.iconTheme = ""
                            Theme.save()
                        }
                    }
                }

                // ── Dark theme card ───────────────────────────────────────────
                Rectangle {
                    id: darkThemeCard
                    width: 150
                    height: 110
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: Theme.iconTheme === "dark" ? 2 : 1
                    border.color: Theme.iconTheme === "dark"
                        ? root.accent
                        : root.cardBorder
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 150 } }

                    // Preview background — dark gray
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 72
                        radius: 10
                        color: "#1c1c1e"
                        clip: true

                        // Subtle top highlight
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.07)
                        }

                        // Preview icons from dark theme folder
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: [
                                    { key: "display",   src: "file:///home/agony/.local/share/Astrea/Assets/icons/settings/icon/dark/display.svg"   },
                                    { key: "network",   src: "file:///home/agony/.local/share/Astrea/Assets/icons/settings/icon/dark/network.svg"   },
                                    { key: "bluetooth", src: "file:///home/agony/.local/share/Astrea/Assets/icons/settings/icon/dark/bluetooth.svg" },
                                    { key: "audio",     src: "file:///home/agony/.local/share/Astrea/Assets/icons/settings/icon/dark/audio.svg"     }
                                ]
                                delegate: Image {
                                    required property var modelData
                                    width: 22; height: 22
                                    source: modelData.src
                                    sourceSize: Qt.size(44, 44)
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    smooth: true
                                    // Hide gracefully if file not found yet
                                    visible: status !== Image.Error
                                    opacity: status === Image.Ready ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                    }

                    // Label row
                    Row {
                        anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                        spacing: 6
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: Theme.iconTheme === "dark" ? root.accent : Qt.rgba(1, 1, 1, 0.25)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            text: "Dark"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.iconTheme === "dark" ? Theme.fontWeightDemiBold : Theme.fontWeightNormal
                            color: Theme.iconTheme === "dark" ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.iconTheme = "dark"
                            Theme.save()
                        }
                    }
                }
            }
        }
    }
}
