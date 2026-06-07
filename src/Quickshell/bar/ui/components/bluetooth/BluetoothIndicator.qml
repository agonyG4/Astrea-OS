import QtQuick
import "../system/base" as SystemComponents
import "../../.."

SystemComponents.TopbarIndicator {
    id: root

    property bool btOn:          false
    property string devicesJson: "[]"
    property bool scanning:      false
    property bool showDeviceName: false

    // ── propriedades derivadas ────────────────────────────────────
    readonly property bool btPopupValid:    root.hostedPopup !== null
    readonly property bool isActive:        btPopupValid && root.hostedPopup.shown
    readonly property bool isScanning:      btPopupValid ? root.hostedPopup.scanning : root.scanning
    readonly property var parsedDevices: {
        try { return JSON.parse(root.devicesJson) } catch(e) { return [] }
    }
    readonly property var  connectedDevices: btPopupValid
        ? root.hostedPopup.parsedDevices.filter(d => d.connected)
        : parsedDevices.filter(d => d.connected)
    readonly property int  connectedCount:  connectedDevices.length
    readonly property string firstDeviceName: connectedCount > 0
        ? connectedDevices[0].name.split(" ")[0]
        : ""

    spacing: 5
    fixedWidth: 28

    Item {
        width:  16
        height: 16

        Rectangle {
            id: scanPulse
            anchors.centerIn: parent
            width: 16; height: 16; radius: 8
            color:        "transparent"
            border.width: 1.5
            border.color: Qt.rgba(0.35, 0.65, 1, 0.7)
            visible:      root.isScanning

            SequentialAnimation on opacity {
                running: root.isScanning
                loops:   Animation.Infinite
                NumberAnimation { to: 0;   duration: Theme.animationPulse }
                NumberAnimation { to: 0.9; duration: 0   }
            }
            SequentialAnimation on scale {
                running: root.isScanning
                loops:   Animation.Infinite
                NumberAnimation { to: 1.8; duration: Theme.animationPulse; easing.type: Easing.OutCubic }
                NumberAnimation { to: 1.0; duration: 0   }
            }
        }

        Text {
            anchors.centerIn: parent
            text:  root.btOn ? "󰂯" : "󰂲"
            font { family: Theme.iconFontFamily; pixelSize: Theme.fontSizeIcon }
            color: !root.btOn ? Theme.shellIconMuted
                 : root.connectedCount > 0 ? Theme.shellIconAccent
                 : Theme.shellIconMain
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }
        }
    }

    Text {
        visible: root.showDeviceName && root.btOn && root.connectedCount > 0
        text:    root.firstDeviceName
        color:   Theme.shellTextDim
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.Medium }
        elide: Text.ElideRight
        width: visible ? Math.min(implicitWidth, 80) : 0
    }
}
