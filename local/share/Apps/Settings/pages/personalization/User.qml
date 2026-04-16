import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../components"

Item {
    id: root
    signal profileImageChanged()

    // ── Theme ─────────────────────────────────────────────────────────────
    property color accent: Theme.accent
    property color textPrimary: Theme.textPrimary
    property color textSecondary: Theme.textSecondary
    property color cardBg: Theme.cardBg
    property color cardBorder: Theme.cardBorder
    property color popupBg: Theme.popupBg

    property string userName: ""
    property string avatarPath: ""
    property string homeDir: Quickshell.env("HOME") || ""
    property int userId: parseInt(Quickshell.env("UID") || "0")
    property int avatarVersion: 0
    property bool avatarBusy: false
    property real spinnerAngle: 0
    property string avatarStatusText: ""
    property string pickedAvatarPath: ""
    readonly property string avatarApplyScript: "/usr/local/bin/astrea-set-profile-image"

    Component.onCompleted: {
        userName = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
        avatarPath = "/var/lib/AccountsService/icons/" + userName
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 28
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 0

            SectionHeader {
                text: "USER PROFILE"
                Layout.bottomMargin: 12
                textSecondary: root.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                radius: 12
                color: root.cardBg
                border.width: 1
                border.color: root.cardBorder
                implicitHeight: profileCardCol.implicitHeight + 40

                ColumnLayout {
                    id: profileCardCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 20 }
                    spacing: 16

                    // Big Avatar
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: 96
                        height: 96

                        AvatarImage {
                            anchors.fill: parent
                            imagePath: root.avatarPath
                            imageVersion: root.avatarVersion
                            fallbackText: root.userName.length > 0
                                ? root.userName[0].toUpperCase()
                                : "?"
                            fallbackFontPixelSize: 40
                            fallbackFontWeight: Font.Medium
                            sourceScale: 4
                            maskMargin: 2
                            borderWidth: 1.5
                            borderColor: Qt.rgba(1, 1, 1, 0.16)
                        }

                        // Edit Button Overlay
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 0; bottomMargin: 0 }
                            width: 30
                            height: 30
                            radius: 15
                            color: Qt.rgba(0.15, 0.15, 0.16, 0.9)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            antialiasing: true
                            
                            Text {
                                anchors.centerIn: parent
                                text: "\uf040" // nf-fa-pencil
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: root.textPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.avatarBusy
                                onClicked: {
                                    root.avatarStatusText = ""
                                    root.pickedAvatarPath = ""
                                    avatarPickerProc.running = false
                                    avatarPickerProc.running = true
                                }
                            }
                        }
                    }

                    // User Name Main
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.userName
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Administrator"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        color: root.textSecondary
                        Layout.topMargin: -8
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 144
                        implicitHeight: 34
                        radius: 8
                        color: avatarChangeArea.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.10)
                               : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        opacity: root.avatarBusy ? 0.75 : 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: root.avatarBusy ? "\uf110" : "\uf030"
                                color: root.textPrimary
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                rotation: root.avatarBusy ? root.spinnerAngle : 0
                            }

                            Text {
                                text: root.avatarBusy ? "Applying..." : "Change photo"
                                color: root.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: avatarChangeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.avatarBusy
                            onClicked: {
                                root.avatarStatusText = ""
                                root.pickedAvatarPath = ""
                                avatarPickerProc.running = false
                                avatarPickerProc.running = true
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: parent.width - 48
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: text.length > 0
                        text: root.avatarStatusText
                        color: text.indexOf("Failed") === 0 ? "#ff7b72" : root.textSecondary
                        font.pixelSize: 11
                    }

                    RotationAnimation {
                        id: spinner
                        target: root
                        property: "spinnerAngle"
                        running: root.avatarBusy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }

                    Item { Layout.preferredHeight: 4 } // Spacer

                    SettingRow {
                        label: "Display Name"
                        sublabel: "Name shown on lockscreen and menus"
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        
                        Rectangle {
                            implicitWidth: 160
                            implicitHeight: 32
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)

                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: root.userName
                                color: root.textPrimary
                                font.pixelSize: 13
                                selectionColor: root.accent
                            }
                        }
                    }

                    SettingRow {
                        label: "Change Password"
                        sublabel: "Update your login and sudo password"
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        
                        Rectangle {
                            implicitWidth: 120
                            implicitHeight: 32
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Change..."
                                color: root.textPrimary
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    SettingRow {
                        label: "Automatic Login"
                        sublabel: "Login without asking for password"
                        isLast: true
                        textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder
                        
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 24
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            
                            Rectangle {
                                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                                width: 20
                                height: 20
                                radius: 10
                                color: "#8e8e93"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: avatarPickerProc
        running: false
        command: [
            "zenity",
            "--file-selection",
            "--title=Choose Profile Picture",
            "--file-filter=Images | *.jpg *.jpeg *.png *.webp *.bmp *.gif"
        ]
        stdout: SplitParser { onRead: (line) => root.pickedAvatarPath = line.trim() }
        onExited: (code) => {
            if (code === 0 && root.pickedAvatarPath) {
                avatarApplyProc.run(root.pickedAvatarPath)
            } else {
                root.pickedAvatarPath = ""
            }
        }
    }

    Process {
        id: avatarApplyProc
        running: false

        function run(src) {
            root.avatarBusy = true
            root.avatarStatusText = "Waiting for authentication..."
            command = [
                "sudo",
                "-n",
                root.avatarApplyScript,
                src,
                root.userName,
                String(root.userId),
                root.homeDir
            ]
            running = false
            running = true
        }

        onExited: (code) => {
            root.avatarBusy = false
            root.pickedAvatarPath = ""

            if (code === 0) {
                root.avatarVersion += 1
                root.avatarStatusText = "Profile photo updated."
                root.profileImageChanged()
            } else {
                root.avatarStatusText = "Failed to update photo. Run the Astrea avatar setup once."
            }
        }
    }
}
