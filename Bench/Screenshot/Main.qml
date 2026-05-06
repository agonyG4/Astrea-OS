import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    readonly property string fullImagePath: Quickshell.env("ASTREA_SCREENSHOT_FULL") || ""
    readonly property string outputPath: Quickshell.env("ASTREA_SCREENSHOT_OUTPUT") || ""
    property real startX: 0
    property real startY: 0
    property real currentX: 0
    property real currentY: 0
    property bool selecting: false
    property bool saving: false
    readonly property real selectionLeft: Math.min(startX, currentX)
    readonly property real selectionTop: Math.min(startY, currentY)
    readonly property real selectionWidth: Math.abs(currentX - startX)
    readonly property real selectionHeight: Math.abs(currentY - startY)
    readonly property bool hasSelection: selectionWidth >= 1 || selectionHeight >= 1

    function selectionGeometry() {
        var x = Math.round(Math.min(startX, currentX))
        var y = Math.round(Math.min(startY, currentY))
        var w = Math.round(Math.abs(currentX - startX))
        var h = Math.round(Math.abs(currentY - startY))

        if (w < 6 || h < 6)
            return ""

        return w + "x" + h + "+" + x + "+" + y
    }

    function saveSelection() {
        if (saving)
            return

        saving = true
        var geometry = selectionGeometry()
        if (geometry === "") {
            saveProcess.command = ["magick", fullImagePath, outputPath]
        } else {
            saveProcess.command = ["magick", fullImagePath, "-crop", geometry, "+repage", outputPath]
        }
        saveProcess.running = true
    }

    Process {
        id: saveProcess
        command: []
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                Qt.quit()
                return
            }

            copyProcess.command = ["bash", "-c", "wl-copy -t image/png < \"$1\"", "wl-copy", root.outputPath]
            copyProcess.running = true
        }
    }

    Process {
        id: copyProcess
        command: []
        running: false
        onExited: function() {
            Qt.quit()
        }
    }

    PanelWindow {
        id: overlay

        visible: true
        color: "#000000"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WlrLayershell.namespace: "bench-screenshot-freeze"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Image {
            id: frozenFrame
            anchors.fill: parent
            source: root.fullImagePath !== "" ? "file://" + root.fullImagePath : ""
            fillMode: Image.Stretch
            asynchronous: false
            cache: false
            smooth: false
        }

        Rectangle {
            anchors.fill: parent
            color: "#66000000"
            visible: !root.hasSelection && !root.saving
        }

        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: root.selectionTop
            color: "#66000000"
            visible: root.hasSelection && !root.saving
        }

        Rectangle {
            x: 0
            y: root.selectionTop
            width: root.selectionLeft
            height: root.selectionHeight
            color: "#66000000"
            visible: root.hasSelection && !root.saving
        }

        Rectangle {
            x: root.selectionLeft + root.selectionWidth
            y: root.selectionTop
            width: parent.width - x
            height: root.selectionHeight
            color: "#66000000"
            visible: root.hasSelection && !root.saving
        }

        Rectangle {
            x: 0
            y: root.selectionTop + root.selectionHeight
            width: parent.width
            height: parent.height - y
            color: "#66000000"
            visible: root.hasSelection && !root.saving
        }

        Rectangle {
            id: selection
            x: root.selectionLeft
            y: root.selectionTop
            width: root.selectionWidth
            height: root.selectionHeight
            visible: root.hasSelection
            color: "transparent"
            border.color: "#f5f5f5"
            border.width: 1
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    Qt.quit()
                    return
                }

                root.startX = mouse.x
                root.startY = mouse.y
                root.currentX = mouse.x
                root.currentY = mouse.y
                root.selecting = true
            }

            onPositionChanged: function(mouse) {
                if (!root.selecting)
                    return

                root.currentX = mouse.x
                root.currentY = mouse.y
            }

            onReleased: function(mouse) {
                if (mouse.button !== Qt.LeftButton || !root.selecting)
                    return

                root.currentX = mouse.x
                root.currentY = mouse.y
                root.selecting = false
                root.saveSelection()
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: Qt.quit()
        }
    }
}
