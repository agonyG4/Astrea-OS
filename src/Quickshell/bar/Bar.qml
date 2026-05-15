import Quickshell
import Quickshell.Wayland
import QtQuick
import "ui"
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

    property QtObject sharedMusicState: null
    property QtObject sharedNetworkState: null
    property QtObject sharedBluetoothState: null
    property QtObject sharedAudioState: null

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
        astreaPopupRef: astreaPopupLoader.item
        netConnected:  bar.netConnected
        netType:       bar.netType
        netPopupRef:   netPopupLoader.item
        btOn:          bar.btOn
        btDevicesJson: bar.btDevicesJson
        btScanning:    bar.btScanning
        btPopupRef:    btPopupLoader.item
        volLevel:      bar.volLevel
        volMuted:      bar.volMuted
        volPopupRef:   volPopupLoader.item
        ccPopupRef:    ccPopupLoader.item
        onAstreaPopupRequested: anchorX => bar.toggleAstreaPopup(anchorX)
        onNetPopupRequested: anchorX => bar.toggleNetPopup(anchorX)
        onBtPopupRequested: anchorX => bar.toggleBtPopup(anchorX)
        onVolPopupRequested: anchorX => bar.toggleVolPopup(anchorX)
        onCcPopupRequested: anchorX => bar.toggleCcPopup(anchorX)
        onVolChangeRequested: function(v) {
            if (bar.sharedAudioState)
                bar.sharedAudioState.setVolume(v)
        }
    }

    function anchorForIndicator(kind) {
        const item = kind === "astrea" ? astreaPopupButtonProbe
            : kind === "net" ? netPopupButtonProbe
            : kind === "bt" ? btPopupButtonProbe
            : kind === "vol" ? volPopupButtonProbe
            : ccPopupButtonProbe
        if (!item)
            return screen.width / 2
        const point = item.mapToItem(null, item.width / 2, item.height / 2)
        return point.x
    }

    function popupAnchor(kind, anchorX) {
        return anchorX !== undefined && isFinite(anchorX) ? anchorX : anchorForIndicator(kind)
    }

    function toggleLoadedPopup(loader, kind, anchorX) {
        const x = popupAnchor(kind, anchorX)
        if (!loader.active) {
            loader.active = true
            Qt.callLater(() => {
                if (loader.item)
                    loader.item.toggleAt(x)
            })
            return
        }

        if (loader.item)
            loader.item.toggleAt(x)
    }

    function toggleAstreaPopup(anchorX) { toggleLoadedPopup(astreaPopupLoader, "astrea", anchorX) }
    function toggleNetPopup(anchorX) { toggleLoadedPopup(netPopupLoader, "net", anchorX) }
    function toggleBtPopup(anchorX) { toggleLoadedPopup(btPopupLoader, "bt", anchorX) }
    function toggleVolPopup(anchorX) { toggleLoadedPopup(volPopupLoader, "vol", anchorX) }
    function toggleCcPopup(anchorX) { toggleLoadedPopup(ccPopupLoader, "cc", anchorX) }

    Item { id: astreaPopupButtonProbe; x: 8; y: 0; width: 36; height: 36; visible: false }
    Item { id: netPopupButtonProbe; x: Math.max(0, bar.width - 190); y: 0; width: 36; height: 36; visible: false }
    Item { id: btPopupButtonProbe; x: Math.max(0, bar.width - 154); y: 0; width: 36; height: 36; visible: false }
    Item { id: volPopupButtonProbe; x: Math.max(0, bar.width - 118); y: 0; width: 36; height: 36; visible: false }
    Item { id: ccPopupButtonProbe; x: Math.max(0, bar.width - 82); y: 0; width: 36; height: 36; visible: false }

    Loader {
        id: volPopupLoader
        active: false
        sourceComponent: VolumePopup {
            masterVol:   bar.volLevel
            masterMuted: bar.volMuted
            onVolumeChangeHandled: (v) => { if (bar.sharedAudioState) bar.sharedAudioState.level = v }
        }
    }

    Loader {
        id: netPopupLoader
        active: false
        sourceComponent: NetworkPopup {
            netType:      bar.netType
            ssid:         bar.netSsid
            downloadText: bar.netDownload
            uploadText:   bar.netUpload
        }
    }

    Loader {
        id: btPopupLoader
        active: false
        sourceComponent: BluetoothPopup {
            btOn:        bar.btOn
            devicesJson: bar.btDevicesJson
            scannedJson: bar.btScannedJson
            scanning:    bar.btScanning
            btProcess:   bar.sharedBluetoothState
        }
    }

    Loader {
        id: ccPopupLoader
        active: false
        sourceComponent: ControlCenterPopup {
            anchorWindow: bar
            netConnected: bar.netConnected
            netType: bar.netType
            ssid: bar.netSsid
            netProcess: bar.sharedNetworkState
            btOn: bar.btOn
            btDevicesJson: bar.btDevicesJson
            btProcess: bar.sharedBluetoothState
            masterVol: bar.volLevel
            masterMuted: bar.volMuted
            musicState: bar.sharedMusicState
            onVolumeChangeHandled: (v) => { if (bar.sharedAudioState) bar.sharedAudioState.level = v }
            onMuteChangeHandled: (muted) => { if (bar.sharedAudioState) bar.sharedAudioState.muted = muted }
        }
    }

    Loader {
        id: astreaPopupLoader
        active: false
        sourceComponent: AstreaPopup {}
    }
}
