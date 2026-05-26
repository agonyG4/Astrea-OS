import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color successColor: Theme.successColor
    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")) + ""
    readonly property string helperPath: astreaRoot + "/System/scripts/astrea-gaming-settings"
    readonly property var fsrOptions: ["0", "1", "2", "3", "4", "5"]

    property bool loading: true
    property string message: ""
    property bool messageIsError: false
    property string buffer: ""
    property var proton: ({})
    property var status: ({ proton_command: "astrea-gaming %command%", proton_wrapper: "", proton_preview: "astrea-gaming %command%" })

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function updateConfig(key, value, showMessage) {
        var next = Object.assign({}, root.proton)
        next[key] = value
        root.proton = next
        root.save(showMessage)
    }

    function save(showMessage) {
        saveProc.showMessage = showMessage
        saveProc.command = [root.helperPath, "save-proton", JSON.stringify(root.proton)]
        saveProc.running = false
        saveProc.running = true
    }

    function loadPayload() {
        root.buffer = ""
        loadProc.running = false
        loadProc.running = true
    }

    Component.onCompleted: loadPayload()

    Process {
        id: loadProc
        command: [root.helperPath, "get"]
        stdout: SplitParser { onRead: line => root.buffer += line }
        onExited: code => {
            root.loading = false
            if (code !== 0) {
                root.message = root.t("apps.settings.pages.gaming.proton.error.load", "Could not load Proton settings")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(root.buffer || "{}")
                root.proton = payload.proton || ({})
                root.status = payload.status || root.status
            } catch (e) {
                root.message = root.t("apps.settings.pages.gaming.proton.error.parse", "Could not parse settings: {error}", { error: e })
                root.messageIsError = true
            }
            root.buffer = ""
        }
    }

    Process {
        id: saveProc
        property bool showMessage: false
        property string saveBuffer: ""
        command: []
        stdout: SplitParser { onRead: line => saveProc.saveBuffer += line }
        onExited: code => {
            if (code !== 0) {
                root.message = root.t("apps.settings.pages.gaming.proton.error.save", "Could not save Proton flags")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(saveProc.saveBuffer || "{}")
                if (payload.status) {
                    root.status.proton_wrapper = payload.status.wrapper || root.status.proton_wrapper
                    root.status.proton_command = payload.status.command || root.status.proton_command
                    root.status.proton_preview = payload.status.preview || root.status.proton_preview
                }
            } catch (e) {}
            saveProc.saveBuffer = ""
            if (saveProc.showMessage) {
                root.message = root.t("apps.settings.pages.gaming.proton.status.applied", "Flags applied to the astrea-gaming wrapper")
                root.messageIsError = false
                messageTimer.restart()
            }
        }
    }

    Timer {
        id: messageTimer
        interval: 2200
        repeat: false
        onTriggered: root.message = ""
    }

    component ActionButton: Rectangle {
        property string label: ""
        signal clicked()
        implicitHeight: 34
        implicitWidth: actionText.implicitWidth + 28
        radius: 8
        color: buttonArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: root.cardBorder
        Text {
            id: actionText
            anchors.centerIn: parent
            text: parent.label
            color: root.textPrimary
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component CompactField: TextField {
        property int fieldWidth: 260
        implicitWidth: fieldWidth
        implicitHeight: 34
        color: root.textPrimary
        font.pixelSize: 13
        selectByMouse: true
        background: Rectangle {
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: parent.activeFocus ? root.accent : root.cardBorder
        }
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        width: 48
        height: 48
        BusyIndicator {
            anchors.fill: parent
            running: root.loading
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading

        SectionHeader {
            text: root.t("apps.settings.pages.gaming.proton.text.proton", "PROTON")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.message !== ""
            text: root.message
            color: root.messageIsError ? root.errorColor : root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 18
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.steam_launch_option", "Steam launch option")
                sublabel: root.status.proton_command || "astrea-gaming %command%"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ActionButton {
                    label: root.t("apps.settings.pages.gaming.proton.label.save", "Save")
                    onClicked: root.save(true)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.wrapper", "Wrapper")
                sublabel: root.status.proton_wrapper || "~/.local/bin/astrea-gaming"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
            }
        }

        SectionHeader {
            text: root.t("apps.settings.pages.gaming.proton.text.runtime", "RUNTIME")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.gamemode", "GameMode")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.gamemode", "Prepends gamemoderun when it is installed")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.gamemode; onToggled: root.updateConfig("gamemode", !root.proton.gamemode, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.mangohud", "MangoHud")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.mangohud", "Prepends mangohud when it is installed")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                ToggleSwitch { checked: !!root.proton.mangohud; onToggled: root.updateConfig("mangohud", !root.proton.mangohud, true) }
            }
        }

        SectionHeader {
            text: root.t("apps.settings.pages.gaming.proton.text.compatibility_flags", "COMPATIBILITY FLAGS")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.nvidia_nvapi", "NVIDIA NVAPI")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.nvidia_nvapi", "Sets PROTON_ENABLE_NVAPI=1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.enable_nvapi; onToggled: root.updateConfig("enable_nvapi", !root.proton.enable_nvapi, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.hide_nvidia_gpu", "Hide NVIDIA GPU")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.hide_nvidia_gpu", "Sets PROTON_HIDE_NVIDIA_GPU=1 for games that misdetect NVIDIA")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.hide_nvidia_gpu; onToggled: root.updateConfig("hide_nvidia_gpu", !root.proton.hide_nvidia_gpu, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.esync", "Esync")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.esync", "When disabled, sets PROTON_NO_ESYNC=1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.enable_esync; onToggled: root.updateConfig("enable_esync", !root.proton.enable_esync, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.fsync", "Fsync")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.fsync", "When disabled, sets PROTON_NO_FSYNC=1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.enable_fsync; onToggled: root.updateConfig("enable_fsync", !root.proton.enable_fsync, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.dxvk_async", "DXVK Async")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.dxvk_async", "Sets DXVK_ASYNC=1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.dxvk_async; onToggled: root.updateConfig("dxvk_async", !root.proton.dxvk_async, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.dxvk_hdr", "DXVK HDR")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.dxvk_hdr", "Sets DXVK_HDR=1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.dxvk_hdr; onToggled: root.updateConfig("dxvk_hdr", !root.proton.dxvk_hdr, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.vkd3d_dxr", "VKD3D DXR")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.vkd3d_dxr", "Sets VKD3D_CONFIG=dxr,dxr11")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.vkd3d_dxr; onToggled: root.updateConfig("vkd3d_dxr", !root.proton.vkd3d_dxr, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.fullscreen_fsr", "Fullscreen FSR")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.fullscreen_fsr", "Sets WINE_FULLSCREEN_FSR=1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.fsr; onToggled: root.updateConfig("fsr", !root.proton.fsr, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.fsr_sharpness", "FSR sharpness")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.fsr_sharpness", "Lower is sharper; saved as WINE_FULLSCREEN_FSR_STRENGTH")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                SelectButton {
                    implicitWidth: 96
                    label: String(root.proton.fsr_strength === undefined ? 2 : root.proton.fsr_strength)
                    options: root.fsrOptions
                    selectedIndex: Math.max(0, root.fsrOptions.indexOf(String(root.proton.fsr_strength === undefined ? 2 : root.proton.fsr_strength)))
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => root.updateConfig("fsr_strength", index, true)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.custom_environment", "Custom environment")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.custom_environment", "Space-separated KEY=VALUE pairs")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                CompactField {
                    text: root.proton.custom_env || ""
                    placeholderText: "RADV_PERFTEST=gpl"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("custom_env", text, true)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.proton.label.custom_prefix", "Custom prefix")
                sublabel: root.t("apps.settings.pages.gaming.proton.sublabel.custom_prefix", "Optional command inserted before the game command")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                CompactField {
                    text: root.proton.custom_prefix || ""
                    placeholderText: "gamescope -f --"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("custom_prefix", text, true)
                }
            }
        }
    }
}
