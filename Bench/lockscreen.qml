import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    Process {
        id: authProcess

        command: ["/home/vitor/GitHub/Astrea-OS/Bench/auth_helper", "vitor", passwordField.text]
        running: false

        onExited: function(code) {
            authProcess.running = false
            if (code === 0) {
                unlockAnimation.start()
            } else {
                passwordBox.shake()
                passwordField.text = ""
                statusText.text = "Senha incorreta"
                statusTimer.restart()
            }
        }
    }

    PanelWindow {
        id: lockscreen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        color: "transparent"

        NumberAnimation {
            id: unlockAnimation
            target: mainRect
            property: "opacity"
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
            onFinished: Qt.quit()
        }

        Rectangle {
            id: mainRect
            anchors.fill: parent

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#0d1117" }
                GradientStop { position: 1.0; color: "#161b22" }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space && !passwordSection.visible) {
                    passwordSection.visible = true
                    passwordField.forceActiveFocus()
                    event.accepted = true
                }
            }

            focus: true

            ColumnLayout {
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 60
                }
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: "#8b949e"
                    font.pixelSize: 20
                    text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
                }

                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignHCenter
                    color: "white"
                    font.pixelSize: 80
                    font.weight: Font.Thin
                    font.family: "monospace"

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                    }

                    Component.onCompleted: {
                        text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }
            }

            Text {
                id: hintText
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 80
                }
                color: "#484f58"
                font.pixelSize: 13
                text: "Pressione espaço para desbloquear"
                visible: !passwordSection.visible

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
                spacing: 16

                Behavior on opacity { NumberAnimation { duration: 200 } }
                opacity: visible ? 1 : 0

                Text {
                    id: statusText
                    Layout.alignment: Qt.AlignHCenter
                    color: "#f85149"
                    font.pixelSize: 13
                    text: ""
                    opacity: text !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Timer {
                        id: statusTimer
                        interval: 2000
                        onTriggered: statusText.text = ""
                    }
                }

                Rectangle {
                    id: passwordBox
                    Layout.alignment: Qt.AlignHCenter
                    color: "#21262d"
                    border.color: passwordField.activeFocus ? "#58a6ff" : "#30363d"
                    border.width: 1
                    radius: 20
                    implicitWidth: 260
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

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        TextInput {
                            id: passwordField
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            color: "white"
                            font.pixelSize: 14
                            echoMode: TextInput.Password
                            cursorVisible: activeFocus

                            Keys.onReturnPressed: {
                                if (text.length > 0 && !authProcess.running)
                                    authProcess.running = true
                            }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_K && (event.modifiers & Qt.MetaModifier)) {
                                    unlockAnimation.start()
                                }
                                if (event.key === Qt.Key_Escape) {
                                    passwordField.text = ""
                                    passwordSection.visible = false
                                    mainRect.forceActiveFocus()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Digite sua senha..."
                                color: "#484f58"
                                font.pixelSize: 14
                                visible: passwordField.text === ""
                            }
                        }
                    }
                }
            }

            Repeater {
                model: 20

                Rectangle {
                    required property int index
                    width: (index % 3) + 1
                    height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.1)
                    x: (index * 137) % parent.width
                    y: (index * 97)  % parent.height

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.05
                            duration: 2000 + (index * 200)
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 0.4
                            duration: 2000 + (index * 150)
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }
    }
}