import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

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
    property string displayName: ""
    property string avatarPath: ""
    property string homeDir: Quickshell.env("HOME") || ""
    property int userId: parseInt(Quickshell.env("UID") || "0")
    property int avatarVersion: 0
    property bool avatarBusy: false
    property bool profileBusy: false
    property string pendingDisplayName: ""
    property bool autologinEnabled: false
    property string profileStatusText: ""
    property string avatarStatusText: ""
    property string pickedAvatarPath: ""
    readonly property string avatarApplyScript: "/usr/local/bin/astrea-set-profile-image"
    readonly property string userProfileScript: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + "/Core/bridge/system/user_profile.py"

    Component.onCompleted: {
        userName = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
        displayName = userName
        avatarPath = "/var/lib/AccountsService/icons/" + userName
        profileStateProc.running = true
    }

    function parseProfilePayload(raw, source) {
        const text = (raw || "").trim()
        if (text === "")
            return
        try {
            const payload = JSON.parse(text)
            if (payload.displayName !== undefined)
                displayName = payload.displayName || userName
            if (payload.autologinEnabled !== undefined)
                autologinEnabled = payload.autologinEnabled === true
        } catch (e) {
            profileStatusText = "Failed to parse " + source + " state."
        }
    }

    function applyDisplayName(name) {
        const trimmed = (name || "").trim().replace(/\s+/g, " ")
        if (trimmed === "" || profileBusy || trimmed === displayName || trimmed === pendingDisplayName)
            return
        pendingDisplayName = trimmed
        profileBusy = true
        profileStatusText = "Waiting for authentication..."
        displayNameProc.command = [
            "python3",
            userProfileScript,
            "set-display-name",
            "--user",
            userName,
            "--name",
            trimmed
        ]
        displayNameProc.running = false
        displayNameProc.running = true
    }

    function setSddmAutologin(enabled) {
        profileBusy = true
        profileStatusText = "Waiting for authentication..."
        autologinProc.command = [
            "python3",
            userProfileScript,
            "set-sddm-autologin",
            "--user",
            userName,
            "--enabled",
            enabled ? "1" : "0"
        ]
        autologinProc.running = false
        autologinProc.running = true
    }

    ScrollPage {
        anchors.fill: parent
        contentMargins: 28
        maxWidth: 900

        SectionHeader {
            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.text.user_profile"]) || "USER PROFILE")
            Layout.bottomMargin: 12
            textSecondary: root.textSecondary
        }

        FormCard {
            Layout.bottomMargin: 28

            Item {
                Layout.fillWidth: true
                implicitHeight: profileHeader.implicitHeight + 32

                ColumnLayout {
                    id: profileHeader
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 20
                    }
                    spacing: 14

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: 96
                        height: 96

                        AvatarImage {
                            anchors.fill: parent
                            imagePath: root.avatarPath
                            imageVersion: root.avatarVersion
                            fallbackText: root.displayName.length > 0
                                ? root.displayName[0].toUpperCase()
                                : "?"
                            fallbackFontPixelSize: 40
                            fallbackFontWeight: Font.Medium
                            sourceScale: 4
                            maskMargin: 2
                            borderWidth: 1.5
                            borderColor: Qt.rgba(1, 1, 1, 0.16)
                        }

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
                                text: root.avatarBusy ? "\uf110" : "\uf040"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: root.textPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: root.avatarBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
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

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.displayName || root.userName
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.text.administrator"]) || "Administrator")
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        color: root.textSecondary
                        Layout.topMargin: -8
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
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.label.display_name"]) || "Display Name")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.sublabel.name_shown_on_lockscreen_and_menus"]) || "Name shown on lockscreen and menus")
                textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder

                RowLayout {
                    spacing: 8

                    Rectangle {
                        implicitWidth: 250
                        implicitHeight: 32
                        radius: Theme.controlRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: root.cardBorder

                        TextInput {
                            id: displayNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.displayName
                            color: root.textPrimary
                            font.pixelSize: Theme.fontSizeSmall
                            selectionColor: root.accent
                            enabled: !root.profileBusy
                            onEditingFinished: {
                                const normalized = (text || "").trim().replace(/\s+/g, " ")
                                if (text !== normalized)
                                    text = normalized
                            }
                            Keys.onReturnPressed: root.applyDisplayName(text)
                            Keys.onEnterPressed: root.applyDisplayName(text)
                        }
                    }

                    Button {
                        label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.text.save"]) || "Save")
                        controlWidth: 72
                        controlHeight: 32
                        enabled: !root.profileBusy
                        onClicked: root.applyDisplayName(displayNameInput.text)
                    }
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.label.change_password"]) || "Change Password")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.sublabel.update_your_login_and_sudo_password"]) || "Update your login and sudo password")
                textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder

                Button {
                    label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.text.change"]) || "Change...")
                    controlWidth: 120
                    controlHeight: 32
                }
            }

            SettingRow {
                label: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.label.automatic_login"]) || "Automatic Login SDDM")
                sublabel: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["apps.settings.pages.personalization.user.sublabel.login_without_asking_for_password"]) || "Create SDDM autologin for this user")
                isLast: true
                textPrimary: root.textPrimary; textSecondary: root.textSecondary; cardBorder: root.cardBorder

                ToggleSwitch {
                    id: autologinToggle
                    checked: root.autologinEnabled
                    enabled: !root.profileBusy
                    onToggled: (targetChecked) => root.setSddmAutologin(targetChecked)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.bottomMargin: 16
                visible: text.length > 0
                text: root.profileStatusText
                color: text.indexOf("Failed") === 0 ? "#ff7b72" : root.textSecondary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }

    Process {
        id: profileStateProc
        running: false
        command: ["python3", root.userProfileScript, "state", "--user", root.userName]
        stdout: SplitParser { onRead: (line) => root.parseProfilePayload(line, "profile") }
    }

    Process {
        id: displayNameProc
        running: false
        stdout: SplitParser { onRead: (line) => root.parseProfilePayload(line, "display name") }
        onExited: (code) => {
            root.profileBusy = false
            root.pendingDisplayName = ""
            root.profileStatusText = code === 0 ? "Display name updated." : "Failed to update display name."
            if (code !== 0)
                profileStateProc.running = true
        }
    }

    Process {
        id: autologinProc
        running: false
        stdout: SplitParser { onRead: (line) => root.parseProfilePayload(line, "SDDM autologin") }
        onExited: (code) => {
            root.profileBusy = false
            root.profileStatusText = code === 0 ? "SDDM autologin updated." : "Failed to update SDDM autologin."
            if (code !== 0) {
                autologinToggle.visualChecked = root.autologinEnabled
                profileStateProc.running = true
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
