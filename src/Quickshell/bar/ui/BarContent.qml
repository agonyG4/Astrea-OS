import QtQuick
import Quickshell
import "components/system/base"
import "components/system/tray"
import "components/system/workspaces"
import "components/bluetooth"
import "components/controlcenter"
import "components/network"
import "components/volume"
import ".."

Item {
    id: root

    property var astreaPopupHost: null
    property var netPopupHost: null
    property var btPopupHost: null
    property var volPopupHost: null
    property var ccPopupHost: null

    property bool netConnected: false
    property string netType: "none"
    property string netDownload: "0 B/s"
    property string netUpload: "0 B/s"
    property bool btOn: false
    property string btDevicesJson: "[]"
    property bool btScanning: false
    property int volLevel: 50
    property bool volMuted: false

    readonly property string quickshellAssetRoot: "file://" + (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Assets/ui/quickshell/bar/"
    readonly property int pillHeight: 36
    readonly property int sidePadding: 10
    readonly property int statusWidth: Math.min(Math.max(0, root.width - launcherSegment.width - 28), statusSegment.row.implicitWidth + 20)

    signal volChangeRequested(int v)

    BarSegment {
        id: launcherSegment
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        segmentHeight: root.pillHeight
        horizontalPadding: root.sidePadding
        spacing: Theme.spacing

        TopbarIndicator {
            id: logoButton
            anchors.verticalCenter: parent.verticalCenter
            popupHost: root.astreaPopupHost
            fixedWidth: 28
            height: 28
            backgroundMargin: 0
            backgroundRadius: Theme.radiusMedium

            Image {
                source: root.quickshellAssetRoot + "astrea.png"
                width: 18
                height: 18
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                opacity: Theme.opacityMuted
            }
        }

        Workspaces {
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    BarSegment {
        id: statusSegment
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        segmentHeight: root.pillHeight
        horizontalPadding: root.sidePadding
        fixedWidth: root.statusWidth
        spacing: 0
        clip: true

        Tray {
            id: trayComp
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: trayComp.width > 0 ? Theme.spacingTiny : 0
            height: root.pillHeight
        }

        Row {
            id: statusRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            NetworkIndicator {
                anchors.verticalCenter: parent.verticalCenter
                popupHost: root.netPopupHost
                netConnected: root.netConnected
                netType: root.netType
                downloadText: root.netDownload
                uploadText: root.netUpload
            }

            BluetoothIndicator {
                anchors.verticalCenter: parent.verticalCenter
                popupHost: root.btPopupHost
                btOn: root.btOn
                devicesJson: root.btDevicesJson
                scanning: root.btScanning
            }

            VolumeIndicator {
                anchors.verticalCenter: parent.verticalCenter
                popupHost: root.volPopupHost
                volLevel: root.volLevel
                volMuted: root.volMuted
                onVolChanged: v => root.volChangeRequested(v)
            }

            ControlCenterButton {
                anchors.verticalCenter: parent.verticalCenter
                popupHost: root.ccPopupHost
            }
        }

        Clock {
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
