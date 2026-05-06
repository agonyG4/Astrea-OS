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
    readonly property string audioStatusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/Astrea/status/audio.json"

    function refreshVolume() {
        audioStatusFile.reload()
    }

    function applyAudioStatus(text) {
        try {
            var payload = JSON.parse(text || "{}")
            bar.volLevel = payload.level !== undefined ? payload.level : bar.volLevel
            bar.volMuted = payload.muted === true
        } catch (error) {
        }
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
            bar.volLevel       = v
            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
            volSetProc.running = false
            volSetProc.running = true
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

    Process {
        id:      volSetProc
        command: []
        running: false
        onExited: {
            statusRefreshProc.running = false
            statusRefreshProc.running = true
        }
    }

    Process {
        id: statusRefreshProc
        command: ["systemctl", "--user", "kill", "-s", "USR1", "astrea-status.service"]
        running: false
        onExited: bar.refreshVolume()
    }

    FileView {
        id: audioStatusFile
        path: bar.audioStatusPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: bar.applyAudioStatus(text())
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

    Loader {
        id: volPopupLoader
        active: false
        sourceComponent: VolumePopup {
            masterVol:   bar.volLevel
            masterMuted: bar.volMuted
            onVolumeChangeHandled: (v) => bar.volLevel = v
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
            btProcess:   btData
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
    }

    Loader {
        id: astreaPopupLoader
        active: false
        sourceComponent: AstreaPopup {}
    }
}
