import QtQuick
import QtQuick.Effects
import Quickshell.Io

Item {
    id: root

    // ─── Public API ───────────────────────────────────────────────
    property bool wifiConnected: false
    property bool btOn:          false
    property int  volLevel:      50
    property bool volMuted:      false
    property var  volPopupRef:   null
    signal volChangeRequested(int v)

    // ─── Layout ───────────────────────────────────────────────────
    height: 36
    width:  rightRow.implicitWidth + 20

    // ─── Clock tick ───────────────────────────────────────────────
    function tick() {
        const now  = new Date()
        const h    = now.getHours()
        const h12  = (h % 12 || 12).toString().padStart(2, "0")
        const m    = now.getMinutes().toString().padStart(2, "0")
        const ampm = h < 12 ? "AM" : "PM"

        clockLabel.text = `${h12}:${m} ${ampm}`

        const days   = ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"]
        const months = ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"]
        dateLabel.text = `${days[now.getDay()]} ${months[now.getMonth()]} ${now.getDate()}`
    }

    // ─── Glass background ─────────────────────────────────────────
    Rectangle {
        id: glassBase
        anchors.fill: parent
        radius: 14
        color: "transparent"

        // Camada de cor principal
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(0.08, 0.09, 0.12, 0.55)
        }

        // Borda com gradiente sutil (topo mais brilhante)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.13)
        }

        // Reflexo interno no topo (efeito vidro)
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 1
                leftMargin: 4
                rightMargin: 4
            }
            height: parent.height * 0.45
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.045)

            // Máscara arredondada no bottom
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskThresholdMin: 0.5
            }
        }
    }

    // ─── Animação de entrada ──────────────────────────────────────
    opacity: 0
    Component.onCompleted: {
        tick()
        appearAnim.start()
    }

    SequentialAnimation {
        id: appearAnim
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0; to: 1
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    // ─── Conteúdo ─────────────────────────────────────────────────
    Row {
        id: rightRow
        anchors.centerIn: parent
        spacing: 0

        WifiIndicator      { wifiConnected: root.wifiConnected }
        BluetoothIndicator { btOn: root.btOn }

        VolumeIndicator {
            volLevel:    root.volLevel
            volMuted:    root.volMuted
            volPopupRef: root.volPopupRef
            onVolChanged: (v) => root.volChangeRequested(v)
        }

        // Separador
Rectangle {
    width: 1
    height: 16
    color: Qt.rgba(1, 1, 1, 0.12)
    anchors.verticalCenter: parent.verticalCenter
}

        // Data
        Item {
            width:  dateLabel.implicitWidth + 16
            height: 36

            Text {
                id: dateLabel
                anchors.centerIn: parent
                color: Qt.rgba(1, 1, 1, 0.45)
                font {
                    pixelSize: 12
                    letterSpacing: 0.3
                }

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: dateLabel; property: "opacity"; to: 0; duration: 120 }
                        NumberAnimation { target: dateLabel; property: "opacity"; to: 1; duration: 120 }
                    }
                }
            }
        }

        // Separador

        // Relógio
        Item {
            width:  clockLabel.implicitWidth + 20
            height: 36

            Text {
                id: clockLabel
                anchors.centerIn: parent
                color: "white"
                font {
                    pixelSize: 14
                    weight:    Font.Medium
                    letterSpacing: 0.5
                }

                // Animação suave ao mudar minuto
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: clockLabel; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockLabel; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

// ─── Hover glow ───────────────────────────────────────────────
Rectangle {
    id: hoverGlow
    anchors.fill: parent
    radius: 14
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, hoverDetect.containsMouse ? 0.28 : 0.13)

    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }

    MouseArea {
        id: hoverDetect
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: (e) => e.accepted = false
    }
}
}

// ─── Componente auxiliar: Separador ───────────────────────────────
// Coloca isso num arquivo Separator.qml separado
/*
Rectangle {
    width: 1
    height: 16
    color: Qt.rgba(1, 1, 1, 0.12)
    anchors.verticalCenter: parent.verticalCenter
}
*/