import Quickshell
import Quickshell.Io
import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.TopbarPopup {
    id: root

    property bool   btOn:        false
    property string devicesJson: "[]"
    property string scannedJson: "[]"
    property bool   scanning:    false
    property var    btProcess:   null
    readonly property string scriptPath: Quickshell.env("HOME") + "/.local/share/Astrea/System/scripts/bluetooth_manager.py"
    readonly property bool powerPending: root.btProcess ? root.btProcess.powerPending : false
    readonly property string powerError: root.btProcess ? root.btProcess.powerError : ""

    readonly property var parsedDevices: {
        try { return JSON.parse(devicesJson) } catch(e) { return [] }
    }
    readonly property var parsedScanned: {
        try { return JSON.parse(scannedJson) } catch(e) { return [] }
    }

    popupWidth: 280

    onShownChanged: {
        if (shown && root.btOn && root.btProcess) {
            root.btProcess.refresh()
            root.btProcess.requestScan("bluetooth-popup")
        } else if (!shown && root.btProcess) {
            root.btProcess.releaseScan("bluetooth-popup")
        }
    }

    // ── Processos ─────────────────────────────────────────────────
    Process {
        id: connectProc
        property string targetMac: ""
        command: ["python3", root.scriptPath, "connect", targetMac]
        running: false
        onExited: if (root.btProcess) root.btProcess.refresh()
    }

    Process {
        id: disconnectProc
        property string targetMac: ""
        command: ["python3", root.scriptPath, "disconnect", targetMac]
        running: false
        onExited: if (root.btProcess) root.btProcess.refresh()
    }

    Process {
        id: btSettingsProc
        command: ["bash", "-c", "blueman-manager || overskride"]
        running: false
    }

    SystemComponents.PopupHeader {
        title: "Bluetooth"
        trailingWidth: 44
        Rectangle {
            anchors.centerIn: parent
            width: 44; height: 24; radius: 12
            color: root.btOn
                ? Qt.rgba(0.20, 0.60, 1.0, 0.30)
                : (powerArea.containsMouse && !root.powerPending ? Theme.separator : Qt.rgba(1, 1, 1, 0.07))
            border { width: 1; color: root.btOn ? Qt.rgba(0.20, 0.60, 1.0, 0.50) : Qt.rgba(1, 1, 1, 0.08) }
            opacity: root.powerPending ? 0.55 : 1.0
            Behavior on color        { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on opacity      { NumberAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text:  root.powerPending ? "󰑐" : "󰂯"
                color: root.btOn ? Theme.iconAccent : Theme.iconMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody }
                Behavior on color { ColorAnimation { duration: 150 } }
                RotationAnimation on rotation {
                    running: root.powerPending
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                enabled: root.btProcess && !root.powerPending
                onClicked: {
                    root.btProcess.setPower(!root.btOn)
                    if (!root.btOn && root.shown)
                        root.btProcess.requestScan("bluetooth-popup")
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.separator }

    Column {
        id: deviceList
        width: parent.width; spacing: 2

        Text {
            visible: root.parsedDevices.length === 0
            width:   parent.width; height: 36
            text:    root.powerError !== "" ? root.powerError : (root.btOn ? "No paired devices" : "Bluetooth off")
            color:   root.powerError !== "" ? Theme.errorColor : Theme.textSecondary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall }
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
                color: root.scanning ? Theme.iconAccent : Theme.textSecondary
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
                RotationAnimation on rotation {
                    running: root.scanning
                    from: 0; to: 360
                    duration: 1200; loops: Animation.Infinite
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  root.scanning ? "Searching…" : "Search for devices"
                color: root.scanning ? Theme.iconAccent : Theme.textDim
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.Medium; letterSpacing: 0.2 }
            }
        }

        MouseArea {
            id: scanBtnArea
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled: !root.scanning
            onClicked: if (root.btProcess) root.btProcess.requestScan("bluetooth-popup")
        }
    }

    Column {
        id: scannedList
        visible: root.parsedScanned.length > 0 || root.scanning
        width: parent.width; spacing: 2

        Text {
            visible: root.parsedScanned.length > 0
            text:  "Available"
            color: Theme.textSecondary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold; letterSpacing: 0.5 }
            bottomPadding: 2
        }

        Text {
            visible: root.scanning && root.parsedScanned.length === 0
            width: parent.width; height: 30
            text:  "Waiting for devices…"
            color: Theme.textSecondary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; italic: true }
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

    Rectangle {
        width: parent.width; height: 32; radius: 10
        color: settingsArea.containsMouse ? Theme.separator : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors.centerIn: parent; spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒓"; color: Theme.textSecondary; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  "Bluetooth Settings"
                color: Theme.textDim
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeSmall; weight: Font.Medium; letterSpacing: 0.2 }
            }
        }

        MouseArea {
            id: settingsArea
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.close()
                btSettingsProc.running = false
                btSettingsProc.running = true
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
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
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
                    family:    Theme.fontFamily
                    pixelSize: Theme.fontSizeBody
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
                    text:  "connected"; color: Theme.iconAccent
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMicro; weight: Font.DemiBold; letterSpacing: 0.3 }
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
                    color: rowHover.containsMouse ? Theme.iconAccent : Qt.rgba(1, 1, 1, 0.40)
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMicro; weight: Font.DemiBold; letterSpacing: 0.3 }
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
