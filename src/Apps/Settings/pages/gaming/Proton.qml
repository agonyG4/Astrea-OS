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
    readonly property var presetOptions: ["Recommended", "NVIDIA features", "HDR display", "Diagnostics", "Custom"]
    readonly property var presetValues: ["recommended", "nvidia", "hdr", "diagnostic", "custom"]
    readonly property var syncModeOptions: ["Proton default", "Disable Esync", "Disable Fsync", "Disable both"]
    readonly property var syncModeValues: ["default", "disable-esync", "disable-fsync", "disable-both"]
    readonly property var defaultProton: ({
        "config_version": 2,
        "preset": "recommended",
        "gamemode": true,
        "mangohud": false,
        "gamescope": false,
        "use_gamescope_profile": true,
        "gamescope_width": 1920,
        "gamescope_height": 1080,
        "gamescope_refresh": 60,
        "gamescope_fullscreen": true,
        "gamescope_immediate_flips": false,
        "gamescope_hide_cursor": false,
        "gamescope_force_grab_cursor": false,
        "gamescope_adaptive_sync": false,
        "gamescope_extra_args": "",
        "enable_nvapi": false,
        "hide_nvidia_gpu": false,
        "sync_mode": "default",
        "enable_esync": true,
        "enable_fsync": true,
        "dxvk_async": false,
        "dxvk_hdr": false,
        "vkd3d_dxr": false,
        "use_wined3d": false,
        "fsr": false,
        "fsr_strength": 2,
        "custom_env": "",
        "custom_prefix": ""
    })

    property bool loading: true
    property string message: ""
    property bool messageIsError: false
    property string buffer: ""
    property var proton: Object.assign({}, defaultProton)
    property var status: ({ proton_command: "astrea-gaming %command%", proton_wrapper: "", proton_preview: "astrea-gaming %command%", proton_env: ({}), proton_prefix: [], proton_preset: "recommended" })

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function presetIndexFor(value) {
        const idx = root.presetValues.indexOf(value || "recommended")
        return idx >= 0 ? idx : root.presetValues.length - 1
    }

    function syncModeIndexFor(value) {
        const idx = root.syncModeValues.indexOf(value || "default")
        return idx >= 0 ? idx : 0
    }

    function presetDescription(value) {
        if (value === "nvidia")
            return "Enables NVAPI for games that need NVIDIA-specific features. Leave off unless the game needs it."
        if (value === "hdr")
            return "Enables the HDR path for games and displays configured for HDR."
        if (value === "diagnostic")
            return "Enables MangoHud and keeps Proton defaults so you can inspect FPS/frame time without changing compatibility."
        if (value === "custom")
            return "Manual compatibility profile. Use this when a specific game needs a workaround."
        return "Keeps Proton defaults and only adds the Astrea launch wrapper. Best starting point for most games."
    }

    function envSummary() {
        const env = root.status.proton_env || ({})
        const keys = Object.keys(env)
        if (!keys.length)
            return "No forced Proton flags"
        return keys.join(", ")
    }

    function prefixSummary() {
        const prefix = root.status.proton_prefix || []
        if (!prefix.length)
            return "No command prefix"
        return prefix.join(" ")
    }

    function makeCustom(next, keepPreset) {
        if (!keepPreset && next.preset !== "custom")
            next.preset = "custom"
    }

    function updateConfig(key, value, showMessage, keepPreset) {
        var next = Object.assign({}, root.defaultProton, root.proton)
        next[key] = value
        root.makeCustom(next, keepPreset || key === "preset")
        root.proton = next
        root.save(showMessage)
    }

    function applyIntField(key, text, fallback) {
        const parsed = parseInt(String(text).trim())
        root.updateConfig(key, isNaN(parsed) ? fallback : parsed, true)
    }

    function applyPreset(index) {
        const preset = root.presetValues[Math.max(0, Math.min(index, root.presetValues.length - 1))]
        var next = Object.assign({}, root.defaultProton, root.proton)
        next.preset = preset
        if (preset !== "custom") {
            next.custom_env = ""
            next.custom_prefix = ""
        }
        if (preset === "recommended") {
            next.gamemode = true
            next.mangohud = false
            next.gamescope = false
            next.enable_nvapi = false
            next.hide_nvidia_gpu = false
            next.sync_mode = "default"
            next.dxvk_async = false
            next.dxvk_hdr = false
            next.vkd3d_dxr = false
            next.use_wined3d = false
            next.fsr = false
        } else if (preset === "nvidia") {
            next.gamemode = true
            next.gamescope = false
            next.enable_nvapi = true
            next.hide_nvidia_gpu = false
            next.sync_mode = "default"
            next.vkd3d_dxr = false
            next.use_wined3d = false
        } else if (preset === "hdr") {
            next.gamemode = true
            next.gamescope = false
            next.dxvk_hdr = true
            next.sync_mode = "default"
            next.use_wined3d = false
        } else if (preset === "diagnostic") {
            next.gamemode = true
            next.mangohud = true
            next.gamescope = false
            next.sync_mode = "default"
            next.use_wined3d = false
        }
        root.proton = next
        root.save(true)
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
            if (code !== 0) {
                root.loading = false
                root.message = root.t("apps.settings.pages.gaming.proton.error.load", "Could not load Proton settings")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(root.buffer || "{}")
                root.proton = Object.assign({}, root.defaultProton, payload.proton || ({}))
                root.status = payload.status || root.status
            } catch (e) {
                root.message = root.t("apps.settings.pages.gaming.proton.error.parse", "Could not parse settings: {error}", { error: e })
                root.messageIsError = true
            }
            root.buffer = ""
            root.loading = false
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
                if (payload.proton)
                    root.proton = Object.assign({}, root.defaultProton, payload.proton)
                if (payload.status) {
                    root.status = Object.assign({}, root.status, payload.status, {
                        proton_wrapper: payload.status.proton_wrapper || payload.status.wrapper || root.status.proton_wrapper,
                        proton_command: payload.status.proton_command || payload.status.command || root.status.proton_command,
                        proton_preview: payload.status.proton_preview || payload.status.preview || root.status.proton_preview,
                        proton_env: payload.status.proton_env || payload.status.env || root.status.proton_env,
                        proton_prefix: payload.status.proton_prefix || payload.status.prefix || root.status.proton_prefix,
                        proton_preset: payload.status.proton_preset || payload.status.preset || root.status.proton_preset
                    })
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

        SectionHeader {
            text: "SETUP"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "Steam launch option"
                sublabel: root.status.proton_command || "astrea-gaming %command%"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ActionButton {
                    label: "Save"
                    onClicked: root.save(true)
                }
            }
            SettingRow {
                label: "Active flags"
                sublabel: root.envSummary()
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
            }
            SettingRow {
                label: "Command prefix"
                sublabel: root.prefixSummary()
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
            }
            SettingRow {
                label: "Wrapper"
                sublabel: root.status.proton_wrapper || "~/.local/bin/astrea-gaming"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
            }
        }

        SectionHeader {
            text: "PROFILE"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "Proton preset"
                sublabel: root.presetDescription(root.proton.preset || "recommended")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                SelectButton {
                    implicitWidth: 190
                    label: root.presetOptions[root.presetIndexFor(root.proton.preset)]
                    options: root.presetOptions
                    selectedIndex: root.presetIndexFor(root.proton.preset)
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => root.applyPreset(index)
                }
            }
            SettingRow {
                label: "Sync behavior"
                sublabel: "Keep Proton defaults unless a specific game needs Esync/Fsync disabled."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                SelectButton {
                    implicitWidth: 170
                    label: root.syncModeOptions[root.syncModeIndexFor(root.proton.sync_mode)]
                    options: root.syncModeOptions
                    selectedIndex: root.syncModeIndexFor(root.proton.sync_mode)
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => root.updateConfig("sync_mode", root.syncModeValues[index], true)
                }
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
                label: "GameMode"
                sublabel: "Recommended. Adds gamemoderun when it is installed so the game can request performance hints."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.gamemode; onToggled: root.updateConfig("gamemode", !root.proton.gamemode, true) }
            }
            SettingRow {
                label: "MangoHud"
                sublabel: "Overlay for FPS, frame time and GPU/CPU telemetry. Useful for testing, noisy for daily play."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.mangohud; onToggled: root.updateConfig("mangohud", !root.proton.mangohud, true) }
            }
            SettingRow {
                label: "Gamescope"
                sublabel: "Wraps the game with the Gamescope profile below. MangoHud uses --mangoapp in this mode."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                ToggleSwitch { checked: !!root.proton.gamescope; onToggled: root.updateConfig("gamescope", !root.proton.gamescope, true) }
            }
        }

        SectionHeader {
            text: "GAMESCOPE"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "Use SteamOS profile"
                sublabel: "Reuses the resolution, refresh and launch flags from the SteamOS Gamescope page."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch {
                    checked: root.proton.use_gamescope_profile === undefined ? true : !!root.proton.use_gamescope_profile
                    onToggled: root.updateConfig("use_gamescope_profile", !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile), true)
                }
            }
            SettingRow {
                label: "Width"
                sublabel: "Manual nested Gamescope output width."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                CompactField { fieldWidth: 92; text: String(root.proton.gamescope_width || 1920); onEditingFinished: root.applyIntField("gamescope_width", text, 1920) }
            }
            SettingRow {
                label: "Height"
                sublabel: "Manual nested Gamescope output height."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                CompactField { fieldWidth: 92; text: String(root.proton.gamescope_height || 1080); onEditingFinished: root.applyIntField("gamescope_height", text, 1080) }
            }
            SettingRow {
                label: "Refresh rate"
                sublabel: "Manual nested Gamescope refresh limit."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                CompactField { fieldWidth: 92; text: String(root.proton.gamescope_refresh || 60); onEditingFinished: root.applyIntField("gamescope_refresh", text, 60) }
            }
            SettingRow {
                label: "Fullscreen"
                sublabel: "Adds -f for a fullscreen nested Gamescope session."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: root.proton.gamescope_fullscreen === undefined ? true : !!root.proton.gamescope_fullscreen; onToggled: root.updateConfig("gamescope_fullscreen", !(root.proton.gamescope_fullscreen === undefined ? true : root.proton.gamescope_fullscreen), true) }
            }
            SettingRow {
                label: "Immediate flips"
                sublabel: "Adds --immediate-flips for lower latency when the driver path supports it."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: !!root.proton.gamescope_immediate_flips; onToggled: root.updateConfig("gamescope_immediate_flips", !root.proton.gamescope_immediate_flips, true) }
            }
            SettingRow {
                label: "Hide cursor"
                sublabel: "Adds --hide-cursor-delay -1 for controller-first games."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: !!root.proton.gamescope_hide_cursor; onToggled: root.updateConfig("gamescope_hide_cursor", !root.proton.gamescope_hide_cursor, true) }
            }
            SettingRow {
                label: "Force cursor grab"
                sublabel: "Adds --force-grab-cursor for games that lose relative mouse input."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: !!root.proton.gamescope_force_grab_cursor; onToggled: root.updateConfig("gamescope_force_grab_cursor", !root.proton.gamescope_force_grab_cursor, true) }
            }
            SettingRow {
                label: "Adaptive sync"
                sublabel: "Adds --adaptive-sync when the display path supports VRR."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                ToggleSwitch { checked: !!root.proton.gamescope_adaptive_sync; onToggled: root.updateConfig("gamescope_adaptive_sync", !root.proton.gamescope_adaptive_sync, true) }
            }
            SettingRow {
                label: "Extra arguments"
                sublabel: "Additional Gamescope flags used after the generated resolution and refresh arguments."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !(root.proton.use_gamescope_profile === undefined ? true : root.proton.use_gamescope_profile)
                opacity: enabled ? 1 : 0.45
                isLast: true
                CompactField {
                    text: root.proton.gamescope_extra_args || ""
                    placeholderText: "--sharpness 10"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("gamescope_extra_args", text, true)
                }
            }
        }

        SectionHeader {
            text: "GRAPHICS FEATURES"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "NVIDIA NVAPI"
                sublabel: "Forces DXVK-NVAPI for games that need NVIDIA-specific features such as DLSS path detection."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.enable_nvapi; onToggled: root.updateConfig("enable_nvapi", !root.proton.enable_nvapi, true) }
            }
            SettingRow {
                label: "HDR path"
                sublabel: "Enables DXVK HDR. Use with an HDR-ready compositor/display setup."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.dxvk_hdr; onToggled: root.updateConfig("dxvk_hdr", !root.proton.dxvk_hdr, true) }
            }
            SettingRow {
                label: "Fullscreen FSR"
                sublabel: "Upscaling fallback for games that run below native resolution."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.fsr; onToggled: root.updateConfig("fsr", !root.proton.fsr, true) }
            }
            SettingRow {
                label: "FSR sharpness"
                sublabel: "Lower values are sharper. Only applies when Fullscreen FSR is enabled."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
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
        }

        SectionHeader {
            text: "ADVANCED COMPATIBILITY"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: "Hide NVIDIA GPU"
                sublabel: "Compatibility workaround for games that pick the wrong GPU path when NVIDIA is visible."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.hide_nvidia_gpu; onToggled: root.updateConfig("hide_nvidia_gpu", !root.proton.hide_nvidia_gpu, true) }
            }
            SettingRow {
                label: "WineD3D fallback"
                sublabel: "Replaces DXVK with WineD3D. Slower, but useful when a DirectX game fails before rendering."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.use_wined3d; onToggled: root.updateConfig("use_wined3d", !root.proton.use_wined3d, true) }
            }
            SettingRow {
                label: "Force VKD3D DXR"
                sublabel: "Advanced ray-tracing fallback. Leave off unless the game specifically needs DXR forced."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.vkd3d_dxr; onToggled: root.updateConfig("vkd3d_dxr", !root.proton.vkd3d_dxr, true) }
            }
            SettingRow {
                label: "Legacy DXVK Async"
                sublabel: "Non-default compatibility flag for old async-patched DXVK builds. Leave off for normal Proton."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.proton.dxvk_async; onToggled: root.updateConfig("dxvk_async", !root.proton.dxvk_async, true) }
            }
            SettingRow {
                label: "Custom environment"
                sublabel: "Space-separated KEY=VALUE pairs for one-off game fixes."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                CompactField {
                    text: root.proton.custom_env || ""
                    placeholderText: "PROTON_LOG=1"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("custom_env", text, true)
                }
            }
            SettingRow {
                label: "Custom prefix"
                sublabel: "Optional command inserted before the game command."
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
