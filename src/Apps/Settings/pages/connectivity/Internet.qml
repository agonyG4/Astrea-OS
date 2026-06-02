import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

Item {
    id: root

    // ── Constants ────────────────────────────────────────────────────────────
    readonly property string _script: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/network/manager.py"
    readonly property var dnsPresets: [
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.auto"]) || "Auto"),       value: "",                             color: "#888888" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.cloudflare"]) || "Cloudflare"), value: "1.1.1.1, 1.0.0.1",           color: "#f38020" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.google"]) || "Google"),     value: "8.8.8.8, 8.8.4.4",           color: "#4285f4" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.quad9"]) || "Quad9"),      value: "9.9.9.9, 149.112.112.112",    color: "#3ddc97" },
        { label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.adguard"]) || "AdGuard"),    value: "94.140.14.14, 94.140.15.15",  color: "#68bc71" },
    ]
    readonly property var _dnsMap: ({
        "1.1.1.1": "Cloudflare", "1.0.0.1": "Cloudflare",
        "8.8.8.8": "Google",     "8.8.4.4": "Google",
        "9.9.9.9": "Quad9",      "149.112.112.112": "Quad9",
        "94.140.14.14": "AdGuard","94.140.15.15": "AdGuard",
    })
    readonly property var _providerColor: ({
        "Cloudflare": "#f38020", "Google": "#4285f4",
        "Quad9": "#3ddc97",      "AdGuard": "#68bc71",
    })

    // ── State ────────────────────────────────────────────────────────────────
    property bool   loading: true
    property string uploadSpeed: "0 B/s"
    property string downloadSpeed: "0 B/s"
    property string interfaceName: ""
    property string currentConnection: ""
    property string firewallStatus: "Inactive"
    property bool   firewallActive: false
    property string currentDnsLabel: "Automatic (ISP)"
    property string currentDnsDetail: "Using DNS provided automatically by the network."
    property color  currentDnsBadgeColor: "#888888"
    property bool   currentDnsAuto: true
    property string applyStatus: ""
    property string selectedPreset: "Auto"
    property bool   wifiLoading: true
    property bool   wifiAvailable: false
    property bool   wifiEnabled: false
    property bool   wifiTogglePending: false
    property string wifiDevice: ""
    property string wifiState: ""
    property string wifiConnectedSsid: ""
    property string wifiActionStatus: ""
    property var    wifiNetworks: []
    property string wifiSelectedSsid: ""
    property bool   wifiSelectedRequiresPassword: false
    property bool   warpLoading: true
    property bool   warpInstalled: false
    property bool   warpConnected: false
    property bool   warpServiceActive: false
    property bool   warpActionPending: false
    property string warpStatus: "Unknown"
    property string warpNetwork: ""
    property string warpDetail: ""
    property string warpServiceState: "unknown"
    property string warpServiceEnabled: "unknown"
    property string warpTrayState: "unknown"
    property string warpActionStatus: ""
    property real   lastRx: 0
    property real   lastTx: 0
    property string _statsBuf: ""
    property string _dnsBuf: ""
    property string _firewallBuf: ""
    property string _wifiBuf: ""
    property string _wifiActionBuf: ""
    property string _warpBuf: ""
    property string _warpActionBuf: ""
    readonly property color accent: Theme.accent
    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBorder: Theme.cardBorder
    readonly property color popupBg: Theme.popupBg
    readonly property var connectedWifiNetwork: wifiNetworks.find(network => !!network.active) || null
    readonly property var availableWifiNetworks: wifiNetworks.filter(network => !network.active)

    // ── Helpers ──────────────────────────────────────────────────────────────
    function formatBytes(b) {
        if (b < 1024)    return b.toFixed(0) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(1) + " MB/s"
    }

    function normalizeDns(v) {
        const raw = (v || "").trim()
        return (raw === "" || raw.toLowerCase() === "auto")
            ? "" : raw.split(/\s*,\s*|\s+/).filter(Boolean).join(", ")
    }

    function connectionKind() {
        const iface = (interfaceName || "").toLowerCase()
        if (iface.startsWith("wl") || iface.includes("wifi") || iface.includes("wlan")) return "Wi-Fi"
        if (iface.startsWith("en") || iface.startsWith("eth"))                           return "Ethernet"
        return "Network"
    }

    function updateDnsPresentation(servers, isAuto) {
        currentDnsAuto = isAuto
        if (isAuto || !servers.length) {
            currentDnsLabel      = "Automatic (ISP)"
            currentDnsDetail     = "Using DNS provided automatically by the network."
            currentDnsBadgeColor = "#888888"
            selectedPreset       = "Auto"
            return
        }
        const joined   = servers.join(", ")
        const provider = _dnsMap[servers[0]] || ""
        const preset   = dnsPresets.find(p => normalizeDns(p.value) === normalizeDns(joined))
        currentDnsLabel      = provider || (preset ? preset.label : "Custom")
        currentDnsDetail     = joined
        currentDnsBadgeColor = _providerColor[currentDnsLabel] || "#888888"
        selectedPreset       = preset ? preset.label : ""
    }

    function fetchDns() {
        if (!dnsProc.running) { _dnsBuf = ""; dnsProc.running = true }
    }

    function applyDnsValue(value) {
        if (applyDnsProc.running || !currentConnection) return
        const normalized     = normalizeDns(value)
        applyDnsProc.conn    = currentConnection
        applyDnsProc.dns     = normalized === "" ? "auto" : normalized.replace(/,\s*/g, " ")
        applyDnsProc.running = true
        applyStatus          = ""
    }

    function wifiSubtitle() {
        if (!wifiAvailable) return "No Wi-Fi adapter detected"
        if (!wifiEnabled) return "Wi-Fi radio disabled"
        if (wifiConnectedSsid) return "Connected to " + wifiConnectedSsid
        return "Available networks"
    }

    function wifiSecurityLabel(network) {
        if (!network || !network.security) return "Open network"
        return network.security
    }

    function loadWifi() {
        if (wifiProc.running) return
        _wifiBuf = ""
        wifiProc.running = true
    }

    function applyWifiPayload(payload) {
        wifiLoading = false
        wifiAvailable = !!payload.available
        wifiEnabled = !!payload.enabled
        wifiDevice = payload.device || ""
        wifiState = payload.state || ""
        wifiConnectedSsid = payload.connected_ssid || ""
        wifiNetworks = payload.networks || []
    }

    function connectWifi(network) {
        if (!network || wifiConnectProc.running) return
        wifiSelectedSsid = network.ssid || ""
        wifiSelectedRequiresPassword = !!network.requires_password
        if (wifiSelectedRequiresPassword) {
            wifiPasswordDialog.open()
            return
        }
        wifiConnectProc.ssid = wifiSelectedSsid
        wifiConnectProc.password = ""
        wifiConnectProc.running = true
    }

    function disconnectWifi() {
        if (wifiDisconnectProc.running) return
        wifiActionStatus = ""
        _wifiActionBuf = ""
        wifiDisconnectProc.running = true
    }

    function setWifiEnabled(enabled) {
        if (!wifiAvailable || wifiRadioProc.running)
            return
        wifiActionStatus = ""
        _wifiActionBuf = ""
        wifiTogglePending = true
        wifiRadioProc.enabledValue = enabled ? "on" : "off"
        wifiRadioProc.running = true
    }

    function warpSubtitle() {
        if (warpLoading) return "Checking Cloudflare WARP"
        if (!warpInstalled) return "warp-cli is not installed"
        if (warpActionPending) return "Applying change"
        if (warpConnected) return warpNetwork ? ("Connected · " + warpNetwork) : "Connected"
        if (warpServiceActive) return "Daemon active, tunnel disconnected"
        return "Daemon stopped"
    }

    function applyWarpPayload(payload) {
        warpLoading = false
        warpInstalled = !!payload.installed
        warpConnected = !!payload.connected
        warpServiceActive = !!payload.service_active
        warpStatus = payload.status || "Unknown"
        warpNetwork = payload.network || ""
        warpDetail = payload.detail || payload.reason || ""
        warpServiceState = payload.service_state || "unknown"
        warpServiceEnabled = payload.service_enabled || "unknown"
        warpTrayState = payload.tray_state || "unknown"
    }

    function loadWarp() {
        if (warpStatusProc.running) return
        _warpBuf = ""
        warpStatusProc.running = true
    }

    function setWarpEnabled(enabled) {
        if (!warpInstalled || warpActionProc.running)
            return
        warpActionStatus = ""
        _warpActionBuf = ""
        warpActionPending = true
        warpActionProc.action = enabled ? "on" : "off"
        warpActionProc.running = true
    }

    function restartWarp() {
        if (!warpInstalled || warpActionProc.running)
            return
        warpActionStatus = ""
        _warpActionBuf = ""
        warpActionPending = true
        warpActionProc.action = "restart"
        warpActionProc.running = true
    }

    // ── Processes ────────────────────────────────────────────────────────────
    Process {
        id: statsProc
        command: ["python3", root._script, "stats"]
        stdout: SplitParser { onRead: (l) => root._statsBuf += l }
        onExited: (code) => {
            if (code === 0 && root._statsBuf) {
                try {
                    const d   = JSON.parse(root._statsBuf)
                    if (d.iface) root.interfaceName = d.iface
                    const rxD = (root.lastRx > 0 && d.rx >= root.lastRx) ? d.rx - root.lastRx : 0
                    const txD = (root.lastTx > 0 && d.tx >= root.lastTx) ? d.tx - root.lastTx : 0
                    root.downloadSpeed = root.formatBytes(rxD)
                    root.uploadSpeed   = root.formatBytes(txD)
                    root.lastRx = d.rx; root.lastTx = d.tx
                } catch (_) {}
            }
            root._statsBuf = ""
        }
    }

    Process {
        id: dnsProc
        command: ["python3", root._script, "dns_info"]
        stdout: SplitParser { onRead: (l) => root._dnsBuf += l }
        onExited: (code) => {
            root.loading = false
            if (code === 0 && root._dnsBuf) {
                try {
                    const d = JSON.parse(root._dnsBuf)
                    root.currentConnection = d.connection || "Unknown"
                    root.updateDnsPresentation(d.dns || [], !!d.auto)
                } catch (_) {}
            }
            root._dnsBuf = ""
        }
    }

    Process {
        id: firewallProc
        command: ["sh", "-c", "systemctl is-active ufw 2>/dev/null || systemctl is-active firewalld 2>/dev/null || echo inactive"]
        stdout: SplitParser { onRead: (l) => root._firewallBuf += l + "\n" }
        onExited: {
            const lines = root._firewallBuf.trim().split(/\n+/).filter(Boolean)
            root.firewallActive = lines.includes("active")
            root.firewallStatus = root.firewallActive ? "Active" : "Inactive"
            root._firewallBuf = ""
        }
    }

    Process {
        id: applyDnsProc
        property string conn: ""
        property string dns: ""
        command: ["python3", root._script, "set_dns", conn, dns]
        stdout: SplitParser {
            onRead: (l) => {
                try { root.applyStatus = JSON.parse(l).success ? "ok" : "error" }
                catch (_) { root.applyStatus = "error" }
            }
        }
        onExited: root.fetchDns()
    }

    Process {
        id: wifiProc
        command: ["python3", root._script, "wifi_status"]
        stdout: SplitParser { onRead: (l) => root._wifiBuf += l }
        onExited: (code) => {
            if (code === 0 && root._wifiBuf) {
                try {
                    const payload = JSON.parse(root._wifiBuf)
                    root.applyWifiPayload(payload)
                } catch (_) {
                    root.wifiLoading = false
                    root.wifiActionStatus = "error"
                }
            } else {
                root.wifiLoading = false
            }
            root._wifiBuf = ""
        }
    }

    Process {
        id: wifiConnectProc
        property string ssid: ""
        property string password: ""
        command: ["python3", root._script, "wifi_connect", ssid, password]
        stdout: SplitParser { onRead: (l) => root._wifiActionBuf += l }
        onExited: (code) => {
            let ok = code === 0
            if (root._wifiActionBuf) {
                try {
                    const payload = JSON.parse(root._wifiActionBuf)
                    ok = ok && payload.success !== false
                    if (ok) root.applyWifiPayload(payload)
                } catch (_) {
                    ok = false
                }
            }
            root.wifiActionStatus = ok ? "ok" : "error"
            root._wifiActionBuf = ""
            root.loadWifi()
        }
    }

    Process {
        id: wifiDisconnectProc
        command: ["python3", root._script, "wifi_disconnect"]
        stdout: SplitParser { onRead: (l) => root._wifiActionBuf += l }
        onExited: (code) => {
            let ok = code === 0
            if (root._wifiActionBuf) {
                try {
                    const payload = JSON.parse(root._wifiActionBuf)
                    ok = ok && payload.success !== false
                    if (ok) root.applyWifiPayload(payload)
                } catch (_) {
                    ok = false
                }
            }
            root.wifiActionStatus = ok ? "ok" : "error"
            root._wifiActionBuf = ""
            root.loadWifi()
        }
    }

    Process {
        id: wifiRadioProc
        property string enabledValue: "on"
        command: ["python3", root._script, "wifi_set_enabled", enabledValue]
        stdout: SplitParser { onRead: (l) => root._wifiActionBuf += l }
        onExited: (code) => {
            let ok = code === 0
            if (root._wifiActionBuf) {
                try {
                    const payload = JSON.parse(root._wifiActionBuf)
                    ok = ok && payload.success !== false
                    if (ok) root.applyWifiPayload(payload)
                } catch (_) {
                    ok = false
                }
            }
            root.wifiTogglePending = false
            root.wifiActionStatus = ok ? "ok" : "error"
            root._wifiActionBuf = ""
            root.loadWifi()
        }
    }

    Process {
        id: warpStatusProc
        command: ["python3", root._script, "warp_status"]
        stdout: SplitParser { onRead: (l) => root._warpBuf += l }
        onExited: (code) => {
            if (code === 0 && root._warpBuf) {
                try {
                    root.applyWarpPayload(JSON.parse(root._warpBuf))
                } catch (_) {
                    root.warpLoading = false
                    root.warpActionStatus = "error"
                }
            } else {
                root.warpLoading = false
            }
            root._warpBuf = ""
        }
    }

    Process {
        id: warpActionProc
        property string action: "on"
        command: action === "restart"
            ? ["python3", root._script, "warp_restart"]
            : ["python3", root._script, "warp_set_enabled", action]
        stdout: SplitParser { onRead: (l) => root._warpActionBuf += l }
        onExited: (code) => {
            let ok = code === 0
            if (root._warpActionBuf) {
                try {
                    const payload = JSON.parse(root._warpActionBuf)
                    ok = ok && payload.success !== false
                    root.applyWarpPayload(payload)
                } catch (_) {
                    ok = false
                }
            }
            root.warpActionPending = false
            root.warpActionStatus = ok ? "ok" : "error"
            root._warpActionBuf = ""
            root.loadWarp()
        }
    }

    Timer { interval: 1000
 running: true
 repeat: true
 onTriggered: if (!statsProc.running) statsProc.running = true }
    Timer { interval: 20000
 running: true
 repeat: true
 onTriggered: root.loadWifi() }
    Timer { interval: 15000
 running: true
 repeat: true
 onTriggered: root.loadWarp() }
    Timer { id: statusClearTimer
 interval: 3000
 repeat: false
 onTriggered: { root.applyStatus = ""; root.wifiActionStatus = ""; root.warpActionStatus = "" } }
    onApplyStatusChanged: if (applyStatus) statusClearTimer.restart()
    onWifiActionStatusChanged: if (wifiActionStatus) statusClearTimer.restart()
    onWarpActionStatusChanged: if (warpActionStatus) statusClearTimer.restart()
    Component.onCompleted: { statsProc.running = true; fetchDns(); firewallProc.running = true; loadWifi(); loadWarp() }

    // ── Inline Components ─────────────────────────────────────────────────────

    // Linha estilo macOS: label cinza à esquerda, valor à direita
    component InfoRow: Item {
        property string label: ""
        property string value: ""
        property bool   isLast: false
        property bool   valueBold: false
        property color  valueColor: Qt.rgba(1,1,1,0.85)

        Layout.fillWidth: true
        implicitHeight: 44

        RowLayout {
            anchors { fill: parent
 leftMargin: 16
 rightMargin: 16 }
            Text {
                text: label
                color: Qt.rgba(1,1,1,0.4)
                font.family: Theme.fontFamily
                font.pixelSize: 13; font.weight: 400
                Layout.preferredWidth: 100
            }
            Text {
                text: value
                color: valueColor
                font.family: Theme.fontFamily
                font.pixelSize: 13; font.weight: valueBold ? 600 : 400
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            visible: !isLast
            anchors { bottom: parent.bottom
 left: parent.left
 right: parent.right
 leftMargin: 16 }
            height: 1
 color: Qt.rgba(1,1,1,0.06)
        }
    }

    // Chip de preset DNS
    component DnsChip: Rectangle {
        property string label: ""
        property string value: ""
        property color  chipColor: "#888"
        property bool   selected: false
        signal clicked()

        implicitWidth: _lbl.implicitWidth + 20
        implicitHeight: 26
 radius: 13
        color: selected ? Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.15) : Qt.rgba(1,1,1,0.05)
        border.width: 1
        border.color: selected ? Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.45) : Qt.rgba(1,1,1,0.08)
        Behavior on color        { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            anchors.centerIn: parent
 spacing: 6
            Rectangle {
                width: 5
 height: 5
 radius: 3
 color: parent.parent.chipColor
                opacity: parent.parent.selected ? 1 : 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: _lbl
 text: parent.parent.label
                color: parent.parent.selected ? parent.parent.chipColor : Theme.textSecondary
                font.family: Theme.fontFamily; font.pixelSize: 12
                font.weight: parent.parent.selected ? 500 : 400
            }
        }
        MouseArea { anchors.fill: parent
 cursorShape: Qt.PointingHandCursor
 onClicked: parent.clicked() }
    }

    component ValueLabel: Text {
        property bool strong: false

        color: root.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        font.weight: strong ? Theme.fontWeightDemiBold : Theme.fontWeightMedium
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        Layout.preferredWidth: 190
    }

    component MiniButton: Rectangle {
        property string label: ""
        property bool primary: false
        property bool enabledState: true
        signal clicked()

        implicitWidth: Math.max(92, buttonLabel.implicitWidth + 26)
        implicitHeight: 32
        radius: 8
        opacity: enabledState ? 1 : 0.55
        color: primary ? Theme.accent : (buttonArea.containsMouse ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.055))
        border.width: primary ? 0 : 1
        border.color: Qt.rgba(1,1,1,0.09)

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: parent.label
            color: parent.primary ? Theme.accentForeground : root.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: 600
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            enabled: parent.enabledState
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.clicked()
        }
    }

    component WifiSignal: Row {
        id: signalBars
        property int strength: 0

        spacing: 2
        width: 22
        height: 16
        Repeater {
            model: 4
            Rectangle {
                width: 4
                height: 4 + index * 3
                radius: 2
                anchors.bottom: parent.bottom
                color: root.accent
                opacity: signalBars.strength > index * 25 ? 0.95 : 0.22
            }
        }
    }

    // Dialog DNS customizado
    Item {
        id: customDnsDialog
        anchors.fill: parent
 visible: false
 z: 100

        function open()  {
            dnsInput.text = root.currentDnsAuto ? "" : root.currentDnsDetail
            visible = true
            dnsInput.forceActiveFocus()
        }
        function apply() { root.applyDnsValue(dnsInput.text); visible = false }

        Rectangle {
            anchors.fill: parent
 color: Qt.rgba(0,0,0,0.4)
            MouseArea { anchors.fill: parent
 onClicked: customDnsDialog.visible = false }
        }

        Rectangle {
            anchors.centerIn: parent
 width: 320
 radius: 14
            color: Qt.rgba(0.13, 0.13, 0.15, 0.98)
            border.width: 1; border.color: Qt.rgba(1,1,1,0.09)
            implicitHeight: _dlg.implicitHeight + 44
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: _dlg
                anchors { left: parent.left
 right: parent.right
 top: parent.top
 margins: 20 }
                spacing: 12

                Text {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.custom_dns"]) || "Custom DNS")
                    color: Qt.rgba(1,1,1,0.85)
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: 600
                }
                Text {
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.enter_one_or_two_servers_separated_by_a_comma_le"]) || "Enter one or two servers separated by a comma. Leave blank to reset to automatic.")
                    color: Qt.rgba(1,1,1,0.35)
                    font.family: Theme.fontFamily; font.pixelSize: 12
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
 height: 34
 radius: 8
                    color: Qt.rgba(1,1,1,0.07)
                    border.width: 1
                    border.color: dnsInput.activeFocus ? Theme.accent : Qt.rgba(1,1,1,0.1)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: dnsInput
                        anchors { fill: parent
 leftMargin: 10
 rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily; font.pixelSize: 13
                        color: Qt.rgba(1,1,1,0.85)
 selectionColor: Theme.accent
                        Keys.onReturnPressed: customDnsDialog.apply()
                        Keys.onEscapePressed: customDnsDialog.visible = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
 spacing: 8
                    Repeater {
                        model: [{ t: "Cancel", accent: false }, { t: "Apply", accent: true }]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
 height: 32
 radius: 8
                            color: modelData.accent ? Theme.accent : Qt.rgba(1,1,1,0.07)
                            border.width: modelData.accent ? 0 : 1; border.color: Qt.rgba(1,1,1,0.09)
                            Text {
                                anchors.centerIn: parent
 text: modelData.t
                                color: modelData.accent ? Theme.accentForeground : Qt.rgba(1,1,1,0.55)
                                font.family: Theme.fontFamily; font.pixelSize: 13
                                font.weight: modelData.accent ? 500 : 400
                            }
                            MouseArea {
                                anchors.fill: parent
 cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.accent ? customDnsDialog.apply() : (customDnsDialog.visible = false)
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: wifiPasswordDialog
        anchors.fill: parent
        visible: false
        z: 101

        function open() {
            wifiPasswordInput.text = ""
            visible = true
            wifiPasswordInput.forceActiveFocus()
        }
        function apply() {
            root.wifiActionStatus = ""
            root._wifiActionBuf = ""
            wifiConnectProc.ssid = root.wifiSelectedSsid
            wifiConnectProc.password = wifiPasswordInput.text
            visible = false
            wifiConnectProc.running = true
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0,0,0,0.4)
            MouseArea { anchors.fill: parent; onClicked: wifiPasswordDialog.visible = false }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 340
            radius: 14
            color: Qt.rgba(0.13, 0.13, 0.15, 0.98)
            border.width: 1
            border.color: Qt.rgba(1,1,1,0.09)
            implicitHeight: wifiDlg.implicitHeight + 44
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: wifiDlg
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 12

                Text {
                    text: root.wifiSelectedSsid
                    color: root.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: 700
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "Network password"
                    color: root.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color: Qt.rgba(1,1,1,0.07)
                    border.width: 1
                    border.color: wifiPasswordInput.activeFocus ? Theme.accent : Qt.rgba(1,1,1,0.1)

                    TextInput {
                        id: wifiPasswordInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: root.textPrimary
                        selectionColor: Theme.accent
                        Keys.onReturnPressed: wifiPasswordDialog.apply()
                        Keys.onEscapePressed: wifiPasswordDialog.visible = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MiniButton {
                        Layout.fillWidth: true
                        label: "Cancel"
                        onClicked: wifiPasswordDialog.visible = false
                    }
                    MiniButton {
                        Layout.fillWidth: true
                        label: "Join"
                        primary: true
                        onClicked: wifiPasswordDialog.apply()
                    }
                }
            }
        }
    }

    // ── Main UI ──────────────────────────────────────────────────────────────
    ScrollPage {
        anchors.fill: parent
        contentMargins: 32
        maxWidth: 900

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.network"]) || "NETWORK")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.status"]) || "Status")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.current_connection_type"]) || "Current connection type")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                ValueLabel {
                    text: root.connectionKind()
                    color: root.accent
                    strong: true
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.connection"]) || "Connection")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.active_networkmanager_profile"]) || "Active NetworkManager profile")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                ValueLabel { text: root.currentConnection || "—" }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.interface"]) || "Interface")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.network_interface_in_use"]) || "Network interface in use")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                ValueLabel { text: root.interfaceName || "—" }
            }

            SettingRow {
                label: "Activity"
                sublabel: "Current transfer rate"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true

                ValueLabel {
                    text: "Down " + root.downloadSpeed + "  Up " + root.uploadSpeed
                    strong: true
                }
            }
        }

        SectionHeader {
            visible: root.wifiAvailable
            text: "WI-FI"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            visible: root.wifiAvailable
            Layout.bottomMargin: 24

            SettingRow {
                label: "Wi-Fi"
                sublabel: root.wifiSubtitle()
                textPrimary: root.textPrimary
                textSecondary: root.wifiActionStatus === "error" ? "#ff5f57" : (root.wifiActionStatus === "ok" ? "#3ddc97" : root.textSecondary)
                cardBorder: root.cardBorder

                ToggleSwitch {
                    enabled: !root.wifiTogglePending
                    checked: root.wifiEnabled
                    onToggled: targetChecked => root.setWifiEnabled(targetChecked)
                }
            }

            SettingRow {
                visible: root.wifiEnabled && root.connectedWifiNetwork !== null
                label: "Connected Network"
                sublabel: root.connectedWifiNetwork
                    ? root.wifiSecurityLabel(root.connectedWifiNetwork) + " · " + (root.connectedWifiNetwork.signal || 0) + "%"
                    : ""
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: !root.wifiEnabled || root.availableWifiNetworks.length === 0

                RowLayout {
                    spacing: 10

                    Text {
                        text: root.connectedWifiNetwork ? root.connectedWifiNetwork.ssid : ""
                        color: root.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: 700
                        elide: Text.ElideRight
                        Layout.preferredWidth: 160
                    }

                    WifiSignal { strength: root.connectedWifiNetwork ? (root.connectedWifiNetwork.signal || 0) : 0 }

                    MiniButton {
                        label: "Disconnect"
                        onClicked: root.disconnectWifi()
                    }
                }
            }

            SettingRow {
                visible: root.wifiEnabled && root.availableWifiNetworks.length > 0
                label: "Available Networks"
                sublabel: "Choose a network to connect"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: false
            }

            Repeater {
                model: root.wifiEnabled ? root.availableWifiNetworks : []
                delegate: SettingRow {
                    required property var modelData
                    required property int index

                    label: modelData.ssid || "Hidden Network"
                    sublabel: root.wifiSecurityLabel(modelData) + " · " + (modelData.signal || 0) + "%"
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder
                    clickable: true
                    isLast: index === root.availableWifiNetworks.length - 1
                    onClicked: root.connectWifi(modelData)

                    RowLayout {
                        spacing: 10

                        WifiSignal { strength: modelData.signal || 0 }

                        MiniButton {
                            label: "Join"
                            primary: true
                            onClicked: root.connectWifi(modelData)
                        }
                    }
                }
            }

            SettingRow {
                visible: root.wifiEnabled && !root.wifiLoading && root.wifiNetworks.length === 0
                label: "No networks found"
                sublabel: "No Wi-Fi networks are visible right now"
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true
            }
        }

        SectionHeader {
            text: "CLOUDFLARE WARP"
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24

            SettingRow {
                label: "Cloudflare WARP"
                sublabel: root.warpActionStatus === "ok"
                    ? "WARP setting applied"
                    : (root.warpActionStatus === "error" ? "Could not apply WARP setting" : root.warpSubtitle())
                textPrimary: root.textPrimary
                textSecondary: root.warpActionStatus === "error" ? "#ff5f57" : (root.warpActionStatus === "ok" ? "#3ddc97" : root.textSecondary)
                cardBorder: root.cardBorder
                isLast: true

                ToggleSwitch {
                    enabled: root.warpInstalled && !root.warpActionPending
                    checked: root.warpConnected
                    onToggled: targetChecked => root.setWarpEnabled(targetChecked)
                }
            }
        }

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.dns"]) || "DNS")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.provider"]) || "Provider")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.current_dns_provider"]) || "Current DNS provider")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                ValueLabel {
                    text: root.currentDnsLabel
                    color: root.currentDnsAuto ? root.textPrimary : root.currentDnsBadgeColor
                    strong: !root.currentDnsAuto
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.mode"]) || "Mode")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.dns_assignment_mode"]) || "DNS assignment mode")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder

                ValueLabel {
                    text: root.currentDnsAuto ? "Automatic" : "Manual"
                    color: root.currentDnsAuto ? root.textSecondary : "#3ddc97"
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.servers"]) || "Servers")
                sublabel: root.currentDnsAuto ? "Assigned by network" : root.currentDnsDetail
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.dns_preset"]) || "DNS preset")
                sublabel: root.applyStatus === "ok"
                    ? "Settings applied"
                    : (root.applyStatus === "error" ? "Failed to apply" : "Choose a provider or return to automatic DNS")
                textPrimary: root.textPrimary
                textSecondary: root.applyStatus === "error" ? "#ff5f57" : (root.applyStatus === "ok" ? "#3ddc97" : root.textSecondary)
                cardBorder: root.cardBorder

                SelectButton {
                    implicitWidth: 160
                    label: root.selectedPreset || "Custom"
                    options: root.dnsPresets.map(p => p.label)
                    selectedIndex: root.dnsPresets.findIndex(p => p.label === root.selectedPreset)
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: index => {
                        const preset = root.dnsPresets[index]
                        root.selectedPreset = preset.label
                        root.applyDnsValue(preset.value)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.custom_dns"]) || "Custom DNS")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.enter_custom_dns_servers_manually"]) || "Set DNS servers manually")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true

                MiniButton {
                    label: "Edit"
                    onClicked: customDnsDialog.open()
                }
            }
        }

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.security"]) || "SECURITY")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 28

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.firewall"]) || "Firewall")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.local_firewall_service_state"]) || "Local firewall service state")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true

                ValueLabel {
                    text: root.firewallStatus
                    color: root.firewallActive ? "#3ddc97" : root.textSecondary
                    strong: root.firewallActive
                }
            }
        }
    }
}
