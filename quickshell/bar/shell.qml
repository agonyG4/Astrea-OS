import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "UI/left"
import "UI/right"
import "modules/wifi"
import "modules/volume"

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
    property var    volPopupRef:   null
    property bool   wifiConnected: false
    property string wifiSsid:      ""
    property bool   btOn:          false
    property int    volLevel:      50
    property bool   volMuted:      false
    property int    _tick:         0

    BarLeft {
        anchors.left:           parent.left
        anchors.leftMargin:     8
        anchors.verticalCenter: parent.verticalCenter
    }

    BarRight {
        id:                     barRight
        anchors.right:          parent.right
        anchors.rightMargin:    6
        anchors.verticalCenter: parent.verticalCenter
        wifiConnected: bar.wifiConnected
        btOn:          bar.btOn
        volLevel:      bar.volLevel
        volMuted:      bar.volMuted
        volPopupRef:   bar.volPopupRef
        onVolChangeRequested: function(v) {
            bar.volLevel       = v
            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
            volSetProc.running = false
            volSetProc.running = true
        }
    }

    // ─── Processes ────────────────────────────────────────────────
    Process {
        id: volSetProc
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "50%"]
        running: false
    }

    Process {
        id: volumeProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                bar.volMuted = data.indexOf("[MUTED]") !== -1
                var m = data.match(/[\d.]+/)
                if (m) bar.volLevel = Math.round(parseFloat(m[0]) * 100)
            }
        }
    }

    WifiProcess {
        id: wifiData
        onConnectedChanged: bar.wifiConnected = wifiData.connected
        onSsidChanged:      bar.wifiSsid      = wifiData.ssid
    }

    BluetoothProcess {
        id: btData
        onPoweredChanged: bar.btOn = btData.powered
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            barRight.tick()
            volumeProc.running = false
            volumeProc.running = true
            if (++bar._tick % 5 === 0) {
                wifiData.refresh()
                btData.refresh()
            }
        }
    }

    VolumePopup {
        id: volPopup
        masterVol:   bar.volLevel
        masterMuted: bar.volMuted
        onVolumeChangeHandled: (v) => bar.volLevel = v
    }

    Component.onCompleted: {
        bar.volPopupRef = volPopup
    }
}