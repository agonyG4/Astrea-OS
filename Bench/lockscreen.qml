import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string currentUser: Quickshell.env("USER")
    readonly property string avatarPath: "file:///var/lib/AccountsService/icons/" + currentUser
    readonly property string wallpaperDir: "file://" + homeDir + "/.local/Astrea/Lockscreen/wallpaper/"

    Process {
        id: authProcess
        command: [homeDir + "/GitHub/Astrea-OS/Bench/auth_helper", root.currentUser, passwordField.text]
        running: false
        onExited: function(code) {
            running = false
            if (code === 0) {
                unlockAnimation.start()
            } else {
                passwordBox.shake()
                passwordField.text = ""
            }
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        Item {
            id: mainRect
            anchors.fill: parent
            focus: true
            opacity: 0

            ParallelAnimation {
                running: true
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
                source: root.wallpaperDir + "wallpaper.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                transformOrigin: Item.Center
            }

            Image {
                anchors.fill: parent
                source: root.wallpaperDir + "blurred.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                opacity: passwordSection.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space && !passwordSection.visible) {
                    passwordSection.visible = true
                    passwordField.forceActiveFocus()
                    event.accepted = true
                }
            }

            // relógio
            ColumnLayout {
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 60
                }
                spacing: 8
                opacity: passwordSection.visible ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: "#8b949e"
                    font.pixelSize: 20
                    font.family: "Inter"
                    text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
                }

                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignHCenter
                    color: "white"
                    font.pixelSize: 100
                    font.weight: Font.Thin
                    font.family: "Inter"
                    Component.onCompleted: text = Qt.formatTime(new Date(), "hh:mm")

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }
            }

            // hint
            Text {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 80
                }
                color: "#ccffffff"
                font.pixelSize: 13
                font.family: "Inter"
                text: "Pressione espaço para desbloquear"
                visible: !passwordSection.visible

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                }
            }

            // dialog de senha
            ColumnLayout {
                id: passwordSection
                visible: false
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -65
                spacing: 0
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // avatar (115x115)
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

                // nome do usuário
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 12
                    color: "white"
                    font.pixelSize: 24
                    font.family: "Inter"
                    font.weight: Font.Regular
                    text: root.currentUser
                }

                // campo de senha
                Rectangle {
                    id: passwordBox
                    Layout.alignment: Qt.AlignHCenter
                    color: "#35ffffff"
                    border.color: "#50000000"
                    border.width: 1
                    radius: 20
                    implicitWidth: 225
                    implicitHeight: 44
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    function shake() { shakeAnim.start() }

                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x - 10; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x + 20; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x - 20; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x + 10; duration: 50 }
                        NumberAnimation { target: passwordBox; property: "x"; to: passwordBox.x;      duration: 50 }
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
                        cursorVisible: activeFocus
                        verticalAlignment: TextInput.AlignVCenter

                        Keys.onReturnPressed: {
                            if (text.length > 0 && !authProcess.running)
                                authProcess.running = true
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_K && (event.modifiers & Qt.MetaModifier))
                                unlockAnimation.start()
                            if (event.key === Qt.Key_Escape) {
                                text = ""
                                passwordSection.visible = false
                                mainRect.forceActiveFocus()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Senha..."
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