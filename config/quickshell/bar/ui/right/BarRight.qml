import QtQuick
import QtQml.Models
import QtQuick.Effects
import Quickshell.Io
import "../components/system"
import "../components/bluetooth"
import "../components/controlcenter"
import "../components/network"
import "../components/volume"
import "../../modules/network"
import "../.."

Item {
    id: root

    // ─── Public API ───────────────────────────────────────────────
    property bool   netConnected: false
    property string netType:      "none"
    property var    netPopupRef:  null
    property bool   btOn:         false
    property var    btPopupRef:   null
    property int    volLevel:     50
    property bool   volMuted:     false
    property var    volPopupRef:  null
    property var    ccPopupRef:   null

    property string _lastClockText: ""
    property string _lastDateText:  ""
    signal volChangeRequested(int v)

    // ─── Layout ───────────────────────────────────────────────────
    height:  36
    width:   rightRow.implicitWidth + 20
    opacity: 0
    clip:    true

    HoverHandler { id: rightRootHover }

    // ─── Timer for Clock Update ───────────────────────────────────
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    Component.onCompleted: {
        root.tick()
        appearAnim.start()
    }

    readonly property var _days:   ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"]
    readonly property var _months: ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]

    function tick() {
        const now  = new Date()
        const h    = now.getHours()
        const nextClockText = `${(h % 12 || 12).toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`
        const nextDateText  = `${root._days[now.getDay()]} ${root._months[now.getMonth()]} ${now.getDate()}`

        if (nextClockText !== root._lastClockText) {
            root._lastClockText = nextClockText
            clockLabel.text = nextClockText
        }
        if (nextDateText !== root._lastDateText) {
            root._lastDateText = nextDateText
            dateLabel.text = nextDateText
        }
    }

    NumberAnimation {
        id: appearAnim
        target: root; property: "opacity"
        from: 0; to: 1
        duration: 400; easing.type: Easing.OutCubic
    }

    // ─── Background ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color: Theme.background
        border { width: 1; color: rightRootHover.hovered ? Theme.barBorderHover : Theme.border }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: 4; rightMargin: 4 }
            height: parent.height * 0.45
            radius: parent.radius
            color:  Qt.rgba(1, 1, 1, 0.045)
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskThresholdMin: 0.5 }
        }
    }

    // ─── Indicators Model ─────────────────────────────────────────
    ListModel {
        id: indicatorOrderModel
        ListElement { kind: "network" }
        ListElement { kind: "bluetooth" }
        ListElement { kind: "volume" }
        ListElement { kind: "controlcenter" }
    }

    Component {
        id: networkIndicatorComponent
        NetworkIndicator {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            netConnected: root.netConnected
            netType:      root.netType
            netPopupRef:  root.netPopupRef
        }
    }

    Component {
        id: bluetoothIndicatorComponent
        BluetoothIndicator {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            btOn:       root.btOn
            btPopupRef: root.btPopupRef
        }
    }

    Component {
        id: volumeIndicatorComponent
        VolumeIndicator {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            volLevel:    root.volLevel
            volMuted:    root.volMuted
            volPopupRef: root.volPopupRef
            onVolChanged: (v) => root.volChangeRequested(v)
        }
    }

    Component {
        id: controlCenterComponent
        ControlCenterButton {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            ccPopupRef: root.ccPopupRef
        }
    }

    DelegateModel {
        id: indicatorVisualModel
        model: indicatorOrderModel
        delegate: Item {
            id: wrapper

            required property int index
            required property string kind

            width: indicatorLoader.item ? indicatorLoader.item.width : 36
            height: 36

            Item {
                id: delegateRoot
                width: parent.width
                height: 36

                Loader {
                    id: indicatorLoader
                    anchors.centerIn: parent
                    sourceComponent: {
                        switch (kind) {
                            case "network": return networkIndicatorComponent
                            case "bluetooth": return bluetoothIndicatorComponent
                            case "volume": return volumeIndicatorComponent
                            case "controlcenter": return controlCenterComponent
                            default: return null
                        }
                    }
                }
            }
        }
    }

    // ─── Main Content ─────────────────────────────────────────────
    Row {
        id: rightRow
        anchors.centerIn: parent
        spacing: 0

        Tray {
            id: trayComp
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            id: trayGap
            width: trayComp.width > 0 ? 8 : 0
            height: 36
        }

        Row {
            id: indicatorsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Repeater {
                model: indicatorVisualModel
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 16
            color: Theme.separator
            visible: indicatorsRow.children.length > 0
        }

        Item {
            width: dateLabel.implicitWidth + 16
            height: 36
            Text {
                id: dateLabel
                anchors.fill: parent
                color: Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font {
                    family: Theme.fontFamilyDisplay
                    pixelSize: Theme.fontSizeSmall
                    weight: Font.Medium
                    letterSpacing: 0.3
                }
                renderType: Text.NativeRendering
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: dateLabel; property: "opacity"; to: 0; duration: 120 }
                        NumberAnimation { target: dateLabel; property: "opacity"; to: 1; duration: 120 }
                    }
                }
            }
        }

        Item {
            width: clockLabel.implicitWidth + 20
            height: 36
            Text {
                id: clockLabel
                anchors.fill: parent
                color: Theme.textActive
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font {
                    family: Theme.fontFamilyDisplay
                    pixelSize: Theme.fontSizeTitle
                    weight: Font.Medium
                    letterSpacing: 0.35
                }
                renderType: Text.NativeRendering
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: clockLabel; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockLabel; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }
}
