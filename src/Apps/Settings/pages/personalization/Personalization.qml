import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color accent: Theme.accent
    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color popupBg: Theme.popupBg

    readonly property var themeOptions: ["Dark", "Light"]
    readonly property var styleOptions: ["Transparent", "Default", "Frosted"]
    readonly property var audioOsdOptions: ["Classic", "iOS"]
    readonly property var iconStyleOptions: ["Colored", "Clear"]
    readonly property var iconStyleValues: [1, 0]
    readonly property var iconThemeOptions: ["Default", "Dark"]
    readonly property var iconThemeValues: ["", "dark"]
    readonly property var accentColors: [
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.blue"]) || "Blue"),   value: "#0a84ff" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.green"]) || "Green"),  value: "#30d158" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.orange"]) || "Orange"), value: "#ff9f0a" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.red"]) || "Red"),    value: "#ff375f" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.purple"]) || "Purple"), value: "#bf5af2" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.teal"]) || "Teal"),   value: "#64d2ff" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.yellow"]) || "Yellow"), value: "#ffd60a" }
    ]

    function iconStyleIndex() {
        const idx = root.iconStyleValues.indexOf(Theme.iconStyle)
        return idx >= 0 ? idx : 0
    }

    function iconThemeIndex() {
        const idx = root.iconThemeValues.indexOf(Theme.iconTheme)
        return idx >= 0 ? idx : 0
    }

    SectionHeader {
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.text.appearance"]) || "APPEARANCE")
        textSecondary: root.textSecondary
        Layout.bottomMargin: 12
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
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.theme"]) || "Theme")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.sublabel.light_or_dark_mode"]) || "Light or dark mode")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                SelectButton {
                    implicitWidth: 140
                    label: root.themeOptions[Theme.themeMode]
                    options: root.themeOptions
                    selectedIndex: Theme.themeMode
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => {
                        Theme.themeMode = index
                        Theme.save()
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.style"]) || "Style")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.sublabel.window_chrome_and_card_treatment"]) || "Window chrome and card treatment")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                SelectButton {
                    implicitWidth: 140
                    label: root.styleOptions[Theme.shellStyle]
                    options: root.styleOptions
                    selectedIndex: Theme.shellStyle
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => {
                        Theme.shellStyle = index
                        Theme.save()
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.accent_color"]) || "Accent color")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.sublabel.used_across_the_whole_shell"]) || "Used across the whole shell")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                RowLayout {
                    spacing: 8
                    Layout.rightMargin: 16

                    Repeater {
                        model: root.accentColors
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: Theme.accentHex === modelData.value
                            width: 22
                            height: 22
                            radius: 11
                            color: modelData.value
                            border.width: active ? 2 : 0
                            border.color: active ? Theme.accentForeground : "transparent"
                            Behavior on border.width { NumberAnimation { duration: 130 } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: Theme.accentForeground
                                opacity: parent.active ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 130 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Theme.accentHex = parent.modelData.value
                                    Theme.save()
                                }
                            }
                        }
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.audio_osd_style"]) || "Audio indicator")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.sublabel.audio_osd_style"]) || "Volume change overlay style")
                isLast: true
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                SelectButton {
                    implicitWidth: 140
                    label: root.audioOsdOptions[Theme.audioOsdStyle]
                    options: root.audioOsdOptions
                    selectedIndex: Theme.audioOsdStyle
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => {
                        Theme.audioOsdStyle = index
                        Theme.save()
                    }
                }
            }
        }
    }

    SectionHeader {
        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.text.icons"]) || "ICONS")
        textSecondary: root.textSecondary
        Layout.bottomMargin: 12
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
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.icon_style"]) || "Icon style")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.sublabel.color_mode_for_custom_icons"]) || "Color mode for custom icons")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                SelectButton {
                    implicitWidth: 140
                    label: root.iconStyleOptions[root.iconStyleIndex()]
                    options: root.iconStyleOptions
                    selectedIndex: root.iconStyleIndex()
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => {
                        Theme.iconStyle = root.iconStyleValues[index]
                        Theme.save()
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.label.icon_theme"]) || "Icon theme")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.personalization.sublabel.choose_the_settings_icon_theme"]) || "Choose the Settings icon theme")
                isLast: true
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                SelectButton {
                    implicitWidth: 140
                    label: root.iconThemeOptions[root.iconThemeIndex()]
                    options: root.iconThemeOptions
                    selectedIndex: root.iconThemeIndex()
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => {
                        Theme.iconTheme = root.iconThemeValues[index]
                        Theme.save()
                    }
                }
            }
        }
    }
}
