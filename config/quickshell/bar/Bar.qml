import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "ui/left"
import "ui/right"
import "modules/network"
import "ui/components/astrea"
import "ui/components/bluetooth"
import "ui/components/network"
import "ui/components/volume"
import "./notifications"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitWidth:  screen.width
    implicitHeight: 48
    color:          "transparent"

    WlrLayershell.namespace:     "bar"
    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.exclusiveZone: 48

    // ─── Public API ───────────────────────────────────────────────
    property bool   netConnected:  false
    property string netType:       "none"
    property string netSsid:       ""
    property string netDownload:   "0 B/s"
    property string netUpload:     "0 B/s"
    property bool   btOn:          false
    property string btDevicesJson: "[]"
    property string btScannedJson: "[]"
    property bool   btScanning:    false
    property int    volLevel:      50
    property bool   volMuted:      false
    property int    _tick:         0

    BarLeft {
        anchors.left:           parent.left
        anchors.leftMargin:     8
        anchors.verticalCenter: parent.verticalCenter
        astreaPopupRef:         astreaPopup
    }

    BarRight {
        id:                     barRight
        anchors.right:          parent.right
        anchors.rightMargin:    6
        anchors.verticalCenter: parent.verticalCenter
        netConnected:  bar.netConnected
        netType:       bar.netType
        netPopupRef:   netPopup
        btOn:          bar.btOn
        btPopupRef:    btPopup
        volLevel:      bar.volLevel
        volMuted:      bar.volMuted
        volPopupRef:   volPopup
        onVolChangeRequested: function(v) {
            bar.volLevel       = v
            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
            volSetProc.running = false
            volSetProc.running = true
        }
    }

    // ─── Processes ────────────────────────────────────────────────
    Process {
        id:      volSetProc
        command: []
        running: false
    }

    Process {
        id:      volumeProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                bar.volMuted = data.includes("[MUTED]")
                const m = data.match(/[\d.]+/)
                if (m) bar.volLevel = Math.round(parseFloat(m[0]) * 100)
            }
        }
    }

    NetworkProcess {
        id: netData
        onConnectedChanged: bar.netConnected = netData.connected
        onSsidChanged:      bar.netSsid      = netData.ssid
        onTypeChanged:      bar.netType      = netData.type
        onDownloadChanged:  bar.netDownload  = netData.download
        onUploadChanged:    bar.netUpload    = netData.upload
    }

    BluetoothProcess {
        id: btData
        onPoweredChanged:     bar.btOn          = btData.powered
        onDevicesJsonChanged: bar.btDevicesJson  = btData.devicesJson
        onScannedJsonChanged: bar.btScannedJson  = btData.scannedJson
        onScanningChanged:    bar.btScanning     = btData.scanning
    }

    Timer {
        interval:         1000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: {
            barRight.tick()
            volumeProc.running = false
            volumeProc.running = true
            if (++bar._tick % 5 === 0) {
                netData.refresh()
                btData.refresh()
            }
        }
    }

    // ─── Popups ───────────────────────────────────────────────────
    VolumePopup {
        id:          volPopup
        masterVol:   bar.volLevel
        masterMuted: bar.volMuted
        onVolumeChangeHandled: (v) => bar.volLevel = v
    }

    NetworkPopup {
        id:           netPopup
        netType:      bar.netType
        ssid:         bar.netSsid
        downloadText: bar.netDownload
        uploadText:   bar.netUpload
    }

    BluetoothPopup {
        id:          btPopup
        btOn:        bar.btOn
        devicesJson: bar.btDevicesJson
        scannedJson: bar.btScannedJson
        scanning:    bar.btScanning
        btProcess:   btData
    }

    AstreaPopup {
        id: astreaPopup
    }
}