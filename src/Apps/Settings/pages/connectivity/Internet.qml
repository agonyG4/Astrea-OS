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
    property real   lastRx: 0
    property real   lastTx: 0
    property string _statsBuf: ""
    property string _dnsBuf: ""
    property string _firewallBuf: ""
    readonly property color accent: Theme.accent
    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBorder: Theme.cardBorder
    readonly property color popupBg: Theme.popupBg

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

    Timer { interval: 1000
 running: true
 repeat: true
 onTriggered: if (!statsProc.running) statsProc.running = true }
    Timer { id: statusClearTimer
 interval: 3000
 repeat: false
 onTriggered: root.applyStatus = "" }
    onApplyStatusChanged: if (applyStatus) statusClearTimer.restart()
    Component.onCompleted: { statsProc.running = true; fetchDns(); firewallProc.running = true }

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

    // Dialog DNS customizado
    Item {
        id: customDnsDialog
        anchors.fill: parent
 visible: false
 z: 100

        function open()  { dnsInput.text = ""; visible = true; dnsInput.forceActiveFocus() }
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
                        Text {
                            anchors.fill: parent
 verticalAlignment: Text.AlignVCenter
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.e_g_8_8_8_8_1_1_1_1"]) || "e.g. 8.8.8.8, 1.1.1.1")
                            font: dnsInput.font
 color: Qt.rgba(1,1,1,0.18)
                            visible: !dnsInput.text && !dnsInput.activeFocus
                        }
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
                isLast: true

                ValueLabel { text: root.interfaceName || "—" }
            }
        }

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.security"]) || "SECURITY")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 24

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
                isLast: true
            }
        }

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.text.quick_presets"]) || "QUICK PRESETS")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        FormCard {
            Layout.bottomMargin: 28

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.dns_preset"]) || "DNS preset")
                sublabel: root.applyStatus === "ok"
                    ? "Settings applied"
                    : (root.applyStatus === "error" ? "Failed to apply" : "Choose a known provider or reset to automatic")
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
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.sublabel.enter_custom_dns_servers_manually"]) || "Enter custom DNS servers manually")
                textPrimary: root.textPrimary
                textSecondary: root.textSecondary
                cardBorder: root.cardBorder
                isLast: true

                SelectButton {
                    implicitWidth: 120
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.internet.label.custom"]) || "Custom")
                    options: []
                    isButton: true
                    accent: root.accent
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    popupBg: root.popupBg
                    onSelected: customDnsDialog.open()
                }
            }
        }
    }
}
