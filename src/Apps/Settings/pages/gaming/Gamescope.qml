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

    property bool loading: true
    property string message: ""
    property bool messageIsError: false
    property string buffer: ""
    property var gamescope: ({})
    property var status: ({ monitors: [], gamescope_command: "", gamescope_launcher: "", environment_file: "" })

    function t(key, fallback, params) {
        return AstreaI18n.I18n.tr(key, fallback, params)
    }

    function updateConfig(key, value, showMessage) {
        var next = Object.assign({}, root.gamescope)
        next[key] = value
        root.gamescope = next
        root.save(showMessage)
    }

    function save(showMessage) {
        saveProc.showMessage = showMessage
        saveProc.command = [root.helperPath, "save-gamescope", JSON.stringify(root.gamescope)]
        saveProc.running = false
        saveProc.running = true
    }

    function applyTextField(key, text, fallback) {
        const parsed = parseInt(String(text).trim())
        root.updateConfig(key, isNaN(parsed) ? fallback : parsed, true)
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
                root.message = root.t("apps.settings.pages.gaming.gamescope.error.load", "Could not load Gamescope settings")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(root.buffer || "{}")
                root.gamescope = payload.gamescope || ({})
                root.status = payload.status || root.status
            } catch (e) {
                root.message = root.t("apps.settings.pages.gaming.gamescope.error.parse", "Could not parse settings: {error}", { error: e })
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
                root.message = root.t("apps.settings.pages.gaming.gamescope.error.save", "Could not save Gamescope session")
                root.messageIsError = true
                return
            }
            try {
                const payload = JSON.parse(saveProc.saveBuffer || "{}")
                if (payload.status) {
                    root.status.gamescope_command = payload.status.command || root.status.gamescope_command
                    root.status.gamescope_launcher = payload.status.launcher || root.status.gamescope_launcher
                    root.status.environment_file = payload.status.environment || root.status.environment_file
                }
            } catch (e) {}
            saveProc.saveBuffer = ""
            if (saveProc.showMessage) {
                root.message = root.t("apps.settings.pages.gaming.gamescope.status.applied", "Configuration applied to the session launcher")
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
        property int fieldWidth: 96
        implicitWidth: fieldWidth
        implicitHeight: 34
        color: root.textPrimary
        font.pixelSize: 13
        horizontalAlignment: TextInput.AlignHCenter
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
            text: root.t("apps.settings.pages.gaming.gamescope.text.gamescope", "GAMESCOPE")
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
                label: root.t("apps.settings.pages.gaming.gamescope.label.session_launcher", "Session launcher")
                sublabel: root.status.gamescope_launcher || root.t("apps.settings.pages.gaming.gamescope.sublabel.generated_local_bin", "Generated in ~/.local/bin")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ActionButton {
                    label: root.t("apps.settings.pages.gaming.gamescope.label.apply", "Apply")
                    onClicked: root.save(true)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.generated_command", "Generated command")
                sublabel: root.status.gamescope_command || root.t("apps.settings.pages.gaming.gamescope.sublabel.command_after_save", "The command will appear after the first save")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
            }
        }

        SectionHeader {
            text: root.t("apps.settings.pages.gaming.gamescope.text.display", "DISPLAY")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.follow_monitor_resolution", "Follow monitor resolution")
                sublabel: root.status.monitors && root.status.monitors.length > 0
                    ? root.t("apps.settings.pages.gaming.gamescope.sublabel.uses_focused_monitor", "Uses the focused monitor resolution and refresh rate when the session launcher is generated")
                    : root.t("apps.settings.pages.gaming.gamescope.sublabel.monitor_unavailable", "Monitor data is unavailable here; saved fallback values are used")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch {
                    checked: !!root.gamescope.follow_monitor
                    onToggled: root.updateConfig("follow_monitor", !root.gamescope.follow_monitor, true)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.width", "Width")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.manual_width", "Manual width used when follow monitor is off")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.gamescope.follow_monitor
                opacity: enabled ? 1 : 0.45
                CompactField {
                    text: String(root.gamescope.width || 1920)
                    onEditingFinished: root.applyTextField("width", text, 1920)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.height", "Height")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.manual_height", "Manual height used when follow monitor is off")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.gamescope.follow_monitor
                opacity: enabled ? 1 : 0.45
                CompactField {
                    text: String(root.gamescope.height || 1080)
                    onEditingFinished: root.applyTextField("height", text, 1080)
                }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.refresh_rate", "Refresh rate")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.target_refresh_rate", "Target refresh rate for the Gamescope session")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                enabled: !root.gamescope.follow_monitor
                opacity: enabled ? 1 : 0.45
                isLast: true
                CompactField {
                    text: String(root.gamescope.refresh || 165)
                    onEditingFinished: root.applyTextField("refresh", text, 165)
                }
            }
        }

        SectionHeader {
            text: root.t("apps.settings.pages.gaming.gamescope.text.flags", "FLAGS")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.fullscreen", "Fullscreen")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.fullscreen", "Launch Gamescope as a fullscreen session")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.fullscreen; onToggled: root.updateConfig("fullscreen", !root.gamescope.fullscreen, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.steam_integration", "Steam integration")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.steam_integration", "Adds --steam and Steam session environment flags")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.steam_integration; onToggled: root.updateConfig("steam_integration", !root.gamescope.steam_integration, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.drm_backend", "DRM backend")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.drm_backend", "Prefer the direct DRM backend for the Steam session")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.backend_drm; onToggled: root.updateConfig("backend_drm", !root.gamescope.backend_drm, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.immediate_flips", "Immediate flips")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.immediate_flips", "Lower latency when supported by the display path")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.immediate_flips; onToggled: root.updateConfig("immediate_flips", !root.gamescope.immediate_flips, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.hide_cursor", "Hide cursor")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.hide_cursor", "Uses --hide-cursor-delay -1")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.hide_cursor; onToggled: root.updateConfig("hide_cursor", !root.gamescope.hide_cursor, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.multiple_xwaylands", "Multiple XWaylands")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.multiple_xwaylands", "Exports STEAM_MULTIPLE_XWAYLANDS for per-game isolation")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.multiple_xwaylands; onToggled: root.updateConfig("multiple_xwaylands", !root.gamescope.multiple_xwaylands, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.color_managed", "Color managed")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.color_managed", "Exports the Steam color-management feature flags")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.color_managed; onToggled: root.updateConfig("color_managed", !root.gamescope.color_managed, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.fancy_scaling", "Fancy scaling")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.fancy_scaling", "Enables the Steam UI scaling controls")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.fancy_scaling; onToggled: root.updateConfig("fancy_scaling", !root.gamescope.fancy_scaling, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.hdr_advertised", "HDR advertised")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.hdr_advertised", "Makes Steam expose HDR support for this session")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch { checked: !!root.gamescope.hdr; onToggled: root.updateConfig("hdr", !root.gamescope.hdr, true) }
            }
            SettingRow {
                label: root.t("apps.settings.pages.gaming.gamescope.label.extra_flags", "Extra Gamescope flags")
                sublabel: root.t("apps.settings.pages.gaming.gamescope.sublabel.extra_flags", "Optional raw flags appended before the Steam command")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
                CompactField {
                    fieldWidth: 260
                    horizontalAlignment: TextInput.AlignLeft
                    text: root.gamescope.extra_args || ""
                    placeholderText: "--adaptive-sync"
                    placeholderTextColor: root.textSecondary
                    onEditingFinished: root.updateConfig("extra_args", text, true)
                }
            }
        }
    }
}
