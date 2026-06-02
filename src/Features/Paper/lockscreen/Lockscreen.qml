import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import "../../../System/i18n" as AstreaI18n

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string currentUser: Quickshell.env("USER")
    readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || (homeDir + "/.local/share/Astrea")) + ""
    readonly property string authHelperPath: "/usr/local/libexec/astrea-auth-helper"
    readonly property string avatarPath: "file:///var/lib/AccountsService/icons/" + currentUser
    readonly property string wallpaperDir: "file://" + homeDir + "/.config/AstreaOS/user/paper/lockscreen/"
    readonly property string regionScript: astreaRoot + "/Core/bridge/system/region.py"
    readonly property string regionSettingsPath: homeDir + "/.config/AstreaOS/system/settings.json"
    readonly property var _countryTimeDefaults: ({
        BR: "24h",
        US: "12h",
        PT: "24h",
        GB: "24h",
        FR: "24h",
        ES: "24h",
        DE: "24h",
        IT: "24h",
        CA: "12h",
        JP: "24h",
        AR: "24h",
        CL: "24h",
        UY: "24h"
    })

    property string timeFormat: "24h"
    property string _regionBuf: ""

    function _resolveTimeFormat(region) {
        const selected = String((region && region.time_format) || "system").toLowerCase()
        if (selected === "12h" || selected === "24h")
            return selected
        const country = String((region && region.country_code) || "BR").toUpperCase()
        return _countryTimeDefaults[country] || "24h"
    }

    function _applyRegionPayload(payload) {
        const nextFormat = (payload && (payload.effective_time_format || _resolveTimeFormat((payload.config || {}).region))) || "24h"
        if (nextFormat === "12h" || nextFormat === "24h")
            root.timeFormat = nextFormat
        root._updateClock()
    }

    function _reloadRegionSettings() {
        if (regionProc.running)
            return
        root._regionBuf = ""
        regionProc.command = ["python3", root.regionScript, "get"]
        regionProc.running = true
    }

    function _formatLockTime(now) {
        const h = now.getHours()
        const m = now.getMinutes().toString().padStart(2, "0")
        if (root.timeFormat === "12h")
            return `${(h % 12 || 12)}:${m}`
        return `${h.toString().padStart(2, "0")}:${m}`
    }

    function _updateClock() {
        if (typeof clockText !== "undefined")
            clockText.text = root._formatLockTime(new Date())
    }

    Component.onCompleted: {
        root._reloadRegionSettings()
        root._updateClock()
    }

    Timer {
        id: regionFileReloadDebounce
        interval: 120
        repeat: false
        onTriggered: regionFile.reload()
    }

    Timer {
        id: regionPollTimer
        interval: 15000
        repeat: true
        running: true
        onTriggered: root._reloadRegionSettings()
    }

    Process {
        id: regionProc
        running: false
        command: []
        stdout: SplitParser {
            onRead: data => root._regionBuf += data
        }
        onExited: code => {
            if (code === 0) {
                try {
                    root._applyRegionPayload(JSON.parse(root._regionBuf || "{}"))
                } catch (error) {
                    console.log("Astrea lockscreen region parse failed:", error)
                }
            }
            root._regionBuf = ""
        }
    }

    FileView {
        id: regionFile
        path: root.regionSettingsPath
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: regionFileReloadDebounce.restart()
        onLoaded: {
            try {
                root._applyRegionPayload({ config: JSON.parse(text() || "{}") })
            } catch (error) {
                console.log("Astrea lockscreen settings parse failed:", error)
            }
        }
    }

    Connections {
        target: AstreaI18n.I18n
        function onMessagesChanged() {
            root._updateClock()
        }
    }

    PanelWindow {
        id: lockWindow
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        ShortcutInhibitor {
            enabled: true
            window: lockWindow
        }

        Item {
            id: mainRect
            anchors.fill: parent
            focus: true
            opacity: 0

            function showPasswordPrompt() {
                passwordSection.visible = true
                passwordField.forceActiveFocus()
            }

            Component.onCompleted: forceActiveFocus()

            Process {
                id: authProcess
                property string pendingPassword: ""
                command: [root.authHelperPath, root.currentUser]
                stdinEnabled: true
                running: false
                onStarted: {
                    authProcess.write(authProcess.pendingPassword + "\n")
                    authProcess.pendingPassword = ""
                }
                onExited: function(code) {
                    authProcess.pendingPassword = ""
                    running = false
                    if (code === 0) {
                        unlockAnimation.start()
                    } else {
                        passwordBox.shake()
                        passwordField.text = ""
                        passwordField.forceActiveFocus()
                    }
                }
            }

            Timer {
                interval: 250
                running: true
                repeat: true
                onTriggered: {
                    if (passwordSection.visible)
                        passwordField.forceActiveFocus()
                    else
                        mainRect.forceActiveFocus()
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                preventStealing: true
                onClicked: mainRect.showPasswordPrompt()
                onWheel: wheel => wheel.accepted = true
            }

            ParallelAnimation {
                id: showAnimation
                running: false
                NumberAnimation {
                    target: mainRect
                    property: "opacity"
                    from: 0; to: 1
                    duration: 600
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wallpaperNormal
                    property: "scale"
                    from: 1.08; to: 1.0
                    duration: 700
                    easing.type: Easing.OutCubic
                }
            }

            NumberAnimation {
                id: unlockAnimation
                target: mainRect
                property: "opacity"
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
                onFinished: Qt.quit()
            }

            Image {
                id: wallpaperNormal
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                source: root.wallpaperDir + "wallpaper.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                transformOrigin: Item.Center
                onStatusChanged: {
                    if (status === Image.Ready)
                        showAnimation.start()
                }
            }

            Image {
                anchors.fill: parent
                source: root.wallpaperDir + "blurred.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                opacity: passwordSection.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
            }

            Keys.onPressed: function(event) {
                if (!passwordSection.visible) {
                    mainRect.showPasswordPrompt()
                    event.accepted = true
                }
            }

            ColumnLayout {
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 60
                }
                spacing: -10
                opacity: passwordSection.visible ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: "#8b949e"
                    font.pixelSize: 20
                    font.family: "Inter"
                    text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#aa000000"
                        shadowBlur: 0.8
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                    }
                }

                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignHCenter
                    color: "white"
                    font.pixelSize: 100
                    font.weight: 400
                    font.family: "Inter"
                    text: root._formatLockTime(new Date())
                    Component.onCompleted: root._updateClock()
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#aa000000"
                        shadowBlur: 0.8
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                    }

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: root._updateClock()
                    }
                }
            }

            Text {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 80
                }
                color: "#ccffffff"
                font.pixelSize: 13
                font.family: "Inter"
                text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["features.paper.lockscreen.lockscreen.text.click_or_press_space_to_unlock"]) || "Clique ou pressione espaço para desbloquear")
                visible: !passwordSection.visible
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#aa000000"
                    shadowBlur: 0.8
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 2
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                }
            }

            ColumnLayout {
                id: passwordSection
                visible: false
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -65
                spacing: 0
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 12
                    width: 115
                    height: 115

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: root.avatarPath
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                        visible: false
                        asynchronous: true
                        layer.enabled: true
                    }

                    Rectangle {
                        id: avatarMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: avatarImage
                        source: avatarImage
                        maskSource: avatarMask
                        antialiasing: true
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    renderType: Text.NativeRendering
                    Layout.bottomMargin: 12
                    color: "white"
                    font.pixelSize: 24
                    font.family: "Inter"
                    font.weight: 400
                    text: root.currentUser
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#aa000000"
                        shadowBlur: 0.8
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                    }
                }

                Rectangle {
                    id: passwordBox
                    Layout.alignment: Qt.AlignHCenter
                    color: "#35ffffff"
                    border.color: "#50000000"
                    border.width: 1
                    radius: 20
                    implicitWidth: 225
                    implicitHeight: 44
                    opacity: authProcess.running ? 0.72 : 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    function shake() { shakeAnim.start() }

                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x - 10; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x + 20; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x - 20; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x + 10; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x; duration: 50 }
                    }

                    TextInput {
                        id: passwordField
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }
                        color: "#000000"
                        font.pixelSize: 14
                        font.family: "Inter"
                        echoMode: TextInput.Password
                        readOnly: authProcess.running
                        cursorVisible: activeFocus && !authProcess.running
                        verticalAlignment: TextInput.AlignVCenter

                        Keys.onReturnPressed: {
                            if (text.length > 0 && !authProcess.running) {
                                authProcess.pendingPassword = text
                                text = ""
                                authProcess.running = true
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (authProcess.running) {
                                event.accepted = true
                                return
                            }

                            if (event.key === Qt.Key_Escape) {
                                text = ""
                                passwordSection.visible = false
                                mainRect.forceActiveFocus()
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ((AstreaI18n.I18n.messages && AstreaI18n.I18n.messages["features.paper.lockscreen.lockscreen.text.senha"]) || "Senha...")
                            color: "#80000000"
                            font.pixelSize: 14
                            font.family: "Inter"
                            visible: passwordField.text === ""
                        }
                    }
                }
            }
        }
    }
}
