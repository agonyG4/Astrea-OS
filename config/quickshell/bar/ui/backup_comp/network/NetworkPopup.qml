import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../.."

PanelWindow {
    id: root

    property bool   shown:        false
    property string netType:      "none"
    property string ssid:         ""
    property string downloadText: "0 B/s"
    property string uploadText:   "0 B/s"
    property real   anchorX:      screen.width / 2   // fallback

    color:   "transparent"
    visible: root.shown

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace:     "topbar-popup"
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    onShownChanged: if (shown) appearAnim.start()

    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
        z: 0
    }

    Item {
        id: card
        anchors.top:       parent.top
        anchors.topMargin: 54
        x:      Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
        width:   280
        height:  cardBg.height
        opacity: 0
        z:       1

        NumberAnimation {
            id: appearAnim
            target: card; property: "opacity"
            from: 0; to: 1
            duration: 220; easing.type: Easing.OutCubic
        }

        MouseArea { anchors.fill: parent; z: -1 }

        Rectangle {
            id: cardBg
            width:  parent.width
            height: innerCol.implicitHeight + 36
            radius: Theme.radiusLarge
            color:  "transparent"

            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.background }
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                color: "transparent"
                border { width: 1; color: Theme.border }
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
            anchors { top: cardBg.top; left: cardBg.left; right: cardBg.right; margins: 18; topMargin: 18 }
            spacing: 14

            // ── Header ────────────────────────────────────────
            Item {
                width: parent.width; height: 24

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text:  root.ssid !== "" ? root.ssid : (root.netType === "wifi" ? "Wi-Fi" : "Ethernet")
                    color: Theme.textActive
                    opacity: 0.85
                    width: parent.width - headerIcon.width - 8
                    elide: Text.ElideRight
                    font { pixelSize: Theme.fontSizeBody; weight: Font.DemiBold; letterSpacing: 0.3; family: Theme.fontFamily }
                }

                Text {
                    id: headerIcon
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text:  root.netType === "wifi" ? "󰖩" : "󰈀"
                    color: Theme.textDim
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIcon }
                }
            }

            // ── Stats ─────────────────────────────────────────
            Row {
                width: parent.width; spacing: 20

                Repeater {
                    model: [
                        { icon: "󰇚", label: "Download", value: root.downloadText },
                        { icon: "󰕒", label: "Upload",   value: root.uploadText   }
                    ]
                    delegate: Row {
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:  modelData.icon
                            color: Qt.rgba(1, 1, 1, 0.40)
                            font { family: Theme.fontFamily; pixelSize: Theme.fontSizeIconLarge }
                        }
                        Column {
                            Text { text: modelData.label; color: Theme.textSecondary; font { family: Theme.fontFamily; pixelSize: Theme.fontSizeExtraSmall } }
                            Text {
                                text:    modelData.value
                                color:   Theme.textActive
                                opacity: 0.85
                                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeBody; weight: Font.Medium }
                            }
                        }
                    }
                }
            }
        }
    }
}