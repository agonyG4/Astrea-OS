import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

ShellRoot {
    id: root

    property bool promptVisible: false
    property string currentMessage: ""
    property string currentAction: ""
    property int themeMode: 0
    property int shellStyle: 0
    property string accentHex: "#0a84ff"
    property bool authLocked: false
    property string localErrorMessage: ""
    property var i18nMessages: ({})
    property string i18nBuffer: ""
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarPath: "/var/lib/AccountsService/icons/" + userName
    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")
    readonly property string themeConfigPath: (Quickshell.env("HOME") || "") + "/.config/AstreaOS/ui/theme.json"
    readonly property string i18nHelperPath: astreaRoot + "/System/i18n/i18n.py"
    readonly property bool isLightTheme: themeMode === 1
    readonly property bool isTransparentShell: shellStyle === 0 || shellStyle === 2
    readonly property color accent: accentHex
    readonly property color accentForeground: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.62 ? "#111111" : "#ffffff"
    readonly property color textPrimary: isLightTheme ? Qt.rgba(0.05, 0.06, 0.07, 0.94) : Qt.rgba(0.96, 0.96, 0.98, 0.94)
    readonly property color textSecondary: isLightTheme ? Qt.rgba(0.13, 0.15, 0.18, 0.76) : Qt.rgba(0.92, 0.94, 0.96, 0.72)
    readonly property color textTertiary: isLightTheme ? Qt.rgba(0.13, 0.15, 0.18, 0.50) : Qt.rgba(0.92, 0.94, 0.96, 0.48)
    readonly property color cardBorder: {
        if (shellStyle === 0)
            return isLightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)
        if (shellStyle === 2)
            return isLightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.06)
        return isLightTheme ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    }
    readonly property color popupBg: isTransparentShell
        ? (isLightTheme ? Qt.rgba(0.98, 0.98, 0.99, 0.92) : Qt.rgba(0.11, 0.11, 0.12, 0.92))
        : (isLightTheme ? Qt.rgba(0.98, 0.98, 0.99, 1) : Qt.rgba(0.11, 0.11, 0.12, 1))
    readonly property color windowWash: {
        if (shellStyle === 0)
            return isLightTheme ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        if (shellStyle === 2)
            return isLightTheme ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        return isLightTheme ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.02)
    }
    readonly property color errorColor: "#ff453a"
    readonly property string fontFamily: "Inter"
    readonly property int fontSizeLarge: 14
    readonly property int fontSizeNormal: 13
    readonly property int fontSizeSmall: 11
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightDemiBold: Font.Medium
    readonly property real opacityDisabled: 0.55
    readonly property real opacityMuted: 0.6
    readonly property int animationQuick: 120
    readonly property color overlayDim: isLightTheme
        ? Qt.rgba(1, 1, 1, isTransparentShell ? 0.16 : 0.22)
        : Qt.rgba(0, 0, 0, isTransparentShell ? 0.18 : 0.36)
    readonly property color cardColor: isTransparentShell
        ? popupBg
        : (isLightTheme ? Qt.rgba(0.95, 0.95, 0.96, 0.98) : Qt.rgba(0.11, 0.11, 0.12, 0.98))
    readonly property color fieldColor: isLightTheme
        ? Qt.rgba(1, 1, 1, isTransparentShell ? 0.72 : 0.92)
        : Qt.rgba(1, 1, 1, isTransparentShell ? 0.085 : 0.11)
    readonly property color disabledFieldColor: isLightTheme
        ? Qt.rgba(0, 0, 0, 0.055)
        : Qt.rgba(1, 1, 1, 0.045)

    function t(key, fallback) {
        return (i18nMessages && i18nMessages[key]) || fallback || key
    }

    function applyThemeConfig(text) {
        try {
            var cfg = JSON.parse(text || "{}")
            var nextThemeMode = cfg.theme_mode === 1 ? 1 : 0
            if (typeof cfg.theme === "string")
                nextThemeMode = cfg.theme.toLowerCase() === "light" ? 1 : 0
            var nextShellStyle = typeof cfg.shell_style === "number" ? cfg.shell_style : 1
            if (nextShellStyle < 0 || nextShellStyle > 2)
                nextShellStyle = 1
            themeMode = nextThemeMode
            shellStyle = nextShellStyle
            accentHex = typeof cfg.accent === "string" && cfg.accent !== "" ? cfg.accent : "#0a84ff"
        } catch (e) {
            themeMode = 0
            shellStyle = 1
            accentHex = "#0a84ff"
        }
    }

    function loadI18nPayload() {
        try {
            var payload = JSON.parse(i18nBuffer || "{}")
            var merged = ({})
            var fallback = payload.fallback || ({})
            var active = payload.strings || ({})
            for (var fallbackKey in fallback)
                merged[fallbackKey] = fallback[fallbackKey]
            for (var activeKey in active)
                merged[activeKey] = active[activeKey]
            i18nMessages = merged
        } catch (e) {
            i18nMessages = ({})
        }
        i18nBuffer = ""
    }

    function activeFlow() {
        return polkit.flow
    }

    function polishedMessage() {
        var message = currentMessage || ""
        if (message === "" || message.length > 88 || message.indexOf("/usr/bin") !== -1 || message.indexOf("pkexec") !== -1)
            return t("features.polkit.auth.permission_message", "Astrea wants permission to make changes.")
        return message
    }

    function resetPrompt() {
        usernameField.text = ""
        passwordField.text = ""
        localErrorMessage = ""
        authLocked = false
        currentMessage = activeFlow() ? activeFlow().message : t("features.polkit.auth.default_message", "Authentication is required.")
        currentAction = activeFlow() ? activeFlow().actionId : ""
    }

    function rejectAttempt(message) {
        localErrorMessage = message
        passwordField.text = ""
        authLocked = true
        shakeAnim.restart()
        unlockTimer.restart()
    }

    function submit() {
        if (!activeFlow() || !activeFlow().isResponseRequired || authLocked)
            return
        if (usernameField.text.trim() !== userName) {
            rejectAttempt(t("features.polkit.auth.invalid_user", "Enter the current user name to continue."))
            return
        }
        if (passwordField.text.length === 0) {
            rejectAttempt(t("features.polkit.auth.empty_password", "Enter your password to continue."))
            return
        }
        authLocked = true
        activeFlow().submit(passwordField.text)
        passwordField.text = ""
    }

    function cancel() {
        if (activeFlow())
            activeFlow().cancelAuthenticationRequest()
        promptVisible = false
        usernameField.text = ""
        passwordField.text = ""
        localErrorMessage = ""
        authLocked = false
    }

    PolkitAgent {
        id: polkit
        path: "/org/astrea/PolicyKit1/AuthenticationAgent"

        onAuthenticationRequestStarted: {
            root.promptVisible = true
            root.resetPrompt()
            focusTimer.restart()
        }

        onFlowChanged: {
            if (flow) {
                root.promptVisible = true
                root.resetPrompt()
                focusTimer.restart()
            }
        }
    }

    FileView {
        id: themeFile
        path: root.themeConfigPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyThemeConfig(text())
    }

    Process {
        id: i18nProc
        command: ["python3", root.i18nHelperPath, "dump"]
        running: true
        stdout: SplitParser {
            onRead: data => root.i18nBuffer += data
        }
        onExited: root.loadI18nPayload()
    }

    Connections {
        target: polkit.flow
        ignoreUnknownSignals: true

        function onIsResponseRequiredChanged() {
            focusTimer.restart()
        }

        function onInputPromptChanged() {
            focusTimer.restart()
        }

        function onSupplementaryMessageChanged() {
            focusTimer.restart()
        }

        function onAuthenticationSucceeded() {
            root.promptVisible = false
            usernameField.text = ""
            passwordField.text = ""
            root.localErrorMessage = ""
            root.authLocked = false
        }

        function onAuthenticationFailed() {
            root.rejectAttempt(root.t("features.polkit.auth.failed", "Authentication failed."))
        }

        function onAuthenticationRequestCancelled() {
            root.promptVisible = false
            usernameField.text = ""
            passwordField.text = ""
            root.localErrorMessage = ""
            root.authLocked = false
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: usernameField.text.length === 0 ? usernameField.focusField() : passwordField.focusField()
    }

    Timer {
        id: unlockTimer
        interval: 650
        repeat: false
        onTriggered: {
            root.authLocked = false
            focusTimer.restart()
        }
    }

    FloatingWindow {
        id: authWindow
        visible: root.promptVisible && polkit.flow !== null
        title: "Astrea Authentication"
        implicitWidth: 360
        implicitHeight: 372
        minimumSize: Qt.size(360, 372)
        maximumSize: Qt.size(360, 372)
        color: "transparent"

        Rectangle {
            id: card
            anchors.fill: parent
            property real shakeOffset: 0
            focus: true
            radius: 11
            color: root.cardColor
            border.width: 1
            border.color: root.isLightTheme ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.16)
            antialiasing: true
            transform: Translate { x: card.shakeOffset }
            Keys.onEscapePressed: root.cancel()

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: card; property: "shakeOffset"; to: -10; duration: 50 }
                NumberAnimation { target: card; property: "shakeOffset"; to: 10; duration: 50 }
                NumberAnimation { target: card; property: "shakeOffset"; to: -10; duration: 50 }
                NumberAnimation { target: card; property: "shakeOffset"; to: 10; duration: 50 }
                NumberAnimation { target: card; property: "shakeOffset"; to: 0; duration: 50 }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: root.windowWash
                visible: root.isTransparentShell || root.isLightTheme
                antialiasing: true
            }

            ColumnLayout {
                id: content
                anchors {
                    fill: parent
                    leftMargin: 18
                    rightMargin: 18
                    topMargin: 16
                    bottomMargin: 14
                }
                spacing: 7

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 66
                    Layout.preferredHeight: 66

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.isLightTheme ? 0.16 : 0.22)
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: root.userName.length > 0 ? root.userName[0].toUpperCase() : "?"
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: 27
                            font.weight: Font.DemiBold
                        }
                    }

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: root.avatarPath
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: status === Image.Ready
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarImage.width
                                height: avatarImage.height
                                radius: width / 2
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.isLightTheme ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(1, 1, 1, 0.28)
                        antialiasing: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.t("features.polkit.auth.title", "Authentication Required")
                    color: root.textPrimary
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSizeLarge
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 44
                    text: root.polishedMessage()
                    color: root.textPrimary
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSizeNormal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeight: 16
                    lineHeightMode: Text.FixedHeight
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: root.t("features.polkit.auth.instruction", "Enter an administrator's name and password to allow this.")
                    color: root.textSecondary
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSizeNormal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeight: 16
                    lineHeightMode: Text.FixedHeight
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    visible: polkit.flow && polkit.flow.supplementaryMessage !== ""
                    text: polkit.flow ? polkit.flow.supplementaryMessage : ""
                    color: polkit.flow && polkit.flow.supplementaryIsError ? root.errorColor : root.textSecondary
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.localErrorMessage !== ""
                    text: root.localErrorMessage
                    color: root.errorColor
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                }

                MacAuthTextField {
                    id: usernameField
                    Layout.fillWidth: true
                    placeholder: root.t("features.polkit.auth.username", "Username")
                    enabled: !root.authLocked
                    onAccepted: passwordField.focusField()
                }

                MacAuthTextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholder: root.t("features.polkit.auth.password", "Password")
                    echoMode: polkit.flow && polkit.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    enabled: polkit.flow && polkit.flow.isResponseRequired && !root.authLocked
                    onAccepted: root.submit()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Layout.topMargin: 5

                    MacAuthButton {
                        Layout.fillWidth: true
                        text: root.t("features.polkit.auth.cancel", "Cancel")
                        onClicked: root.cancel()
                    }

                    MacAuthButton {
                        Layout.fillWidth: true
                        text: root.t("features.polkit.auth.ok", "OK")
                        primary: true
                        enabled: usernameField.text.trim().length > 0 && passwordField.text.length > 0 && !root.authLocked
                        onClicked: root.submit()
                    }
                }
            }
        }
    }

    component MacAuthTextField: Rectangle {
        property alias text: input.text
        property alias readOnly: input.readOnly
        property alias echoMode: input.echoMode
        property string placeholder: ""
        signal accepted()

        function focusField() {
            input.forceActiveFocus()
        }

        implicitHeight: 32
        radius: 6
        color: enabled ? root.fieldColor : root.disabledFieldColor
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? root.accent : root.cardBorder
        opacity: enabled ? 1 : root.opacityMuted

        Behavior on color { ColorAnimation { duration: root.animationQuick; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: root.animationQuick; easing.type: Easing.OutCubic } }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            verticalAlignment: TextInput.AlignVCenter
            color: root.textPrimary
            selectionColor: root.accent
            selectedTextColor: root.accentForeground
            font.family: root.fontFamily
            font.pixelSize: root.fontSizeLarge
            renderType: TextInput.NativeRendering
            onAccepted: parent.accepted()
            Keys.onEscapePressed: root.cancel()
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: 11
                verticalCenter: parent.verticalCenter
            }
            visible: input.text.length === 0 && !input.activeFocus
            text: placeholder
            color: root.textTertiary
            font.family: root.fontFamily
            font.pixelSize: root.fontSizeLarge
            renderType: Text.NativeRendering
        }
    }

    component MacAuthButton: Rectangle {
        property string text: ""
        property bool primary: false
        readonly property bool hovered: hoverHandler.hovered
        readonly property bool pressed: pressArea.pressed
        signal clicked()

        implicitHeight: 31
        radius: 6
        opacity: enabled ? 1 : (primary ? 0.58 : 0.82)
        color: {
            if (primary)
                return enabled ? (pressed ? Qt.darker(root.accent, 1.12) : root.accent) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.62)
            if (pressed)
                return root.isLightTheme ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.20)
            if (hovered)
                return root.isLightTheme ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.17)
            return root.isLightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.13)
        }
        border.width: primary ? 0 : 1
        border.color: root.cardBorder
        scale: enabled && pressed ? 0.985 : 1

        Behavior on color { ColorAnimation { duration: root.animationQuick; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.animationQuick; easing.type: Easing.OutCubic } }

        HoverHandler { id: hoverHandler; enabled: parent.enabled }

        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            text: parent.text
            color: parent.primary ? root.accentForeground : root.textPrimary
            font.family: root.fontFamily
            font.pixelSize: root.fontSizeLarge
            font.weight: root.fontWeightMedium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: pressArea
            anchors.fill: parent
            enabled: parent.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
