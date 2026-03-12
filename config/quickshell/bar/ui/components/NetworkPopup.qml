import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: root

    property bool   shown:        false
    property string netType:      "none"
    property string ssid:         ""
    property string downloadText: "0 B/s"
    property string uploadText:   "0 B/s"

    color: "transparent"

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true

    WlrLayershell.namespace:     "topbar-popup"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    visible: root.shown

    onShownChanged: {
        if (shown) {
            appearAnim.start()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    Item {
        id: card
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   54
        anchors.rightMargin: 108
        width:  280
        height: cardBg.height
        z: 1

        opacity: 0
        SequentialAnimation {
            id: appearAnim
            NumberAnimation {
                target: card
                property: "opacity"
                from: 0; to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: {}
        }

        Rectangle {
            id: cardBg
            width:  parent.width
            height: innerCol.implicitHeight + 36
            radius: 18
            color:  "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(0.08, 0.09, 0.12, 0.55)
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.13)
            }


            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            Qt.rgba(0, 0, 0, 0.5)
                shadowBlur:             0.9
                shadowVerticalOffset:   6
                shadowHorizontalOffset: 0
            }
        }

        Column {
            id: innerCol
            anchors {
                top:    cardBg.top; left: cardBg.left; right: cardBg.right
                margins: 18; topMargin: 18
            }
            spacing: 14

            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:  root.ssid !== "" ? root.ssid : (root.netType === 'wifi' ? "Wi-Fi" : "Ethernet")
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font {
                        pixelSize:     13
                        weight:        Font.DemiBold
                        letterSpacing: 0.3
                    }
                    elide: Text.ElideRight
                    width: parent.width - headerIcon.width - 8
                }
                
                Text {
                    id: headerIcon
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.netType === "wifi" ? "󰖩" : "󰈀"
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 18
                }
            }

            Row {
                width: parent.width
                spacing: 20
                
                Row {
                    spacing: 8
                    Text {
                        text: "󰇚"
                        color: Qt.rgba(1, 1, 1, 0.40)
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        Text { text: "Download"; color: Qt.rgba(1, 1, 1, 0.40); font.pixelSize: 10 }
                        Text {
                            text: root.downloadText
                            color: Qt.rgba(1, 1, 1, 0.85)
                            font { pixelSize: 13; weight: Font.Medium }
                        }
                    }
                }
                Row {
                    spacing: 8
                    Text {
                        text: "󰕒"
                        color: Qt.rgba(1, 1, 1, 0.40)
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        Text { text: "Upload"; color: Qt.rgba(1, 1, 1, 0.40); font.pixelSize: 10 }
                        Text {
                            text: root.uploadText
                            color: Qt.rgba(1, 1, 1, 0.85)
                            font { pixelSize: 13; weight: Font.Medium }
                        }
                    }
                }
            }
        }
    }
}
