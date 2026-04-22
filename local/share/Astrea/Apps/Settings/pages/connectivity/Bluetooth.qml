import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "file:/home/agony/.local/share/Astrea/Core/components"

ScrollPage {
    id: root
    contentMargins: 28
    maxWidth: 1000

    readonly property string scriptPath: Quickshell.env("HOME") + "/.local/share/Astrea/System/scripts/bluetooth_manager.py"
    readonly property var retryOptions: [6, 12, 20, 30, 60]
    readonly property var snoozeOptions: [60, 180, 300, 600, 900]

    property bool loading: true
    property bool powered: false
    property string connectedName: ""
    property var pairedDevices: []
    property var btConfig: ({
        enabled: true,
        trusted_only: true,
        retry_interval_sec: 12,
        disconnect_snooze_sec: 300,
        device_order: [],
        device_overrides: {}
    })
    property string _statusBuf: ""

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg

    function loadStatus() {
        if (statusProc.running)
            return
        _statusBuf = ""
        statusProc.running = true
    }

    function saveConfig(nextConfig) {
        btConfig = nextConfig
        saveConfigProc.jsonData = JSON.stringify(nextConfig)
        saveConfigProc.command = ["python3", root.scriptPath, "save_config", saveConfigProc.jsonData]
        saveConfigProc.running = false
        saveConfigProc.running = true
    }

    function mutateConfig(mutator) {
        var next = JSON.parse(JSON.stringify(btConfig))
        mutator(next)
        saveConfig(next)
    }

    function toggleDevice(mac, enabled) {
        mutateConfig(function(next) {
            if (!next.device_overrides)
                next.device_overrides = {}
            next.device_overrides[mac] = { auto_connect: enabled }
        })
    }

    function retryLabel(seconds) {
        return String(seconds) + "s"
    }

    function retryOptionLabels(values) {
        return values.map(function(seconds) { return root.retryLabel(seconds) })
    }

    function deviceSubtitle(device) {
        var tags = []
        if (device.connected)
            tags.push("connected")
        if (device.trusted)
            tags.push("trusted")
        if (device.cooldown_active)
            tags.push("paused")
        if (!tags.length)
            tags.push("paired")
        return device.mac + "  •  " + tags.join("  •  ")
    }

    Process {
        id: statusProc
        command: ["python3", root.scriptPath, "status"]
        stdout: SplitParser {
            onRead: line => root._statusBuf += line
        }
        onExited: exitCode => {
            root.loading = false
            if (exitCode === 0 && root._statusBuf.trim()) {
                try {
                    const payload = JSON.parse(root._statusBuf)
                    root.powered = !!payload.powered
                    root.connectedName = payload.connected_name || ""
                    root.pairedDevices = payload.paired_devices || []
                    root.btConfig = payload.config || root.btConfig
                } catch (e) {
                    console.log("Bluetooth settings parse error:", e)
                }
            }
            root._statusBuf = ""
        }
    }

    Process {
        id: saveConfigProc
        property string jsonData: ""
        command: []
        onExited: root.loadStatus()
    }

    Process {
        id: reconnectProc
        command: ["python3", root.scriptPath, "force_autoconnect"]
        onExited: root.loadStatus()
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.loadStatus()
    }

    component ToggleSwitch: Rectangle {
        id: toggle
        width: 36
        height: 20
        radius: 10
        implicitWidth: 36
        implicitHeight: 20
        property bool checked: false
        signal toggled()
        color: checked ? root.accent : Qt.rgba(1, 1, 1, 0.18)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component StatusBadge: Rectangle {
        id: badge
        property string label: ""
        property color tone: Qt.rgba(1, 1, 1, 0.14)
        radius: 9
        color: tone
        implicitHeight: 24
        implicitWidth: textItem.implicitWidth + 18

        Text {
            id: textItem
            anchors.centerIn: parent
            text: badge.label
            color: "#ffffff"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    SectionHeader {
        text: "BLUETOOTH"
        textSecondary: root.textSecondary
        Layout.bottomMargin: 12
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.bottomMargin: 24
        radius: 12
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        implicitHeight: overviewCol.implicitHeight + 24

        ColumnLayout {
            id: overviewCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Smart reconnect"
                        color: root.textPrimary
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: connectedName !== ""
                            ? "Connected to " + connectedName
                            : (powered ? "Waiting for a known device" : "Bluetooth is off")
                        color: root.textSecondary
                        font.pixelSize: 12
                    }
                }

                StatusBadge {
                    label: powered ? "Powered" : "Off"
                    tone: powered ? Qt.rgba(0.18, 0.67, 0.38, 0.30) : Qt.rgba(0.75, 0.29, 0.24, 0.28)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.cardBorder }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StatusBadge {
                    label: String(root.pairedDevices.length) + " paired"
                    tone: Qt.rgba(0.25, 0.45, 0.95, 0.24)
                }

                StatusBadge {
                    label: connectedName !== "" ? "1 active" : "0 active"
                    tone: connectedName !== "" ? Qt.rgba(0.18, 0.67, 0.38, 0.30) : Qt.rgba(1, 1, 1, 0.12)
                }

                Item { Layout.fillWidth: true }

                SelectButton {
                    implicitWidth: 150
                    isButton: true
                    label: reconnectProc.running ? "Reconnecting..." : "Reconnect now"
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: {
                        if (!reconnectProc.running) {
                            reconnectProc.running = false
                            reconnectProc.running = true
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.bottomMargin: 24
        radius: 12
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        implicitHeight: automationCol.implicitHeight

        ColumnLayout {
            id: automationCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            SettingRow {
                label: "Auto reconnect"
                sublabel: "Reconnect paired devices automatically when Bluetooth becomes available."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch {
                    checked: root.btConfig.enabled !== false
                    onToggled: root.mutateConfig(function(next) {
                        next.enabled = !checked
                    })
                }
            }

            SettingRow {
                label: "Trusted devices only"
                sublabel: "Ignore paired devices that are not marked as trusted."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                ToggleSwitch {
                    checked: root.btConfig.trusted_only !== false
                    onToggled: root.mutateConfig(function(next) {
                        next.trusted_only = !checked
                    })
                }
            }

            SettingRow {
                label: "Retry interval"
                sublabel: "How often the system tries a new reconnect cycle."
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                SelectButton {
                    implicitWidth: 110
                    label: root.retryLabel(root.btConfig.retry_interval_sec || 12)
                    options: root.retryOptionLabels(root.retryOptions)
                    selectedIndex: Math.max(0, root.retryOptions.indexOf(root.btConfig.retry_interval_sec || 12))
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => root.mutateConfig(function(next) {
                        next.retry_interval_sec = root.retryOptions[index]
                    })
                }
            }

            SettingRow {
                label: "Manual disconnect snooze"
                sublabel: "Pause automatic reconnect after disconnecting a device manually."
                isLast: true
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                SelectButton {
                    implicitWidth: 110
                    label: root.retryLabel(root.btConfig.disconnect_snooze_sec || 300)
                    options: root.retryOptionLabels(root.snoozeOptions)
                    selectedIndex: Math.max(0, root.snoozeOptions.indexOf(root.btConfig.disconnect_snooze_sec || 300))
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => root.mutateConfig(function(next) {
                        next.disconnect_snooze_sec = root.snoozeOptions[index]
                    })
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        radius: 12
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        implicitHeight: deviceCol.implicitHeight + 8

        ColumnLayout {
            id: deviceCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Paired devices"
                    color: root.textPrimary
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Text {
                visible: !root.loading && root.pairedDevices.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.bottomMargin: 18
                text: "No paired devices yet. Once you pair one, it will appear here for auto-connect control."
                wrapMode: Text.Wrap
                color: root.textSecondary
                font.pixelSize: 12
            }

            Repeater {
                model: root.pairedDevices
                delegate: SettingRow {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    label: modelData.name
                    sublabel: root.deviceSubtitle(modelData)
                    isLast: index === root.pairedDevices.length - 1
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    ToggleSwitch {
                        checked: modelData.auto_connect !== false
                        onToggled: root.toggleDevice(modelData.mac, !checked)
                    }
                }
            }
        }
    }
}
