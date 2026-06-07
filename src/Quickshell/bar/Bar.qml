import Quickshell
import Quickshell.Wayland
import QtQuick
import "ui/components/astrea"
import "ui/components/bluetooth"
import "ui/components/controlcenter"
import "ui/components/network"
import "ui/components/system/base"
import "ui/components/system/popups"
import "ui/components/system/tray"
import "ui/components/system/workspaces"
import "ui/components/volume"
import "../notifications/ui" as NotificationUi

Scope {
    id: bar

    property var screen: null
    property QtObject sharedMusicState: null
    property QtObject sharedNetworkState: null
    property QtObject sharedBluetoothState: null
    property QtObject sharedAudioState: null
    property int externalVolumeOsdSerial: 0
    property int externalVolumeOsdLevel: volLevel
    property bool externalVolumeOsdMuted: volMuted
    readonly property int barHeight: 45
    readonly property int pillHeight: 36
    readonly property int pillTopMargin: Math.round((barHeight - pillHeight) / 2)
    readonly property int leftMargin: 8
    readonly property int rightMargin: 6
    readonly property int sidePadding: 10
    readonly property int screenWidth: screen ? screen.width : 1920
    readonly property int launcherWidth: Math.max(
        48,
        logoButton.width + Theme.spacing + workspaceStrip.implicitWidth + sidePadding * 2
    )
    readonly property int launcherSurfaceWidth: Math.max(
        launcherWidth,
        logoButton.width + Theme.spacing + workspaceStrip.reservedWidth + sidePadding * 2
    )
    readonly property int statusWidth: Math.min(
        Math.max(1, screenWidth - launcherWidth - leftMargin - rightMargin - 28),
        statusSegment.row.implicitWidth + sidePadding * 2
    )
    readonly property int statusLeft: Math.max(leftMargin + launcherWidth + 28, screenWidth - statusWidth - rightMargin)

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

    PanelWindow {
        id: reserveSurface
        screen: bar.screen
        anchors { top: true; left: true; right: true }
        implicitWidth: bar.screenWidth
        implicitHeight: bar.barHeight
        color: "transparent"

        WlrLayershell.namespace: "astrea-top-reserve"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: bar.barHeight
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }

    PanelWindow {
        id: launcherSurface
        screen: bar.screen
        anchors { top: true; left: true }
        implicitWidth: bar.launcherSurfaceWidth
        implicitHeight: bar.pillHeight
        color: "transparent"

        WlrLayershell.namespace: "astrea-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.margins.left: bar.leftMargin
        WlrLayershell.margins.top: bar.pillTopMargin

        BarSegment {
            id: launcherSegment
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            segmentHeight: bar.pillHeight
            horizontalPadding: bar.sidePadding
            spacing: Theme.spacing

            TopbarIndicator {
                id: logoButton
                anchors.verticalCenter: parent.verticalCenter
                popupHost: astreaPopupHost
                fixedWidth: 28
                height: 28
                backgroundMargin: 0
                backgroundRadius: Theme.radiusMedium

                Image {
                    source: "file://" + (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Assets/ui/quickshell/bar/astrea.png"
                    width: 18
                    height: 18
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    opacity: Theme.opacityMuted
                }
            }

            Workspaces {
                id: workspaceStrip
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
            }
        }
    }

    PanelWindow {
        id: statusSurface
        screen: bar.screen
        anchors { top: true; left: true }
        implicitWidth: bar.statusWidth
        implicitHeight: bar.pillHeight
        color: "transparent"

        WlrLayershell.namespace: "astrea-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.margins.left: bar.statusLeft
        WlrLayershell.margins.top: bar.pillTopMargin

        BarSegment {
            id: statusSegment
            anchors.fill: parent
            segmentHeight: bar.pillHeight
            horizontalPadding: bar.sidePadding
            fixedWidth: bar.statusWidth
            spacing: 0
            clip: true

            Tray {
                id: trayComp
                anchors.verticalCenter: parent.verticalCenter
                anchorOffset: bar.statusLeft
            }

            Item {
                width: trayComp.width > 0 ? Theme.spacingTiny : 0
                height: bar.pillHeight
            }

            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                NetworkIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    popupHost: netPopupHost
                    netConnected: bar.netConnected
                    netType: bar.netType
                    downloadText: bar.netDownload
                    uploadText: bar.netUpload
                }

                BluetoothIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    popupHost: btPopupHost
                    btOn: bar.btOn
                    devicesJson: bar.btDevicesJson
                    scanning: bar.btScanning
                }

                VolumeIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    popupHost: volPopupHost
                    volLevel: bar.volLevel
                    volMuted: bar.volMuted
                    onVolChanged: v => {
                        if (bar.sharedAudioState)
                            bar.sharedAudioState.setVolume(v)
                    }
                }

                ControlCenterButton {
                    anchors.verticalCenter: parent.verticalCenter
                    popupHost: ccPopupHost
                }
            }

            Clock {
                anchors.verticalCenter: parent.verticalCenter
                popupHost: notificationPopupHost
            }
        }
    }

    onExternalVolumeOsdSerialChanged: {
        if (bar.externalVolumeOsdSerial > 0 && bar.screen === Quickshell.screens[0])
            volumeOsd.showVolume(bar.externalVolumeOsdLevel, bar.externalVolumeOsdMuted)
    }

    PopupHost {
        id: volPopupHost
        anchorOffset: bar.statusLeft
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
        anchorOffset: bar.statusLeft
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
        anchorOffset: bar.statusLeft
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
        anchorOffset: bar.statusLeft
        sourceComponent: Component {
            ControlCenterPopup {
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
        id: notificationPopupHost
        anchorOffset: bar.statusLeft
        sourceComponent: Component {
            NotificationUi.NotificationHistoryPanel {}
        }
    }

    PopupHost {
        id: astreaPopupHost
        anchorOffset: bar.leftMargin
        sourceComponent: Component {
            AstreaPopup {}
        }
    }

    VolumeOsd {
        id: volumeOsd
        screen: bar.screen
    }
}
