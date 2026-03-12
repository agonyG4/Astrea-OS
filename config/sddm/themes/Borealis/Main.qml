import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0
import QtGraphicalEffects 1.15

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#000000"
    focus: true

    property bool unlocking: false
    property int sessionIndex: sessionModel.lastIndex

    Component.onCompleted: passwordInput.forceActiveFocus()

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "/usr/share/sddm/themes/Borealis/assets/wallpaper/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
    }

    GaussianBlur {
        anchors.fill: wallpaper
        source: wallpaper
        radius: unlocking ? 30 : 0
        samples: 61
        cached: true
        Behavior on radius { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    }
    // Island
    Rectangle {
        id: island
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        width: 120
        height: 34
        radius: 20
        color: "#000000"
        clip: true

        Image {
            anchors.centerIn: parent
            width: 15
            height: 18
            source: "/usr/share/sddm/themes/Borealis/assets/island/lock.png"
            fillMode: Image.PreserveAspectFit
        }
    }

    // Relógio
    Text {
        id: clock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -300
        color: "#ffffff"
        font.pixelSize: 105
        opacity: 0.4
        font.family: "Inter"
        font.weight: Font.Light
        renderType: Text.QtRendering

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm")
        }
        Component.onCompleted: text = Qt.formatTime(new Date(), "hh:mm")
    }

    // Data
    Text {
        anchors.top: clock.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        color: "#888888"
        font.pixelSize: 18
        font.family: "Inter"
        text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
    }

    // Container senha
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 100
        spacing: 10
        opacity: unlocking ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

        // Reforça foco quando o campo aparece
        onVisibleChanged: {
            if (visible) passwordInput.forceActiveFocus()
        }

        // Nome do usuário
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: userModel.data(userModel.index(userModel.lastIndex, 0), Qt.DisplayRole) || "usuário"
            color: "#ffffff"
            font.family: "Inter"
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        // Caixa liquid glass
        Rectangle {
            id: passwordBox
            width: 300
            height: 52
            radius: 26
            color: "#33ffffff"
            border.color: Qt.rgba(0, 0, 0, 0.50)
            border.width: 1
            clip: true

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                echoMode: TextInput.Password
                color: "#000000"
                font.family: "Inter"
                font.pixelSize: 15
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter

                Keys.onPressed: (event) => {
                    // Ativa o campo sem descartar o caractere digitado
                    if (!unlocking) {
                        unlocking = true
                        // NÃO setar event.accepted = true aqui
                    }
                }

                Keys.onReturnPressed: {
                    // Busca o username de login (UserRole+1), não o nome de exibição
                    var username = userModel.data(
                        userModel.index(userModel.lastIndex, 0),
                        Qt.UserRole + 1
                    )
                    sddm.login(username, passwordInput.text, sessionIndex)
                }
            }

            // Placeholder
            Text {
                anchors.centerIn: parent
                text: "senha"
                color: "#aaffffff"
                font.family: "Inter Display"
                font.pixelSize: 15
                visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
            }
        }
    }

    // Captura teclas mesmo antes de unlocking ser true
    Keys.onPressed: (event) => {
        if (!unlocking) {
            unlocking = true
        }
    }
}