import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".." as Components

Rectangle {
    id: root
    color: Qt.rgba(1, 1, 1, 0.05)

    required property var   model
    required property int   selectedIndex
    signal selectIndex(int index)
    signal openUserProfile()

    property string userName:   ""
    property string avatarPath: ""
    property int avatarVersion: 0
    property bool   isSudo:     false

    Component.onCompleted: {
        userName   = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
        avatarPath = "/var/lib/AccountsService/icons/" + userName
        checkSudoProc.running = true
    }

    Process {
        id: checkSudoProc
        command: ["bash", "-c", "groups " + root.userName + " | grep -q 'wheel\\|sudo'"]
        onExited: (exitCode) => root.isSudo = (exitCode === 0)
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
            Layout.preferredHeight: 64
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openUserProfile()
            }

            RowLayout {
                anchors.fill: parent
                spacing: 12

                // Avatar
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    width: 48
                    height: 48

                    // Fallback: círculo com inicial
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0.04, 0.52, 1.0, 0.18)
                        antialiasing: true
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 4, height * 4)
                        layer.samples: 8

                        Text {
                            anchors.centerIn: parent
                            text: root.userName.length > 0
                                  ? root.userName[0].toUpperCase()
                                  : "?"
                            font.family: Components.Theme.fontFamily
                            font.pixelSize: Components.Theme.fontSizeAvatar
                            font.weight: Components.Theme.fontWeightMedium
                            color: "#0a84ff"
                        }
                    }

                    // Foto real (sobrepõe o fallback se carregar)
                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: "file://" + root.avatarPath + "?v=" + root.avatarVersion
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        visible: false
                        asynchronous: true
                        sourceSize: Qt.size(width * 2, height * 2)
                        layer.enabled: true
                    }

                    Rectangle {
                        id: avatarMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: avatarMaskFrame
                        source: avatarImg
                        maskSource: avatarMask
                        antialiasing: true
                    }

                    Item {
                        id: avatarMaskFrame
                        anchors.fill: parent
                        anchors.margins: 1.5
                    }

                    // Borda circular (sempre visível, sobre tudo)
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.25
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        antialiasing: true
                    }
                }

                // Nome e Sudo badge
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.userName
                        font.family: Components.Theme.fontFamily
                        font.pixelSize: Components.Theme.fontSizeLarge
                        font.weight: Components.Theme.fontWeightMedium
                        color: "#ffffff"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "sudo"
                        font.family: Components.Theme.fontFamily
                        font.pixelSize: Components.Theme.fontSizeTiny
                        font.weight: Components.Theme.fontWeightNormal
                        color: Qt.rgba(1, 1, 1, 0.45)
                        visible: root.isSudo
                    }
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
                Components.NavItem {
                    anchors.fill: parent
                    label:      model.label
                    sym:        model.sym !== undefined ? model.sym : ""
                    iconSource: model.iconSource !== undefined ? model.iconSource : ""
                    iconKey:    model.iconKey !== undefined ? model.iconKey : ""
                    selected:   root.selectedIndex === index
                    onClicked:  root.selectIndex(index)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
