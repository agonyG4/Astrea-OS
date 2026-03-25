import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../components/system"
import "../components/bluetooth"
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
    signal volChangeRequested(int v)

    // ─── Layout ───────────────────────────────────────────────────
    height:  36
    width:   rightRow.implicitWidth + 20
    opacity: 0

    HoverHandler { id: rightRootHover }

    Component.onCompleted: { tick(); appearAnim.start() }

    // ─── Clock tick ───────────────────────────────────────────────
    readonly property var   _days:   ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"]
    readonly property var   _months: ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]

    function tick() {
        const now  = new Date()
        const h    = now.getHours()
        clockLabel.text = `${(h % 12 || 12).toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`
        dateLabel.text  = `${root._days[now.getDay()]} ${root._months[now.getMonth()]} ${now.getDate()}`
    }

    // ─── Animação de entrada ──────────────────────────────────────
    NumberAnimation {
        id: appearAnim
        target: root; property: "opacity"
        from: 0; to: 1
        duration: 400; easing.type: Easing.OutCubic
    }

    // ─── Glass background ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color:  "transparent"

        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.background }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"
            border { width: 1; color: Theme.border }
        }
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: 4; rightMargin: 4 }
            height: parent.height * 0.45
            radius: parent.radius
            color:  Qt.rgba(1, 1, 1, 0.045)
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskThresholdMin: 0.5 }
        }
    }

    // ─── Hover glow ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge - 2
        color:  "transparent"
        border { width: 1; color: rightRootHover.hovered ? Theme.barBorderHover : Theme.border }
        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // ─── Conteúdo ─────────────────────────────────────────────────
    Row {
        id: rightRow
        anchors.centerIn: parent
        spacing: 0

        Tray {
            id: trayComp
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: trayComp.width > 0 ? 8 : 0; height: 36 }

        NetworkIndicator {
            anchors.verticalCenter: parent.verticalCenter
            netConnected: root.netConnected
            netType:      root.netType
            netPopupRef:  root.netPopupRef
        }

        BluetoothIndicator {
            anchors.verticalCenter: parent.verticalCenter
            btOn:       root.btOn
            btPopupRef: root.btPopupRef
        }

        VolumeIndicator {
            anchors.verticalCenter: parent.verticalCenter
            volLevel:    root.volLevel
            volMuted:    root.volMuted
            volPopupRef: root.volPopupRef
            onVolChanged: (v) => root.volChangeRequested(v)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 16
            color: Theme.separator
        }

        // ── Data ──────────────────────────────────────────────────
        Item {
            width:  dateLabel.implicitWidth + 16
            height: 36
            Text {
                id: dateLabel
                anchors.centerIn: parent
                color: Theme.textSecondary
                font { pixelSize: 12; letterSpacing: 0.3 }
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: dateLabel; property: "opacity"; to: 0; duration: 120 }
                        NumberAnimation { target: dateLabel; property: "opacity"; to: 1; duration: 120 }
                    }
                }
            }
        }

        // ── Relógio ───────────────────────────────────────────────
        Item {
            width:  clockLabel.implicitWidth + 20
            height: 36
            Text {
                id: clockLabel
                anchors.centerIn: parent
                color: Theme.textActive
                font { pixelSize: 14; weight: Font.Medium; letterSpacing: 0.5 }
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