import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

Item {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    property color accent:        "#0a84ff"
    property color textPrimary:   "#ffffff"
    property color textSecondary: "#98989f"
    property color cardBg:        Qt.rgba(1, 1, 1, 0.05)
    property color cardBorder:    Qt.rgba(1, 1, 1, 0.08)
    property color popupBg:       Qt.rgba(0.13, 0.13, 0.14, 0.97)

    // ── State ─────────────────────────────────────────────────────────────
    property int selectedTheme:      0
    property int selectedStyle:      0
    property int selectedAccent:     0

    readonly property var themeOptions: ["Dark", "Light"]
    readonly property var styleOptions: ["Default", "Rounded", "Flat", "Bordered"]
    readonly property var accentColors: [
        { label: "Blue",   value: "#0a84ff" },
        { label: "Green",  value: "#30d158" },
        { label: "Orange", value: "#ff9f0a" },
        { label: "Red",    value: "#ff375f" },
        { label: "Purple", value: "#bf5af2" },
        { label: "Teal",   value: "#64d2ff" },
        { label: "Yellow", value: "#ffd60a" }
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

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0, 0, 0, 0.38)
                    z: 10
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "\uf017"; color: Qt.rgba(1, 1, 1, 0.4); font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "Coming soon"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 12 }
                    }
                }

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
                            label: root.themeOptions[root.selectedTheme]
                            options: root.themeOptions
                            selectedIndex: root.selectedTheme
                            onSelected: (i) => root.selectedTheme = i
                            accent: root.accent; textPrimary: root.textPrimary; textSecondary: root.textSecondary; popupBg: root.popupBg
                        }
                    }

                    SettingRow {
                        label: "Style"
                        sublabel: "Window and widget style"
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        SelectButton {
                            implicitWidth: 140
                            label: root.styleOptions[root.selectedStyle]
                            options: root.styleOptions
                            selectedIndex: root.selectedStyle
                            onSelected: (i) => root.selectedStyle = i
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
                                    readonly property bool active: root.selectedAccent === index
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
                                        onClicked: root.selectedAccent = index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
