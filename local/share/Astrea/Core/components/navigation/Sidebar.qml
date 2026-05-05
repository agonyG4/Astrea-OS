import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".." as Components

Item {
    id: root

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

    Components.SidebarFrame {
        anchors.fill: parent
        backgroundColor: Qt.rgba(1, 1, 1, 0.05)
        washColor: Qt.rgba(1, 1, 1, 0.015)
        borderColor: Qt.rgba(1, 1, 1, 0.08)
        contentTopPadding: 16
        contentBottomPadding: 16
        contentSpacing: 2

        // ── Profile header ────────────────────────────────────────────────
        Item {
            width: parent.width - 32
            x: 16
            height: 64

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

                    Components.AvatarImage {
                        anchors.fill: parent
                        imagePath: root.avatarPath
                        imageVersion: root.avatarVersion
                        fallbackText: root.userName.length > 0
                            ? root.userName[0].toUpperCase()
                            : "?"
                        fallbackFontFamily: Components.Theme.fontFamily
                        fallbackFontPixelSize: Components.Theme.fontSizeAvatar
                        fallbackFontWeight: Components.Theme.fontWeightMedium
                        sourceScale: 4
                        maskMargin: 1
                        borderWidth: 1
                        borderColor: Qt.rgba(1, 1, 1, 0.18)
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
            width: parent.width - 32
            x: 16
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        Item { width: 1; height: 4 }

        // ── Nav items ─────────────────────────────────────────────────────
        Repeater {
            model: root.model
            delegate: Item {
                width: parent.width
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

        Item { width: 1; height: 8 }
    }
}
