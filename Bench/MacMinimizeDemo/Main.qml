import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: window

    visible: true
    width: 620
    height: 390
    minimumWidth: 360
    minimumHeight: 220
    title: "Mac Minimize Demo"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    property bool minimizing: false
    property real chromeRadius: 14

    function minimizeWithFreeze() {
        if (minimizing)
            return

        minimizing = true
        frozenLayer.scheduleUpdate()
        frozenLayer.live = false
        frozenLayer.visible = true
        appSurface.visible = false
        minimizeAnimation.restart()
    }

    function restoreAnimationState() {
        minimizing = false
        frozenLayer.visible = false
        frozenLayer.opacity = 1
        frozenLayer.scale = 1
        frozenLayer.x = 0
        frozenLayer.y = 0
        appSurface.visible = true
        frozenLayer.live = true
    }

    onVisibilityChanged: {
        if (window.visibility !== Window.Minimized)
            restoreAnimationState()
    }

    onClosing: function(close) {
        close.accepted = false
    }

    Rectangle {
        id: appSurface
        anchors.fill: parent
        radius: window.chromeRadius
        color: "#17181b"
        border.color: "#33363d"
        border.width: 1
        layer.enabled: true

        Rectangle {
            id: titlebar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 42
            radius: window.chromeRadius
            color: "#22242a"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: window.chromeRadius
                color: titlebar.color
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: window.startSystemMove()
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                WindowDot {
                    fill: "#ff5f57"
                    stroke: "#d64842"
                    enabledDot: false
                    tooltip: "Fechar desativado"
                }

                WindowDot {
                    fill: "#ffbd2e"
                    stroke: "#d99f24"
                    tooltip: "Minimizar"
                    onClicked: window.minimizeWithFreeze()
                }

                WindowDot {
                    fill: "#28c840"
                    stroke: "#20a934"
                    enabledDot: false
                    tooltip: "Zoom desativado"
                }
            }
        }
    }

    ShaderEffectSource {
        id: frozenLayer
        sourceItem: appSurface
        hideSource: false
        live: true
        recursive: true
        width: window.width
        height: window.height
        transformOrigin: Item.BottomLeft
        smooth: true
        opacity: 1
        visible: false
    }

    ParallelAnimation {
        id: minimizeAnimation

        SequentialAnimation {
            NumberAnimation {
                target: frozenLayer
                property: "scale"
                to: 0.08
                duration: 420
                easing.type: Easing.InCubic
            }
        }

        NumberAnimation {
            target: frozenLayer
            property: "x"
            to: 34
            duration: 420
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: frozenLayer
            property: "y"
            to: window.height - 12
            duration: 420
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: frozenLayer
            property: "opacity"
            to: 0
            duration: 420
            easing.type: Easing.InCubic
        }

        onStopped: {
            if (window.minimizing)
                window.showMinimized()
        }
    }

    component WindowDot: Item {
        id: dotRoot

        signal clicked()

        property color fill: "#ffffff"
        property color stroke: "#000000"
        property bool enabledDot: true
        property string tooltip: ""

        width: 14
        height: 14
        opacity: enabledDot ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: dotRoot.fill
            border.color: dotRoot.stroke
            border.width: 1
        }

        MouseArea {
            id: dotMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: dotRoot.enabledDot ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: {
                if (dotRoot.enabledDot)
                    dotRoot.clicked()
            }
        }

        ToolTip.visible: dotMouse.containsMouse
        ToolTip.text: dotRoot.tooltip
        ToolTip.delay: 350
    }
}
