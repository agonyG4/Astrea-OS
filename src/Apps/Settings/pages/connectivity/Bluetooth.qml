import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root
    contentMargins: 32
    maxWidth: 900

    readonly property string scriptPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/scripts/bluetooth_manager.py"
    
    property bool loading: true
    property bool powered: false
    property string adapterName: ""
    property string connectedName: ""
    property var pairedDevices: []
    property var btConfig: ({})
    property string _statusBuf: ""
    property string _powerBuf: ""
    property bool powerPending: false
    property string powerError: ""
    readonly property color accent: Theme.accent

    onPoweredChanged: {
        if (powered) startScan()
        else stopScan()
    }
    
    Component.onCompleted: {
        loadStatus()
        if (powered) startScan()
    }
    
    // Discovery State
    property bool scanning: false
    property var scannedDevices: []
    property string pairingMac: ""

    function loadStatus() {
        if (statusProc.running) return
        _statusBuf = ""
        statusProc.running = true
    }

    function setPower(target) {
        if (root.powerPending || target === root.powered)
            return

        root.powerPending = true
        root.powerError = ""
        root._powerBuf = ""

        if (!target)
            root.stopScan()

        btPowerProc.command = ["python3", root.scriptPath, "power", target ? "on" : "off"]
        btPowerProc.running = false
        btPowerProc.running = true
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
                    root.adapterName = payload.adapter_name || ""
                    root.connectedName = payload.connected_name || ""
                    root.pairedDevices = payload.paired_devices || []
                    root.btConfig = payload.config || {}
                } catch (e) { console.log("BT Error:", e) }
            }
            root._statusBuf = ""
        }
    }

    Process {
        id: btPowerProc
        command: []
        stdout: SplitParser {
            onRead: line => root._powerBuf += line
        }
        onExited: exitCode => {
            root.powerPending = false

            let ok = exitCode === 0
            try {
                if (root._powerBuf.trim()) {
                    const payload = JSON.parse(root._powerBuf)
                    ok = ok && payload.success === true
                    if (typeof payload.powered === "boolean")
                        root.powered = payload.powered
                    if (!ok)
                        root.powerError = payload.stderr || payload.stdout || payload.error || "Não foi possível alterar o Bluetooth."
                }
            } catch (e) {
                ok = false
                root.powerError = "Resposta inválida do Bluetooth."
                console.log("BT power parse error:", e)
            }
            if (!ok && root.powerError === "")
                root.powerError = "Não foi possível alterar o Bluetooth."

            root._powerBuf = ""
            postPowerRefresh.restart()
        }
    }

    Timer {
        id: postPowerRefresh
        interval: 450
        repeat: false
        onTriggered: root.loadStatus()
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.loadStatus()
    }

    Process {
        id: btControlProc
        onExited: () => root.loadStatus()
    }

    // --- Discovery Processes ---
    function startScan() {
        if (!root.powered || scanning) return
        scanning = true
        scannedDevices = []
        scanProc.running = false
        scanProc.running = true
    }

    function stopScan() {
        scanProc.running = false
        scanStopProc.running = false
        scanStopProc.running = true
        scanning = false
    }

    function pairDevice(mac) {
        if (!mac) return
        pairingMac = mac
        pairProc.targetMac = mac
        pairProc.running = false
        pairProc.running = true
    }

    Process {
        id: scanProc
        command: ["python3", root.scriptPath, "scan-stream"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const payload = JSON.parse(data.trim())
                    if (payload.event === "done") {
                        root.scanning = false
                    } else if (payload.event === "found") {
                        const mac = payload.mac || ""
                        const name = payload.name || ""
                        const isPaired = root.pairedDevices.some(d => d.mac === mac)
                        const isScanned = root.scannedDevices.some(d => d.mac === mac)
                        if (mac && name && !isPaired && !isScanned) {
                            const updated = root.scannedDevices.slice()
                            updated.push({ mac: mac, name: name })
                            root.scannedDevices = updated
                        }
                    }
                } catch (error) {
                }
            }
        }
        onRunningChanged: if (!running) root.scanning = false
    }

    Process {
        id: scanStopProc
        command: ["bluetoothctl", "scan", "off"]
        running: false
    }

    Process {
        id: pairProc
        property string targetMac: ""
        command: ["bluetoothctl", "pair", targetMac]
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                trustProc.targetMac = targetMac
                trustProc.running = false
                trustProc.running = true
                return
            }
            root.pairingMac = ""
            root.loadStatus()
            root.scannedDevices = []
            root.startScan() // Refresh scan after pairing
        }
    }

    Process {
        id: trustProc
        property string targetMac: ""
        command: ["bluetoothctl", "trust", targetMac]
        running: false
        onExited: () => {
            root.pairingMac = ""
            root.loadStatus()
            root.scannedDevices = []
            root.startScan() // Refresh scan after pairing
        }
    }


    ColumnLayout {
        width: parent.width
        spacing: 24

        // ── Main Card ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Theme.cardBg
            border.width: 1
            border.color: Theme.cardBorder
            implicitHeight: mainCardCol.implicitHeight + 32

            ColumnLayout {
                id: mainCardCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Bluetooth Icon (Fixed blue background, larger size)
                    Rectangle {
                        width: 50
                        height: 40
                        radius: 8
                        color: "transparent"

                        Image {
                            anchors.centerIn: parent
                            width: 60; height: 60
                            source: "file://" + (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Assets/icons/settings/bluetooth.svg"
                            sourceSize: Qt.size(120, 120)
                            mipmap: true
                            smooth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.bluetooth.text.bluetooth"]) || "Bluetooth")
                            color: Theme.textPrimary
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.family: Theme.fontFamily
                        }

                        Text {
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["settings.bluetooth.accessories_help"]) || "Connect to accessories you can use for music streaming, typing, and gaming.")
                            color: Theme.textSecondary
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            font.family: Theme.fontFamily
                            lineHeight: 1.1
                            opacity: 0.85
                        }
                    }

                    ToggleSwitch {
                        checked: root.powered
                        enabled: !root.powerPending
                        opacity: enabled ? 1.0 : 0.55
                        onToggled: root.setPower(!root.powered)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.cardBorder
                    opacity: 0.4
                }

                Text {
                    text: root.powerError !== ""
                          ? root.powerError
                          : root.powerPending
                            ? "Alterando estado do Bluetooth..."
                            : root.powered
                              ? "Este Astrea pode ser encontrado como \"" + root.adapterName + "\" enquanto os Ajustes de Bluetooth estiverem abertos."
                              : "Bluetooth desligado."
                    color: root.powerError !== "" ? Theme.errorColor : Theme.textSecondary
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                    opacity: 0.7
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }

        // ── Section Header: MY DEVICES ──────────────────────────────────
        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.bluetooth.text.meus_dispositivos"]) || "MY DEVICES")
            Layout.leftMargin: 12
            Layout.topMargin: 8
            visible: root.pairedDevices.length > 0
        }

        // ── Paired Devices Card ──────────────────────────────────────────
        FormCard {
            visible: root.pairedDevices.length > 0

            Repeater {
                model: root.pairedDevices
                delegate: IconListRow {
                    iconText: modelData.connected ? "󰂱" : "󰂯"
                    iconColor: modelData.connected ? root.accent : Theme.textSecondary
                    iconOpacity: modelData.connected ? 1.0 : 0.6
                    label: modelData.name
                    sublabel: modelData.connected ? "Conectado" : "Não conectado"
                    showChevron: true
                    isLast: index === root.pairedDevices.length - 1
                    
                    onClicked: {
                        if (modelData.connected) {
                            btControlProc.command = ["python3", root.scriptPath, "disconnect", modelData.mac]
                        } else {
                            btControlProc.command = ["python3", root.scriptPath, "connect", modelData.mac]
                        }
                        btControlProc.running = false
                        btControlProc.running = true
                    }
                }
            }
        }
        // ── Section Header: OTHER DEVICES ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 20
            visible: root.scannedDevices.length > 0
            
            SectionHeader {
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.connectivity.bluetooth.text.outros_dispositivos"]) || "OTHER DEVICES")
                Layout.fillWidth: true
            }
            
            // Scanning Indicator
            Text {
                id: scanText
                visible: root.scanning
                property int dotCount: 0
                text: {
                    if (dotCount === 0) return "Buscando"
                    if (dotCount === 1) return "Buscando."
                    if (dotCount === 2) return "Buscando.."
                    return "Buscando..."
                }
                color: Theme.textSecondary
                font.pixelSize: 11
                font.family: Theme.fontFamily
                opacity: 0.5
                Layout.alignment: Qt.AlignVCenter
                
                Timer {
                    running: scanText.visible
                    repeat: true
                    interval: 400
                    onTriggered: scanText.dotCount = (scanText.dotCount + 1) % 4
                }
            }
        }

        // ── Other Devices Card ──────────────────────────────────────────
        FormCard {
            visible: root.scannedDevices.length > 0

            Repeater {
                model: root.scannedDevices
                delegate: IconListRow {
                    iconText: "󰂯"
                    label: modelData.name
                    isLast: index === root.scannedDevices.length - 1
                    interactive: root.pairingMac === ""
                    onClicked: root.pairDevice(modelData.mac)

                    // Pairing indicator slot
                    BusyIndicator {
                        visible: root.pairingMac === modelData.mac
                        running: visible
                        implicitWidth: 16; implicitHeight: 16
                    }
                }
            }
        }
    }
}
