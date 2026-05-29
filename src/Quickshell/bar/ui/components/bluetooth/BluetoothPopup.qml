import Quickshell
import Quickshell.Io
import QtQuick
import "../system/popups" as SystemComponents
import "../../.."
import "../../../../AstreaI18n" as AstreaI18n

SystemComponents.TopbarPopup {
    id: root

    property bool   btOn:        false
    property string devicesJson: "[]"
    property string scannedJson: "[]"
    property bool   scanning:    false
    property var    btProcess:   null
    readonly property string scriptPath: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/System/scripts/bluetooth_manager.py"
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
        command: ["blueman-manager"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                btSettingsFallbackProc.running = false
                btSettingsFallbackProc.running = true
            }
        }
    }

    Process {
        id: btSettingsFallbackProc
        command: ["overskride"]
        running: false
    }

    SystemComponents.PopupHeader {
        title: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.bluetooth.bluetooth_popup.title.bluetooth"]) || "Bluetooth")
        trailingWidth: 44
        Rectangle {
            anchors.centerIn: parent
            width: 44; height: 24; radius: height / 2
            color: root.btOn
                ? Qt.rgba(0.20, 0.60, 1.0, 0.30)
                : (powerArea.containsMouse && !root.powerPending ? Theme.shellSeparator : Qt.rgba(1, 1, 1, 0.07))
            border { width: 1; color: root.btOn ? Qt.rgba(0.20, 0.60, 1.0, 0.50) : Qt.rgba(1, 1, 1, 0.08) }
            opacity: root.powerPending ? 0.55 : 1.0
            Behavior on color        { ColorAnimation { duration: Theme.animationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }
            Behavior on opacity      { NumberAnimation { duration: Theme.animationQuick } }

            Text {
                anchors.centerIn: parent
                text:  root.powerPending ? "󰑐" : "󰂯"
                color: root.btOn ? Theme.shellIconAccent : Theme.shellIconMuted
                font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeBody }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                RotationAnimation on rotation {
                    running: root.powerPending
                    from: 0
                    to: 360
                    duration: Theme.animationPulse
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

    Rectangle { width: parent.width; height: 1; color: Theme.shellSeparator }

    Column {
        id: deviceList
        width: parent.width; spacing: 2

        Text {
            visible: root.parsedDevices.length === 0
            width:   parent.width; height: 36
            text:    root.powerError !== "" ? root.powerError : (root.btOn ? "No paired devices" : "Bluetooth off")
            color:   root.powerError !== "" ? Theme.errorColor : Theme.shellTextSecondary
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

    Rectangle { visible: root.btOn; width: parent.width; height: 1; color: Theme.shellSeparator }

    Rectangle {
        visible: root.btOn
        width: parent.width; height: 32; radius: Theme.controlRadius
        color: root.scanning
            ? Qt.rgba(0.20, 0.60, 1.0, 0.10)
            : (scanBtnArea.containsMouse ? Theme.shellSeparator : "transparent")
        border { width: root.scanning ? 1 : 0; color: Qt.rgba(0.20, 0.60, 1.0, 0.25) }
        Behavior on color { ColorAnimation { duration: Theme.animationFast } }

        Row {
            anchors.centerIn: parent; spacing: Theme.spacingSmall

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  root.scanning ? "󰑐" : "󰍉"
                color: root.scanning ? Theme.shellIconAccent : Theme.shellTextSecondary
                font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
                RotationAnimation on rotation {
                    running: root.scanning
                    from: 0; to: 360
                    duration: Theme.animationSpin; loops: Animation.Infinite
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  root.scanning ? "Searching…" : "Search for devices"
                color: root.scanning ? Theme.shellIconAccent : Theme.shellTextDim
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
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.bluetooth.bluetooth_popup.text.available"]) || "Available")
            color: Theme.shellTextSecondary
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.DemiBold; letterSpacing: 0.5 }
            bottomPadding: 2
        }

        Text {
            visible: root.scanning && root.parsedScanned.length === 0
            width: parent.width; height: 30
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.bluetooth.bluetooth_popup.text.waiting_for_devicesa"]) || "Waiting for devices…")
            color: Theme.shellTextSecondary
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
                Behavior on opacity { NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic } }

                onActivated: {
                    if (!root.btProcess) return
                    root.btProcess.pairProc.targetMac = modelData.mac
                    root.btProcess.pairProc.running   = false
                    root.btProcess.pairProc.running   = true
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.shellSeparator }

    Rectangle {
        width: parent.width; height: 32; radius: Theme.controlRadius
        color: settingsArea.containsMouse ? Theme.shellSeparator : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animationFast } }

        Row {
            anchors.centerIn: parent; spacing: Theme.spacingSmall
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒓"; color: Theme.shellTextSecondary; font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.bluetooth.bluetooth_popup.text.bluetooth_settings"]) || "Bluetooth Settings")
                color: Theme.shellTextDim
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

        height: 38; radius: Theme.controlRadius

        color: isConnected
            ? Qt.rgba(0.20, 0.60, 1.0, 0.12)
            : (rowHover.containsMouse ? Theme.shellSeparator : "transparent")
        border { width: 1; color: isConnected ? Qt.rgba(0.20, 0.60, 1.0, 0.25) : "transparent" }
        Behavior on color        { ColorAnimation { duration: Theme.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animationFast } }

        Row {
            anchors { fill: parent; leftMargin: Theme.spacingMedium; rightMargin: Theme.spacingMedium }
            spacing: Theme.spacingMedium

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:  rowRoot.isPaired ? "󰂱" : "󰂴"
                color: rowRoot.isConnected ? Theme.shellIconAccent : Theme.shellIconMain
                font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
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
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
            }

            Rectangle {
                visible: rowRoot.isConnected
                anchors.verticalCenter: parent.verticalCenter
                width: 60; height: 18; radius: height / 2
                color: Qt.rgba(0.20, 0.60, 1.0, 0.20)
                Text {
                    anchors.centerIn: parent
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.bluetooth.bluetooth_popup.text.connected"]) || "connected"); color: Theme.shellIconAccent
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMicro; weight: Font.DemiBold; letterSpacing: 0.3 }
                }
            }

            Rectangle {
                visible: !rowRoot.isPaired
                anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 18; radius: height / 2
                color: rowHover.containsMouse
                    ? Qt.rgba(0.20, 0.60, 1.0, 0.25)
                    : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color { ColorAnimation { duration: Theme.animationFast } }
                Text {
                    anchors.centerIn: parent
                    text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["quickshell.bar.ui.components.bluetooth.bluetooth_popup.text.pair"]) || "pair")
                    color: rowHover.containsMouse ? Theme.shellIconAccent : Qt.rgba(1, 1, 1, 0.40)
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeMicro; weight: Font.DemiBold; letterSpacing: 0.3 }
                    Behavior on color { ColorAnimation { duration: Theme.animationFast } }
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
