import Quickshell
import Quickshell.Wayland
import QtQuick
import "ui"
import "ui/components/astrea"
import "ui/components/bluetooth"
import "ui/components/controlcenter"
import "ui/components/network"
import "ui/components/system/popups"
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

    property QtObject sharedMusicState: null
    property QtObject sharedNetworkState: null
    property QtObject sharedBluetoothState: null
    property QtObject sharedAudioState: null
    property int externalVolumeOsdSerial: 0
    property int externalVolumeOsdLevel: volLevel
    property bool externalVolumeOsdMuted: volMuted

    readonly property bool   netConnected:  sharedNetworkState ? sharedNetworkState.connected : false
    readonly property string netType:       sharedNetworkState ? sharedNetworkState.type : "none"
    readonly property string netSsid:       sharedNetworkState ? sharedNetworkState.ssid : ""
    readonly property string netDownload:   sharedNetworkState ? sharedNetworkState.download : "0 B/s"
    readonly property string netUpload:     sharedNetworkState ? sharedNetworkState.upload : "0 B/s"
    readonly property bool   btOn:          sharedBluetoothState ? sharedBluetoothState.powered : false
    readonly property string btDevicesJson: sharedBluetoothState ? sharedBluetoothState.devicesJson : "[]"
    readonly property string btScannedJson: sharedBluetoothState ? sharedBluetoothState.scannedJson : "[]"
    readonly property bool   btScanning:    sharedBluetoothState ? sharedBluetoothState.scanning : false
    readonly property int    volLevel:      sharedAudioState ? sharedAudioState.level : 50
    readonly property bool   volMuted:      sharedAudioState ? sharedAudioState.muted : false

    BarContent {
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 8
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        height: 36
        astreaPopupHost: astreaPopupHost
        netConnected:  bar.netConnected
        netType:       bar.netType
        netDownload:   bar.netDownload
        netUpload:     bar.netUpload
        netPopupHost:  netPopupHost
        btOn:          bar.btOn
        btDevicesJson: bar.btDevicesJson
        btScanning:    bar.btScanning
        btPopupHost:   btPopupHost
        volLevel:      bar.volLevel
        volMuted:      bar.volMuted
        volPopupHost:  volPopupHost
        ccPopupHost:   ccPopupHost
        onVolChangeRequested: function(v) {
            if (bar.sharedAudioState)
                bar.sharedAudioState.setVolume(v)
        }
    }

    onExternalVolumeOsdSerialChanged: {
        if (bar.externalVolumeOsdSerial > 0 && bar.screen === Quickshell.screens[0])
            volumeOsd.showVolume(bar.externalVolumeOsdLevel, bar.externalVolumeOsdMuted)
    }

    PopupHost {
        id: volPopupHost
        sourceComponent: Component {
            VolumePopup {
                masterVol:   bar.volLevel
                masterMuted: bar.volMuted
                onVolumeChangeHandled: (v) => { if (bar.sharedAudioState) bar.sharedAudioState.level = v }
            }
        }
    }

    PopupHost {
        id: netPopupHost
        sourceComponent: Component {
            NetworkPopup {
                netType:      bar.netType
                ssid:         bar.netSsid
                downloadText: bar.netDownload
                uploadText:   bar.netUpload
            }
        }
    }

    PopupHost {
        id: btPopupHost
        sourceComponent: Component {
            BluetoothPopup {
                btOn:        bar.btOn
                devicesJson: bar.btDevicesJson
                scannedJson: bar.btScannedJson
                scanning:    bar.btScanning
                btProcess:   bar.sharedBluetoothState
            }
        }
    }

    PopupHost {
        id: ccPopupHost
        sourceComponent: Component {
            ControlCenterPopup {
                anchorWindow: bar
                netConnected: bar.netConnected
                netType: bar.netType
                ssid: bar.netSsid
                netProcess: bar.sharedNetworkState
                btOn: bar.btOn
                btDevicesJson: bar.btDevicesJson
                btScanning: bar.btScanning
                btProcess: bar.sharedBluetoothState
                masterVol: bar.volLevel
                masterMuted: bar.volMuted
                musicState: bar.sharedMusicState
                onVolumeChangeHandled: (v) => { if (bar.sharedAudioState) bar.sharedAudioState.level = v }
                onMuteChangeHandled: (muted) => { if (bar.sharedAudioState) bar.sharedAudioState.muted = muted }
            }
        }
    }

    PopupHost {
        id: astreaPopupHost
        sourceComponent: Component {
            AstreaPopup {}
        }
    }

    VolumeOsd {
        id: volumeOsd
        screen: bar.screen
    }
}
