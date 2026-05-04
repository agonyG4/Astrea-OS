import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "ui"
import "modules/network"
import "ui/components/astrea"
import "ui/components/bluetooth"
import "ui/components/controlcenter"
import "ui/components/network"
import "ui/components/volume"

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitWidth:  screen.width
    implicitHeight: 45
    color:          "transparent"

    WlrLayershell.namespace:     "bar"
    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.exclusiveZone: 45

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
    property QtObject sharedMusicState: null

    function refreshVolume() {
        volumeProc.running = false
        volumeProc.running = true
    }

    BarContent {
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 8
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        height: 36
        astreaPopupRef: astreaPopup
        netConnected:  bar.netConnected
        netType:       bar.netType
        netPopupRef:   netPopup
        btOn:          bar.btOn
        btPopupRef:    btPopup
        volLevel:      bar.volLevel
        volMuted:      bar.volMuted
        volPopupRef:   volPopup
        ccPopupRef:    ccPopup
        onVolChangeRequested: function(v) {
            bar.volLevel       = v
            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
            volSetProc.running = false
            volSetProc.running = true
            volRefreshDebounce.restart()
        }
    }

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

    Timer {
        id: volRefreshDebounce
        interval: 180
        repeat: false
        onTriggered: bar.refreshVolume()
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
        interval:         3000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: bar.refreshVolume()
    }

    Timer {
        interval:         5000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: netData.refresh()
    }

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

    ControlCenterPopup {
        id: ccPopup
        anchorWindow: bar
        netConnected: bar.netConnected
        netType: bar.netType
        ssid: bar.netSsid
        netProcess: netData
        btOn: bar.btOn
        btDevicesJson: bar.btDevicesJson
        btProcess: btData
        masterVol: bar.volLevel
        masterMuted: bar.volMuted
        musicState: bar.sharedMusicState
        onVolumeChangeHandled: (v) => bar.volLevel = v
        onMuteChangeHandled: (muted) => bar.volMuted = muted
    }

    AstreaPopup {
        id: astreaPopup
    }
}
