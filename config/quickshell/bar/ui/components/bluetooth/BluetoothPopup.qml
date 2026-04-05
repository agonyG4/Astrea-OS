import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool   shown:       false
    property bool   btOn:        false
    property string devicesJson: "[]"
    property string scannedJson: "[]"
    property bool   scanning:    false
    property var    btProcess:   null
    property real   anchorX:     screen.width - 158  // fallback

    readonly property var parsedDevices: {
        try { return JSON.parse(devicesJson) } catch(e) { return [] }
    }
    readonly property var parsedScanned: {
        try { return JSON.parse(scannedJson) } catch(e) { return [] }
    }

    color:   "transparent"
    visible: root.shown

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace:     "topbar-popup"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    onShownChanged: {
        if (shown) appearAnim.start()
        else if (root.scanning && root.btProcess) root.btProcess.stopScan()
    }

    // ── Processos ─────────────────────────────────────────────────
    Process {
        id: connectProc
        property string targetMac: ""
        command: ["bluetoothctl", "connect", targetMac]
        running: false
    }

    Process {
        id: disconnectProc
        property string targetMac: ""
        command: ["bluetoothctl", "disconnect", targetMac]
        running: false
    }

    Process {
        id: btPowerProc
        property bool turnOn: true
        command: ["bluetoothctl", "power", turnOn ? "on" : "off"]
        running: false
    }

    Process {
        id: btSettingsProc
        command: ["bash", "-c", "blueman-manager || overskride"]
        running: false
    }

    // ── Overlay dismiss ───────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    // ── Card ──────────────────────────────────────────────────────
    Item {
        id: card
        anchors.top:       parent.top
        anchors.topMargin: 54
        x:      Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
        width:   280
        height:  cardBg.height
        opacity: 0
        scale:   0.95
        z:       1

        SequentialAnimation {
            id: appearAnim
            ParallelAnimation {
                NumberAnimation {
                    target: card; property: "opacity"
                    from: 0; to: 1
                    duration: 200; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: card; property: "scale"
                    from: 0.95; to: 1.0
                    duration: 250; easing.type: Easing.OutBack
                }
            }
        }

        MouseArea { anchors.fill: parent; z: -1 }

        Rectangle {
            id: cardBg
            width:  parent.width
            height: innerCol.implicitHeight + 36
            radius: Theme.radiusLarge
            color:  "transparent"

            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.background }
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                color: "transparent"
                border { width: 1; color: Theme.border }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            Qt.rgba(0, 0, 0, 0.5)
                shadowBlur:             0.9
                shadowVerticalOffset:   6
                shadowHorizontalOffset: 0
            }
        }

        Column {
            id: innerCol
            anchors { top: cardBg.top; left: cardBg.left; right: cardBg.right; margins: 18; topMargin: 18 }
            spacing: 12

            // ── Header ────────────────────────────────────────
            Item {
                width: parent.width; height: 24

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text:    "Bluetooth"
                    color:   Theme.textActive
                    opacity: 0.85
                    font { pixelSize: Theme.fontSizeBody; weight: Font.DemiBold; letterSpacing: 0.3 }
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 44; height: 24; radius: 12
                    color: root.btOn
                        ? Qt.rgba(0.20, 0.60, 1.0, 0.30)
                        : (powerArea.containsMouse ? Theme.separator : Qt.rgba(1, 1, 1, 0.07))
                    border { width: 1; color: root.btOn ? Qt.rgba(0.20, 0.60, 1.0, 0.50) : Qt.rgba(1, 1, 1, 0.08) }
                    Behavior on color        { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text:  "󰂯"
                        color: root.btOn ? Theme.iconAccent : Theme.iconMuted
                        font.pixelSize: 13
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            btPowerProc.turnOn  = !root.btOn
                            btPowerProc.running = false
                            btPowerProc.running = true
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.separator }

            // ── Pareados ──────────────────────────────────────
            Column {
                id: deviceList
                width: parent.width; spacing: 2

                Text {
                    visible: root.parsedDevices.length === 0
                    width:   parent.width; height: 36
                    text:    root.btOn ? "No paired devices" : "Bluetooth off"
                    color:   Theme.textSecondary
                    font { pixelSize: 12; family: Theme.fontFamily }
                    verticalAlignment:   Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: root.parsedDevices
                    delegate: BtDeviceRow {
                        width:       deviceList.width
                        deviceName:  modelData.name
                        isConnected: modelData.connected === true
                        isPaired:    true
                        onActivated: {
                            const proc = modelData.connected ? disconnectProc : connectProc
                            proc.targetMac = modelData.mac
                            proc.running   = false
                            proc.running   = true
                        }
                    }
                }
            }

            Rectangle { visible: root.btOn; width: parent.width; height: 1; color: Theme.separator }

            // ── Botão Procurar ────────────────────────────────
            Rectangle {
                visible: root.btOn
                width: parent.width; height: 32; radius: 10
                color: root.scanning
                    ? Qt.rgba(0.20, 0.60, 1.0, 0.10)
                    : (scanBtnArea.containsMouse ? Theme.separator : "transparent")
                border { width: root.scanning ? 1 : 0; color: Qt.rgba(0.20, 0.60, 1.0, 0.25) }
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent; spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  root.scanning ? "󰑐" : "󰍉"
                        color: root.scanning ? "#60aaff" : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeIcon
                        RotationAnimation on rotation {
                            running: root.scanning
                            from: 0; to: 360
                            duration: 1200; loops: Animation.Infinite
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  root.scanning ? "Searching…" : "Search for devices"
                        color: root.scanning ? "#60aaff" : Theme.textDim
                        font { pixelSize: 12; weight: Font.Medium; letterSpacing: 0.2 }
                    }
                }

                MouseArea {
                    id: scanBtnArea
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !root.scanning
                    onClicked: if (root.btProcess) root.btProcess.startScan()
                }
            }

            // ── Disponíveis ───────────────────────────────────
            Column {
                id: scannedList
                visible: root.parsedScanned.length > 0 || root.scanning
                width: parent.width; spacing: 2

                Text {
                    visible: root.parsedScanned.length > 0
                    text:  "Available"
                    color: Theme.textSecondary
                    font { pixelSize: 11; weight: Font.DemiBold; letterSpacing: 0.5 }
                    bottomPadding: 2
                }

                Text {
                    visible: root.scanning && root.parsedScanned.length === 0
                    width: parent.width; height: 30
                    text:  "Waiting for devices…"
                    color: Theme.textSecondary
                    font { pixelSize: 12; italic: true }
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: root.parsedScanned
                    delegate: BtDeviceRow {
                        width:       scannedList.width
                        deviceName:  modelData.name
                        isConnected: false
                        isPaired:    false
                        opacity:     0

                        Component.onCompleted: opacity = 1
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        onActivated: {
                            if (!root.btProcess) return
                            root.btProcess.pairProc.targetMac = modelData.mac
                            root.btProcess.pairProc.running   = false
                            root.btProcess.pairProc.running   = true
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.separator }

            // ── Footer ────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 32; radius: 10
                color: settingsArea.containsMouse ? Theme.separator : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰒓"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeIcon
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  "Bluetooth Settings"
                        color: Theme.textDim
                        font { pixelSize: 12; weight: Font.Medium; letterSpacing: 0.2 }
                    }
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.shown          = false
                        btSettingsProc.running = false
                        btSettingsProc.running = true
                    }
                }
            }
        }
    }

    // ── Componente BtDeviceRow ────────────────────────────────────
    component BtDeviceRow: Rectangle {
        id: rowRoot
        property string deviceName:  ""
        property bool   isConnected: false
        property bool   isPaired:    true
        signal activated()

        height: 38; radius: 10

        color: isConnected
            ? Qt.rgba(0.20, 0.60, 1.0, 0.12)
            : (rowHover.containsMouse ? Theme.separator : "transparent")
        border { width: 1; color: isConnected ? Qt.rgba(0.20, 0.60, 1.0, 0.25) : "transparent" }
        Behavior on color        { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  rowRoot.isPaired ? "󰂱" : "󰂴"
                color: rowRoot.isConnected ? Theme.iconAccent : Theme.iconMain
                font.pixelSize: Theme.fontSizeIcon
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  rowRoot.deviceName
                color: rowRoot.isConnected ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.75)
                width: parent.width - 26 - 10
                       - (rowRoot.isConnected ? 68 : 0)
                       - (!rowRoot.isPaired   ? 52 : 0)
                elide: Text.ElideRight
                font {
                    pixelSize: 13
                    weight:    rowRoot.isConnected ? Font.DemiBold : Font.Normal
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                visible: rowRoot.isConnected
                anchors.verticalCenter: parent.verticalCenter
                width: 60; height: 18; radius: 9
                color: Qt.rgba(0.20, 0.60, 1.0, 0.20)
                Text {
                    anchors.centerIn: parent
                    text:  "connected"; color: "#60aaff"
                    font { pixelSize: 9; weight: Font.DemiBold; letterSpacing: 0.3 }
                }
            }

            Rectangle {
                visible: !rowRoot.isPaired
                anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 18; radius: 9
                color: rowHover.containsMouse
                    ? Qt.rgba(0.20, 0.60, 1.0, 0.25)
                    : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text:  "pair"
                    color: rowHover.containsMouse ? "#60aaff" : Qt.rgba(1, 1, 1, 0.40)
                    font { pixelSize: 9; weight: Font.DemiBold; letterSpacing: 0.3 }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: rowRoot.activated()
        }
    }
}