import QtQuick
import "../system" as SystemComponents
import "../../.."

SystemComponents.IndicatorButton {
    id: root

    property bool btOn:          false
    property string devicesJson: "[]"
    property bool scanning:      false
    property var  btPopupRef:    null

    // ── propriedades derivadas ────────────────────────────────────
    readonly property bool btPopupValid:    root.btPopupRef !== null
    readonly property bool isActive:        btPopupValid && root.btPopupRef.shown
    readonly property bool isScanning:      btPopupValid ? root.btPopupRef.scanning : root.scanning
    readonly property var parsedDevices: {
        try { return JSON.parse(root.devicesJson) } catch(e) { return [] }
    }
    readonly property var  connectedDevices: btPopupValid
        ? root.btPopupRef.parsedDevices.filter(d => d.connected)
        : parsedDevices.filter(d => d.connected)
    readonly property int  connectedCount:  connectedDevices.length
    readonly property string firstDeviceName: connectedCount > 0
        ? connectedDevices[0].name.split(" ")[0]
        : ""

    popupRef: root.btPopupRef
    spacing: 5

    Item {
        width:  18
        height: 18

        Rectangle {
            id: scanPulse
            anchors.centerIn: parent
            width: 18; height: 18; radius: 9
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
            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
            color: !root.btOn ? Theme.iconMuted
                 : root.connectedCount > 0 ? Theme.iconAccent
                 : Theme.iconMain
            Behavior on color { ColorAnimation { duration: Theme.animationFast } }
        }
    }

    Text {
        visible: root.btOn && root.connectedCount > 0
        text:    root.firstDeviceName
        color:   Theme.textDim
        font { family: Theme.fontFamily; pixelSize: Theme.fontSizeCaption; weight: Font.Medium }
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 80)
    }
}
