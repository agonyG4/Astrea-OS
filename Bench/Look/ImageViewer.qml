import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../Explorer" as Finder

ApplicationWindow {
    id: root
    visible: true
    width: 1000
    height: 700
    title: "ImageLook"
    color: "#0f0f0f"

    property string imagePath: ""
    property string fileName: ""
    property real zoomLevel: 1.0
    property real minZoom: 0.1
    property real maxZoom: 10.0
    property bool fitMode: true

    Shortcut { sequence: "Ctrl+O"; onActivated: fileDialog.openDialog() }
    Shortcut { sequence: "Ctrl+="; onActivated: zoomIn() }
    Shortcut { sequence: "Ctrl+-"; onActivated: zoomOut() }
    Shortcut { sequence: "Ctrl+0"; onActivated: resetZoom() }
    Shortcut { sequence: "F";      onActivated: fitToWindow() }
    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

    function zoomIn()  { setZoom(zoomLevel * 1.25) }
    function zoomOut() { setZoom(zoomLevel * 0.8)  }
    function resetZoom() {
        fitMode = false
        setZoom(1.0)
    }
    function fitToWindow() {
        fitMode = true
        if (img.status === Image.Ready) {
            var scaleW = flickable.width  / img.sourceSize.width
            var scaleH = flickable.height / img.sourceSize.height
            zoomLevel = Math.min(scaleW, scaleH)
        }
    }
    function setZoom(z) {
        fitMode = false
        zoomLevel = Math.max(minZoom, Math.min(maxZoom, z))
    }
    function loadImage(url) {
        imagePath = url
        var parts = url.toString().split("/")
        fileName = parts[parts.length - 1]
        fitMode = true
    }

    header: ToolBar {
        height: 52

        background: Rectangle {
            color: "#1a1a1a"
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#2a2a2a"
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Text {
                text: "◈ ImageViewer"
                font.pixelSize: 15
                font.letterSpacing: 1
                font.weight: Font.Medium
                color: "#e8e8e8"
            }

            Item { Layout.fillWidth: true }

            ToolButton {
                implicitWidth: 80
                implicitHeight: 34
                onClicked: fileDialog.openDialog()
                ToolTip.visible: hovered
                ToolTip.text: "Open image (Ctrl+O)"

                contentItem: RowLayout {
                    spacing: 6
                    Text {
                        text: "⊕"
                        font.pixelSize: 16
                        color: "#e8e8e8"
                    }
                    Text {
                        text: "Open"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#e8e8e8"
                    }
                }

                background: Rectangle {
                    color: parent.hovered ? "#2e2e2e" : "#252525"
                    radius: 6
                    border.color: "#3a3a3a"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            Rectangle { width: 1; height: 28; color: "#2a2a2a" }

            ToolButton {
                implicitWidth: 34
                implicitHeight: 34
                enabled: root.imagePath !== ""
                onClicked: zoomOut()
                ToolTip.visible: hovered
                ToolTip.text: "Zoom out (Ctrl+-)"

                contentItem: Text {
                    text: "−"
                    font.pixelSize: 18
                    color: "#e8e8e8"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.hovered ? "#2e2e2e" : "transparent"
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            Text {
                text: Math.round(zoomLevel * 100) + "%"
                font.pixelSize: 13
                font.family: "monospace"
                color: "#888"
                horizontalAlignment: Text.AlignHCenter
                width: 52
            }

            ToolButton {
                implicitWidth: 34
                implicitHeight: 34
                enabled: root.imagePath !== ""
                onClicked: zoomIn()
                ToolTip.visible: hovered
                ToolTip.text: "Zoom in (Ctrl++)"

                contentItem: Text {
                    text: "+"
                    font.pixelSize: 16
                    color: "#e8e8e8"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.hovered ? "#2e2e2e" : "transparent"
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            ToolButton {
                implicitWidth: 34
                implicitHeight: 34
                enabled: root.imagePath !== ""
                onClicked: fitToWindow()
                ToolTip.visible: hovered
                ToolTip.text: "Fit to window (F)"

                contentItem: Text {
                    text: "⊡"
                    font.pixelSize: 15
                    color: fitMode ? "#7eb8f7" : "#888"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.hovered ? "#2e2e2e" : "transparent"
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            ToolButton {
                implicitWidth: 38
                implicitHeight: 34
                enabled: root.imagePath !== ""
                onClicked: resetZoom()
                ToolTip.visible: hovered
                ToolTip.text: "Actual size (Ctrl+0)"

                contentItem: Text {
                    text: "1:1"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: "#e8e8e8"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.hovered ? "#2e2e2e" : "transparent"
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth:  Math.max(width,  img.width  * zoomLevel)
        contentHeight: Math.max(height, img.height * zoomLevel)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    var factor = (event.angleDelta.y > 0) ? 1.15 : (1 / 1.15)
                    setZoom(zoomLevel * factor)
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: root.imagePath === ""

            Text {
                text: "⬡"
                font.pixelSize: 64
                color: "#2a2a2a"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "No image open"
                font.pixelSize: 18
                font.weight: Font.Light
                font.letterSpacing: 1
                color: "#3a3a3a"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Ctrl+O  or  drag & drop"
                font.pixelSize: 13
                font.family: "monospace"
                color: "#2e2e2e"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Image {
            id: img
            source: root.imagePath
            smooth: zoomLevel < 3
            mipmap: zoomLevel < 1
            cache: false
            fillMode: Image.Pad
            asynchronous: true

            width:  sourceSize.width
            height: sourceSize.height

            x: Math.max(0, (flickable.width  - width  * zoomLevel) / 2) / zoomLevel
            y: Math.max(0, (flickable.height - height * zoomLevel) / 2) / zoomLevel
            scale: zoomLevel
            transformOrigin: Item.TopLeft

            onStatusChanged: {
                if (status === Image.Ready && fitMode) fitToWindow()
            }

            BusyIndicator {
                anchors.centerIn: parent
                running: img.status === Image.Loading
                visible: running
            }

            Rectangle {
                anchors.centerIn: parent
                width: 220
                height: 80
                radius: 10
                color: "#1e1010"
                border.color: "#5a2020"
                border.width: 1
                visible: img.status === Image.Error

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "⚠ Cannot load image"
                        color: "#e06060"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "Unsupported format or missing file"
                        color: "#884444"
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: function(drop) {
            if (drop.hasUrls) loadImage(drop.urls[0])
        }
        onEntered: dropOverlay.visible = true
        onExited:  dropOverlay.visible = false

        Rectangle {
            id: dropOverlay
            anchors.fill: parent
            color: "#40000000"
            visible: false
            border.color: "#7eb8f7"
            border.width: 2

            Text {
                anchors.centerIn: parent
                text: "Drop image here"
                font.pixelSize: 24
                font.weight: Font.Light
                font.letterSpacing: 2
                color: "#7eb8f7"
            }
        }
    }

    footer: Rectangle {
        height: 28
        color: "#141414"
        visible: root.imagePath !== ""

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#222"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 20

            Text {
                text: root.fileName
                font.pixelSize: 12
                font.family: "monospace"
                color: "#666"
                elide: Text.ElideMiddle
                Layout.maximumWidth: 400
            }

            Item { Layout.fillWidth: true }

            Text {
                text: img.status === Image.Ready
                    ? img.sourceSize.width + " × " + img.sourceSize.height + " px"
                    : ""
                font.pixelSize: 12
                font.family: "monospace"
                color: "#555"
            }
        }
    }

    Finder.FileDialog {
        id: fileDialog
        dialogTitle: "Open Image"
        mode: "open_file"
        nameFilters: [
            "Images (*.png *.jpg *.jpeg *.gif *.bmp *.webp *.tiff *.svg *.ico)",
            "All files (*)"
        ]
        onFileChosen: loadImage(fileUrl)
    }
}
