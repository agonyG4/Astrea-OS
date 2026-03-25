import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Rectangle {
    id: root
    color: Qt.rgba(1, 1, 1, 0.05)

    required property var   model
    required property int   selectedIndex
    signal selectIndex(int index)          // ← estava faltando isso

    property string userName:   ""
    property string avatarPath: ""

    Component.onCompleted: {
        userName   = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
        avatarPath = "/var/lib/AccountsService/icons/" + userName
    }

    // ── Borda direita ─────────────────────────────────────────────────────
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // ── Layout principal ──────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; topMargin: 16; bottomMargin: 16 }
        spacing: 2

        // ── Profile header ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 82
            Layout.bottomMargin: 8

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                // Avatar
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 52
                    height: 52

                    // Fallback: círculo com inicial
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0.04, 0.52, 1.0, 0.18)
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: root.userName.length > 0
                                  ? root.userName[0].toUpperCase()
                                  : "?"
                            font.pixelSize: 22
                            font.weight: Font.Medium
                            color: "#0a84ff"
                        }
                    }

                    // Foto real (sobrepõe o fallback se carregar)
                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: "file://" + root.avatarPath
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        sourceSize: Qt.size(width * 2, height * 2)

                        layer.enabled: visible
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 2, height * 2)
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: avatarImg.width
                                    height: avatarImg.height
                                    radius: width / 2
                                    antialiasing: true
                                }
                                textureSize: Qt.size(avatarImg.width * 2, avatarImg.height * 2)
                                smooth: true
                            }
                        }
                    }

                    // Borda circular (sempre visível, sobre tudo)
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(1, 1, 1, 0.20)
                        antialiasing: true
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 2, height * 2)
                    }
                }

                // Nome
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.userName
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: "#ffffff"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.maximumWidth: root.width - 32
                }
            }
        }

        // Divisor
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 4
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── Nav items ─────────────────────────────────────────────────────
        Repeater {
            model: root.model
            delegate: Item {
                Layout.fillWidth: true
                height: 40
                NavItem {
                    anchors.fill: parent
                    label:    model.label
                    sym:      model.sym
                    selected: root.selectedIndex === index
                    onClicked: root.selectIndex(index)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}